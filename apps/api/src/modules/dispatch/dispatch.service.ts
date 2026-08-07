import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { RedisService } from '../../redis/redis.service';
import { EventsGateway } from '../../gateways/events.gateway';
import { NotificationsService } from '../notifications/notifications.service';
import { distanceMeters } from '../../common/utils/geo.util';

const SEARCH_RADII_KM = [3, 8, 20];
/** Accept window when offers were sent this round */
const OFFER_TTL_SECONDS = 25;
/** Short pause between empty radius rounds */
const EMPTY_ROUND_PAUSE_MS = 800;

@Injectable()
export class DispatchService {
  private readonly logger = new Logger(DispatchService.name);

  constructor(
    private prisma: PrismaService,
    private redis: RedisService,
    private events: EventsGateway,
    private notifications: NotificationsService,
  ) {}

  /** Fire-and-forget dispatch rounds for a new ride. */
  async startDispatch(rideId: string) {
    setImmediate(() => {
      this.runDispatch(rideId).catch((e) =>
        this.logger.error(`Dispatch failed for ${rideId}: ${e.message}`, e.stack),
      );
    });
  }

  private async runDispatch(rideId: string) {
    const ride = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (!ride || !['REQUESTED', 'SEARCHING'].includes(ride.status)) return;

    await this.transition(rideId, 'SEARCHING', ride.status);
    this.logger.log(`Dispatch start ride=${rideId} cat=${ride.vehicleCategoryId}`);

    const offeredDrivers = new Set<string>();

    for (const radiusKm of SEARCH_RADII_KM) {
      const current = await this.prisma.ride.findUnique({ where: { id: rideId } });
      if (!current || !['SEARCHING', 'DRIVER_OFFERED'].includes(current.status)) {
        return;
      }

      const nearby = await this.findNearbyDrivers(
        Number(ride.pickupLat),
        Number(ride.pickupLng),
        radiusKm,
      );
      this.logger.log(
        `Ride ${rideId} radius ${radiusKm}km candidates geo=${nearby.length}`,
      );

      const candidates = [];
      for (const n of nearby) {
        if (offeredDrivers.has(n.driverId)) continue;
        const driver = await this.prisma.driverProfile.findUnique({
          where: { id: n.driverId },
          include: {
            assignments: {
              where: { active: true },
              include: { vehicle: true },
              take: 1,
            },
            user: true,
          },
        });
        if (!driver) continue;
        if (driver.approvalStatus !== 'APPROVED') continue;
        if (driver.operationalStatus !== 'ONLINE') continue;
        const vehicle = driver.assignments[0]?.vehicle;
        if (!vehicle) continue;
        if (vehicle.vehicleCategoryId !== ride.vehicleCategoryId) {
          this.logger.debug(
            `Skip driver ${driver.id}: category mismatch ${vehicle.vehicleCategoryId} != ${ride.vehicleCategoryId}`,
          );
          continue;
        }

        const score =
          1000 -
          (n.distanceM || 0) / 100 +
          Number(driver.averageRating) * 20 -
          Number(driver.cancellationRate);

        candidates.push({ driver, distanceM: n.distanceM || 0, score });
      }

      candidates.sort((a, b) => b.score - a.score);
      const top = candidates.slice(0, 5);

      if (top.length === 0) {
        // Do not burn 20s waiting when nobody was offered — expand radius fast
        await this.sleep(EMPTY_ROUND_PAUSE_MS);
        continue;
      }

      for (const c of top) {
        offeredDrivers.add(c.driver.id);
        const expiresAt = new Date(Date.now() + OFFER_TTL_SECONDS * 1000);
        const offer = await this.prisma.rideDriverOffer.create({
          data: {
            rideId,
            driverId: c.driver.id,
            offerStatus: 'PENDING',
            offeredAt: new Date(),
            expiresAt,
            pickupDistanceMeters: c.distanceM,
            pickupEtaSeconds: Math.round((c.distanceM / 1000 / 25) * 3600),
            rankingScore: c.score,
          },
        });

        await this.transition(rideId, 'DRIVER_OFFERED', 'SEARCHING');

        this.logger.log(
          `Offered ride ${rideId} → driver ${c.driver.id} (user ${c.driver.userId}) offer=${offer.id}`,
        );

        this.events.emitToDriver(c.driver.userId, 'ride.offer', {
          offerId: offer.id,
          rideId,
          pickupAddress: ride.pickupAddress,
          dropoffAddress: ride.dropoffAddress,
          estimatedFare: ride.estimatedFare,
          pickupDistanceMeters: c.distanceM,
          expiresAt,
        });

        await this.notifications.push(c.driver.userId, {
          title: 'New ride offer',
          body: `Pickup: ${ride.pickupAddress}`,
          data: { rideId, offerId: offer.id },
        });
      }

      await this.sleep(OFFER_TTL_SECONDS * 1000 + 300);

      const assigned = await this.prisma.ride.findUnique({ where: { id: rideId } });
      if (assigned?.status === 'DRIVER_ASSIGNED') return;

      await this.prisma.rideDriverOffer.updateMany({
        where: { rideId, offerStatus: 'PENDING' },
        data: { offerStatus: 'EXPIRED' },
      });
    }

    const final = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (
      final &&
      ['SEARCHING', 'DRIVER_OFFERED', 'REQUESTED'].includes(final.status)
    ) {
      await this.transition(rideId, 'NO_DRIVERS_AVAILABLE', final.status);
      const passenger = await this.prisma.passengerProfile.findUnique({
        where: { id: final.passengerId },
      });
      if (passenger) {
        this.events.emitToPassenger(passenger.userId, 'ride.no_drivers', {
          rideId,
        });
        await this.notifications.push(passenger.userId, {
          title: 'No drivers available',
          body: 'Please try again in a few minutes.',
          data: { rideId },
        });
      }
      this.logger.warn(`No drivers for ride ${rideId}`);
    }
  }

  /**
   * Prefer Redis GEO; if empty (GPS never posted / Redis restart), fall back to DB locations.
   */
  private async findNearbyDrivers(
    pickupLat: number,
    pickupLng: number,
    radiusKm: number,
  ) {
    let nearby = await this.redis.geoRadius(pickupLng, pickupLat, radiusKm);

    if (nearby.length === 0) {
      const online = await this.prisma.driverProfile.findMany({
        where: {
          operationalStatus: 'ONLINE',
          approvalStatus: 'APPROVED',
          location: { isNot: null },
        },
        include: { location: true },
      });

      nearby = [];
      for (const d of online) {
        if (!d.location) continue;
        const dist = distanceMeters(
          pickupLat,
          pickupLng,
          Number(d.location.latitude),
          Number(d.location.longitude),
        );
        if (dist <= radiusKm * 1000) {
          nearby.push({
            driverId: d.id,
            latitude: Number(d.location.latitude),
            longitude: Number(d.location.longitude),
            distanceM: Math.round(dist),
          });
          // heal GEO index so next search is fast
          await this.redis.geoAdd(
            d.id,
            Number(d.location.longitude),
            Number(d.location.latitude),
          );
        }
      }
      nearby.sort((a, b) => (a.distanceM || 0) - (b.distanceM || 0));
    }

    return nearby;
  }

  private async transition(rideId: string, newStatus: string, previous?: string) {
    await this.prisma.ride.update({
      where: { id: rideId },
      data: { status: newStatus as never },
    });
    await this.prisma.rideStatusHistory.create({
      data: {
        rideId,
        previousStatus: (previous as never) || undefined,
        newStatus: newStatus as never,
        actorType: 'SYSTEM',
      },
    });
  }

  private sleep(ms: number) {
    return new Promise((r) => setTimeout(r, ms));
  }
}
