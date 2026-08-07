import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';
import { distanceMeters } from '../common/utils/geo.util';

export interface GeoDriver {
  driverId: string;
  latitude: number;
  longitude: number;
  distanceM?: number;
}

@Injectable()
export class RedisService implements OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private client: Redis | null = null;
  private memoryGeo = new Map<string, { lat: number; lng: number }>();
  private memoryKv = new Map<string, { value: string; expiresAt?: number }>();
  private useMemory = false;

  constructor(private config: ConfigService) {
    const host = this.config.get('REDIS_HOST', 'localhost');
    const port = Number(this.config.get('REDIS_PORT', 6379));
    try {
      this.client = new Redis({
        host,
        port,
        maxRetriesPerRequest: 1,
        lazyConnect: true,
        connectTimeout: 2000,
      });
      this.client.connect().catch(() => {
        this.logger.warn('Redis unavailable — using in-memory fallback');
        this.useMemory = true;
        this.client = null;
      });
    } catch {
      this.useMemory = true;
      this.client = null;
    }
  }

  async onModuleDestroy() {
    if (this.client) await this.client.quit().catch(() => undefined);
  }

  async set(key: string, value: string, ttlSeconds?: number) {
    if (this.useMemory || !this.client) {
      this.memoryKv.set(key, {
        value,
        expiresAt: ttlSeconds ? Date.now() + ttlSeconds * 1000 : undefined,
      });
      return;
    }
    if (ttlSeconds) await this.client.set(key, value, 'EX', ttlSeconds);
    else await this.client.set(key, value);
  }

  async get(key: string): Promise<string | null> {
    if (this.useMemory || !this.client) {
      const item = this.memoryKv.get(key);
      if (!item) return null;
      if (item.expiresAt && item.expiresAt < Date.now()) {
        this.memoryKv.delete(key);
        return null;
      }
      return item.value;
    }
    return this.client.get(key);
  }

  async del(key: string) {
    if (this.useMemory || !this.client) {
      this.memoryKv.delete(key);
      return;
    }
    await this.client.del(key);
  }

  async geoAdd(driverId: string, lng: number, lat: number) {
    if (this.useMemory || !this.client) {
      this.memoryGeo.set(driverId, { lat, lng });
      return;
    }
    await this.client.geoadd('drivers:geo', lng, lat, driverId);
  }

  async geoRemove(driverId: string) {
    if (this.useMemory || !this.client) {
      this.memoryGeo.delete(driverId);
      return;
    }
    await this.client.zrem('drivers:geo', driverId);
  }

  async geoRadius(
    lng: number,
    lat: number,
    radiusKm: number,
  ): Promise<GeoDriver[]> {
    if (this.useMemory || !this.client) {
      const results: GeoDriver[] = [];
      for (const [driverId, pos] of this.memoryGeo) {
        const d = distanceMeters(lat, lng, pos.lat, pos.lng);
        if (d <= radiusKm * 1000) {
          results.push({
            driverId,
            latitude: pos.lat,
            longitude: pos.lng,
            distanceM: Math.round(d),
          });
        }
      }
      return results.sort((a, b) => (a.distanceM || 0) - (b.distanceM || 0));
    }

    const raw = (await this.client.georadius(
      'drivers:geo',
      lng,
      lat,
      radiusKm,
      'km',
      'WITHDIST',
      'WITHCOORD',
      'ASC',
    )) as [string, string, [string, string]][];

    return raw.map(([driverId, distKm, coords]) => ({
      driverId,
      latitude: Number(coords[1]),
      longitude: Number(coords[0]),
      distanceM: Math.round(Number(distKm) * 1000),
    }));
  }
}
