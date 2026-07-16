process.env.NODE_ENV ??= 'test';
process.env.DATABASE_URL ??=
  'postgresql://texerp_app:texerp_app@localhost:5432/texerp';
process.env.REDIS_URL ??= 'redis://localhost:6379';
