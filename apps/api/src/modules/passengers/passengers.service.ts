import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class PassengersService {
  constructor(private prisma: PrismaService) {}

  private async getPassenger(userId: string) {
    const p = await this.prisma.passengerProfile.findUnique({
      where: { userId },
      include: { user: true },
    });
    if (!p) {
      throw new NotFoundException({
        code: 'NOT_FOUND',
        message: 'Passenger profile not found',
      });
    }
    return p;
  }

  async getMe(userId: string) {
    return this.getPassenger(userId);
  }

  async updateProfile(userId: string, data: { fullName?: string; email?: string }) {
    await this.getPassenger(userId);
    return this.prisma.user.update({
      where: { id: userId },
      data: {
        fullName: data.fullName,
        email: data.email,
      },
    });
  }

  async listSavedPlaces(userId: string) {
    return this.prisma.savedPlace.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async addSavedPlace(
    userId: string,
    data: { label: string; address: string; latitude: number; longitude: number },
  ) {
    return this.prisma.savedPlace.create({
      data: { userId, ...data },
    });
  }

  async history(userId: string) {
    const passenger = await this.getPassenger(userId);
    return this.prisma.ride.findMany({
      where: { passengerId: passenger.id },
      orderBy: { createdAt: 'desc' },
      take: 50,
      include: {
        category: true,
        driver: { include: { user: true } },
        payments: true,
      },
    });
  }
}
