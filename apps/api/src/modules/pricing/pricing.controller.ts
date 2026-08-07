import { Body, Controller, Get, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IsNumber, IsOptional, IsString, IsUUID } from 'class-validator';
import { PricingService } from './pricing.service';
import { Public } from '../../common/decorators/roles.decorator';

class EstimateDto {
  @IsUUID()
  vehicleCategoryId!: string;

  @IsNumber()
  pickupLat!: number;

  @IsNumber()
  pickupLng!: number;

  @IsNumber()
  dropoffLat!: number;

  @IsNumber()
  dropoffLng!: number;

  @IsOptional()
  @IsString()
  promoCode?: string;
}

@ApiTags('pricing')
@ApiBearerAuth()
@Controller()
export class PricingController {
  constructor(private pricing: PricingService) {}

  @Public()
  @Get('vehicle-categories')
  categories() {
    return this.pricing.listCategories();
  }

  @Post('fares/estimate')
  estimate(@Body() dto: EstimateDto) {
    return this.pricing.estimate(dto);
  }
}
