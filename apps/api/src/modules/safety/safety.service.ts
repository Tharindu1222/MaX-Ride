import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { EventsGateway } from '../../gateways/events.gateway';
import { IncidentLevel } from '@prisma/client';

@Injectable()
export class SafetyService {
  private readonly logger = new Logger(SafetyService.name);

  constructor(
    private prisma: PrismaService,
    private events: EventsGateway,
  ) {}

  async triggerSos(
    userId: string,
    data: {
      rideId?: string;
      latitude?: number;
      longitude?: number;
      notes?: string;
    },
  ) {
    const incident = await this.prisma.safetyIncident.create({
      data: {
        reporterId: userId,
        rideId: data.rideId,
        latitude: data.latitude,
        longitude: data.longitude,
        notes: data.notes,
        level: IncidentLevel.CRITICAL,
        status: 'OPEN',
      },
    });
    this.logger.warn(`[SOS] user=${userId} ride=${data.rideId} incident=${incident.id}`);
    this.events.server?.emit('admin.sos', incident);
    return incident;
  }

  listIncidents() {
    return this.prisma.safetyIncident.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  updateIncident(id: string, status: string) {
    return this.prisma.safetyIncident.update({
      where: { id },
      data: { status },
    });
  }
}
