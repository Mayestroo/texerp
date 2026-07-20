import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateReportExports1753500000000 implements MigrationInterface {
  name = 'CreateReportExports1753500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE report_exports (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        report_type varchar(50) NOT NULL,
        format varchar(20) NOT NULL DEFAULT 'EXCEL',
        status varchar(20) NOT NULL DEFAULT 'QUEUED',
        filters jsonb NOT NULL,
        file_url varchar(500),
        file_size_bytes bigint,
        error_message text,
        generated_at timestamptz,
        expires_at timestamptz,
        requested_by uuid NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT report_exports_format_check CHECK (format IN ('EXCEL')),
        CONSTRAINT report_exports_status_check CHECK (status IN ('QUEUED', 'GENERATING', 'READY', 'FAILED')),
        CONSTRAINT report_exports_type_check CHECK (report_type IN ('PRODUCTION')),
        FOREIGN KEY (tenant_id, requested_by) REFERENCES users(tenant_id, id)
      );
    `);

    await queryRunner.query(`
      ALTER TABLE report_exports ENABLE ROW LEVEL SECURITY;
      ALTER TABLE report_exports FORCE ROW LEVEL SECURITY;
      CREATE POLICY report_exports_tenant_isolation ON report_exports
        USING (
          tenant_id = nullif(current_setting('app.current_tenant_id', true), '')::uuid
        )
        WITH CHECK (
          tenant_id = nullif(current_setting('app.current_tenant_id', true), '')::uuid
        );
    `);

    await queryRunner.query(`
      CREATE INDEX report_exports_requested_by_idx
        ON report_exports (tenant_id, requested_by, created_at DESC);
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP TABLE IF EXISTS report_exports;
    `);
  }
}
