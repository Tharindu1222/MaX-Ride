import { Controller, Get } from '@nestjs/common';
import { Public } from './common/decorators/roles.decorator';

@Controller()
export class HealthController {
  @Public()
  @Get('health')
  health() {
    return {
      status: 'ok',
      platform: 'MaX Ride',
      market: 'Sri Lanka',
      currency: 'LKR',
      timestamp: new Date().toISOString(),
    };
  }
}
