import { Body, Controller, Get, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IsNumber, IsOptional, IsString } from 'class-validator';
import { PassengersService } from './passengers.service';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';

class UpdatePassengerDto {
  @IsOptional() @IsString() fullName?: string;
  @IsOptional() @IsString() email?: string;
}

class SavedPlaceDto {
  @IsString() label!: string;
  @IsString() address!: string;
  @IsNumber() latitude!: number;
  @IsNumber() longitude!: number;
}

@ApiTags('passengers')
@ApiBearerAuth()
@Roles('PASSENGER')
@Controller('passengers')
export class PassengersController {
  constructor(private passengers: PassengersService) {}

  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.passengers.getMe(user.id);
  }

  @Patch('me')
  update(@CurrentUser() user: AuthUser, @Body() dto: UpdatePassengerDto) {
    return this.passengers.updateProfile(user.id, dto);
  }

  @Get('me/places')
  places(@CurrentUser() user: AuthUser) {
    return this.passengers.listSavedPlaces(user.id);
  }

  @Post('me/places')
  addPlace(@CurrentUser() user: AuthUser, @Body() dto: SavedPlaceDto) {
    return this.passengers.addSavedPlace(user.id, dto);
  }

  @Get('me/rides')
  history(@CurrentUser() user: AuthUser) {
    return this.passengers.history(user.id);
  }
}
