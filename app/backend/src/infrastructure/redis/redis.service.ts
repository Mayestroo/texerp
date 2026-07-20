import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleDestroy {
  private readonly client: Redis;

  constructor(config: ConfigService) {
    this.client = new Redis(config.getOrThrow<string>('REDIS_URL'), {
      maxRetriesPerRequest: 1,
    });
  }

  async revokeSession(sessionId: string, ttlSeconds: number): Promise<void> {
    await this.client.set(
      `auth:session-revoked:${sessionId}`,
      '1',
      'EX',
      Math.max(ttlSeconds, 1),
    );
  }

  async isSessionRevoked(sessionId: string): Promise<boolean> {
    return (await this.client.exists(`auth:session-revoked:${sessionId}`)) === 1;
  }

  async consumeRateLimit(
    key: string,
    limit: number,
    windowSeconds: number,
  ): Promise<boolean> {
    const count = await this.client.eval(
      `local count = redis.call('INCR', KEYS[1])
       if count == 1 then redis.call('EXPIRE', KEYS[1], ARGV[1]) end
       return count`,
      1,
      key,
      windowSeconds,
    );
    return Number(count) <= limit;
  }

  async get(key: string): Promise<string | null> {
    return this.client.get(key);
  }

  async set(key: string, value: string, option?: 'EX', ttlSeconds?: number): Promise<void> {
    if (option === 'EX' && ttlSeconds !== undefined) {
      await this.client.set(key, value, 'EX', ttlSeconds);
    } else {
      await this.client.set(key, value);
    }
  }

  async del(key: string): Promise<void> {
    await this.client.del(key);
  }

  getRedis(): Redis {
    return this.client;
  }

  async onModuleDestroy(): Promise<void> {
    await this.client.quit();
  }
}
