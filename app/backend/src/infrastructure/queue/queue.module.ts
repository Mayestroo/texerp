import { Global, Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { ConfigService } from '@nestjs/config';

@Global()
@Module({
  imports: [
    BullModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        const redisUrl = config.getOrThrow<string>('REDIS_URL');
        try {
          const url = new URL(redisUrl);
          return {
            connection: {
              host: url.hostname || 'localhost',
              port: url.port ? parseInt(url.port) : 6379,
              password: url.password || undefined,
              username: url.username || undefined,
            },
          };
        } catch {
          // Fallback if redisUrl isn't parseable as URL
          return {
            connection: {
              host: 'localhost',
              port: 6379,
            },
          };
        }
      },
    }),
    BullModule.registerQueue(
      { name: 'payroll-calculation' },
      { name: 'payroll-export' },
      { name: 'report-export' },
      { name: 'notification-dispatch' },
    ),
  ],
  exports: [BullModule],
})
export class QueueModule {}
