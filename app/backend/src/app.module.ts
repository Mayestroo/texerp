import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { EventEmitterModule } from '@nestjs/event-emitter';
import { APP_GUARD } from '@nestjs/core';
import { configuration, validationSchema } from './shared/config/configuration';
import { HealthModule } from './modules/health/health.module';
import { DatabaseModule } from './infrastructure/database/database.module';
import { IamModule } from './modules/iam/iam.module';
import { OperationsModule } from './modules/operations/operations.module';
import { RedisModule } from './infrastructure/redis/redis.module';
import { RateLimitModule } from './infrastructure/rate-limit/rate-limit.module';
import { RateLimitGuard } from './infrastructure/rate-limit/rate-limit.guard';
import { OrganizationModule } from './modules/organization/organization.module';
import { ProductionModule } from './modules/production/production.module';
import { PayrollModule } from './modules/payroll/payroll.module';
import { QueueModule } from './infrastructure/queue/queue.module';
import { StorageModule } from './infrastructure/storage/storage.module';
import { FcmModule } from './infrastructure/fcm/fcm.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { ReportsModule } from './modules/reports/reports.module';
import { SettingsModule } from './modules/settings/settings.module';
import { WarehouseModule } from './modules/warehouse/warehouse.module';
import { WorkersModule } from './workers/workers.module';
import { PlatformModule } from './modules/platform/platform.module';
import { EventsModule } from './shared/events/events.module';
import { MonitoringModule } from './infrastructure/monitoring/monitoring.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      cache: true,
      load: [configuration],
      validationSchema,
      validationOptions: { abortEarly: false },
    }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres' as const,
        url: config.getOrThrow<string>('DATABASE_URL'),
        autoLoadEntities: true,
        synchronize: false,
      }),
    }),
    EventEmitterModule.forRoot(),
    EventsModule,
    DatabaseModule,
    RedisModule,
    RateLimitModule,
    QueueModule,
    StorageModule,
    FcmModule,
    IamModule,
    OperationsModule,
    OrganizationModule,
    ProductionModule,
    PayrollModule,
    ReportsModule,
    NotificationsModule,
    SettingsModule,
    WarehouseModule,
    WorkersModule,
    PlatformModule,
    HealthModule,
    MonitoringModule,
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: RateLimitGuard,
    },
  ],
})
export class AppModule {}
