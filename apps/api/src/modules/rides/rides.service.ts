import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../../prisma/prisma.service';
import { PricingService } from '../pricing/pricing.service';
import { DispatchService } from '../dispatch/dispatch.service';
import { PaymentsService } from '../payments/payments.service';
import { WalletsService } from '../wallets/wallets.service';
import { EventsGateway } from '../../gateways/events.gateway';
import {
  distanceMeters,
  generateRideNumber,
  generateStartPin,
  estimateDurationSeconds,
} from '../../common/utils/geo.util';
import { PaymentMethod, RideStatus } from '@prisma/client';

const VALID: Record<string, string[]> = {
  REQUESTED: ['SEARCHING', 'CANCELLED_BY_PASSENGER', 'CANCELLED_BY_SYSTEM'],
  SEARCHING: [
    'DRIVER_OFFERED',
    'NO_DRIVERS_AVAILABLE',
    'CANCELLED_BY_PASSENGER',
    'CANCELLED_BY_SYSTEM',
  ],
  DRIVER_OFFERED: [
    'DRIVER_ASSIGNED',
    'SEARCHING',
    'NO_DRIVERS_AVAILABLE',
    'CANCELLED_BY_PASSENGER',
    'CANCELLED_BY_SYSTEM',
  ],
  DRIVER_ASSIGNED: [
    'DRIVER_ARRIVED',
    'CANCELLED_BY_PASSENGER',
    'CANCELLED_BY_DRIVER',
    'CANCELLED_BY_SYSTEM',
  ],
  DRIVER_ARRIVED: [
    'TRIP_STARTED',
    'CANCELLED_BY_PASSENGER',
    'CANCELLED_BY_DRIVER',
    'CANCELLED_BY_SYSTEM',
  ],
  TRIP_STARTED: ['TRIP_COMPLETED', 'CANCELLED_BY_SYSTEM'],
  TRIP_COMPLETED: ['PAYMENT_PENDING', 'PAYMENT_FAILED'],
  PAYMENT_PENDING: [],
  PAYMENT_FAILED: [],
  NO_DRIVERS_AVAILABLE: ['SEARCHING', 'CANCELLED_BY_PASSENGER', 'CANCELLED_BY_SYSTEM'],
  CANCELLED_BY_PASSENGER: [],
  CANCELLED_BY_DRIVER: [],
  CANCELLED_BY_SYSTEM: [],
};

@Injectable()
export class RidesService {
  private readonly logger = new Logger(RidesService.name);

  constructor(
    private prisma: PrismaService,
    private pricing: PricingService,
    private dispatch: DispatchService,
    private payments: PaymentsService,
    private wallets: WalletsService,
    private events: EventsGateway,
  ) {}

  async requestRide(
    userId: string,
    dto: {
      vehicleCategoryId: string;
      pickupAddress: string;
      pickupLat: number;
      pickupLng: number;
      dropoffAddress: string;
      dropoffLat: number;
      dropoffLng: number;
      paymentMethod: PaymentMethod;
      promoCode?: string;
      passengerNote?: string;
      idempotencyKey?: string;
    },
  ) {
    const passenger = await this.prisma.passengerProfile.findUnique({
      where: { userId },
    });
    if (!passenger) throw new ForbiddenException('Not a passenger');

    const active = await this.prisma.ride.findFirst({
      where: {
        passengerId: passenger.id,
        status: {
          in: [
            'REQUESTED',
            'SEARCHING',
            'DRIVER_OFFERED',
            'DRIVER_ASSIGNED',
            'DRIVER_ARRIVED',
            'TRIP_STARTED',
            'PAYMENT_PENDING',
          ],
        },
      },
    });
    if (active) {
      throw new ConflictException({
        code: 'RIDE_INVALID_STATE',
        message: 'You already have an active ride',
        details: { rideId: active.id },
      });
    }

    const estimate = await this.pricing.estimate({
      vehicleCategoryId: dto.vehicleCategoryId,
      pickupLat: dto.pickupLat,
      pickupLng: dto.pickupLng,
      dropoffLat: dto.dropoffLat,
      dropoffLng: dto.dropoffLng,
      promoCode: dto.promoCode,
    });

    const pin = generateStartPin();
    const startPinHash = await bcrypt.hash(pin, 8);

    const ride = await this.prisma.ride.create({
      data: {
        rideNumber: generateRideNumber(),
        passengerId: passenger.id,
        vehicleCategoryId: dto.vehicleCategoryId,
        pickupAddress: dto.pickupAddress,
        pickupLat: dto.pickupLat,
        pickupLng: dto.pickupLng,
        dropoffAddress: dto.dropoffAddress,
        dropoffLat: dto.dropoffLat,
        dropoffLng: dto.dropoffLng,
        status: RideStatus.REQUESTED,
        paymentMethod: dto.paymentMethod,
        estimatedDistanceMeters: estimate.estimatedDistanceMeters,
        estimatedDurationSeconds: estimate.estimatedDurationSeconds,
        estimatedFare: estimate.estimatedFare,
        discountAmount: estimate.discountAmount,
        bookingFee: estimate.bookingFee,
        surgeMultiplier: estimate.surgeMultiplier,
        promoCode: dto.promoCode?.toUpperCase(),
        passengerNote: dto.passengerNote,
        startPinHash,
        requestedAt: new Date(),
      },
    });

    await this.recordHistory(ride.id, null, 'REQUESTED', userId, 'PASSENGER');
    this.dispatch.startDispatch(ride.id);

    return {
      ...ride,
      startPin: pin, // shown once to passenger at request (MVP)
    };
  }

  async searchAgain(userId: string, rideId: string) {
    const ride = await this.getRide(userId, rideId);
    if (
      !['NO_DRIVERS_AVAILABLE', 'SEARCHING', 'DRIVER_OFFERED'].includes(
        ride.status,
      )
    ) {
      throw new ConflictException({
        code: 'RIDE_INVALID_STATE',
        message: 'Ride is not waiting for a driver',
      });
    }
    if (ride.status === 'NO_DRIVERS_AVAILABLE') {
      await this.prisma.ride.update({
        where: { id: rideId },
        data: { status: 'SEARCHING' },
      });
      await this.recordHistory(
        rideId,
        'NO_DRIVERS_AVAILABLE',
        'SEARCHING',
        userId,
        'PASSENGER',
      );
    }
    this.dispatch.startDispatch(rideId);
    return this.getRide(userId, rideId);
  }

  async getRide(userId: string, rideId: string) {
    const ride = await this.prisma.ride.findUnique({
      where: { id: rideId },
      include: {
        category: true,
        passenger: { include: { user: true } },
        driver: { include: { user: true, location: true } },
        vehicle: true,
        payments: true,
        offers: true,
        statusHistory: { orderBy: { createdAt: 'asc' } },
      },
    });
    if (!ride) {
      throw new NotFoundException({ code: 'RIDE_NOT_FOUND', message: 'Ride not found' });
    }
    // authorize: passenger, assigned driver, or admin
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { passengerProfile: true, driverProfile: true },
    });
    const isPassenger = user?.passengerProfile?.id === ride.passengerId;
    const isDriver = user?.driverProfile?.id === ride.driverId;
    const isAdmin = user?.userType === 'ADMIN';
    if (!isPassenger && !isDriver && !isAdmin) {
      throw new ForbiddenException('Not allowed');
    }
    return ride;
  }

  async acceptOffer(userId: string, offerId: string) {
    return this.prisma.$transaction(async (tx) => {
      const offer = await tx.rideDriverOffer.findUnique({
        where: { id: offerId },
        include: {
          ride: true,
          driver: { include: { assignments: { where: { active: true }, take: 1 }, user: true } },
        },
      });
      if (!offer) throw new NotFoundException('Offer not found');
      if (offer.driver.userId !== userId) throw new ForbiddenException();
      if (offer.offerStatus !== 'PENDING') {
        throw new ConflictException({ code: 'OFFER_EXPIRED', message: 'Offer not pending' });
      }
      if (offer.expiresAt < new Date()) {
        await tx.rideDriverOffer.update({
          where: { id: offerId },
          data: { offerStatus: 'EXPIRED' },
        });
        throw new ConflictException({ code: 'OFFER_EXPIRED', message: 'Offer expired' });
      }

      const ride = offer.ride;
      if (!['SEARCHING', 'DRIVER_OFFERED'].includes(ride.status)) {
        throw new ConflictException({
          code: 'RIDE_INVALID_STATE',
          message: 'Ride no longer available',
        });
      }

      // Atomic assignment: only update if still unassigned
      const updated = await tx.ride.updateMany({
        where: {
          id: ride.id,
          driverId: null,
          status: { in: ['SEARCHING', 'DRIVER_OFFERED'] },
        },
        data: {
          driverId: offer.driverId,
          vehicleId: offer.driver.assignments[0]?.vehicleId,
          status: 'DRIVER_ASSIGNED',
          driverAssignedAt: new Date(),
        },
      });

      if (updated.count === 0) {
        throw new ConflictException({
          code: 'RIDE_INVALID_STATE',
          message: 'Ride already assigned',
        });
      }

      await tx.rideDriverOffer.update({
        where: { id: offerId },
        data: { offerStatus: 'ACCEPTED', respondedAt: new Date() },
      });
      await tx.rideDriverOffer.updateMany({
        where: {
          rideId: ride.id,
          id: { not: offerId },
          offerStatus: 'PENDING',
        },
        data: { offerStatus: 'CANCELLED', respondedAt: new Date() },
      });
      await tx.driverProfile.update({
        where: { id: offer.driverId },
        data: { operationalStatus: 'BUSY' },
      });
      await tx.rideStatusHistory.create({
        data: {
          rideId: ride.id,
          previousStatus: ride.status,
          newStatus: 'DRIVER_ASSIGNED',
          changedByUserId: userId,
          actorType: 'DRIVER',
        },
      });

      const full = await tx.ride.findUnique({
        where: { id: ride.id },
        include: {
          driver: { include: { user: true, location: true } },
          vehicle: true,
          passenger: { include: { user: true } },
        },
      });

      return full;
    }).then(async (full) => {
      if (!full) return full;
      this.events.emitToPassenger(full.passenger.userId, 'ride.driver_assigned', {
        rideId: full.id,
        driver: {
          id: full.driver?.id,
          name: full.driver?.user.fullName,
          phone: full.driver?.user.phoneNumber,
          rating: full.driver?.averageRating,
        },
        vehicle: full.vehicle,
      });
      this.events.emitToDriver(userId, 'ride.accepted', { rideId: full.id });
      return full;
    });
  }

  async rejectOffer(userId: string, offerId: string) {
    const offer = await this.prisma.rideDriverOffer.findUnique({
      where: { id: offerId },
      include: { driver: true },
    });
    if (!offer || offer.driver.userId !== userId) {
      throw new NotFoundException('Offer not found');
    }
    return this.prisma.rideDriverOffer.update({
      where: { id: offerId },
      data: { offerStatus: 'REJECTED', respondedAt: new Date() },
    });
  }

  async driverArrived(userId: string, rideId: string) {
    const ride = await this.requireDriverRide(userId, rideId);
    this.assertTransition(ride.status, 'DRIVER_ARRIVED');
    const updated = await this.prisma.ride.update({
      where: { id: rideId },
      data: { status: 'DRIVER_ARRIVED', driverArrivedAt: new Date() },
      include: { passenger: true },
    });
    await this.recordHistory(rideId, ride.status, 'DRIVER_ARRIVED', userId, 'DRIVER');
    this.events.emitToPassenger(updated.passenger.userId, 'ride.driver_arrived', { rideId });
    return updated;
  }

  async startTrip(userId: string, rideId: string, pin: string) {
    const ride = await this.requireDriverRide(userId, rideId);
    this.assertTransition(ride.status, 'TRIP_STARTED');
    if (!ride.startPinHash || !(await bcrypt.compare(pin, ride.startPinHash))) {
      throw new BadRequestException({ code: 'PIN_INVALID', message: 'Invalid start PIN' });
    }
    const updated = await this.prisma.ride.update({
      where: { id: rideId },
      data: { status: 'TRIP_STARTED', tripStartedAt: new Date() },
      include: { passenger: true, driver: true },
    });
    await this.prisma.driverProfile.update({
      where: { id: ride.driverId! },
      data: { operationalStatus: 'ON_TRIP' },
    });
    await this.recordHistory(rideId, ride.status, 'TRIP_STARTED', userId, 'DRIVER');
    this.events.emitToPassenger(updated.passenger.userId, 'ride.trip_started', { rideId });
    return updated;
  }

  async completeTrip(userId: string, rideId: string) {
    const ride = await this.requireDriverRide(userId, rideId);
    this.assertTransition(ride.status, 'TRIP_COMPLETED');

    // Prevent double complete
    const locked = await this.prisma.ride.updateMany({
      where: { id: rideId, status: 'TRIP_STARTED' },
      data: { status: 'TRIP_COMPLETED', tripCompletedAt: new Date() },
    });
    if (locked.count === 0) {
      throw new ConflictException({
        code: 'RIDE_INVALID_STATE',
        message: 'Trip already completed or invalid state',
      });
    }

    const actualDistance = distanceMeters(
      Number(ride.pickupLat),
      Number(ride.pickupLng),
      Number(ride.dropoffLat),
      Number(ride.dropoffLng),
    );
    const duration = ride.tripStartedAt
      ? Math.round((Date.now() - ride.tripStartedAt.getTime()) / 1000)
      : estimateDurationSeconds(actualDistance);

    const fare = await this.pricing.computeFinalFare({
      vehicleCategoryId: ride.vehicleCategoryId,
      distanceMeters: actualDistance,
      durationSeconds: duration,
      promoCode: ride.promoCode || undefined,
    });

    await this.prisma.ride.update({
      where: { id: rideId },
      data: {
        actualDistanceMeters: Math.round(actualDistance),
        actualDurationSeconds: duration,
        finalFare: fare.finalFare,
        bookingFee: fare.bookingFee,
        waitingFee: fare.waitingFee,
        discountAmount: fare.discountAmount,
        surgeMultiplier: fare.surgeMultiplier,
        status: ride.paymentMethod === 'CASH' ? 'TRIP_COMPLETED' : 'PAYMENT_PENDING',
      },
    });
    await this.recordHistory(rideId, 'TRIP_STARTED', 'TRIP_COMPLETED', userId, 'DRIVER');

    const payment = await this.payments.settleRide(rideId);

    await this.prisma.driverProfile.update({
      where: { id: ride.driverId! },
      data: {
        operationalStatus: 'ONLINE',
        totalCompletedRides: { increment: 1 },
      },
    });
    await this.dispatch.notifyDriverAvailable(ride.driverId!);

    const full = await this.prisma.ride.findUnique({
      where: { id: rideId },
      include: { passenger: true, payments: true, driver: { include: { user: true } } },
    });

    this.events.emitToPassenger(full!.passenger.userId, 'ride.completed', {
      rideId,
      finalFare: fare.finalFare,
      payment,
    });
    this.events.emitToDriver(userId, 'ride.completed', { rideId, finalFare: fare.finalFare });

    return full;
  }

  async cancelRide(userId: string, rideId: string, reason?: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { passengerProfile: true, driverProfile: true },
    });
    const ride = await this.prisma.ride.findUnique({
      where: { id: rideId },
      include: { passenger: true, driver: { include: { user: true } } },
    });
    if (!ride) throw new NotFoundException('Ride not found');

    const isPassenger = user?.passengerProfile?.id === ride.passengerId;
    const isDriver = user?.driverProfile?.id === ride.driverId;
    if (!isPassenger && !isDriver && user?.userType !== 'ADMIN') {
      throw new ForbiddenException();
    }

    const terminal = [
      'TRIP_COMPLETED',
      'CANCELLED_BY_PASSENGER',
      'CANCELLED_BY_DRIVER',
      'CANCELLED_BY_SYSTEM',
      'NO_DRIVERS_AVAILABLE',
    ];
    if (terminal.includes(ride.status)) {
      throw new ConflictException({ code: 'RIDE_INVALID_STATE', message: 'Cannot cancel' });
    }

    if (ride.status === 'TRIP_STARTED' && isPassenger) {
      throw new BadRequestException('Cannot cancel after trip started');
    }

    const newStatus = isPassenger
      ? 'CANCELLED_BY_PASSENGER'
      : isDriver
        ? 'CANCELLED_BY_DRIVER'
        : 'CANCELLED_BY_SYSTEM';

    const updated = await this.prisma.ride.update({
      where: { id: rideId },
      data: {
        status: newStatus as never,
        cancelledAt: new Date(),
        cancellationReason: reason,
      },
    });
    await this.recordHistory(rideId, ride.status, newStatus, userId, isPassenger ? 'PASSENGER' : 'DRIVER');

    if (ride.driverId) {
      await this.prisma.driverProfile.update({
        where: { id: ride.driverId },
        data: { operationalStatus: 'ONLINE' },
      });
      await this.dispatch.notifyDriverAvailable(ride.driverId);
    }

    this.events.emitToPassenger(ride.passenger.userId, 'ride.cancelled', {
      rideId,
      status: newStatus,
    });
    if (ride.driver?.userId) {
      this.events.emitToDriver(ride.driver.userId, 'ride.cancelled', {
        rideId,
        status: newStatus,
      });
    }

    return updated;
  }

  async rateRide(
    userId: string,
    rideId: string,
    score: number,
    comment?: string,
  ) {
    if (score < 1 || score > 5) throw new BadRequestException('Score 1-5');
    const ride = await this.getRide(userId, rideId);
    if (ride.status !== 'TRIP_COMPLETED') {
      throw new BadRequestException('Ride not completed');
    }
    const rating = await this.prisma.rating.create({
      data: {
        rideId,
        raterId: userId,
        rateeType: ride.passenger.userId === userId ? 'DRIVER' : 'PASSENGER',
        score,
        comment,
      },
    });

    if (ride.driverId && ride.passenger.userId === userId) {
      const agg = await this.prisma.rating.aggregate({
        where: { ride: { driverId: ride.driverId }, rateeType: 'DRIVER' },
        _avg: { score: true },
      });
      await this.prisma.driverProfile.update({
        where: { id: ride.driverId },
        data: { averageRating: agg._avg.score || score },
      });
    }

    return rating;
  }

  private assertTransition(from: string, to: string) {
    if (!VALID[from]?.includes(to)) {
      throw new ConflictException({
        code: 'RIDE_INVALID_STATE',
        message: `Cannot transition ${from} → ${to}`,
      });
    }
  }

  private async requireDriverRide(userId: string, rideId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });
    if (!driver) throw new ForbiddenException();
    const ride = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (!ride || ride.driverId !== driver.id) {
      throw new NotFoundException({ code: 'RIDE_NOT_FOUND', message: 'Ride not found' });
    }
    return ride;
  }

  private async recordHistory(
    rideId: string,
    prev: string | null,
    next: string,
    userId: string | null,
    actorType: string,
  ) {
    await this.prisma.rideStatusHistory.create({
      data: {
        rideId,
        previousStatus: (prev as never) || undefined,
        newStatus: next as never,
        changedByUserId: userId || undefined,
        actorType,
      },
    });
  }
}
