import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Server } from 'node:http';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/shared/bootstrap/configure-app';

interface HealthBody {
  status: string;
  timestamp: string;
}

describe('Health endpoint', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = module.createNestApplication();
    configureApp(app);
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('responds to a live HTTP request', async () => {
    const server = app.getHttpServer() as Server;
    const response = await request(server).get('/api/v1/health').expect(200);
    const body = response.body as HealthBody;

    expect(response.headers['x-api-version']).toBe('1.0.0');
    expect(body).toMatchObject({ status: 'ok' });
    expect(new Date(body.timestamp).toISOString()).toBe(body.timestamp);
  });
});
