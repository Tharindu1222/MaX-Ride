import { Module, forwardRef } from '@nestjs/common';
import { DispatchService } from './dispatch.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [forwardRef(() => NotificationsModule)],
  providers: [DispatchService],
  exports: [DispatchService],
})
export class DispatchModule {}
