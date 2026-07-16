import {
  INestApplication,
  ValidationPipe,
  VersioningType,
} from '@nestjs/common';
import { NextFunction, Request, Response } from 'express';
import helmet from 'helmet';

export function configureApp(app: INestApplication): void {
  app.use(helmet());
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
}
