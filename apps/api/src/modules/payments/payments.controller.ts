import { Controller, Get, Post, Param } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { PaymentsService } from './payments.service';
import { Roles } from '../../common/decorators/roles.decorator';

@ApiTags('payments')
@ApiBearerAuth()
@Controller('payments')
export class PaymentsController {
  constructor(private payments: PaymentsService) {}

  @Roles('ADMIN', 'SUPER_ADMIN', 'FINANCE')
  @Get()
  list() {
    return this.payments.listForAdmin();
  }

  @Post('rides/:rideId/settle')
  settle(@Param('rideId') rideId: string) {
    return this.payments.settleRide(rideId);
  }
}
