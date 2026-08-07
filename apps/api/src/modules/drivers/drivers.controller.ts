import { Body, Controller, Get, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import {
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
} from 'class-validator';
import { DriversService } from './drivers.service';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';

class UpdateDriverDto {
  @IsOptional() @IsString() fullName?: string;
  @IsOptional() @IsString() nicNumber?: string;
  @IsOptional() @IsString() drivingLicenseNumber?: string;
  @IsOptional() @IsString() dateOfBirth?: string;
}

class DocumentDto {
  @IsString() documentType!: string;
  @IsString() fileUrl!: string;
  @IsOptional() @IsString() expiresAt?: string;
}

class VehicleDto {
  @IsUUID() vehicleCategoryId!: string;
  @IsString() registrationNumber!: string;
  @IsOptional() @IsString() make?: string;
  @IsOptional() @IsString() model?: string;
  @IsOptional() @IsNumber() manufactureYear?: number;
  @IsOptional() @IsString() color?: string;
}

class OnlineDto {
  @IsBoolean() online!: boolean;
}

class LocationDto {
  @IsNumber() latitude!: number;
  @IsNumber() longitude!: number;
  @IsOptional() @IsNumber() heading?: number;
  @IsOptional() @IsNumber() speedMps?: number;
}

@ApiTags('drivers')
@ApiBearerAuth()
@Roles('DRIVER')
@Controller('drivers')
export class DriversController {
  constructor(private drivers: DriversService) {}

  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.drivers.getMe(user.id);
  }

  @Patch('me')
  update(@CurrentUser() user: AuthUser, @Body() dto: UpdateDriverDto) {
    return this.drivers.updateProfile(user.id, dto);
  }

  @Post('me/submit')
  submit(@CurrentUser() user: AuthUser) {
    return this.drivers.submitApplication(user.id);
  }

  @Post('me/documents')
  document(@CurrentUser() user: AuthUser, @Body() dto: DocumentDto) {
    return this.drivers.uploadDocument(
      user.id,
      dto.documentType,
      dto.fileUrl,
      dto.expiresAt,
    );
  }

  @Post('me/vehicles')
  vehicle(@CurrentUser() user: AuthUser, @Body() dto: VehicleDto) {
    return this.drivers.registerVehicle(user.id, dto);
  }

  @Post('me/online')
  online(@CurrentUser() user: AuthUser, @Body() dto: OnlineDto) {
    return this.drivers.setOnlineStatus(user.id, dto.online);
  }

  @Post('me/location')
  location(@CurrentUser() user: AuthUser, @Body() dto: LocationDto) {
    return this.drivers.updateLocation(
      user.id,
      dto.latitude,
      dto.longitude,
      dto.heading,
      dto.speedMps,
    );
  }

  @Get('me/earnings')
  earnings(@CurrentUser() user: AuthUser) {
    return this.drivers.earnings(user.id);
  }

  @Get('me/offers')
  offers(@CurrentUser() user: AuthUser) {
    return this.drivers.pendingOffers(user.id);
  }

  @Get('me/active-ride')
  activeRide(@CurrentUser() user: AuthUser) {
    return this.drivers.activeRide(user.id);
  }
}
