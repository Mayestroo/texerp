import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateProductionEntries1752800000000
  implements MigrationInterface
{
  name = 'CreateProductionEntries1752800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE production_entries (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        worker_id uuid NOT NULL,
        operation_id uuid NOT NULL,
        quantity integer NOT NULL,
        record_date date NOT NULL,
        status varchar(20) NOT NULL DEFAULT 'PENDING',
        operation_name_snapshot varchar(255) NOT NULL,
        operation_code_snapshot varchar(50),
        unit_price_snapshot integer NOT NULL,
        currency_snapshot char(3) NOT NULL DEFAULT 'UZS',
        worker_note varchar(500),
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),

        CONSTRAINT production_entries_quantity_check CHECK (quantity > 0),
        CONSTRAINT production_entries_currency_snapshot_check
          CHECK (currency_snapshot = 'UZS'),
        CONSTRAINT production_entries_status_check
          CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'SUSPICIOUS')),
        FOREIGN KEY (tenant_id, worker_id) REFERENCES users(tenant_id, id),
        FOREIGN KEY (tenant_id, operation_id) REFERENCES operations(tenant_id, id)
      );

      CREATE UNIQUE INDEX production_entries_duplicate_check
        ON production_entries (tenant_id, worker_id, operation_id, record_date)
        WHERE status = 'PENDING';

      CREATE INDEX production_entries_pending_worker_idx
        ON production_entries (tenant_id, worker_id, status, record_date DESC)
        WHERE status = 'PENDING';

      CREATE FUNCTION production_back_date_window()
      RETURNS smallint
      LANGUAGE sql
      SECURITY DEFINER
      SET search_path = pg_catalog
      AS $$
        SELECT back_date_window_days
        FROM public.tenants
        WHERE id = nullif(current_setting('app.current_tenant_id', true), '')::uuid;
      $$;

      REVOKE ALL ON FUNCTION production_back_date_window() FROM PUBLIC;
      GRANT EXECUTE ON FUNCTION production_back_date_window() TO texerp_app;
    `);

    await queryRunner.query(`
      ALTER TABLE production_entries ENABLE ROW LEVEL SECURITY;
      ALTER TABLE production_entries FORCE ROW LEVEL SECURITY;
      CREATE POLICY production_entries_tenant_isolation ON production_entries
        USING (
          tenant_id = nullif(current_setting('app.current_tenant_id', true), '')::uuid
        )
        WITH CHECK (
          tenant_id = nullif(current_setting('app.current_tenant_id', true), '')::uuid
        );
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP TABLE IF EXISTS production_entries;
      DROP FUNCTION IF EXISTS production_back_date_window();
    `);
  }
}
