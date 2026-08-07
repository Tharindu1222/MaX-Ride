import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { WalletsService } from '../wallets/wallets.service';
import { AuditService } from '../audit/audit.service';

@Injectable()
export class AdminService {
  constructor(
    private prisma: PrismaService,
    private wallets: WalletsService,
    private audit: AuditService,
  ) {}

  async dashboard() {
    const [
      activeRides,
      completedToday,
      pendingDrivers,
      openTickets,
      sosOpen,
      passengerCount,
      driverCount,
    ] = await Promise.all([
      this.prisma.ride.count({
        where: {
          status: {
            in: [
              'REQUESTED',
              'SEARCHING',
              'DRIVER_OFFERED',
              'DRIVER_ASSIGNED',
              'DRIVER_ARRIVED',
              'TRIP_STARTED',
            ],
          },
        },
      }),
      this.prisma.ride.count({
        where: {
          status: 'TRIP_COMPLETED',
          tripCompletedAt: { gte: new Date(new Date().setHours(0, 0, 0, 0)) },
        },
      }),
      this.prisma.driverProfile.count({
        where: { approvalStatus: { in: ['SUBMITTED', 'UNDER_REVIEW'] } },
      }),
      this.prisma.supportTicket.count({ where: { status: 'OPEN' } }),
      this.prisma.safetyIncident.count({ where: { status: 'OPEN' } }),
      this.prisma.passengerProfile.count(),
      this.prisma.driverProfile.count({ where: { approvalStatus: 'APPROVED' } }),
    ]);

    return {
      activeRides,
      completedToday,
      pendingDrivers,
      openTickets,
      sosOpen,
      passengerCount,
      driverCount,
      platform: 'MaX Ride',
      currency: 'LKR',
    };
  }

  liveRides() {
    return this.prisma.ride.findMany({
      where: {
        status: {
          in: [
            'SEARCHING',
            'DRIVER_OFFERED',
            'DRIVER_ASSIGNED',
            'DRIVER_ARRIVED',
            'TRIP_STARTED',
          ],
        },
      },
      orderBy: { createdAt: 'desc' },
      include: {
        passenger: { include: { user: true } },
        driver: { include: { user: true, location: true } },
        category: true,
      },
      take: 100,
    });
  }

  listPassengers() {
    return this.prisma.passengerProfile.findMany({
      include: { user: true },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  listDrivers(status?: string) {
    return this.prisma.driverProfile.findMany({
      where: status ? { approvalStatus: status as never } : undefined,
      include: {
        user: true,
        documents: true,
        assignments: { include: { vehicle: { include: { category: true } } } },
        wallet: true,
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async reviewDriver(
    adminId: string,
    driverId: string,
    decision: 'APPROVED' | 'REJECTED' | 'SUSPENDED',
    notes?: string,
  ) {
    const driver = await this.prisma.driverProfile.update({
      where: { id: driverId },
      data: {
        approvalStatus: decision,
        approvedAt: decision === 'APPROVED' ? new Date() : undefined,
        approvedBy: adminId,
      },
    });

    // Auto-approve vehicles on driver approve (MVP convenience)
    if (decision === 'APPROVED') {
      const assignments = await this.prisma.vehicleDriverAssignment.findMany({
        where: { driverId },
      });
      for (const a of assignments) {
        await this.prisma.vehicle.update({
          where: { id: a.vehicleId },
          data: { approvalStatus: 'APPROVED' },
        });
      }
      for (const doc of await this.prisma.driverDocument.findMany({
        where: { driverId, status: 'PENDING' },
      })) {
        await this.prisma.driverDocument.update({
          where: { id: doc.id },
          data: { status: 'APPROVED', reviewedAt: new Date(), reviewNotes: notes },
        });
      }
    }

    await this.audit.log(adminId, 'DRIVER_REVIEW', 'DriverProfile', driverId, {
      decision,
      notes,
    });
    return driver;
  }

  async upsertPricing(
    adminId: string,
    data: {
      id?: string;
      vehicleCategoryId: string;
      name: string;
      baseFare: number;
      perKmFare: number;
      perMinuteFare: number;
      bookingFee: number;
      minimumFare: number;
      waitingPerMinute?: number;
      surgeMultiplier?: number;
    },
  ) {
    const payload = {
      vehicleCategoryId: data.vehicleCategoryId,
      name: data.name,
      baseFare: data.baseFare,
      perKmFare: data.perKmFare,
      perMinuteFare: data.perMinuteFare,
      bookingFee: data.bookingFee,
      minimumFare: data.minimumFare,
      waitingPerMinute: data.waitingPerMinute ?? 0,
      surgeMultiplier: data.surgeMultiplier ?? 1,
      currency: 'LKR',
      isActive: true,
    };

    const rule = data.id
      ? await this.prisma.pricingRule.update({ where: { id: data.id }, data: payload })
      : await this.prisma.pricingRule.create({ data: payload });

    await this.audit.log(adminId, 'PRICING_UPSERT', 'PricingRule', rule.id, data);
    return rule;
  }

  listPricing() {
    return this.prisma.pricingRule.findMany({
      include: { category: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async upsertPromo(
    adminId: string,
    data: {
      code: string;
      description?: string;
      discountType: string;
      discountValue: number;
      maxDiscount?: number;
      minFare?: number;
      usageLimit?: number;
      validFrom: string;
      validTo: string;
    },
  ) {
    const promo = await this.prisma.promoCode.upsert({
      where: { code: data.code.toUpperCase() },
      create: {
        code: data.code.toUpperCase(),
        description: data.description,
        discountType: data.discountType,
        discountValue: data.discountValue,
        maxDiscount: data.maxDiscount,
        minFare: data.minFare,
        usageLimit: data.usageLimit,
        validFrom: new Date(data.validFrom),
        validTo: new Date(data.validTo),
      },
      update: {
        description: data.description,
        discountType: data.discountType,
        discountValue: data.discountValue,
        maxDiscount: data.maxDiscount,
        minFare: data.minFare,
        usageLimit: data.usageLimit,
        validFrom: new Date(data.validFrom),
        validTo: new Date(data.validTo),
        isActive: true,
      },
    });
    await this.audit.log(adminId, 'PROMO_UPSERT', 'PromoCode', promo.id, data);
    return promo;
  }

  listPromos() {
    return this.prisma.promoCode.findMany({ orderBy: { createdAt: 'desc' } });
  }

  async walletAdjust(
    adminId: string,
    driverId: string,
    amount: number,
    direction: 'CREDIT' | 'DEBIT',
    description: string,
  ) {
    if (amount <= 0) throw new BadRequestException('Amount must be positive');
    const txn = await this.wallets.adjust(driverId, amount, direction, description);
    await this.audit.log(adminId, 'WALLET_ADJUST', 'DriverWallet', driverId, {
      amount,
      direction,
      description,
    });
    return txn;
  }

  async cancelRide(adminId: string, rideId: string, reason: string) {
    const ride = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (!ride) throw new NotFoundException('Ride not found');
    const updated = await this.prisma.ride.update({
      where: { id: rideId },
      data: {
        status: 'CANCELLED_BY_SYSTEM',
        cancelledAt: new Date(),
        cancellationReason: reason,
      },
    });
    if (ride.driverId) {
      await this.prisma.driverProfile.update({
        where: { id: ride.driverId },
        data: { operationalStatus: 'ONLINE' },
      });
    }
    await this.audit.log(adminId, 'RIDE_CANCEL', 'Ride', rideId, { reason });
    return updated;
  }

  auditLogs() {
    return this.prisma.auditLog.findMany({
      orderBy: { createdAt: 'desc' },
      take: 200,
      include: { actor: true },
    });
  }

  reports() {
    return this.prisma.$transaction(async (tx) => {
      const byStatus = await tx.ride.groupBy({
        by: ['status'],
        _count: true,
      });
      const payments = await tx.payment.aggregate({
        _sum: { amount: true },
        _count: true,
      });
      return {
        ridesByStatus: byStatus,
        paymentVolume: payments._sum.amount,
        paymentCount: payments._count,
        currency: 'LKR',
      };
    });
  }
}
