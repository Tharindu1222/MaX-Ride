import { Body, Controller, Get, Param, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IsEnum, IsOptional, IsString } from 'class-validator';
import { SupportService } from './support.service';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { TicketCategory } from '@prisma/client';

class CreateTicketDto {
  @IsEnum(TicketCategory) category!: TicketCategory;
  @IsString() subject!: string;
  @IsString() description!: string;
  @IsOptional() @IsString() rideId?: string;
}

class StatusDto {
  @IsString() status!: string;
}

@ApiTags('support')
@ApiBearerAuth()
@Controller('support')
export class SupportController {
  constructor(private support: SupportService) {}

  @Post('tickets')
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateTicketDto) {
    return this.support.create(user.id, dto);
  }

  @Get('tickets/me')
  mine(@CurrentUser() user: AuthUser) {
    return this.support.listMine(user.id);
  }

  @Roles('ADMIN', 'SUPPORT', 'OPERATIONS', 'SUPER_ADMIN')
  @Get('tickets')
  all() {
    return this.support.listAll();
  }

  @Roles('ADMIN', 'SUPPORT', 'OPERATIONS', 'SUPER_ADMIN')
  @Patch('tickets/:id')
  update(@Param('id') id: string, @Body() dto: StatusDto) {
    return this.support.updateStatus(id, dto.status);
  }
}
