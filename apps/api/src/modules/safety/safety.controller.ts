import { Body, Controller, Get, Param, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IsNumber, IsOptional, IsString } from 'class-validator';
import { SafetyService } from './safety.service';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';

class SosDto {
  @IsOptional() @IsString() rideId?: string;
  @IsOptional() @IsNumber() latitude?: number;
  @IsOptional() @IsNumber() longitude?: number;
  @IsOptional() @IsString() notes?: string;
}

@ApiTags('safety')
@ApiBearerAuth()
@Controller('safety')
export class SafetyController {
  constructor(private safety: SafetyService) {}

  @Post('sos')
  sos(@CurrentUser() user: AuthUser, @Body() dto: SosDto) {
    return this.safety.triggerSos(user.id, dto);
  }

  @Roles('ADMIN', 'OPERATIONS', 'SUPER_ADMIN', 'SUPPORT')
  @Get('incidents')
  list() {
    return this.safety.listIncidents();
  }

  @Roles('ADMIN', 'OPERATIONS', 'SUPER_ADMIN', 'SUPPORT')
  @Patch('incidents/:id')
  update(@Param('id') id: string, @Body() body: { status: string }) {
    return this.safety.updateIncident(id, body.status);
  }
}
