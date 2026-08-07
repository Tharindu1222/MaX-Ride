import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { TicketCategory } from '@prisma/client';

@Injectable()
export class SupportService {
  constructor(private prisma: PrismaService) {}

  create(
    userId: string,
    data: {
      category: TicketCategory;
      subject: string;
      description: string;
      rideId?: string;
    },
  ) {
    return this.prisma.supportTicket.create({
      data: { userId, ...data },
    });
  }

  listMine(userId: string) {
    return this.prisma.supportTicket.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  listAll() {
    return this.prisma.supportTicket.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  updateStatus(id: string, status: string) {
    return this.prisma.supportTicket.update({
      where: { id },
      data: { status: status as never },
    });
  }
}
