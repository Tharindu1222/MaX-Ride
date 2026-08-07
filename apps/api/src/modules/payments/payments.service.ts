import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { WalletsService } from '../wallets/wallets.service';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    private prisma: PrismaService,
    private wallets: WalletsService,
    private config: ConfigService,
  ) {}

  async settleRide(rideId: string) {
    const ride = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (!ride || ride.finalFare == null) return null;

    const amount = Number(ride.finalFare);
    const idempotencyKey = `ride-pay-${rideId}`;

    const existing = await this.prisma.payment.findUnique({
      where: { idempotencyKey },
    });
    if (existing) return existing;

    if (ride.paymentMethod === 'CASH') {
      const payment = await this.prisma.payment.create({
        data: {
          rideId,
          passengerId: ride.passengerId,
          paymentMethod: 'CASH',
          gateway: 'MOCK_CASH',
          amount,
          currency: this.config.get('CURRENCY', 'LKR'),
          status: 'CASH_COLLECTED',
          idempotencyKey,
          paidAt: new Date(),
        },
      });
      if (ride.driverId) {
        await this.wallets.recordCashTrip(ride.driverId, rideId, amount);
      }
      return payment;
    }

    // Mock card gateway — always succeeds
    this.logger.log(`[MOCK CARD] Charging LKR ${amount} for ride ${rideId}`);
    const payment = await this.prisma.payment.create({
      data: {
        rideId,
        passengerId: ride.passengerId,
        paymentMethod: 'CARD',
        gateway: 'MOCK_CARD',
        gatewayReference: `mock_${Date.now()}`,
        amount,
        currency: this.config.get('CURRENCY', 'LKR'),
        status: 'CAPTURED',
        idempotencyKey,
        paidAt: new Date(),
      },
    });

    await this.prisma.ride.update({
      where: { id: rideId },
      data: { status: 'TRIP_COMPLETED' },
    });

    if (ride.driverId) {
      await this.wallets.recordCardTrip(ride.driverId, rideId, amount);
    }

    return payment;
  }

  async listForAdmin() {
    return this.prisma.payment.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: { ride: true },
    });
  }
}
