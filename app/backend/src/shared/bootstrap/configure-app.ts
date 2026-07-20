import {
  INestApplication,
  ValidationPipe,
  VersioningType,
} from '@nestjs/common';
import { NextFunction, Request, Response } from 'express';
import { ConfigService } from '@nestjs/config';
import helmet from 'helmet';
import { HttpExceptionFilter } from '../http/http-exception.filter';

export function configureApp(app: INestApplication): void {
  app.use(helmet());
  const config = app.get(ConfigService);
  const hops = config.get<number>('trustedProxyHops');
  if (hops !== undefined) {
    app.getHttpAdapter().getInstance().set('trust proxy', hops);
  } else {
    const nodeEnv = config.get<string>('nodeEnv');
    if (nodeEnv === 'production') {
      app.getHttpAdapter().getInstance().set('trust proxy', 1);
    }
  }
  app.setGlobalPrefix('api');
  app.enableVersioning({
    type: VersioningType.URI,
    defaultVersion: '1',
  });
  app.enableShutdownHooks();
  app.use((_request: Request, response: Response, next: NextFunction) => {
    response.setHeader('X-API-Version', '1.0.0');
    next();
  });
  app.useGlobalPipes(
    new ValidationPipe({
      forbidNonWhitelisted: true,
      transform: true,
      whitelist: true,
    }),
  );
  app.useGlobalFilters(new HttpExceptionFilter());
}
