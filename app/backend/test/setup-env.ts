import { generateKeyPairSync } from 'node:crypto';

process.env.NODE_ENV ??= 'test';
process.env.DATABASE_URL ??=
  'postgresql://texerp_app:texerp_app@localhost:5432/texerp';
process.env.REDIS_URL ??= 'redis://localhost:6379';

const keys = generateKeyPairSync('rsa', {
  modulusLength: 2048,
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  publicKeyEncoding: { type: 'spki', format: 'pem' },
});

process.env.JWT_PRIVATE_KEY_BASE64 ??= Buffer.from(keys.privateKey).toString(
  'base64',
);
process.env.JWT_PUBLIC_KEY_BASE64 ??= Buffer.from(keys.publicKey).toString(
  'base64',
);
