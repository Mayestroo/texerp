import { Injectable } from '@nestjs/common';
import { QueryFailedError, type EntityManager } from 'typeorm';
import { TenantDatabase } from '../../../infrastructure/database/tenant-database';
import { uuidv7 } from '../../../shared/utils/uuid';
import { AccessTokenClaims } from '../../iam/application/access-token-claims';
import { CreateDepartmentDto } from './dto/create-department.dto';
import { ListDepartmentsQueryDto } from './dto/list-departments-query.dto';
import { UpdateDepartmentDto } from './dto/update-department.dto';
import { DepartmentCodeAlreadyExistsError } from './errors/department-code-already-exists.error';
import { DepartmentNameAlreadyExistsError } from './errors/department-name-already-exists.error';
import { DepartmentNotFoundError } from './errors/department-not-found.error';
import { EmptyDepartmentUpdateError } from './errors/empty-department-update.error';
import { ForemanNotFoundError } from './errors/foreman-not-found.error';

interface RequestMetadata {
  ipAddress?: string;
  userAgent?: string;
}

interface DepartmentView {
  id: string;
  name: string;
  code: string;
  is_active: boolean;
  foreman: { id: string; full_name: string } | null;
  worker_count: number;
}

interface DepartmentState {
  name: string;
  code: string;
  foreman_id: string | null;
  is_active: boolean;
}

interface PostgresError {
  code?: string;
  constraint?: string;
}

@Injectable()
export class DepartmentsService {
  constructor(private readonly tenantDatabase: TenantDatabase) {}

  async list(
    tenantId: string,
    query: ListDepartmentsQueryDto,
  ): Promise<DepartmentView[]> {
    return this.tenantDatabase.withTenant(tenantId, (manager) =>
      manager.query<DepartmentView[]>(
        `SELECT
           d.id,
           d.name,
           d.code,
           d.is_active,
           CASE WHEN f.id IS NULL THEN NULL
             ELSE json_build_object('id', f.id, 'full_name', f.full_name)
           END AS foreman,
           count(fa.id)::integer AS worker_count
         FROM departments d
         LEFT JOIN users f
           ON f.tenant_id = d.tenant_id AND f.id = d.foreman_id
         LEFT JOIN foreman_assignments fa
           ON fa.tenant_id = d.tenant_id
          AND fa.department_id = d.id
          AND fa.unassigned_at IS NULL
         WHERE d.tenant_id = $1
           AND ($2::boolean OR d.is_active)
         GROUP BY d.id, f.id
         ORDER BY d.name ASC, d.id ASC`,
        [tenantId, query.include_inactive],
      ),
    );
  }

  async create(
    tenantId: string,
    actor: AccessTokenClaims,
    dto: CreateDepartmentDto,
    metadata: RequestMetadata,
  ): Promise<DepartmentView> {
    const departmentId = uuidv7();
    try {
      return await this.tenantDatabase.withTenant(tenantId, async (manager) => {
        await this.requireActiveForeman(manager, tenantId, dto.foreman_id);
        const afterState = {
          id: departmentId,
          name: dto.name,
          code: dto.code,
          foreman_id: dto.foreman_id,
          is_active: true,
        };
        await manager.query(
          `INSERT INTO audit_events
            (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
             after_state, ip_address, user_agent)
           VALUES ($1, $2, 'DEPARTMENT', $3, 'DEPARTMENT_CREATED', $4, $5,
             $6::jsonb, $7, $8)`,
          [
            uuidv7(),
            tenantId,
            departmentId,
            actor.sub,
            actor.role,
            JSON.stringify(afterState),
            metadata.ipAddress ?? null,
            metadata.userAgent ?? null,
          ],
        );
        await manager.query(
          `INSERT INTO departments (id, tenant_id, name, code, foreman_id)
           VALUES ($1, $2, $3, $4, $5)`,
          [departmentId, tenantId, dto.name, dto.code, dto.foreman_id],
        );
        return this.requireDepartmentView(manager, tenantId, departmentId);
      });
    } catch (error) {
      this.mapUniqueViolation(error);
      throw error;
    }
  }

  async update(
    tenantId: string,
    actor: AccessTokenClaims,
    departmentId: string,
    dto: UpdateDepartmentDto,
    metadata: RequestMetadata,
  ): Promise<DepartmentView> {
    if (
      dto.name === undefined &&
      dto.code === undefined &&
      dto.foreman_id === undefined &&
      dto.is_active === undefined
    ) {
      throw new EmptyDepartmentUpdateError();
    }

    try {
      return await this.tenantDatabase.withTenant(tenantId, async (manager) => {
        const rows = await manager.query<DepartmentState[]>(
          `SELECT name, code, foreman_id, is_active
           FROM departments
           WHERE tenant_id = $1 AND id = $2
           FOR UPDATE`,
          [tenantId, departmentId],
        );
        const current = rows[0];
        if (!current) throw new DepartmentNotFoundError();
        if (dto.foreman_id !== undefined) {
          await this.requireActiveForeman(manager, tenantId, dto.foreman_id);
        }

        const beforeState: Record<string, unknown> = {};
        const afterState: Record<string, unknown> = {};
        for (const field of [
          'name',
          'code',
          'foreman_id',
          'is_active',
        ] as const) {
          if (dto[field] !== undefined && dto[field] !== current[field]) {
            beforeState[field] = current[field];
            afterState[field] = dto[field];
          }
        }

        if (Object.keys(afterState).length > 0) {
          await manager.query(
            `INSERT INTO audit_events
              (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
               before_state, after_state, ip_address, user_agent)
             VALUES ($1, $2, 'DEPARTMENT', $3, 'DEPARTMENT_UPDATED', $4, $5,
               $6::jsonb, $7::jsonb, $8, $9)`,
            [
              uuidv7(),
              tenantId,
              departmentId,
              actor.sub,
              actor.role,
              JSON.stringify(beforeState),
              JSON.stringify(afterState),
              metadata.ipAddress ?? null,
              metadata.userAgent ?? null,
            ],
          );
          await manager.query(
            `UPDATE departments
             SET name = CASE WHEN $3 THEN $4 ELSE name END,
                 code = CASE WHEN $5 THEN $6 ELSE code END,
                 foreman_id = CASE WHEN $7 THEN $8 ELSE foreman_id END,
                 is_active = CASE WHEN $9 THEN $10 ELSE is_active END,
                 updated_at = now()
             WHERE tenant_id = $1 AND id = $2`,
            [
              tenantId,
              departmentId,
              dto.name !== undefined,
              dto.name ?? null,
              dto.code !== undefined,
              dto.code ?? null,
              dto.foreman_id !== undefined,
              dto.foreman_id ?? null,
              dto.is_active !== undefined,
              dto.is_active ?? null,
            ],
          );
        }
        return this.requireDepartmentView(manager, tenantId, departmentId);
      });
    } catch (error) {
      this.mapUniqueViolation(error);
      throw error;
    }
  }

  private async requireActiveForeman(
    manager: EntityManager,
    tenantId: string,
    foremanId: string,
  ): Promise<void> {
    const rows = await manager.query<Array<{ id: string }>>(
      `SELECT id
       FROM users
       WHERE tenant_id = $1
         AND id = $2
         AND role = 'FOREMAN'
         AND status = 'ACTIVE'
       FOR UPDATE`,
      [tenantId, foremanId],
    );
    if (!rows[0]) throw new ForemanNotFoundError();
  }

  private async requireDepartmentView(
    manager: EntityManager,
    tenantId: string,
    departmentId: string,
  ): Promise<DepartmentView> {
    const rows = await manager.query<DepartmentView[]>(
      `SELECT
         d.id,
         d.name,
         d.code,
         d.is_active,
         CASE WHEN f.id IS NULL THEN NULL
           ELSE json_build_object('id', f.id, 'full_name', f.full_name)
         END AS foreman,
         count(fa.id)::integer AS worker_count
       FROM departments d
       LEFT JOIN users f
         ON f.tenant_id = d.tenant_id AND f.id = d.foreman_id
       LEFT JOIN foreman_assignments fa
         ON fa.tenant_id = d.tenant_id
        AND fa.department_id = d.id
        AND fa.unassigned_at IS NULL
       WHERE d.tenant_id = $1 AND d.id = $2
       GROUP BY d.id, f.id`,
      [tenantId, departmentId],
    );
    if (!rows[0]) throw new DepartmentNotFoundError();
    return rows[0];
  }

  private mapUniqueViolation(error: unknown): void {
    if (!(error instanceof QueryFailedError)) return;
    const driverError = error.driverError as PostgresError;
    if (driverError.code !== '23505') return;
    if (
      driverError.constraint === 'departments_tenant_name_key' ||
      driverError.constraint === 'departments_tenant_id_name_key'
    ) {
      throw new DepartmentNameAlreadyExistsError();
    }
    if (
      driverError.constraint === 'departments_tenant_code_key' ||
      driverError.constraint === 'departments_tenant_id_code_key'
    ) {
      throw new DepartmentCodeAlreadyExistsError();
    }
  }
}
