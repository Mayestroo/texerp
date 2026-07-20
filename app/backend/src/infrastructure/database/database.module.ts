import { Global, Module } from '@nestjs/common';
import { TenantDatabase } from './tenant-database';

@Global()
@Module({
  providers: [TenantDatabase],
  exports: [TenantDatabase],
})
export class DatabaseModule {}
