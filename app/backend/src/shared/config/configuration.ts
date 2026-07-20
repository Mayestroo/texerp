import * as Joi from 'joi';

export interface AppConfiguration {
  nodeEnv: 'development' | 'test' | 'production';
  port: number;
  databaseUrl: string;
  redisUrl: string;
  jwtPrivateKeyBase64: string;
  jwtPublicKeyBase64: string;
  s3Bucket?: string;
  s3Endpoint?: string;
  s3Region?: string;
  s3AccessKeyId?: string;
  s3SecretAccessKey?: string;
  s3ForcePathStyle?: string;
  fcmProjectId?: string;
  fcmClientEmail?: string;
  fcmPrivateKeyBase64?: string;
  trustedProxyHops?: number;
}

export const configuration = (): AppConfiguration => ({
  nodeEnv: process.env.NODE_ENV as AppConfiguration['nodeEnv'],
  port: Number(process.env.PORT),
  databaseUrl: process.env.DATABASE_URL ?? '',
  redisUrl: process.env.REDIS_URL ?? '',
  jwtPrivateKeyBase64: process.env.JWT_PRIVATE_KEY_BASE64 ?? '',
  jwtPublicKeyBase64: process.env.JWT_PUBLIC_KEY_BASE64 ?? '',
  s3Bucket: process.env.S3_BUCKET,
  s3Endpoint: process.env.S3_ENDPOINT,
  s3Region: process.env.S3_REGION,
  s3AccessKeyId: process.env.S3_ACCESS_KEY_ID,
  s3SecretAccessKey: process.env.S3_SECRET_ACCESS_KEY,
  s3ForcePathStyle: process.env.S3_FORCE_PATH_STYLE,
  fcmProjectId: process.env.FCM_PROJECT_ID,
  fcmClientEmail: process.env.FCM_CLIENT_EMAIL,
  fcmPrivateKeyBase64: process.env.FCM_PRIVATE_KEY_BASE64,
  trustedProxyHops: process.env.TRUSTED_PROXY_HOPS ? Number(process.env.TRUSTED_PROXY_HOPS) : undefined,
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
  S3_BUCKET: Joi.string().optional(),
  S3_ENDPOINT: Joi.string().uri({ allowRelative: false }).optional(),
  S3_REGION: Joi.string().optional(),
  S3_ACCESS_KEY_ID: Joi.string().optional(),
  S3_SECRET_ACCESS_KEY: Joi.string().optional(),
  S3_FORCE_PATH_STYLE: Joi.string().optional(),
  FCM_PROJECT_ID: Joi.string().optional(),
  FCM_CLIENT_EMAIL: Joi.string().email().optional(),
  FCM_PRIVATE_KEY_BASE64: Joi.string().base64().optional(),
  TRUSTED_PROXY_HOPS: Joi.number().integer().min(0).max(10).optional(),
});
