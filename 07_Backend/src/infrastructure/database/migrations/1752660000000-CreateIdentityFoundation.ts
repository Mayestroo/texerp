import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateIdentityFoundation1752660000000
  implements MigrationInterface
{
  name = 'CreateIdentityFoundation1752660000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TYPE tenant_status AS ENUM ('ACTIVE', 'SUSPENDED', 'TERMINATED');
      CREATE TYPE tenant_language AS ENUM ('uz', 'ru', 'uz_ru');
      CREATE TYPE user_role AS ENUM ('WORKER', 'FOREMAN', 'ACCOUNTANT', 'DIRECTOR');
      CREATE TYPE user_status AS ENUM ('ACTIVE', 'DEACTIVATED');

      CREATE TABLE tenants (
        id uuid PRIMARY KEY,
        name varchar(255) NOT NULL,
        slug varchar(100) NOT NULL UNIQUE,
        status tenant_status NOT NULL DEFAULT 'ACTIVE',
        timezone varchar(50) NOT NULL DEFAULT 'Asia/Tashkent',
        language tenant_language NOT NULL DEFAULT 'uz',
        currency char(3) NOT NULL DEFAULT 'UZS',
        back_date_window_days smallint NOT NULL DEFAULT 3,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT tenants_back_date_window_check
          CHECK (back_date_window_days BETWEEN 1 AND 7),
        CONSTRAINT tenants_currency_check CHECK (currency = 'UZS')
      );

      CREATE TABLE users (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        phone varchar(13) NOT NULL,
        pin_hash varchar(255) NOT NULL,
        full_name varchar(255) NOT NULL,
        worker_code varchar(20) NOT NULL,
        role user_role NOT NULL,
        status user_status NOT NULL DEFAULT 'ACTIVE',
        language varchar(2) NOT NULL DEFAULT 'uz',
        avatar_url varchar(500),
        failed_login_attempts smallint NOT NULL DEFAULT 0,
        locked_until timestamptz,
        deactivated_at timestamptz,
        deactivated_by uuid,
        created_by uuid,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT users_phone_format_check CHECK (phone ~ '^\\+998[0-9]{9}$'),
        CONSTRAINT users_language_check CHECK (language IN ('uz', 'ru')),
        CONSTRAINT users_failed_login_attempts_check CHECK (failed_login_attempts >= 0),
        UNIQUE (tenant_id, id),
        UNIQUE (phone),
        UNIQUE (tenant_id, worker_code),
        FOREIGN KEY (tenant_id, deactivated_by) REFERENCES users(tenant_id, id),
        FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id)
      );

      CREATE TABLE departments (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        name varchar(255) NOT NULL,
        code varchar(30) NOT NULL,
        foreman_id uuid,
        is_active boolean NOT NULL DEFAULT true,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        UNIQUE (tenant_id, id),
        UNIQUE (tenant_id, code),
        UNIQUE (tenant_id, name),
        FOREIGN KEY (tenant_id, foreman_id) REFERENCES users(tenant_id, id)
      );

      CREATE TABLE foreman_assignments (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        worker_id uuid NOT NULL,
        foreman_id uuid NOT NULL,
        department_id uuid NOT NULL,
        assigned_at timestamptz NOT NULL DEFAULT now(),
        unassigned_at timestamptz,
        assigned_by uuid NOT NULL,
        CONSTRAINT foreman_assignments_distinct_users_check
          CHECK (worker_id <> foreman_id),
        CONSTRAINT foreman_assignments_dates_check
          CHECK (unassigned_at IS NULL OR unassigned_at >= assigned_at),
        FOREIGN KEY (tenant_id, worker_id) REFERENCES users(tenant_id, id),
        FOREIGN KEY (tenant_id, foreman_id) REFERENCES users(tenant_id, id),
        FOREIGN KEY (tenant_id, department_id) REFERENCES departments(tenant_id, id),
        FOREIGN KEY (tenant_id, assigned_by) REFERENCES users(tenant_id, id)
      );

      CREATE UNIQUE INDEX foreman_assignments_one_active_per_worker
        ON foreman_assignments (tenant_id, worker_id)
        WHERE unassigned_at IS NULL;
      CREATE INDEX foreman_assignments_active_foreman_idx
        ON foreman_assignments (tenant_id, foreman_id)
        WHERE unassigned_at IS NULL;

      CREATE TABLE user_sessions (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        user_id uuid NOT NULL,
        refresh_token_hash varchar(255) NOT NULL UNIQUE,
        device_fingerprint varchar(255),
        ip_address inet,
        user_agent varchar(500),
        expires_at timestamptz NOT NULL,
        revoked_at timestamptz,
        revoked_reason varchar(100),
        created_at timestamptz NOT NULL DEFAULT now(),
        UNIQUE (tenant_id, id),
        FOREIGN KEY (tenant_id, user_id) REFERENCES users(tenant_id, id)
      );
      CREATE INDEX user_sessions_active_user_idx
        ON user_sessions (tenant_id, user_id, expires_at)
        WHERE revoked_at IS NULL;

      CREATE TABLE audit_events (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        aggregate_type varchar(100) NOT NULL,
        aggregate_id uuid NOT NULL,
        action varchar(100) NOT NULL,
        actor_id uuid NOT NULL,
        actor_role user_role NOT NULL,
        before_state jsonb,
        after_state jsonb,
        reason text,
        ip_address inet,
        user_agent varchar(500),
        occurred_at timestamptz NOT NULL DEFAULT now(),
        FOREIGN KEY (tenant_id, actor_id) REFERENCES users(tenant_id, id)
      );
      CREATE INDEX audit_events_aggregate_idx
        ON audit_events (tenant_id, aggregate_type, aggregate_id, occurred_at DESC);
    `);

    for (const table of [
      'users',
      'departments',
      'foreman_assignments',
      'user_sessions',
      'audit_events',
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

    await queryRunner.query(`
      REVOKE ALL ON tenants FROM texerp_app;
      REVOKE UPDATE, DELETE ON audit_events FROM texerp_app;
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP TABLE IF EXISTS audit_events;
      DROP TABLE IF EXISTS user_sessions;
      DROP TABLE IF EXISTS foreman_assignments;
      DROP TABLE IF EXISTS departments;
      DROP TABLE IF EXISTS users;
      DROP TABLE IF EXISTS tenants;
      DROP TYPE IF EXISTS user_status;
      DROP TYPE IF EXISTS user_role;
      DROP TYPE IF EXISTS tenant_language;
      DROP TYPE IF EXISTS tenant_status;
    `);
  }
}
