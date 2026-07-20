import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateDeviceTokens1753000000000 implements MigrationInterface {
  name = 'CreateDeviceTokens1753000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE device_tokens (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        user_id uuid NOT NULL,
        fcm_token varchar(500) NOT NULL,
        platform varchar(10) NOT NULL,
        is_active boolean NOT NULL DEFAULT true,
        registered_at timestamptz NOT NULL DEFAULT now(),
        last_used_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT device_tokens_platform_check CHECK (platform IN ('ANDROID', 'IOS')),
        UNIQUE (tenant_id, id),
        FOREIGN KEY (tenant_id, user_id) REFERENCES users(tenant_id, id)
      );

      CREATE UNIQUE INDEX device_tokens_active_user_platform_idx
        ON device_tokens (tenant_id, user_id, platform)
        WHERE is_active = true;

      CREATE INDEX device_tokens_fcm_token_idx
        ON device_tokens (fcm_token);
    `);

    await queryRunner.query(`
      ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
      ALTER TABLE device_tokens FORCE ROW LEVEL SECURITY;
      CREATE POLICY device_tokens_tenant_isolation ON device_tokens
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
      DROP TABLE IF EXISTS device_tokens;
    `);
  }
}
