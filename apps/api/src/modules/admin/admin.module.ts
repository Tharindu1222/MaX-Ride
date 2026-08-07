import { Module } from '@nestjs/common';
import { AdminService } from './admin.service';
import { AdminController } from './admin.controller';
import { WalletsModule } from '../wallets/wallets.module';
import { AuditModule } from '../audit/audit.module';

@Module({
  imports: [WalletsModule, AuditModule],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
