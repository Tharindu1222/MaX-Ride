import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AuditService {
  constructor(private prisma: PrismaService) {}

  log(
    actorId: string | null,
    action: string,
    entityType?: string,
    entityId?: string,
    metadata?: unknown,
  ) {
    return this.prisma.auditLog.create({
      data: {
        actorId: actorId || undefined,
        action,
        entityType,
        entityId,
        metadata: metadata ? JSON.stringify(metadata) : undefined,
      },
    });
  }
}
