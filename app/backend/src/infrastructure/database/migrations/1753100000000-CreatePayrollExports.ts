import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreatePayrollExports1753100000000 implements MigrationInterface {
  name = 'CreatePayrollExports1753100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE payroll_exports (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        payroll_period_id uuid NOT NULL,
        format varchar(20) NOT NULL,
        status varchar(20) NOT NULL,
        file_url varchar(500),
        file_size_bytes bigint,
        generated_at timestamptz,
        expires_at timestamptz,
        requested_by uuid NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT payroll_exports_format_check CHECK (format IN ('EXCEL', 'PDF_ALL', 'PDF_PER_WORKER')),
        CONSTRAINT payroll_exports_status_check CHECK (status IN ('QUEUED', 'GENERATING', 'READY', 'FAILED')),
        UNIQUE (tenant_id, id),
        FOREIGN KEY (tenant_id, payroll_period_id) REFERENCES payroll_periods(tenant_id, id),
        FOREIGN KEY (tenant_id, requested_by) REFERENCES users(tenant_id, id)
      );
    `);

    await queryRunner.query(`
      ALTER TABLE payroll_exports ENABLE ROW LEVEL SECURITY;
      ALTER TABLE payroll_exports FORCE ROW LEVEL SECURITY;
      CREATE POLICY payroll_exports_tenant_isolation ON payroll_exports
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
      DROP TABLE IF EXISTS payroll_exports;
    `);
  }
}
