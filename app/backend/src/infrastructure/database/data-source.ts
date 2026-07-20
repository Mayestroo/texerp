import 'dotenv/config';
import { DataSource } from 'typeorm';

export default new DataSource({
  type: 'postgres',
  url: process.env.DATABASE_ADMIN_URL ?? process.env.DATABASE_URL,
  migrations: [`${__dirname}/migrations/*{.ts,.js}`],
  migrationsTableName: 'schema_migrations',
  synchronize: false,
});
