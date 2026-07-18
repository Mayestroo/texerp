import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddApprovalFields1752850000000 implements MigrationInterface {
  name = 'AddApprovalFields1752850000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE production_entries
        ADD COLUMN approved_at timestamptz,
        ADD COLUMN approved_by uuid,
        ADD COLUMN rejected_at timestamptz,
        ADD COLUMN rejected_by uuid,
        ADD COLUMN rejection_reason varchar(500),
        ADD COLUMN foreman_note varchar(500),
        ADD COLUMN correction_comment varchar(500);

      ALTER TABLE production_entries
        ADD CONSTRAINT production_entries_approved_by_fk
          FOREIGN KEY (tenant_id, approved_by) REFERENCES users(tenant_id, id),
        ADD CONSTRAINT production_entries_rejected_by_fk
          FOREIGN KEY (tenant_id, rejected_by) REFERENCES users(tenant_id, id);
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE production_entries
        DROP CONSTRAINT IF EXISTS production_entries_rejected_by_fk,
        DROP CONSTRAINT IF EXISTS production_entries_approved_by_fk,
        DROP COLUMN IF EXISTS correction_comment,
        DROP COLUMN IF EXISTS foreman_note,
        DROP COLUMN IF EXISTS rejection_reason,
        DROP COLUMN IF EXISTS rejected_by,
        DROP COLUMN IF EXISTS rejected_at,
        DROP COLUMN IF EXISTS approved_by,
        DROP COLUMN IF EXISTS approved_at;
    `);
  }
}
