import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { configuration, validationSchema } from './shared/config/configuration';
import { HealthModule } from './modules/health/health.module';
import { DatabaseModule } from './infrastructure/database/database.module';
import { IamModule } from './modules/iam/iam.module';
import { OperationsModule } from './modules/operations/operations.module';
import { RedisModule } from './infrastructure/redis/redis.module';
import { OrganizationModule } from './modules/organization/organization.module';
import { ProductionModule } from './modules/production/production.module';
import { PayrollModule } from './modules/payroll/payroll.module';

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
    DatabaseModule,
    RedisModule,
    IamModule,
    OperationsModule,
    OrganizationModule,
    ProductionModule,
    PayrollModule,
    HealthModule,
  ],
})
export class AppModule {}
