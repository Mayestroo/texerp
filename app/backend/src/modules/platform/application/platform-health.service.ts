import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { PlatformDatabase } from '../../../infrastructure/database/platform-database';
import { RedisService } from '../../../infrastructure/redis/redis.service';

interface HealthCheckResult {
  database: { status: 'ok' | 'error'; message?: string };
  redis: { status: 'ok' | 'error'; message?: string };
  queues: { status: 'ok' | 'error'; details: Record<string, { status: 'ok' | 'error'; message?: string }> };
  timestamp: string;
}

@Injectable()
export class PlatformHealthService {
  constructor(
    private readonly platformDatabase: PlatformDatabase,
    private readonly redisService: RedisService,
    @InjectQueue('payroll-calculation') private readonly payrollCalculationQueue: Queue,
    @InjectQueue('payroll-export') private readonly payrollExportQueue: Queue,
    @InjectQueue('report-export') private readonly reportExportQueue: Queue,
    @InjectQueue('notification-dispatch') private readonly notificationDispatchQueue: Queue,
  ) {}

  async check(): Promise<HealthCheckResult> {
    const [database, redis, queues] = await Promise.all([
      this.checkDatabase(),
      this.checkRedis(),
      this.checkQueues(),
    ]);

    return {
      database,
      redis,
      queues,
      timestamp: new Date().toISOString(),
    };
  }

  private async checkDatabase(): Promise<HealthCheckResult['database']> {
    try {
      await this.platformDatabase.execute(async (manager) => {
        await manager.query('SELECT 1');
      });
      return { status: 'ok' };
    } catch (error) {
      return {
        status: 'error',
        message: error instanceof Error ? error.message : 'Database check failed',
      };
    }
  }

  private async checkRedis(): Promise<HealthCheckResult['redis']> {
    try {
      const redis = this.redisService.getRedis();
      await redis.ping();
      return { status: 'ok' };
    } catch (error) {
      return {
        status: 'error',
        message: error instanceof Error ? error.message : 'Redis check failed',
      };
    }
  }

  private async checkQueues(): Promise<HealthCheckResult['queues']> {
    const queueNames = [
      { queue: this.payrollCalculationQueue, name: 'payroll-calculation' },
      { queue: this.payrollExportQueue, name: 'payroll-export' },
      { queue: this.reportExportQueue, name: 'report-export' },
      { queue: this.notificationDispatchQueue, name: 'notification-dispatch' },
    ];

    const details: Record<string, { status: 'ok' | 'error'; message?: string }> = {};
    let allOk = true;

    await Promise.all(
      queueNames.map(async ({ queue, name }) => {
        try {
          await queue.getJobCounts();
          details[name] = { status: 'ok' };
        } catch (error) {
          allOk = false;
          details[name] = {
            status: 'error',
            message: error instanceof Error ? error.message : 'Queue check failed',
          };
        }
      }),
    );

    return {
      status: allOk ? 'ok' : 'error',
      details,
    };
  }
}
