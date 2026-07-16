import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateAuthLookup1752661000000 implements MigrationInterface {
  name = 'CreateAuthLookup1752661000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE used_refresh_tokens (
        refresh_token_hash varchar(255) PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        session_id uuid NOT NULL,
        user_id uuid NOT NULL,
        used_at timestamptz NOT NULL DEFAULT now(),
        FOREIGN KEY (tenant_id, session_id)
          REFERENCES user_sessions(tenant_id, id) ON DELETE CASCADE,
        FOREIGN KEY (tenant_id, user_id)
          REFERENCES users(tenant_id, id)
      );
      ALTER TABLE used_refresh_tokens ENABLE ROW LEVEL SECURITY;
      ALTER TABLE used_refresh_tokens FORCE ROW LEVEL SECURITY;
      CREATE POLICY used_refresh_tokens_tenant_isolation ON used_refresh_tokens
        USING (
          tenant_id = nullif(current_setting('app.current_tenant_id', true), '')::uuid
        )
        WITH CHECK (
          tenant_id = nullif(current_setting('app.current_tenant_id', true), '')::uuid
        );
      REVOKE UPDATE, DELETE ON used_refresh_tokens FROM texerp_app;

      CREATE FUNCTION auth_lookup_user(p_phone text)
      RETURNS TABLE (
        id uuid,
        tenant_id uuid,
        phone varchar,
        pin_hash varchar,
        full_name varchar,
        worker_code varchar,
        role user_role,
        user_status user_status,
        language varchar,
        avatar_url varchar,
        department_id uuid,
        department_name varchar,
        foreman_id uuid,
        foreman_name varchar,
        failed_login_attempts smallint,
        locked_until timestamptz,
        tenant_status tenant_status
      )
      LANGUAGE sql
      SECURITY DEFINER
      SET search_path = pg_catalog
      AS $$
        SELECT
          u.id,
          u.tenant_id,
          u.phone,
          u.pin_hash,
          u.full_name,
          u.worker_code,
          u.role,
          u.status,
          u.language,
          u.avatar_url,
          d.id,
          d.name,
          f.id,
          f.full_name,
          u.failed_login_attempts,
          u.locked_until,
          t.status
        FROM public.users u
        JOIN public.tenants t ON t.id = u.tenant_id
        LEFT JOIN public.foreman_assignments a
          ON a.tenant_id = u.tenant_id
          AND a.worker_id = u.id
          AND a.unassigned_at IS NULL
        LEFT JOIN public.departments d
          ON d.tenant_id = a.tenant_id AND d.id = a.department_id
        LEFT JOIN public.users f
          ON f.tenant_id = a.tenant_id AND f.id = a.foreman_id
        WHERE u.phone = p_phone
        LIMIT 1
      $$;

      REVOKE ALL ON FUNCTION auth_lookup_user(text) FROM PUBLIC;
      GRANT EXECUTE ON FUNCTION auth_lookup_user(text) TO texerp_app;

      CREATE FUNCTION auth_lookup_session(p_refresh_token_hash varchar)
      RETURNS TABLE (
        session_id uuid,
        tenant_id uuid,
        user_id uuid,
        refresh_token_hash varchar,
        expires_at timestamptz,
        revoked_at timestamptz,
        phone varchar,
        role user_role,
        user_status user_status,
        tenant_status tenant_status,
        token_state varchar
      )
      LANGUAGE sql
      SECURITY DEFINER
      SET search_path = pg_catalog
      AS $$
        WITH token_match AS (
          SELECT s.id AS session_id, 'CURRENT'::varchar AS token_state
          FROM public.user_sessions s
          WHERE s.refresh_token_hash = p_refresh_token_hash
          UNION ALL
          SELECT r.session_id, 'USED'::varchar AS token_state
          FROM public.used_refresh_tokens r
          WHERE r.refresh_token_hash = p_refresh_token_hash
          LIMIT 1
        )
        SELECT
          s.id,
          s.tenant_id,
          s.user_id,
          s.refresh_token_hash,
          s.expires_at,
          s.revoked_at,
          u.phone,
          u.role,
          u.status,
          t.status,
          token_match.token_state
        FROM token_match
        JOIN public.user_sessions s ON s.id = token_match.session_id
        JOIN public.users u ON u.id = s.user_id AND u.tenant_id = s.tenant_id
        JOIN public.tenants t ON t.id = s.tenant_id
      $$;

      REVOKE ALL ON FUNCTION auth_lookup_session(varchar) FROM PUBLIC;
      GRANT EXECUTE ON FUNCTION auth_lookup_session(varchar) TO texerp_app;

      CREATE FUNCTION auth_validate_session(
        p_session_id uuid,
        p_user_id uuid,
        p_tenant_id uuid
      )
      RETURNS boolean
      LANGUAGE sql
      SECURITY DEFINER
      SET search_path = pg_catalog
      AS $$
        SELECT EXISTS (
          SELECT 1
          FROM public.user_sessions s
          JOIN public.users u
            ON u.id = s.user_id AND u.tenant_id = s.tenant_id
          JOIN public.tenants t ON t.id = s.tenant_id
          WHERE s.id = p_session_id
            AND s.user_id = p_user_id
            AND s.tenant_id = p_tenant_id
            AND s.revoked_at IS NULL
            AND s.expires_at > now()
            AND u.status = 'ACTIVE'
            AND t.status = 'ACTIVE'
        )
      $$;
      REVOKE ALL ON FUNCTION auth_validate_session(uuid, uuid, uuid) FROM PUBLIC;
      GRANT EXECUTE ON FUNCTION auth_validate_session(uuid, uuid, uuid) TO texerp_app;

      CREATE FUNCTION revoke_sessions_on_user_deactivation()
      RETURNS trigger
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path = pg_catalog
      AS $$
      BEGIN
        IF OLD.status = 'ACTIVE' AND NEW.status = 'DEACTIVATED' THEN
          UPDATE public.user_sessions
          SET revoked_at = now(), revoked_reason = 'DEACTIVATED'
          WHERE tenant_id = NEW.tenant_id
            AND user_id = NEW.id
            AND revoked_at IS NULL;
        END IF;
        RETURN NEW;
      END
      $$;
      REVOKE ALL ON FUNCTION revoke_sessions_on_user_deactivation() FROM PUBLIC;
      CREATE TRIGGER users_revoke_sessions_on_deactivation
        AFTER UPDATE OF status ON users
        FOR EACH ROW
        EXECUTE FUNCTION revoke_sessions_on_user_deactivation();
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP TRIGGER IF EXISTS users_revoke_sessions_on_deactivation ON users;
      DROP FUNCTION IF EXISTS revoke_sessions_on_user_deactivation();
      DROP FUNCTION IF EXISTS auth_validate_session(uuid, uuid, uuid);
      DROP FUNCTION IF EXISTS auth_lookup_session(varchar);
      DROP FUNCTION IF EXISTS auth_lookup_user(text);
      DROP TABLE IF EXISTS used_refresh_tokens;
    `);
  }
}
