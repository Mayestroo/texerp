import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateTenantSettings1753600000000 implements MigrationInterface {
  name = 'CreateTenantSettings1753600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE tenant_settings (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL UNIQUE REFERENCES tenants(id),
        back_date_window_days smallint NOT NULL DEFAULT 3,
        suspicious_quantity_multiplier numeric(6,2) NOT NULL DEFAULT 3,
        payroll_min_pay integer NOT NULL DEFAULT 0,
        duplicate_window_minutes integer NOT NULL DEFAULT 60,
        stock_negative_mode varchar(20) NOT NULL DEFAULT 'HARD_BLOCK',
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        updated_by uuid,
        CONSTRAINT tenant_settings_back_date_check CHECK (back_date_window_days BETWEEN 1 AND 7),
        CONSTRAINT tenant_settings_multiplier_check CHECK (suspicious_quantity_multiplier > 0),
        CONSTRAINT tenant_settings_min_pay_check CHECK (payroll_min_pay >= 0),
        CONSTRAINT tenant_settings_dup_window_check CHECK (duplicate_window_minutes >= 1),
        CONSTRAINT tenant_settings_stock_mode_check CHECK (stock_negative_mode IN ('HARD_BLOCK', 'WARNING'))
      );

      ALTER TABLE tenant_settings ENABLE ROW LEVEL SECURITY;
      ALTER TABLE tenant_settings FORCE ROW LEVEL SECURITY;
      CREATE POLICY tenant_settings_tenant_isolation ON tenant_settings
        USING (
          tenant_id = nullif(current_setting('app.current_tenant_id', true), '')::uuid
        )
        WITH CHECK (
          tenant_id = nullif(current_setting('app.current_tenant_id', true), '')::uuid
        );

      -- Backfill existing tenants with default settings.
      INSERT INTO tenant_settings (id, tenant_id)
      SELECT gen_random_uuid(), id FROM tenants
      ON CONFLICT (tenant_id) DO NOTHING;

      -- Read the back-date window from tenant_settings instead of tenants.
      -- The function intentionally has no parameters; it reads the tenant from
      -- the current_setting set by the application connection so it stays
      -- compatible with the existing call sites and migration 1752800000000.
      DROP FUNCTION IF EXISTS production_back_date_window(uuid);
      DROP FUNCTION IF EXISTS production_back_date_window();

      CREATE OR REPLACE FUNCTION production_back_date_window()
      RETURNS integer
      LANGUAGE sql
      SECURITY DEFINER
      SET search_path = pg_catalog
      STABLE
      AS $$
        SELECT COALESCE(
          (SELECT back_date_window_days FROM tenant_settings
           WHERE tenant_id = nullif(current_setting('app.current_tenant_id', true), '')::uuid),
          3
        );
      $$;

      REVOKE ALL ON FUNCTION production_back_date_window() FROM PUBLIC;
      GRANT EXECUTE ON FUNCTION production_back_date_window() TO texerp_app;

      -- Tenant profile fields are stored on the tenants table, which the app
      -- role cannot read directly. Expose them through a SECURITY DEFINER
      -- function so the settings endpoint can return them.
      CREATE OR REPLACE FUNCTION get_tenant_profile(p_tenant_id uuid)
      RETURNS TABLE(name varchar, timezone varchar, language varchar, currency varchar)
      LANGUAGE sql
      SECURITY DEFINER
      SET search_path = pg_catalog
      STABLE
      AS $$
        SELECT name, timezone, language, currency
        FROM tenants
        WHERE id = p_tenant_id;
      $$;

      REVOKE ALL ON FUNCTION get_tenant_profile(uuid) FROM PUBLIC;
      GRANT EXECUTE ON FUNCTION get_tenant_profile(uuid) TO texerp_app;
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP TABLE IF EXISTS tenant_settings;
      DROP FUNCTION IF EXISTS production_back_date_window();
      DROP FUNCTION IF EXISTS get_tenant_profile(uuid);
    `);
  }
}
