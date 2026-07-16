import { Injectable } from '@nestjs/common';
import { DataSource, EntityManager } from 'typeorm';

@Injectable()
export class TenantDatabase {
  constructor(private readonly dataSource: DataSource) {}

  async withTenant<T>(
    tenantId: string,
    operation: (manager: EntityManager) => Promise<T>,
  ): Promise<T> {
    return this.dataSource.transaction(async (manager) => {
      await manager.query(
        `SELECT set_config('app.current_tenant_id', $1, true)`,
        [tenantId],
      );
      return operation(manager);
    });
  }
}
