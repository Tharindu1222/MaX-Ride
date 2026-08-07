import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import {
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
} from 'class-validator';
import { RidesService } from './rides.service';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { PaymentMethod } from '@prisma/client';

class RequestRideDto {
  @IsUUID() vehicleCategoryId!: string;
  @IsString() pickupAddress!: string;
  @IsNumber() pickupLat!: number;
  @IsNumber() pickupLng!: number;
  @IsString() dropoffAddress!: string;
  @IsNumber() dropoffLat!: number;
  @IsNumber() dropoffLng!: number;
  @IsEnum(PaymentMethod) paymentMethod!: PaymentMethod;
  @IsOptional() @IsString() promoCode?: string;
  @IsOptional() @IsString() passengerNote?: string;
  @IsOptional() @IsString() idempotencyKey?: string;
}

class PinDto {
  @IsString() pin!: string;
}

class CancelDto {
  @IsOptional() @IsString() reason?: string;
}

class RateDto {
  @IsNumber() @Min(1) @Max(5) score!: number;
  @IsOptional() @IsString() comment?: string;
}

@ApiTags('rides')
@ApiBearerAuth()
@Controller('rides')
export class RidesController {
  constructor(private rides: RidesService) {}

  @Post()
  request(@CurrentUser() user: AuthUser, @Body() dto: RequestRideDto) {
    return this.rides.requestRide(user.id, dto);
  }

  @Get(':id')
  get(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.rides.getRide(user.id, id);
  }

  @Post('offers/:offerId/accept')
  accept(@CurrentUser() user: AuthUser, @Param('offerId') offerId: string) {
    return this.rides.acceptOffer(user.id, offerId);
  }

  @Post('offers/:offerId/reject')
  reject(@CurrentUser() user: AuthUser, @Param('offerId') offerId: string) {
    return this.rides.rejectOffer(user.id, offerId);
  }

  @Post(':id/arrived')
  arrived(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.rides.driverArrived(user.id, id);
  }

  @Post(':id/start')
  start(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: PinDto,
  ) {
    return this.rides.startTrip(user.id, id, dto.pin);
  }

  @Post(':id/complete')
  complete(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.rides.completeTrip(user.id, id);
  }

  @Post(':id/cancel')
  cancel(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: CancelDto,
  ) {
    return this.rides.cancelRide(user.id, id, dto.reason);
  }

  @Post(':id/rate')
  rate(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: RateDto,
  ) {
    return this.rides.rateRide(user.id, id, dto.score, dto.comment);
  }
}
