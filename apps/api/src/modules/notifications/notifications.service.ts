import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(private prisma: PrismaService) {}

  async push(
    userId: string,
    payload: { title: string; body: string; data?: Record<string, unknown> },
  ) {
    // Mock FCM — persist in-app notification
    this.logger.log(`[MOCK FCM] user=${userId} ${payload.title}: ${payload.body}`);
    return this.prisma.notification.create({
      data: {
        userId,
        title: payload.title,
        body: payload.body,
        channel: 'MOCK_FCM',
        dataJson: payload.data ? JSON.stringify(payload.data) : undefined,
      },
    });
  }

  async list(userId: string) {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async markRead(userId: string, id: string) {
    return this.prisma.notification.updateMany({
      where: { id, userId },
      data: { readAt: new Date() },
    });
  }
}
