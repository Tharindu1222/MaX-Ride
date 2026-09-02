import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { RedisService } from '../../redis/redis.service';
import { EventsGateway } from '../../gateways/events.gateway';
import { NotificationsService } from '../notifications/notifications.service';
import { distanceMeters } from '../../common/utils/geo.util';

const SEARCH_RADII_KM = [3, 8, 30];
/** Accept window when offers were sent this round */
const OFFER_TTL_SECONDS = 20;
/** Keep searching so a driver who just finished a trip can still be matched */
const SEARCH_WINDOW_MS = 75_000;
const RETRY_PAUSE_MS = 2_000;

type NearbyDriver = {
  driverId: string;
  latitude: number;
  longitude: number;
  distanceM?: number;
};

@Injectable()
export class DispatchService {
  private readonly logger = new Logger(DispatchService.name);
  private readonly inflight = new Set<string>();

  constructor(
    private prisma: PrismaService,
    private redis: RedisService,
    private events: EventsGateway,
    private notifications: NotificationsService,
  ) {}

  /** Fire-and-forget dispatch rounds for a new or waiting ride. */
  async startDispatch(rideId: string) {
    if (this.inflight.has(rideId)) return;
    this.inflight.add(rideId);
    setImmediate(() => {
      this.runDispatch(rideId)
        .catch((e) =>
          this.logger.error(
            `Dispatch failed for ${rideId}: ${e.message}`,
            e.stack,
          ),
        )
        .finally(() => this.inflight.delete(rideId));
    });
  }

  /**
   * Call when a driver becomes free (trip complete / go online) so waiting
   * passengers are matched immediately instead of staying on NO_DRIVERS.
   */
  async notifyDriverAvailable(driverId?: string) {
    await this.healIdleDrivers(driverId);
    if (driverId) {
      const loc = await this.prisma.driverLocation.findUnique({
        where: { driverId },
      });
      if (loc) {
        await this.redis.geoAdd(
          driverId,
          Number(loc.longitude),
          Number(loc.latitude),
        );
      }
    }
    const waiting = await this.prisma.ride.findMany({
      where: {
        status: {
          in: [
            'REQUESTED',
            'SEARCHING',
            'DRIVER_OFFERED',
            'NO_DRIVERS_AVAILABLE',
          ],
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 25,
    });
    for (const ride of waiting) {
      if (ride.status === 'NO_DRIVERS_AVAILABLE') {
        await this.transition(ride.id, 'SEARCHING', ride.status);
      }
      this.startDispatch(ride.id);
    }
  }

  private async runDispatch(rideId: string) {
    const ride = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (
      !ride ||
      ![
        'REQUESTED',
        'SEARCHING',
        'DRIVER_OFFERED',
        'NO_DRIVERS_AVAILABLE',
      ].includes(ride.status)
    ) {
      return;
    }

    if (ride.status === 'NO_DRIVERS_AVAILABLE' || ride.status === 'REQUESTED') {
      await this.transition(rideId, 'SEARCHING', ride.status);
    }
    this.logger.log(
      `Dispatch start ride=${rideId} cat=${ride.vehicleCategoryId}`,
    );

    const deadline = Date.now() + SEARCH_WINDOW_MS;

    while (Date.now() < deadline) {
      const current = await this.prisma.ride.findUnique({
        where: { id: rideId },
      });
      if (
        !current ||
        !['SEARCHING', 'DRIVER_OFFERED'].includes(current.status)
      ) {
        return;
      }

      await this.healIdleDrivers();

      let offeredThisRound = false;
      for (const radiusKm of SEARCH_RADII_KM) {
        const latest = await this.prisma.ride.findUnique({
          where: { id: rideId },
        });
        if (
          !latest ||
          !['SEARCHING', 'DRIVER_OFFERED'].includes(latest.status)
        ) {
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

        const candidates = await this.rankCandidates(
          nearby,
          ride.vehicleCategoryId,
          rideId,
        );

        if (candidates.length === 0) continue;

        for (const c of candidates.slice(0, 5)) {
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

          if (latest.status === 'SEARCHING') {
            await this.transition(rideId, 'DRIVER_OFFERED', 'SEARCHING');
          }
          offeredThisRound = true;

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

        const assigned = await this.prisma.ride.findUnique({
          where: { id: rideId },
        });
        if (assigned?.status === 'DRIVER_ASSIGNED') return;

        await this.prisma.rideDriverOffer.updateMany({
          where: { rideId, offerStatus: 'PENDING' },
          data: { offerStatus: 'EXPIRED' },
        });

        if (assigned?.status === 'DRIVER_OFFERED') {
          await this.transition(rideId, 'SEARCHING', 'DRIVER_OFFERED');
        }
        break;
      }

      if (!offeredThisRound) {
        await this.sleep(RETRY_PAUSE_MS);
      }
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
          body: 'Please try again — drivers may come online shortly.',
          data: { rideId },
        });
      }
      this.logger.warn(`No drivers for ride ${rideId}`);
    }
  }

  private async rankCandidates(
    nearby: NearbyDriver[],
    vehicleCategoryId: string,
    rideId: string,
  ) {
    const pending = await this.prisma.rideDriverOffer.findMany({
      where: {
        rideId,
        offerStatus: 'PENDING',
        expiresAt: { gt: new Date() },
      },
      select: { driverId: true },
    });
    const pendingIds = new Set(pending.map((p) => p.driverId));

    const matched: Array<{
      driver: {
        id: string;
        userId: string;
        averageRating: unknown;
        cancellationRate: unknown;
      };
      distanceM: number;
      score: number;
      categoryMatch: boolean;
    }> = [];

    for (const n of nearby) {
      if (pendingIds.has(n.driverId)) continue;
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
      if (!['ONLINE', 'BUSY', 'ON_TRIP'].includes(driver.operationalStatus)) {
        continue;
      }
      if (driver.operationalStatus !== 'ONLINE') {
        const busyOnTrip = await this.prisma.ride.count({
          where: {
            driverId: driver.id,
            status: {
              in: ['DRIVER_ASSIGNED', 'DRIVER_ARRIVED', 'TRIP_STARTED'],
            },
          },
        });
        if (busyOnTrip > 0) continue;
        await this.prisma.driverProfile.update({
          where: { id: driver.id },
          data: { operationalStatus: 'ONLINE' },
        });
      }
      const vehicle = driver.assignments[0]?.vehicle;
      if (!vehicle) {
        this.logger.debug(`Skip driver ${driver.id}: no active vehicle`);
        continue;
      }

      const categoryMatch = vehicle.vehicleCategoryId === vehicleCategoryId;
      const score =
        1000 -
        (n.distanceM || 0) / 100 +
        Number(driver.averageRating) * 20 -
        Number(driver.cancellationRate) +
        (categoryMatch ? 200 : 0);

      matched.push({
        driver,
        distanceM: n.distanceM || 0,
        score,
        categoryMatch,
      });
    }

    const preferred = matched.filter((m) => m.categoryMatch);
    const pool = preferred.length > 0 ? preferred : matched;
    if (preferred.length === 0 && matched.length > 0) {
      this.logger.warn(
        `Ride ${rideId}: no category match, offering ${matched.length} nearby driver(s)`,
      );
    }
    pool.sort((a, b) => b.score - a.score);
    return pool;
  }

  /**
   * Union Redis GEO + DB locations so a Redis miss cannot hide an online driver.
   */
  private async findNearbyDrivers(
    pickupLat: number,
    pickupLng: number,
    radiusKm: number,
  ): Promise<NearbyDriver[]> {
    const byId = new Map<string, NearbyDriver>();

    try {
      const geo = await this.redis.geoRadius(pickupLng, pickupLat, radiusKm);
      for (const n of geo) byId.set(n.driverId, n);
    } catch (e) {
      this.logger.warn(
        `GEO lookup failed: ${e instanceof Error ? e.message : e}`,
      );
    }

    const online = await this.prisma.driverProfile.findMany({
      where: {
        approvalStatus: 'APPROVED',
        operationalStatus: { in: ['ONLINE', 'BUSY', 'ON_TRIP'] },
        location: { isNot: null },
      },
      include: { location: true },
    });

    for (const d of online) {
      if (!d.location) continue;
      const dist = distanceMeters(
        pickupLat,
        pickupLng,
        Number(d.location.latitude),
        Number(d.location.longitude),
      );
      if (dist <= radiusKm * 1000) {
        byId.set(d.id, {
          driverId: d.id,
          latitude: Number(d.location.latitude),
          longitude: Number(d.location.longitude),
          distanceM: Math.round(dist),
        });
        await this.redis.geoAdd(
          d.id,
          Number(d.location.longitude),
          Number(d.location.latitude),
        );
      }
    }

    return [...byId.values()].sort(
      (a, b) => (a.distanceM || 0) - (b.distanceM || 0),
    );
  }

  /** Drivers stuck BUSY/ON_TRIP after a finished ride cannot receive new offers. */
  async healIdleDrivers(driverId?: string) {
    const stuck = await this.prisma.driverProfile.findMany({
      where: {
        ...(driverId ? { id: driverId } : {}),
        operationalStatus: { in: ['BUSY', 'ON_TRIP'] },
        rides: {
          none: {
            status: {
              in: ['DRIVER_ASSIGNED', 'DRIVER_ARRIVED', 'TRIP_STARTED'],
            },
          },
        },
      },
      include: { location: true },
    });

    for (const d of stuck) {
      await this.prisma.driverProfile.update({
        where: { id: d.id },
        data: { operationalStatus: 'ONLINE' },
      });
      if (d.location) {
        await this.redis.geoAdd(
          d.id,
          Number(d.location.longitude),
          Number(d.location.latitude),
        );
      }
      this.logger.log(`Healed driver ${d.id} ${d.operationalStatus} → ONLINE`);
    }
  }

  private async transition(
    rideId: string,
    newStatus: string,
    previous?: string,
  ) {
    if (previous === newStatus) return;
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
