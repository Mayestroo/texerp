import { Injectable } from '@nestjs/common';
import { RedisService } from '../redis/redis.service';

@Injectable()
export class RateLimitService {
  constructor(private readonly redisService: RedisService) {}

  async increment(key: string, windowSec: number): Promise<{ count: number; ttl: number }> {
    const redis = this.redisService.getRedis();

    const result = (await redis.eval(
      `local count = redis.call('INCR', KEYS[1])
       if count == 1 then redis.call('EXPIRE', KEYS[1], ARGV[1]) end
       local ttl = redis.call('TTL', KEYS[1])
       return {count, ttl}`,
      1,
      key,
      windowSec,
    )) as [number, number];

    const [count, ttl] = result;
    return { count, ttl: ttl > 0 ? ttl : windowSec };
  }
}
