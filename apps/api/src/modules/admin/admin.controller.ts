import { Body, Controller, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import {
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
} from 'class-validator';
import { AdminService } from './admin.service';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';

class ReviewDriverDto {
  @IsEnum(['APPROVED', 'REJECTED', 'SUSPENDED'] as const)
  decision!: 'APPROVED' | 'REJECTED' | 'SUSPENDED';
  @IsOptional() @IsString() notes?: string;
}

class PricingDto {
  @IsOptional() @IsUUID() id?: string;
  @IsUUID() vehicleCategoryId!: string;
  @IsString() name!: string;
  @IsNumber() baseFare!: number;
  @IsNumber() perKmFare!: number;
  @IsNumber() perMinuteFare!: number;
  @IsNumber() bookingFee!: number;
  @IsNumber() minimumFare!: number;
  @IsOptional() @IsNumber() waitingPerMinute?: number;
  @IsOptional() @IsNumber() surgeMultiplier?: number;
}

class PromoDto {
  @IsString() code!: string;
  @IsOptional() @IsString() description?: string;
  @IsString() discountType!: string;
  @IsNumber() discountValue!: number;
  @IsOptional() @IsNumber() maxDiscount?: number;
  @IsOptional() @IsNumber() minFare?: number;
  @IsOptional() @IsNumber() usageLimit?: number;
  @IsString() validFrom!: string;
  @IsString() validTo!: string;
}

class WalletAdjustDto {
  @IsUUID() driverId!: string;
  @IsNumber() amount!: number;
  @IsEnum(['CREDIT', 'DEBIT'] as const) direction!: 'CREDIT' | 'DEBIT';
  @IsString() description!: string;
}

class CancelRideDto {
  @IsString() reason!: string;
}

@ApiTags('admin')
@ApiBearerAuth()
@Roles('ADMIN', 'SUPER_ADMIN', 'OPERATIONS', 'VERIFICATION', 'FINANCE', 'MARKETING', 'SUPPORT')
@Controller('admin')
export class AdminController {
  constructor(private admin: AdminService) {}

  @Get('dashboard')
  dashboard() {
    return this.admin.dashboard();
  }

  @Get('rides/live')
  liveRides() {
    return this.admin.liveRides();
  }

  @Get('passengers')
  passengers() {
    return this.admin.listPassengers();
  }

  @Get('drivers')
  drivers(@Query('status') status?: string) {
    return this.admin.listDrivers(status);
  }

  @Patch('drivers/:id/review')
  review(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ReviewDriverDto,
  ) {
    return this.admin.reviewDriver(user.id, id, dto.decision, dto.notes);
  }

  @Get('pricing')
  pricing() {
    return this.admin.listPricing();
  }

  @Post('pricing')
  upsertPricing(@CurrentUser() user: AuthUser, @Body() dto: PricingDto) {
    return this.admin.upsertPricing(user.id, dto);
  }

  @Get('promos')
  promos() {
    return this.admin.listPromos();
  }

  @Post('promos')
  upsertPromo(@CurrentUser() user: AuthUser, @Body() dto: PromoDto) {
    return this.admin.upsertPromo(user.id, dto);
  }

  @Post('wallets/adjust')
  walletAdjust(@CurrentUser() user: AuthUser, @Body() dto: WalletAdjustDto) {
    return this.admin.walletAdjust(
      user.id,
      dto.driverId,
      dto.amount,
      dto.direction,
      dto.description,
    );
  }

  @Post('rides/:id/cancel')
  cancelRide(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: CancelRideDto,
  ) {
    return this.admin.cancelRide(user.id, id, dto.reason);
  }

  @Get('audit')
  audit() {
    return this.admin.auditLogs();
  }

  @Get('reports')
  reports() {
    return this.admin.reports();
  }
}
