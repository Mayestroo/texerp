import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateOperationsCatalog1752750000000
  implements MigrationInterface
{
  name = 'CreateOperationsCatalog1752750000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TYPE operation_unit AS ENUM ('PIECE', 'METER', 'PAIR');

      CREATE TABLE operations (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        name varchar(255) NOT NULL,
        code varchar(50),
        unit operation_unit NOT NULL,
        unit_price integer NOT NULL,
        currency char(3) NOT NULL DEFAULT 'UZS',
        sort_order integer NOT NULL DEFAULT 0,
        is_active boolean NOT NULL DEFAULT true,
        created_by uuid NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT operations_unit_price_check CHECK (unit_price > 0),
        CONSTRAINT operations_currency_check CHECK (currency = 'UZS'),
        CONSTRAINT operations_tenant_id_id_key UNIQUE (tenant_id, id),
        CONSTRAINT operations_tenant_name_key UNIQUE (tenant_id, name),
        CONSTRAINT operations_tenant_code_key UNIQUE (tenant_id, code),
        FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id)
      );

      CREATE TABLE operation_price_history (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        operation_id uuid NOT NULL,
        unit_price integer NOT NULL,
        currency char(3) NOT NULL DEFAULT 'UZS',
        effective_from timestamptz NOT NULL,
        effective_to timestamptz,
        changed_by uuid NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT operation_price_history_unit_price_check CHECK (unit_price > 0),
        CONSTRAINT operation_price_history_currency_check CHECK (currency = 'UZS'),
        CONSTRAINT operation_price_history_dates_check
          CHECK (effective_to IS NULL OR effective_to >= effective_from),
        CONSTRAINT operation_price_history_tenant_id_id_key UNIQUE (tenant_id, id),
        FOREIGN KEY (tenant_id, operation_id) REFERENCES operations(tenant_id, id),
        FOREIGN KEY (tenant_id, changed_by) REFERENCES users(tenant_id, id)
      );

      CREATE INDEX operations_active_catalog_idx
        ON operations (tenant_id, sort_order, name, id) WHERE is_active;
      CREATE INDEX operations_catalog_idx
        ON operations (tenant_id, sort_order, name, id);
      CREATE UNIQUE INDEX operation_price_history_one_current_per_operation
        ON operation_price_history (tenant_id, operation_id)
        WHERE effective_to IS NULL;
    `);

    for (const table of ['operations', 'operation_price_history']) {
      await queryRunner.query(`
        ALTER TABLE ${table} ENABLE ROW LEVEL SECURITY;
        ALTER TABLE ${table} FORCE ROW LEVEL SECURITY;
        CREATE POLICY ${table}_tenant_isolation ON ${table}
          USING (
            tenant_id = nullif(current_setting('app.current_tenant_id', true), '')::uuid
          )
          WITH CHECK (
            tenant_id = nullif(current_setting('app.current_tenant_id', true), '')::uuid
          );
      `);
    }
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP TABLE IF EXISTS operation_price_history;
      DROP TABLE IF EXISTS operations;
      DROP TYPE IF EXISTS operation_unit;
    `);
  }
}
