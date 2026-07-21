import { Injectable, NestInterceptor, ExecutionContext, CallHandler } from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { Counter, Histogram, Registry } from 'prom-client';

@Injectable()
export class PrometheusService {
  public readonly registry: Registry;
  public readonly httpRequestCounter: Counter<string>;
  public readonly httpRequestDurationHistogram: Histogram<string>;

  constructor() {
    this.registry = new Registry();

    this.httpRequestCounter = new Counter({
      name: 'http_requests_total',
      help: 'Total number of HTTP requests processed',
      labelNames: ['method', 'route', 'status_code'],
      registers: [this.registry],
    });

    this.httpRequestDurationHistogram = new Histogram({
      name: 'http_request_duration_seconds',
      help: 'HTTP request duration in seconds',
      labelNames: ['method', 'route', 'status_code'],
      buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
      registers: [this.registry],
    });
  }

  public async getMetrics(): Promise<string> {
    return this.registry.metrics();
  }
}

@Injectable()
export class PrometheusInterceptor implements NestInterceptor {
  constructor(private readonly prometheusService: PrometheusService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const http = context.switchToHttp();
    const request = http.getRequest();
    const response = http.getResponse();
    const startTime = Date.now();

    return next.handle().pipe(
      tap({
        next: () => {
          this.recordMetric(request, response.statusCode, startTime);
        },
        error: (error) => {
          const status = error.status || error.statusCode || 500;
          this.recordMetric(request, status, startTime);
        },
      }),
    );
  }

  private recordMetric(request: any, statusCode: number, startTime: number): void {
    const route = request.route?.path || request.url.split('?')[0] || 'unknown';
    const method = request.method;
    const durationInSeconds = (Date.now() - startTime) / 1000;

    this.prometheusService.httpRequestCounter.inc({
      method,
      route,
      status_code: statusCode.toString(),
    });

    this.prometheusService.httpRequestDurationHistogram.observe(
      {
        method,
        route,
        status_code: statusCode.toString(),
      },
      durationInSeconds,
    );
  }
}
