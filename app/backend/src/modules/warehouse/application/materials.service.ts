import { Injectable } from '@nestjs/common';
import { QueryFailedError, type EntityManager } from 'typeorm';
import { TenantDatabase } from '../../../infrastructure/database/tenant-database';
import { uuidv7 } from '../../../shared/common/uuid';
import { CreateMaterialDto } from './dto/create-material.dto';
import { ListMaterialsQueryDto } from './dto/list-materials-query.dto';
import { UpdateMaterialDto } from './dto/update-material.dto';
import { MaterialCodeExistsError } from './errors/material-code-exists.error';
import { MaterialNotFoundError } from './errors/material-not-found.error';

export interface MaterialView {
  id: string;
  tenant_id: string;
  code: string;
  name: string;
  category: string | null;
  unit: 'METERS' | 'KG' | 'ROLLS' | 'PIECES';
  min_quantity: number | null;
  is_active: boolean;
  balance: number;
  created_by: string;
  created_at: Date;
  updated_at: Date;
}

interface MaterialRow {
  id: string;
  tenant_id: string;
  code: string;
  name: string;
  category: string | null;
  unit: 'METERS' | 'KG' | 'ROLLS' | 'PIECES';
  min_quantity: number | null;
  is_active: boolean;
  created_by: string;
  created_at: Date;
  updated_at: Date;
}

@Injectable()
export class MaterialsService {
  constructor(private readonly tenantDatabase: TenantDatabase) {}

  async create(
    tenantId: string,
    actorId: string,
    dto: CreateMaterialDto,
  ): Promise<MaterialView> {
    try {
      return await this.tenantDatabase.withTenant(tenantId, async (manager) => {
        await this.assertCodeAvailable(manager, tenantId, dto.code);

        const materialId = uuidv7();
        const timestampResult = await manager.query<{ ts: Date }[]>(
          `SELECT clock_timestamp() AS ts`,
        );
        const timestamp = timestampResult[0].ts;

        await manager.query(
          `INSERT INTO materials
             (id, tenant_id, code, name, category, unit, min_quantity,
              is_active, created_by, created_at, updated_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, true, $8, $9, $9)`,
          [
            materialId,
            tenantId,
            dto.code.trim(),
            dto.name.trim(),
            dto.category?.trim() ?? null,
            dto.unit,
            dto.min_quantity ?? null,
            actorId,
            timestamp,
          ],
        );

        return {
          id: materialId,
          tenant_id: tenantId,
          code: dto.code.trim(),
          name: dto.name.trim(),
          category: dto.category?.trim() ?? null,
          unit: dto.unit,
          min_quantity: dto.min_quantity ?? null,
          is_active: true,
          balance: 0,
          created_by: actorId,
          created_at: timestamp,
          updated_at: timestamp,
        };
      });
    } catch (error) {
      this.mapUniqueViolation(error);
      throw error;
    }
  }

  async list(
    tenantId: string,
    query: ListMaterialsQueryDto,
  ): Promise<{ data: MaterialView[]; total: number }> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const conditions: string[] = ['m.tenant_id = $1'];
      const params: unknown[] = [tenantId];
      let paramIndex = 2;

      if (query.is_active !== undefined) {
        conditions.push(`m.is_active = $${paramIndex++}`);
        params.push(query.is_active);
      }
      if (query.category) {
        conditions.push(`m.category = $${paramIndex++}`);
        params.push(query.category);
      }
      if (query.search) {
        const search = `%${query.search}%`;
        conditions.push(
          `(m.name ILIKE $${paramIndex++} OR m.code ILIKE $${paramIndex++})`,
        );
        params.push(search, search);
      }

      const whereClause = conditions.join(' AND ');

      const countResult = await manager.query<{ count: string }[]>(
        `SELECT COUNT(*)::text AS count
         FROM materials m
         WHERE ${whereClause}`,
        params,
      );
      const total = Number.parseInt(countResult[0].count, 10);

      const limitIndex = paramIndex++;
      const offsetIndex = paramIndex;
      const materials = await manager.query<MaterialRow[]>(
        `SELECT m.id, m.tenant_id, m.code, m.name, m.category, m.unit,
                m.min_quantity, m.is_active, m.created_by, m.created_at, m.updated_at
         FROM materials m
         WHERE ${whereClause}
         ORDER BY m.created_at DESC
         LIMIT $${limitIndex} OFFSET $${offsetIndex}`,
        [...params, query.limit, query.offset],
      );

      const data = await Promise.all(
        materials.map(async (material) => ({
          ...material,
          balance: await this.computeBalance(manager, tenantId, material.id),
        })),
      );

      return { data, total };
    });
  }

  async get(tenantId: string, materialId: string): Promise<MaterialView> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const material = await this.requireMaterial(manager, tenantId, materialId);
      const balance = await this.computeBalance(manager, tenantId, materialId);
      return { ...material, balance };
    });
  }

  async update(
    tenantId: string,
    materialId: string,
    dto: UpdateMaterialDto,
  ): Promise<MaterialView> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      await this.requireMaterial(manager, tenantId, materialId);

      const sets: string[] = [];
      const values: unknown[] = [];
      let paramIndex = 1;

      if (dto.name !== undefined) {
        sets.push(`name = $${paramIndex++}`);
        values.push(dto.name.trim());
      }
      if (dto.category !== undefined) {
        sets.push(`category = $${paramIndex++}`);
        values.push(dto.category?.trim() ?? null);
      }
      if (dto.min_quantity !== undefined) {
        sets.push(`min_quantity = $${paramIndex++}`);
        values.push(dto.min_quantity);
      }

      if (sets.length === 0) {
        const material = await this.requireMaterial(
          manager,
          tenantId,
          materialId,
        );
        return {
          ...material,
          balance: await this.computeBalance(manager, tenantId, materialId),
        };
      }

      sets.push(`updated_at = now()`);
      values.push(tenantId);
      values.push(materialId);

      await manager.query(
        `UPDATE materials SET ${sets.join(', ')}
         WHERE tenant_id = $${paramIndex++} AND id = $${paramIndex}`,
        values,
      );

      const material = await this.requireMaterial(
        manager,
        tenantId,
        materialId,
      );
      return {
        ...material,
        balance: await this.computeBalance(manager, tenantId, materialId),
      };
    });
  }

  async deactivate(tenantId: string, materialId: string): Promise<MaterialView> {
    return this.setActive(tenantId, materialId, false);
  }

  async activate(tenantId: string, materialId: string): Promise<MaterialView> {
    return this.setActive(tenantId, materialId, true);
  }

  async getBalance(
    tenantId: string,
    materialId: string,
  ): Promise<{ material_id: string; balance: number }> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      await this.requireMaterial(manager, tenantId, materialId);
      const balance = await this.computeBalance(manager, tenantId, materialId);
      return { material_id: materialId, balance };
    });
  }

  async requireMaterial(
    manager: EntityManager,
    tenantId: string,
    materialId: string,
  ): Promise<MaterialRow> {
    const rows = await manager.query<MaterialRow[]>(
      `SELECT id, tenant_id, code, name, category, unit, min_quantity,
              is_active, created_by, created_at, updated_at
       FROM materials
       WHERE tenant_id = $1 AND id = $2
       LIMIT 1`,
      [tenantId, materialId],
    );
    const material = rows[0];
    if (!material) {
      throw new MaterialNotFoundError(materialId);
    }
    return material;
  }

  async computeBalance(
    manager: EntityManager,
    tenantId: string,
    materialId: string,
  ): Promise<number> {
    const result = await manager.query<{ balance: number | string }[]>(
      `SELECT COALESCE(SUM(
         CASE WHEN type IN ('RECEIPT', 'CORRECTION_POSITIVE') THEN quantity
              WHEN type IN ('ISSUANCE', 'CORRECTION_NEGATIVE') THEN -quantity
         END
       ), 0) AS balance
       FROM stock_movements
       WHERE tenant_id = $1 AND material_id = $2`,
      [tenantId, materialId],
    );
    const raw = result[0]?.balance ?? 0;
    return typeof raw === 'string' ? Number.parseFloat(raw) : Number(raw);
  }

  private async setActive(
    tenantId: string,
    materialId: string,
    isActive: boolean,
  ): Promise<MaterialView> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      await this.requireMaterial(manager, tenantId, materialId);

      await manager.query(
        `UPDATE materials
         SET is_active = $3, updated_at = now()
         WHERE tenant_id = $1 AND id = $2`,
        [tenantId, materialId, isActive],
      );

      const material = await this.requireMaterial(
        manager,
        tenantId,
        materialId,
      );
      return {
        ...material,
        balance: await this.computeBalance(manager, tenantId, materialId),
      };
    });
  }

  private async assertCodeAvailable(
    manager: EntityManager,
    tenantId: string,
    code: string,
  ): Promise<void> {
    const rows = await manager.query<{ id: string }[]>(
      `SELECT id FROM materials
       WHERE tenant_id = $1 AND lower(code) = lower($2)
       LIMIT 1`,
      [tenantId, code.trim()],
    );
    if (rows[0]) {
      throw new MaterialCodeExistsError(code);
    }
  }

  private mapUniqueViolation(error: unknown): void {
    if (!(error instanceof QueryFailedError)) return;
    const driverError = error.driverError as {
      code?: string;
      constraint?: string;
    };
    if (
      driverError?.code === '23505' &&
      driverError?.constraint === 'materials_code_ci_uidx'
    ) {
      const message = error.message;
      const match = /Key \(tenant_id, lower\(code\)\)=\(([^,]+), ([^)]+)\)/.exec(
        message,
      );
      throw new MaterialCodeExistsError(match?.[2] ?? 'unknown');
    }
  }
}
