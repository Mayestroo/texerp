import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreatePayrollTables1752900000000 implements MigrationInterface {
  name = 'CreatePayrollTables1752900000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TYPE payroll_period_status AS ENUM (
        'DRAFT', 'CALCULATING', 'CALCULATED', 'FINALIZED'
      );
      CREATE TYPE payroll_adjustment_type AS ENUM ('BONUS', 'DEDUCTION');

      CREATE TABLE payroll_periods (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        name varchar(255) NOT NULL,
        start_date date NOT NULL,
        end_date date NOT NULL,
        status payroll_period_status NOT NULL DEFAULT 'DRAFT',
        worker_count integer NOT NULL DEFAULT 0,
        total_gross bigint NOT NULL DEFAULT 0,
        total_final bigint NOT NULL DEFAULT 0,
        calculated_at timestamptz,
        finalized_at timestamptz,
        created_by uuid NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT payroll_periods_dates_check
          CHECK (end_date >= start_date),
        UNIQUE (tenant_id, id),
        FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id)
      );

      CREATE UNIQUE INDEX payroll_periods_no_overlap
        ON payroll_periods (tenant_id, start_date, end_date);

      CREATE INDEX payroll_periods_status_idx
        ON payroll_periods (tenant_id, status, created_at DESC);

      CREATE TABLE payroll_calculations (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        period_id uuid NOT NULL,
        worker_id uuid NOT NULL,
        total_pieces integer NOT NULL DEFAULT 0,
        gross_earnings bigint NOT NULL DEFAULT 0,
        total_bonuses bigint NOT NULL DEFAULT 0,
        total_deductions bigint NOT NULL DEFAULT 0,
        total_advances bigint NOT NULL DEFAULT 0,
        advance_carryforward bigint NOT NULL DEFAULT 0,
        final_pay bigint NOT NULL DEFAULT 0,
        has_adjustments boolean NOT NULL DEFAULT false,
        calculation_version integer NOT NULL DEFAULT 1,
        entries_count integer NOT NULL DEFAULT 0,
        calculated_at timestamptz NOT NULL DEFAULT now(),
        UNIQUE (tenant_id, id),
        UNIQUE (tenant_id, period_id, worker_id),
        FOREIGN KEY (tenant_id, period_id) REFERENCES payroll_periods(tenant_id, id),
        FOREIGN KEY (tenant_id, worker_id) REFERENCES users(tenant_id, id)
      );
      CREATE INDEX payroll_calculations_period_idx
        ON payroll_calculations (tenant_id, period_id);

      CREATE TABLE payroll_adjustments (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        period_id uuid NOT NULL,
        worker_id uuid NOT NULL,
        type payroll_adjustment_type NOT NULL,
        amount bigint NOT NULL,
        reason varchar(500) NOT NULL,
        created_by uuid NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT payroll_adjustments_amount_check CHECK (amount > 0),
        UNIQUE (tenant_id, id),
        FOREIGN KEY (tenant_id, period_id) REFERENCES payroll_periods(tenant_id, id),
        FOREIGN KEY (tenant_id, worker_id) REFERENCES users(tenant_id, id),
        FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id)
      );
      CREATE INDEX payroll_adjustments_period_idx
        ON payroll_adjustments (tenant_id, period_id, worker_id);

      CREATE TABLE payroll_advances (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        period_id uuid NOT NULL,
        worker_id uuid NOT NULL,
        amount bigint NOT NULL,
        given_date date NOT NULL,
        reason varchar(500),
        created_by uuid NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT payroll_advances_amount_check CHECK (amount > 0),
        UNIQUE (tenant_id, id),
        FOREIGN KEY (tenant_id, period_id) REFERENCES payroll_periods(tenant_id, id),
        FOREIGN KEY (tenant_id, worker_id) REFERENCES users(tenant_id, id),
        FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id)
      );
      CREATE INDEX payroll_advances_period_idx
        ON payroll_advances (tenant_id, period_id, worker_id);
    `);

    for (const table of [
      'payroll_periods',
      'payroll_calculations',
      'payroll_adjustments',
      'payroll_advances',
    ]) {
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
      DROP TABLE IF EXISTS payroll_advances;
      DROP TABLE IF EXISTS payroll_adjustments;
      DROP TABLE IF EXISTS payroll_calculations;
      DROP TABLE IF EXISTS payroll_periods;
      DROP TYPE IF EXISTS payroll_adjustment_type;
      DROP TYPE IF EXISTS payroll_period_status;
    `);
  }
}
