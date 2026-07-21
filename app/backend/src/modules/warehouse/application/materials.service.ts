import { Injectable } from '@nestjs/common';
import { QueryFailedError, type EntityManager } from 'typeorm';
import { TenantDatabase } from '../../../infrastructure/database/tenant-database';
import { uuidv7 } from '../../../shared/common/uuid';
import { CreateMaterialDto } from './dto/create-material.dto';
import { ListMaterialsQueryDto } from './dto/list-materials-query.dto';
import { UpdateMaterialDto } from './dto/update-material.dto';
import { MaterialCodeExistsError } from './errors/material-code-exists.error';
import { MaterialNotFoundError } from './errors/material-not-found.error';
import { stockBalanceSumCase } from './stock-balance.helper';
import { StockMovementsService } from './stock-movements.service';

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

interface MaterialListRow extends MaterialRow {
  balance: number | string;
}

@Injectable()
export class MaterialsService {
  constructor(
    private readonly tenantDatabase: TenantDatabase,
    private readonly stockMovementsService: StockMovementsService,
  ) {}

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

        const afterState = {
          id: materialId,
          code: dto.code.trim(),
          name: dto.name.trim(),
          category: dto.category?.trim() ?? null,
          unit: dto.unit,
          min_quantity: dto.min_quantity ?? null,
          is_active: true,
        };

        await this.insertAudit(manager, tenantId, materialId, 'MATERIAL_CREATED', actorId, null, afterState);

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
          ...afterState,
          tenant_id: tenantId,
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
      const materials = await manager.query<MaterialListRow[]>(
        `SELECT m.id, m.tenant_id, m.code, m.name, m.category, m.unit,
                m.min_quantity, m.is_active, m.created_by, m.created_at, m.updated_at,
                COALESCE(b.balance, 0) AS balance
         FROM materials m
         LEFT JOIN (
           SELECT material_id, ${stockBalanceSumCase.trim()} AS balance
           FROM stock_movements
           WHERE tenant_id = $1
           GROUP BY material_id
         ) b ON b.material_id = m.id
         WHERE ${whereClause}
         ORDER BY m.created_at DESC
         LIMIT $${limitIndex} OFFSET $${offsetIndex}`,
        [...params, query.limit, query.offset],
      );

      const data = materials.map((material) => ({
        ...material,
        balance:
          typeof material.balance === 'string'
            ? Number.parseFloat(material.balance)
            : Number(material.balance),
      }));

      return { data, total };
    });
  }

  async get(tenantId: string, materialId: string): Promise<MaterialView> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const material = await this.requireMaterial(manager, tenantId, materialId);
      const balance = await this.stockMovementsService.computeBalance(materialId, manager);
      return { ...material, balance };
    });
  }

  async update(
    tenantId: string,
    actorId: string,
    materialId: string,
    dto: UpdateMaterialDto,
  ): Promise<MaterialView> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const material = await this.requireMaterial(manager, tenantId, materialId);

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
        const balance = await this.stockMovementsService.computeBalance(materialId, manager);
        return { ...material, balance };
      }

      const beforeState = {
        name: material.name,
        category: material.category,
        min_quantity: material.min_quantity,
      };
      const afterState = {
        name: dto.name !== undefined ? dto.name.trim() : material.name,
        category:
          dto.category !== undefined
            ? dto.category?.trim() ?? null
            : material.category,
        min_quantity:
          dto.min_quantity !== undefined
            ? dto.min_quantity
            : material.min_quantity,
      };

      await this.insertAudit(manager, tenantId, materialId, 'MATERIAL_UPDATED', actorId, beforeState, afterState);

      sets.push(`updated_at = now()`);
      values.push(tenantId);
      values.push(materialId);

      await manager.query(
        `UPDATE materials SET ${sets.join(', ')}
         WHERE tenant_id = $${paramIndex++} AND id = $${paramIndex}`,
        values,
      );

      const updated = await this.requireMaterial(manager, tenantId, materialId);
      const balance = await this.stockMovementsService.computeBalance(materialId, manager);
      return { ...updated, balance };
    });
  }

  async deactivate(
    tenantId: string,
    actorId: string,
    materialId: string,
  ): Promise<MaterialView> {
    return this.setActive(tenantId, actorId, materialId, false);
  }

  async activate(
    tenantId: string,
    actorId: string,
    materialId: string,
  ): Promise<MaterialView> {
    return this.setActive(tenantId, actorId, materialId, true);
  }

  async getBalance(
    tenantId: string,
    materialId: string,
  ): Promise<{ material_id: string; balance: number }> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      await this.requireMaterial(manager, tenantId, materialId);
      const balance = await this.stockMovementsService.computeBalance(materialId, manager);
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

  private async setActive(
    tenantId: string,
    actorId: string,
    materialId: string,
    isActive: boolean,
  ): Promise<MaterialView> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const material = await this.requireMaterial(manager, tenantId, materialId);

      const beforeState = { is_active: material.is_active };
      const afterState = { is_active: isActive };
      const action = isActive ? 'MATERIAL_REACTIVATED' : 'MATERIAL_DEACTIVATED';

      await this.insertAudit(manager, tenantId, materialId, action, actorId, beforeState, afterState);

      await manager.query(
        `UPDATE materials
         SET is_active = $3, updated_at = now()
         WHERE tenant_id = $1 AND id = $2`,
        [tenantId, materialId, isActive],
      );

      const updated = await this.requireMaterial(manager, tenantId, materialId);
      const balance = await this.stockMovementsService.computeBalance(materialId, manager);
      return { ...updated, balance };
    });
  }

  private async insertAudit(
    manager: EntityManager,
    tenantId: string,
    materialId: string,
    action: 'MATERIAL_CREATED' | 'MATERIAL_UPDATED' | 'MATERIAL_DEACTIVATED' | 'MATERIAL_REACTIVATED',
    actorId: string,
    beforeState: Record<string, unknown> | null,
    afterState: Record<string, unknown>,
  ): Promise<void> {
    if (beforeState === null) {
      await manager.query(
        `INSERT INTO audit_events
           (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
            after_state, ip_address, user_agent)
         VALUES ($1, $2, 'MATERIAL', $3, $4, $5, 'DIRECTOR',
            $6::jsonb, $7, $8)`,
        [uuidv7(), tenantId, materialId, action, actorId, JSON.stringify(afterState), null, null],
      );
      return;
    }

    await manager.query(
      `INSERT INTO audit_events
         (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
          before_state, after_state, ip_address, user_agent)
       VALUES ($1, $2, 'MATERIAL', $3, $4, $5, 'DIRECTOR',
          $6::jsonb, $7::jsonb, $8, $9)`,
      [uuidv7(), tenantId, materialId, action, actorId, JSON.stringify(beforeState), JSON.stringify(afterState), null, null],
    );
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
