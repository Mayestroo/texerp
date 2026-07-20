import { Injectable } from '@nestjs/common';
import { RedisService } from '../../../infrastructure/redis/redis.service';
import { SettingsService } from './settings.service';

export interface TenantConfig {
  tenant_id: string;
  back_date_window_days: number;
  suspicious_quantity_multiplier: number;
  payroll_min_pay: number;
  duplicate_window_minutes: number;
  stock_negative_mode: 'HARD_BLOCK' | 'WARNING';
}

@Injectable()
export class TenantConfigService {
  private readonly CACHE_TTL = 300; // 5 minutes

  constructor(
    private readonly redisService: RedisService,
    private readonly settingsService: SettingsService,
  ) {}

  async get(tenantId: string): Promise<TenantConfig> {
    const cacheKey = `tenant:${tenantId}:config`;
    const redis = this.redisService.getRedis();

    const cached = await redis.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as TenantConfig;
    }

    const config = await this.settingsService.get(tenantId);
    await redis.set(cacheKey, JSON.stringify(config), 'EX', this.CACHE_TTL);
    return config;
  }

  async invalidate(tenantId: string): Promise<void> {
    const redis = this.redisService.getRedis();
    await redis.del(`tenant:${tenantId}:config`);
  }
}
