import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { RedisService } from '../../redis/redis.service';
import { DriverApprovalStatus, DriverOperationalStatus } from '@prisma/client';
import { DispatchService } from '../dispatch/dispatch.service';

@Injectable()
export class DriversService {
  constructor(
    private prisma: PrismaService,
    private redis: RedisService,
    private dispatch: DispatchService,
  ) {}

  private async getDriverByUser(userId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
      include: {
        documents: true,
        assignments: { include: { vehicle: { include: { category: true } } } },
        wallet: true,
        location: true,
        user: true,
      },
    });
    if (!driver) {
      throw new NotFoundException({ code: 'NOT_FOUND', message: 'Driver profile not found' });
    }
    return driver;
  }

  async getMe(userId: string) {
    return this.getDriverByUser(userId);
  }

  async updateProfile(
    userId: string,
    data: {
      fullName?: string;
      nicNumber?: string;
      drivingLicenseNumber?: string;
      dateOfBirth?: string;
    },
  ) {
    const driver = await this.getDriverByUser(userId);
    if (data.fullName) {
      await this.prisma.user.update({
        where: { id: userId },
        data: { fullName: data.fullName },
      });
    }
    return this.prisma.driverProfile.update({
      where: { id: driver.id },
      data: {
        nicNumber: data.nicNumber,
        drivingLicenseNumber: data.drivingLicenseNumber,
        dateOfBirth: data.dateOfBirth ? new Date(data.dateOfBirth) : undefined,
      },
    });
  }

  async submitApplication(userId: string) {
    const driver = await this.getDriverByUser(userId);
    if (driver.approvalStatus === 'APPROVED') {
      throw new BadRequestException('Already approved');
    }
    return this.prisma.driverProfile.update({
      where: { id: driver.id },
      data: { approvalStatus: DriverApprovalStatus.SUBMITTED },
    });
  }

  async uploadDocument(
    userId: string,
    documentType: string,
    fileUrl: string,
    expiresAt?: string,
  ) {
    const driver = await this.getDriverByUser(userId);
    return this.prisma.driverDocument.create({
      data: {
        driverId: driver.id,
        documentType: documentType as never,
        fileUrl,
        expiresAt: expiresAt ? new Date(expiresAt) : undefined,
      },
    });
  }

  async registerVehicle(
    userId: string,
    data: {
      vehicleCategoryId: string;
      registrationNumber: string;
      make?: string;
      model?: string;
      manufactureYear?: number;
      color?: string;
    },
  ) {
    const driver = await this.getDriverByUser(userId);
    const registrationNumber = data.registrationNumber.trim().toUpperCase();
    if (!registrationNumber) {
      throw new BadRequestException({
        code: 'VALIDATION_FAILED',
        message: 'Registration number is required',
      });
    }

    let vehicle = await this.prisma.vehicle.findUnique({
      where: { registrationNumber },
    });

    if (vehicle) {
      // Idempotent for re-submit: update details and rebind to this driver
      vehicle = await this.prisma.vehicle.update({
        where: { id: vehicle.id },
        data: {
          vehicleCategoryId: data.vehicleCategoryId,
          make: data.make,
          model: data.model,
          manufactureYear: data.manufactureYear,
          color: data.color,
          isActive: true,
        },
      });
    } else {
      vehicle = await this.prisma.vehicle.create({
        data: {
          vehicleCategoryId: data.vehicleCategoryId,
          registrationNumber,
          make: data.make,
          model: data.model,
          manufactureYear: data.manufactureYear,
          color: data.color,
        },
      });
    }

    await this.prisma.vehicleDriverAssignment.upsert({
      where: {
        vehicleId_driverId: {
          vehicleId: vehicle.id,
          driverId: driver.id,
        },
      },
      create: {
        vehicleId: vehicle.id,
        driverId: driver.id,
        isPrimary: true,
        active: true,
      },
      update: {
        isPrimary: true,
        active: true,
      },
    });

    return vehicle;
  }

  async setOnlineStatus(userId: string, online: boolean) {
    const driver = await this.getDriverByUser(userId);
    if (online) {
      if (driver.approvalStatus !== 'APPROVED') {
        throw new ForbiddenException({
          code: 'FORBIDDEN',
          message: 'Driver not approved',
        });
      }
      if (driver.assignments.length === 0) {
        throw new BadRequestException('Register a vehicle first');
      }
    }

    const operationalStatus = online
      ? DriverOperationalStatus.ONLINE
      : DriverOperationalStatus.OFFLINE;

    const updated = await this.prisma.driverProfile.update({
      where: { id: driver.id },
      data: { operationalStatus },
    });

    if (!online) {
      await this.redis.geoRemove(driver.id);
      return updated;
    }

    // Dispatch matches drivers by live GEO. Wait for the app to POST /location.
    if (driver.location) {
      const lat = Number(driver.location.latitude);
      const lng = Number(driver.location.longitude);
      await this.prisma.driverLocation.upsert({
        where: { driverId: driver.id },
        create: { driverId: driver.id, latitude: lat, longitude: lng },
        update: { latitude: lat, longitude: lng },
      });
      await this.redis.geoAdd(driver.id, lng, lat);
    }
    await this.dispatch.notifyDriverAvailable(driver.id);

    return updated;
  }

  async updateLocation(
    userId: string,
    lat: number,
    lng: number,
    heading?: number,
    speedMps?: number,
  ) {
    const driver = await this.getDriverByUser(userId);

    const location = await this.prisma.driverLocation.upsert({
      where: { driverId: driver.id },
      create: {
        driverId: driver.id,
        latitude: lat,
        longitude: lng,
        heading,
        speedMps,
      },
      update: {
        latitude: lat,
        longitude: lng,
        heading,
        speedMps,
      },
    });

    // Re-read status so a concurrent go-online still lands in GEO index
    const status = (
      await this.prisma.driverProfile.findUnique({ where: { id: driver.id } })
    )?.operationalStatus;

    if (
      status === 'ONLINE' ||
      status === 'ON_TRIP' ||
      status === 'BUSY'
    ) {
      await this.redis.geoAdd(driver.id, lng, lat);
    }

    return location;
  }

  async earnings(userId: string) {
    const driver = await this.getDriverByUser(userId);
    const wallet = driver.wallet;
    const recent = await this.prisma.walletTransaction.findMany({
      where: { walletId: wallet?.id },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
    const trips = await this.prisma.ride.count({
      where: { driverId: driver.id, status: 'TRIP_COMPLETED' },
    });
    return { wallet, totalCompletedTrips: trips, transactions: recent };
  }

  async pendingOffers(userId: string) {
    const driver = await this.getDriverByUser(userId);
    return this.prisma.rideDriverOffer.findMany({
      where: {
        driverId: driver.id,
        offerStatus: 'PENDING',
        expiresAt: { gt: new Date() },
      },
      include: {
        ride: {
          include: { category: true, passenger: { include: { user: true } } },
        },
      },
      orderBy: { offeredAt: 'desc' },
    });
  }

  async activeRide(userId: string) {
    const driver = await this.getDriverByUser(userId);
    return this.prisma.ride.findFirst({
      where: {
        driverId: driver.id,
        status: {
          in: ['DRIVER_ASSIGNED', 'DRIVER_ARRIVED', 'TRIP_STARTED'],
        },
      },
      include: {
        passenger: { include: { user: true } },
        category: true,
      },
    });
  }
}
