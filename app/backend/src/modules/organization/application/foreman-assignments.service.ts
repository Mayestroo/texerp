import { Injectable } from '@nestjs/common';
import type { EntityManager } from 'typeorm';
import { TenantDatabase } from '../../../infrastructure/database/tenant-database';
import { uuidv7 } from '../../../shared/common/uuid';
import { AccessTokenClaims } from '../../iam/application/access-token-claims';
import { SetForemanAssignmentDto } from './dto/set-foreman-assignment.dto';
import { DepartmentHasNoForemanError } from './errors/department-has-no-foreman.error';
import { DepartmentNotFoundError } from './errors/department-not-found.error';
import { WorkerNotFoundError } from './errors/worker-not-found.error';

interface RequestMetadata {
  ipAddress?: string;
  userAgent?: string;
}

interface WorkerRow {
  id: string;
  full_name: string;
}

interface DepartmentRow {
  id: string;
  name: string;
  code: string;
  foreman_id: string | null;
  foreman_name?: string;
}

interface AssignmentRow {
  id: string;
  worker_id: string;
  foreman_id: string;
  department_id: string;
  assigned_at: Date;
}

interface AssignmentView {
  id: string;
  worker: WorkerRow;
  department: Pick<DepartmentRow, 'id' | 'name' | 'code'>;
  foreman: { id: string; full_name: string };
  assigned_at: Date;
}

interface UserSummary {
  id: string;
  full_name: string;
  worker_code: string;
  phone: string;
  role: AccessTokenClaims['role'];
  status: 'ACTIVE' | 'DEACTIVATED';
  avatar_url: string | null;
  department: { id: string; name: string } | null;
  foreman: { id: string; full_name: string } | null;
}

@Injectable()
export class ForemanAssignmentsService {
  constructor(private readonly tenantDatabase: TenantDatabase) {}

  async listMyWorkers(
    tenantId: string,
    foremanId: string,
  ): Promise<UserSummary[]> {
    return this.tenantDatabase.withTenant(tenantId, (manager) =>
      manager.query<UserSummary[]>(
        `SELECT
           u.id,
           u.full_name,
           u.worker_code,
           u.phone,
           u.role,
           u.status,
           u.avatar_url,
           CASE WHEN d.id IS NULL THEN NULL
             ELSE json_build_object('id', d.id, 'name', d.name)
           END AS department,
           CASE WHEN f.id IS NULL THEN NULL
             ELSE json_build_object('id', f.id, 'full_name', f.full_name)
           END AS foreman
         FROM users u
         JOIN foreman_assignments fa
           ON fa.tenant_id = u.tenant_id
          AND fa.worker_id = u.id
          AND fa.foreman_id = $2
          AND fa.unassigned_at IS NULL
         LEFT JOIN departments d
           ON d.tenant_id = fa.tenant_id AND d.id = fa.department_id
         LEFT JOIN users f
           ON f.tenant_id = fa.tenant_id AND f.id = fa.foreman_id
         WHERE u.tenant_id = $1
           AND u.role = 'WORKER'
           AND u.status = 'ACTIVE'
         ORDER BY u.full_name ASC, u.id ASC`,
        [tenantId, foremanId],
      ),
    );
  }

  async setAssignment(
    tenantId: string,
    actor: AccessTokenClaims,
    workerId: string,
    dto: SetForemanAssignmentDto,
    metadata: RequestMetadata,
  ): Promise<AssignmentView> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const worker = await this.lockActiveWorker(manager, tenantId, workerId);
      const departments = await manager.query<DepartmentRow[]>(
        `SELECT d.id, d.name, d.code, d.foreman_id
         FROM departments d
         WHERE d.tenant_id = $1 AND d.id = $2 AND d.is_active = true
         FOR UPDATE`,
        [tenantId, dto.department_id],
      );
      const department = departments[0];
      if (!department) throw new DepartmentNotFoundError();
      if (!department.foreman_id) {
        throw new DepartmentHasNoForemanError();
      }
      const foreman = await this.lockActiveForeman(
        manager,
        tenantId,
        department.foreman_id,
      );
      department.foreman_name = foreman.full_name;

      const assignments = await manager.query<AssignmentRow[]>(
        `SELECT id, worker_id, foreman_id, department_id, assigned_at
         FROM foreman_assignments
         WHERE tenant_id = $1 AND worker_id = $2 AND unassigned_at IS NULL
         FOR UPDATE`,
        [tenantId, workerId],
      );
      const current = assignments[0];
      if (
        current?.department_id === department.id &&
        current.foreman_id === department.foreman_id
      ) {
        return this.toView(current, worker, department);
      }

      const assignmentId = uuidv7();
      const changedAt = await this.readDatabaseTimestamp(manager);
      const afterState = {
        assignment_id: assignmentId,
        worker_id: workerId,
        department_id: department.id,
        foreman_id: department.foreman_id,
      };
      const beforeState = current
        ? {
            assignment_id: current.id,
            worker_id: current.worker_id,
            department_id: current.department_id,
            foreman_id: current.foreman_id,
          }
        : null;
      await this.insertAudit(
        manager,
        tenantId,
        workerId,
        current ? 'FOREMAN_REASSIGNED' : 'FOREMAN_ASSIGNED',
        actor,
        beforeState,
        afterState,
        metadata,
      );
      if (current) {
        await manager.query(
          `UPDATE foreman_assignments
           SET unassigned_at = $3
           WHERE tenant_id = $1 AND id = $2`,
          [tenantId, current.id, changedAt],
        );
      }
      await manager.query(
        `INSERT INTO foreman_assignments
          (id, tenant_id, worker_id, foreman_id, department_id, assigned_at, assigned_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [
          assignmentId,
          tenantId,
          workerId,
          department.foreman_id,
          department.id,
          changedAt,
          actor.sub,
        ],
      );
      return this.toView(
        {
          id: assignmentId,
          worker_id: workerId,
          foreman_id: department.foreman_id,
          department_id: department.id,
          assigned_at: changedAt,
        },
        worker,
        department,
      );
    });
  }

  async unassign(
    tenantId: string,
    actor: AccessTokenClaims,
    workerId: string,
    metadata: RequestMetadata,
  ): Promise<{ message: string }> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      await this.lockActiveWorker(manager, tenantId, workerId);
      const assignments = await manager.query<AssignmentRow[]>(
        `SELECT id, worker_id, foreman_id, department_id, assigned_at
         FROM foreman_assignments
         WHERE tenant_id = $1 AND worker_id = $2 AND unassigned_at IS NULL
         FOR UPDATE`,
        [tenantId, workerId],
      );
      const current = assignments[0];
      if (!current) return { message: 'Ishchi brigadirdan ajratildi' };

      const unassignedAt = await this.readDatabaseTimestamp(manager);
      await this.insertAudit(
        manager,
        tenantId,
        workerId,
        'FOREMAN_UNASSIGNED',
        actor,
        {
          assignment_id: current.id,
          worker_id: current.worker_id,
          department_id: current.department_id,
          foreman_id: current.foreman_id,
          unassigned_at: null,
        },
        {
          assignment_id: current.id,
          worker_id: current.worker_id,
          department_id: current.department_id,
          foreman_id: current.foreman_id,
          unassigned_at: unassignedAt,
        },
        metadata,
      );
      await manager.query(
        `UPDATE foreman_assignments
         SET unassigned_at = $3
         WHERE tenant_id = $1 AND id = $2`,
        [tenantId, current.id, unassignedAt],
      );
      return { message: 'Ishchi brigadirdan ajratildi' };
    });
  }

  private async lockActiveWorker(
    manager: EntityManager,
    tenantId: string,
    workerId: string,
  ): Promise<WorkerRow> {
    const workers = await manager.query<WorkerRow[]>(
      `SELECT id, full_name
       FROM users
       WHERE tenant_id = $1
         AND id = $2
         AND role = 'WORKER'
         AND status = 'ACTIVE'
       FOR UPDATE`,
      [tenantId, workerId],
    );
    if (!workers[0]) throw new WorkerNotFoundError();
    return workers[0];
  }

  private async lockActiveForeman(
    manager: EntityManager,
    tenantId: string,
    foremanId: string,
  ): Promise<{ full_name: string }> {
    const foremen = await manager.query<Array<{ full_name: string }>>(
      `SELECT full_name
       FROM users
       WHERE tenant_id = $1
         AND id = $2
         AND role = 'FOREMAN'
         AND status = 'ACTIVE'
       FOR UPDATE`,
      [tenantId, foremanId],
    );
    if (!foremen[0]) throw new DepartmentHasNoForemanError();
    return foremen[0];
  }

  private async readDatabaseTimestamp(manager: EntityManager): Promise<Date> {
    const rows = await manager.query<Array<{ changed_at: Date }>>(
      'SELECT clock_timestamp() AS changed_at',
    );
    const changedAt = rows[0]?.changed_at;
    if (!changedAt) throw new Error('PostgreSQL did not return a timestamp');
    return changedAt;
  }

  private toView(
    assignment: AssignmentRow,
    worker: WorkerRow,
    department: DepartmentRow,
  ): AssignmentView {
    return {
      id: assignment.id,
      worker,
      department: {
        id: department.id,
        name: department.name,
        code: department.code,
      },
      foreman: {
        id: department.foreman_id!,
        full_name: department.foreman_name!,
      },
      assigned_at: assignment.assigned_at,
    };
  }

  private async insertAudit(
    manager: EntityManager,
    tenantId: string,
    workerId: string,
    action: 'FOREMAN_ASSIGNED' | 'FOREMAN_REASSIGNED' | 'FOREMAN_UNASSIGNED',
    actor: AccessTokenClaims,
    beforeState: Record<string, unknown> | null,
    afterState: Record<string, unknown>,
    metadata: RequestMetadata,
  ): Promise<void> {
    await manager.query(
      `INSERT INTO audit_events
        (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
         before_state, after_state, ip_address, user_agent)
       VALUES ($1, $2, 'FOREMAN_ASSIGNMENT', $3, $4, $5, $6,
         $7::jsonb, $8::jsonb, $9, $10)`,
      [
        uuidv7(),
        tenantId,
        workerId,
        action,
        actor.sub,
        actor.role,
        beforeState === null ? null : JSON.stringify(beforeState),
        JSON.stringify(afterState),
        metadata.ipAddress ?? null,
        metadata.userAgent ?? null,
      ],
    );
  }
}
