import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateNotifications1753200000000 implements MigrationInterface {
  name = 'CreateNotifications1753200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE notifications (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        recipient_id uuid NOT NULL,
        type varchar(100) NOT NULL,
        title_uz varchar(255) NOT NULL,
        title_ru varchar(255) NOT NULL,
        body_uz text NOT NULL,
        body_ru text NOT NULL,
        data jsonb,
        channel varchar(20) NOT NULL DEFAULT 'BOTH',
        push_status varchar(20) NOT NULL DEFAULT 'PENDING',
        push_sent_at timestamptz,
        push_attempts integer NOT NULL DEFAULT 0,
        is_read boolean NOT NULL DEFAULT false,
        read_at timestamptz,
        archived_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT notifications_channel_check CHECK (channel IN ('PUSH', 'IN_APP', 'BOTH')),
        CONSTRAINT notifications_push_status_check CHECK (push_status IN ('PENDING', 'SENT', 'DELIVERED', 'FAILED')),
        UNIQUE (tenant_id, id),
        FOREIGN KEY (tenant_id, recipient_id) REFERENCES users(tenant_id, id)
      );

      CREATE TABLE notification_preferences (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        user_id uuid NOT NULL,
        notification_type varchar(100) NOT NULL,
        is_enabled boolean NOT NULL DEFAULT true,
        UNIQUE (tenant_id, id),
        UNIQUE (tenant_id, user_id, notification_type),
        FOREIGN KEY (tenant_id, user_id) REFERENCES users(tenant_id, id)
      );

      CREATE INDEX notifications_recipient_unread_idx
        ON notifications (tenant_id, recipient_id)
        WHERE is_read = false;

      CREATE INDEX notifications_recipient_created_idx
        ON notifications (tenant_id, recipient_id, created_at DESC);
    `);

    for (const table of ['notifications', 'notification_preferences']) {
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
      DROP TABLE IF EXISTS notification_preferences;
      DROP TABLE IF EXISTS notifications;
    `);
  }
}
