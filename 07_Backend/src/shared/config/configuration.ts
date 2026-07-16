import * as Joi from 'joi';

export interface AppConfiguration {
  nodeEnv: 'development' | 'test' | 'production';
  port: number;
  databaseUrl: string;
  redisUrl: string;
  jwtPrivateKeyBase64: string;
  jwtPublicKeyBase64: string;
}

export const configuration = (): AppConfiguration => ({
  nodeEnv: process.env.NODE_ENV as AppConfiguration['nodeEnv'],
  port: Number(process.env.PORT),
  databaseUrl: process.env.DATABASE_URL ?? '',
  redisUrl: process.env.REDIS_URL ?? '',
  jwtPrivateKeyBase64: process.env.JWT_PRIVATE_KEY_BASE64 ?? '',
  jwtPublicKeyBase64: process.env.JWT_PUBLIC_KEY_BASE64 ?? '',
});

export const validationSchema = Joi.object({
  NODE_ENV: Joi.string()
    .valid('development', 'test', 'production')
    .default('development'),
  PORT: Joi.number().port().default(3000),
  DATABASE_URL: Joi.string().uri({ scheme: ['postgres', 'postgresql'] }).required(),
  REDIS_URL: Joi.string().uri({ scheme: ['redis', 'rediss'] }).required(),
  JWT_PRIVATE_KEY_BASE64: Joi.string().base64().required(),
  JWT_PUBLIC_KEY_BASE64: Joi.string().base64().required(),
});
