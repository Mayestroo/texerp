import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateWarehouseTables1753400000000
  implements MigrationInterface
{
  name = 'CreateWarehouseTables1753400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE materials (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        code varchar(50) NOT NULL,
        name varchar(255) NOT NULL,
        category varchar(100),
        unit varchar(20) NOT NULL,
        min_quantity numeric(14,3),
        is_active boolean NOT NULL DEFAULT true,
        created_by uuid NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT materials_unit_check CHECK (unit IN ('METERS', 'KG', 'ROLLS', 'PIECES')),
        CONSTRAINT materials_min_qty_check CHECK (min_quantity IS NULL OR min_quantity >= 0),
        UNIQUE (tenant_id, id),
        FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id)
      );

      CREATE UNIQUE INDEX materials_code_ci_uidx ON materials (tenant_id, lower(code));
      CREATE INDEX materials_active_category_idx ON materials (tenant_id, is_active, category);

      CREATE TABLE stock_movements (
        id uuid PRIMARY KEY,
        tenant_id uuid NOT NULL REFERENCES tenants(id),
        material_id uuid NOT NULL,
        type varchar(30) NOT NULL,
        quantity numeric(14,3) NOT NULL,
        unit_snapshot varchar(20) NOT NULL,
        supplier_name varchar(255),
        destination varchar(255),
        movement_date date NOT NULL,
        note text,
        photo_urls jsonb DEFAULT '[]'::jsonb,
        correction_reason text,
        is_flagged boolean NOT NULL DEFAULT false,
        recorded_by uuid NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT stock_movements_type_check CHECK (type IN ('RECEIPT', 'ISSUANCE', 'CORRECTION_POSITIVE', 'CORRECTION_NEGATIVE')),
        CONSTRAINT stock_movements_qty_check CHECK (quantity > 0),
        UNIQUE (tenant_id, id),
        FOREIGN KEY (tenant_id, material_id) REFERENCES materials(tenant_id, id),
        FOREIGN KEY (tenant_id, recorded_by) REFERENCES users(tenant_id, id)
      );

      CREATE INDEX stock_movements_material_idx ON stock_movements (tenant_id, material_id, created_at DESC);
      CREATE INDEX stock_movements_date_idx ON stock_movements (tenant_id, movement_date DESC);
    `);

    for (const table of ['materials', 'stock_movements']) {
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
      REVOKE UPDATE, DELETE ON stock_movements FROM texerp_app;
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP TABLE IF EXISTS stock_movements;
      DROP TABLE IF EXISTS materials;
    `);
  }
}
