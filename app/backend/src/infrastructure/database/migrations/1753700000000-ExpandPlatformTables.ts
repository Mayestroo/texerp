import { MigrationInterface, QueryRunner } from 'typeorm';

export class ExpandPlatformTables1753700000000 implements MigrationInterface {
  name = 'ExpandPlatformTables1753700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE tenants ADD COLUMN IF NOT EXISTS legal_name varchar(255);
      ALTER TABLE tenants ADD COLUMN IF NOT EXISTS contact_email varchar(255);
      ALTER TABLE tenants ADD COLUMN IF NOT EXISTS contact_phone varchar(30);
      ALTER TABLE tenants ADD COLUMN IF NOT EXISTS country varchar(2) DEFAULT 'UZ';
      ALTER TABLE tenants ADD COLUMN IF NOT EXISTS terminated_at timestamptz;
      ALTER TABLE tenants ADD COLUMN IF NOT EXISTS deletion_scheduled_at timestamptz;
      ALTER TABLE tenants ADD COLUMN IF NOT EXISTS suspend_reason text;

      CREATE TABLE subscription_plans (
        id uuid PRIMARY KEY,
        name varchar(100) NOT NULL UNIQUE,
        description text,
        price_monthly_tiyin integer NOT NULL DEFAULT 0,
        price_annual_tiyin integer NOT NULL DEFAULT 0,
        currency varchar(3) NOT NULL DEFAULT 'UZS',
        user_limit integer,
        storage_quota_gb integer,
        features jsonb NOT NULL DEFAULT '[]'::jsonb,
        is_active boolean NOT NULL DEFAULT true,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now()
      );

      CREATE TABLE tenant_subscriptions (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        plan_id uuid NOT NULL REFERENCES subscription_plans(id),
        billing_cycle varchar(20) NOT NULL DEFAULT 'MONTHLY',
        status varchar(20) NOT NULL DEFAULT 'ACTIVE',
        started_at timestamptz NOT NULL DEFAULT now(),
        ends_at timestamptz,
        created_by uuid,
        created_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT tenant_subscriptions_cycle_check CHECK (billing_cycle IN ('MONTHLY', 'ANNUAL')),
        CONSTRAINT tenant_subscriptions_status_check CHECK (status IN ('ACTIVE', 'SUSPENDED', 'CANCELLED'))
      );
      CREATE UNIQUE INDEX tenant_subscriptions_one_active_idx ON tenant_subscriptions (tenant_id) WHERE status = 'ACTIVE';

      CREATE TABLE tenant_feature_flags (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        feature_key varchar(100) NOT NULL,
        is_enabled boolean NOT NULL DEFAULT false,
        enabled_at timestamptz,
        enabled_by uuid,
        UNIQUE (tenant_id, feature_key)
      );
      ALTER TABLE tenant_feature_flags ENABLE ROW LEVEL SECURITY;
      ALTER TABLE tenant_feature_flags FORCE ROW LEVEL SECURITY;
      CREATE POLICY tenant_feature_flags_tenant_isolation ON tenant_feature_flags
        USING (tenant_id = nullif(current_setting('app.current_tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = nullif(current_setting('app.current_tenant_id', true), '')::uuid);

      CREATE TABLE platform_users (
        id uuid PRIMARY KEY,
        email varchar(255) NOT NULL UNIQUE,
        password_hash varchar(255) NOT NULL,
        full_name varchar(255) NOT NULL,
        status varchar(20) NOT NULL DEFAULT 'ACTIVE',
        failed_login_attempts smallint NOT NULL DEFAULT 0,
        locked_until timestamptz,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now()
      );

      CREATE TABLE platform_sessions (
        id uuid PRIMARY KEY,
        platform_user_id uuid NOT NULL REFERENCES platform_users(id),
        refresh_token_hash varchar(255) NOT NULL,
        expires_at timestamptz NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now()
      );

      CREATE TABLE platform_audit_events (
        id uuid PRIMARY KEY,
        event_type varchar(100) NOT NULL,
        actor_id uuid NOT NULL,
        tenant_id uuid,
        target_type varchar(50),
        target_id uuid,
        payload jsonb,
        created_at timestamptz NOT NULL DEFAULT now()
      );

      INSERT INTO subscription_plans (id, name, description, user_limit, features)
      VALUES (gen_random_uuid(), 'Standard', 'Standard plan for textile factories', 200, '["module.production","module.payroll","module.warehouse","module.reports"]'::jsonb);

      REVOKE ALL ON subscription_plans FROM texerp_app;
      REVOKE ALL ON tenant_subscriptions FROM texerp_app;
      REVOKE ALL ON tenant_feature_flags FROM texerp_app;
      REVOKE ALL ON platform_users FROM texerp_app;
      REVOKE ALL ON platform_sessions FROM texerp_app;
      REVOKE ALL ON platform_audit_events FROM texerp_app;
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP TABLE IF EXISTS platform_audit_events;
      DROP TABLE IF EXISTS platform_sessions;
      DROP TABLE IF EXISTS platform_users;
      DROP TABLE IF EXISTS tenant_feature_flags;
      DROP TABLE IF EXISTS tenant_subscriptions;
      DROP TABLE IF EXISTS subscription_plans;

      ALTER TABLE tenants DROP COLUMN IF EXISTS legal_name;
      ALTER TABLE tenants DROP COLUMN IF EXISTS contact_email;
      ALTER TABLE tenants DROP COLUMN IF EXISTS contact_phone;
      ALTER TABLE tenants DROP COLUMN IF EXISTS country;
      ALTER TABLE tenants DROP COLUMN IF EXISTS terminated_at;
      ALTER TABLE tenants DROP COLUMN IF EXISTS deletion_scheduled_at;
      ALTER TABLE tenants DROP COLUMN IF EXISTS suspend_reason;
    `);
  }
}
