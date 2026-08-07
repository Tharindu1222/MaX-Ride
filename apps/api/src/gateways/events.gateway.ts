import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Server, Socket } from 'socket.io';

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/realtime',
})
export class EventsGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(EventsGateway.name);
  private userSockets = new Map<string, Set<string>>();

  constructor(
    private jwt: JwtService,
    private config: ConfigService,
  ) {}

  async handleConnection(client: Socket) {
    try {
      const token =
        (client.handshake.auth?.token as string) ||
        (client.handshake.headers.authorization || '').replace('Bearer ', '');
      if (!token) {
        client.disconnect();
        return;
      }
      const payload = await this.jwt.verifyAsync(token, {
        secret: this.config.get('JWT_ACCESS_SECRET'),
      });
      const userId = payload.sub as string;
      client.data.userId = userId;
      client.data.userType = payload.userType;
      client.join(`user:${userId}`);
      if (!this.userSockets.has(userId)) this.userSockets.set(userId, new Set());
      this.userSockets.get(userId)!.add(client.id);
      this.logger.log(`WS connected user=${userId}`);
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    const userId = client.data.userId as string | undefined;
    if (userId && this.userSockets.has(userId)) {
      this.userSockets.get(userId)!.delete(client.id);
    }
  }

  @SubscribeMessage('ride.subscribe')
  onSubscribeRide(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { rideId: string },
  ) {
    if (body?.rideId) client.join(`ride:${body.rideId}`);
    return { ok: true };
  }

  @SubscribeMessage('location.driver')
  onDriverLocation(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    body: { rideId?: string; latitude: number; longitude: number; heading?: number },
  ) {
    if (body?.rideId) {
      this.server.to(`ride:${body.rideId}`).emit('driver.location', {
        rideId: body.rideId,
        latitude: body.latitude,
        longitude: body.longitude,
        heading: body.heading,
        at: new Date().toISOString(),
      });
    }
  }

  emitToPassenger(userId: string, event: string, payload: unknown) {
    this.server.to(`user:${userId}`).emit(event, payload);
  }

  emitToDriver(userId: string, event: string, payload: unknown) {
    this.server.to(`user:${userId}`).emit(event, payload);
  }

  emitToRide(rideId: string, event: string, payload: unknown) {
    this.server.to(`ride:${rideId}`).emit(event, payload);
  }
}
