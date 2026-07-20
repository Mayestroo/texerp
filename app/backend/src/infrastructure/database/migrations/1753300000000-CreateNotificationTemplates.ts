import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateNotificationTemplates1753300000000 implements MigrationInterface {
  name = 'CreateNotificationTemplates1753300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE notification_templates (
        id uuid PRIMARY KEY,
        tenant_id uuid REFERENCES tenants(id),
        type varchar(100) NOT NULL,
        channel varchar(20) NOT NULL DEFAULT 'BOTH',
        title_uz varchar(255) NOT NULL,
        title_ru varchar(255) NOT NULL,
        body_uz text NOT NULL,
        body_ru text NOT NULL,
        is_critical boolean NOT NULL DEFAULT false,
        is_active boolean NOT NULL DEFAULT true,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT notification_templates_channel_check CHECK (channel IN ('PUSH', 'IN_APP', 'BOTH', 'SMS'))
      );

      CREATE UNIQUE INDEX notification_templates_platform_default_idx
        ON notification_templates (type)
        WHERE tenant_id IS NULL AND is_active = true;

      CREATE UNIQUE INDEX notification_templates_tenant_override_idx
        ON notification_templates (tenant_id, type)
        WHERE tenant_id IS NOT NULL AND is_active = true;

      ALTER TABLE notification_templates ENABLE ROW LEVEL SECURITY;
      ALTER TABLE notification_templates FORCE ROW LEVEL SECURITY;
      CREATE POLICY notification_templates_tenant_isolation ON notification_templates
        USING (
          tenant_id IS NULL OR
          tenant_id = nullif(current_setting('app.current_tenant_id', true), '')::uuid
        )
        WITH CHECK (
          tenant_id = nullif(current_setting('app.current_tenant_id', true), '')::uuid
        );

      CREATE FUNCTION resolve_notification_template(p_type varchar)
      RETURNS TABLE(id uuid, title_uz varchar, title_ru varchar, body_uz text, body_ru text, channel varchar, is_critical boolean) AS $$
        SELECT nt.id, nt.title_uz, nt.title_ru, nt.body_uz, nt.body_ru, nt.channel, nt.is_critical
        FROM notification_templates nt
        WHERE nt.type = p_type AND nt.is_active = true
          AND (
            nt.tenant_id = nullif(current_setting('app.current_tenant_id', true), '')::uuid
            OR nt.tenant_id IS NULL
          )
        ORDER BY nt.tenant_id NULLS LAST
        LIMIT 1;
      $$ LANGUAGE sql SECURITY DEFINER STABLE;

      GRANT EXECUTE ON FUNCTION resolve_notification_template(varchar) TO texerp_app;
      REVOKE EXECUTE ON FUNCTION resolve_notification_template(varchar) FROM PUBLIC;

      INSERT INTO notification_templates (id, tenant_id, type, channel, title_uz, title_ru, body_uz, body_ru, is_critical) VALUES
        (gen_random_uuid(), NULL, 'ENTRY_APPROVED', 'BOTH', 'Yozuv tasdiqlandi', 'Запись одобрена', '{{foreman_name}} ''{{operation_name}}'' uchun {{quantity}} dona yozuvingizni tasdiqladi', '{{foreman_name}} одобрил вашу запись на {{quantity}} единиц для ''{{operation_name}}''', false),
        (gen_random_uuid(), NULL, 'ENTRY_REJECTED', 'BOTH', 'Yozuv rad etildi', 'Запись отклонена', '{{foreman_name}} yozuvingizni rad etdi: {{reason}}', '{{foreman_name}} отклонил вашу запись: {{reason}}', false),
        (gen_random_uuid(), NULL, 'PAYROLL_FINALIZED', 'BOTH', 'Oylik yakunlandi', 'Зарплата завершена', '{{period_name}} davri uchun oylik hisob-kitobi yakunlandi', 'Расчет зарплаты за период {{period_name}} завершен', true),
        (gen_random_uuid(), NULL, 'EXPORT_READY', 'BOTH', 'Eksport tayyor', 'Экспорт готов', '{{export_type}} tayyor. Yuklab olish mumkin.', '{{export_type}} готов. Можно скачивать.', false),
        (gen_random_uuid(), NULL, 'LOW_STOCK_ALERT', 'BOTH', 'Ombor ogohlantirishi', 'Складское предупреждение', '{{material_name}} zahirasi kam: {{balance}} (min: {{min_quantity}})', 'Запас {{material_name}} низкий: {{balance}} (мин: {{min_quantity}})', false);
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP FUNCTION IF EXISTS resolve_notification_template(varchar);
      DROP TABLE IF EXISTS notification_templates;
    `);
  }
}
