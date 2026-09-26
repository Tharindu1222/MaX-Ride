import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import {
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
} from 'class-validator';
import { PricingService } from './pricing.service';
import { Public } from '../../common/decorators/roles.decorator';
import { ServiceType } from '@prisma/client';

class EstimateDto {
  @IsUUID()
  vehicleCategoryId!: string;

  @IsNumber()
  pickupLat!: number;

  @IsNumber()
  pickupLng!: number;

  @IsOptional()
  @IsNumber()
  dropoffLat?: number;

  @IsOptional()
  @IsNumber()
  dropoffLng?: number;

  @IsOptional()
  @IsString()
  promoCode?: string;

  @IsOptional()
  @IsEnum(ServiceType)
  serviceType?: ServiceType;

  @IsOptional()
  @IsUUID()
  rentalPackageId?: string;
}

@ApiTags('pricing')
@ApiBearerAuth()
@Controller()
export class PricingController {
  constructor(private pricing: PricingService) {}

  @Public()
  @Get('vehicle-categories')
  categories(@Query('serviceType') serviceType?: ServiceType) {
    return this.pricing.listCategories(serviceType ?? ServiceType.RIDE);
  }

  @Public()
  @Get('rental-packages')
  rentalPackages() {
    return this.pricing.listRentalPackages();
  }

  @Post('fares/estimate')
  estimate(@Body() dto: EstimateDto) {
    return this.pricing.estimate(dto);
  }
}
