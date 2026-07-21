import { Module, Global } from '@nestjs/common';
import { APP_INTERCEPTOR, APP_FILTER } from '@nestjs/core';
import { PrometheusService, PrometheusInterceptor } from './prometheus.service';
import { MetricsController } from './metrics.controller';
import { SentryExceptionFilter } from './sentry.filter';

@Global()
@Module({
  controllers: [MetricsController],
  providers: [
    PrometheusService,
    {
      provide: APP_INTERCEPTOR,
      useClass: PrometheusInterceptor,
    },
    {
      provide: APP_FILTER,
      useClass: SentryExceptionFilter,
    },
  ],
  exports: [PrometheusService],
})
export class MonitoringModule {}
