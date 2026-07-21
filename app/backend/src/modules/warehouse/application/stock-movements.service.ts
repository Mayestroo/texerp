import { Injectable } from '@nestjs/common';
import { type EntityManager } from 'typeorm';
import { TenantDatabase } from '../../../infrastructure/database/tenant-database';
import { uuidv7 } from '../../../shared/common/uuid';
import { DomainEventPublisher, EventNames } from '../../../shared/events';
import { TenantConfigService } from '../../settings/application/tenant-config.service';
import { ListMovementsQueryDto } from './dto/list-movements-query.dto';
import { RecordCorrectionDto } from './dto/record-correction.dto';
import { RecordIssuanceDto } from './dto/record-issuance.dto';
import { RecordReceiptDto } from './dto/record-receipt.dto';
import { InsufficientStockError } from './errors/insufficient-stock.error';
import { MaterialInactiveError } from './errors/material-inactive.error';
import { MaterialNotFoundError } from './errors/material-not-found.error';
import { stockBalanceSumCase } from './stock-balance.helper';

export type StockMovementType =
  | 'RECEIPT'
  | 'ISSUANCE'
  | 'CORRECTION_POSITIVE'
  | 'CORRECTION_NEGATIVE';

export interface StockMovementView {
  id: string;
  tenant_id: string;
  material_id: string;
  type: StockMovementType;
  quantity: number;
  unit_snapshot: string;
  supplier_name: string | null;
  destination: string | null;
  movement_date: string;
  note: string | null;
  photo_urls: string[];
  correction_reason: string | null;
  is_flagged: boolean;
  recorded_by: string;
  created_at: Date;
}

@Injectable()
export class StockMovementsService {
  constructor(
    private readonly tenantDatabase: TenantDatabase,
    private readonly eventPublisher: DomainEventPublisher,
    private readonly tenantConfigService: TenantConfigService,
  ) {}

  async recordReceipt(
    tenantId: string,
    actorId: string,
    materialId: string,
    dto: RecordReceiptDto,
  ): Promise<StockMovementView> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const material = await this.lockMaterialOrFail(
        manager,
        tenantId,
        materialId,
      );
      const balanceBefore = await this.computeBalance(materialId, manager);
      const newBalance = balanceBefore + dto.quantity;

      const movementId = uuidv7();
      const timestampResult = await manager.query<{ ts: Date }[]>(
        `SELECT clock_timestamp() AS ts`,
      );
      const timestamp = timestampResult[0].ts;

      await this.insertMovementAudit(
        manager,
        tenantId,
        movementId,
        'STOCK_RECEIPT_RECORDED',
        actorId,
        { balance: balanceBefore },
        {
          type: 'RECEIPT',
          material_id: materialId,
          quantity: dto.quantity,
          supplier_name: dto.supplier_name ?? null,
          movement_date: dto.movement_date,
          new_balance: newBalance,
        },
      );

      const movement = await this.insertMovement(
        manager,
        tenantId,
        actorId,
        materialId,
        'RECEIPT',
        dto.quantity,
        material.unit,
        {
          movement_date: dto.movement_date,
          supplier_name: dto.supplier_name,
          note: dto.note,
          photo_urls: dto.photo_urls,
        },
        movementId,
        timestamp,
      );

      this.eventPublisher.publish(
        EventNames.MATERIAL_RECEIVED,
        'StockMovement',
        movement.id,
        tenantId,
        actorId,
        'DIRECTOR',
        {
          material_id: materialId,
          material_code: material.code,
          quantity: dto.quantity,
          supplier_name: dto.supplier_name ?? null,
          movement_date: dto.movement_date,
        },
      );

      await this.maybePublishLowStock(manager, tenantId, actorId, material);

      return movement;
    });
  }

  async recordIssuance(
    tenantId: string,
    actorId: string,
    materialId: string,
    dto: RecordIssuanceDto,
  ): Promise<StockMovementView> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const material = await this.lockMaterialOrFail(
        manager,
        tenantId,
        materialId,
      );
      const balanceBefore = await this.computeBalance(materialId, manager);
      const config = await this.tenantConfigService.get(tenantId);
      const wouldGoNegative = balanceBefore < dto.quantity;

      if (wouldGoNegative && config.stock_negative_mode === 'HARD_BLOCK') {
        throw new InsufficientStockError(materialId, dto.quantity, balanceBefore);
      }

      const isFlagged =
        wouldGoNegative && config.stock_negative_mode === 'WARNING';
      const newBalance = balanceBefore - dto.quantity;

      const movementId = uuidv7();
      const timestampResult = await manager.query<{ ts: Date }[]>(
        `SELECT clock_timestamp() AS ts`,
      );
      const timestamp = timestampResult[0].ts;

      await this.insertMovementAudit(
        manager,
        tenantId,
        movementId,
        'STOCK_ISSUANCE_RECORDED',
        actorId,
        { balance: balanceBefore },
        {
          type: 'ISSUANCE',
          material_id: materialId,
          quantity: dto.quantity,
          destination: dto.destination ?? null,
          movement_date: dto.movement_date,
          new_balance: newBalance,
          is_flagged: isFlagged,
        },
      );

      const movement = await this.insertMovement(
        manager,
        tenantId,
        actorId,
        materialId,
        'ISSUANCE',
        dto.quantity,
        material.unit,
        {
          movement_date: dto.movement_date,
          destination: dto.destination,
          note: dto.note,
          is_flagged: isFlagged,
        },
        movementId,
        timestamp,
      );

      this.eventPublisher.publish(
        EventNames.MATERIAL_ISSUED,
        'StockMovement',
        movement.id,
        tenantId,
        actorId,
        'DIRECTOR',
        {
          material_id: materialId,
          material_code: material.code,
          quantity: dto.quantity,
          destination: dto.destination ?? null,
          movement_date: dto.movement_date,
          is_flagged: isFlagged,
        },
      );

      if (isFlagged) {
        this.eventPublisher.publish(
          EventNames.NEGATIVE_STOCK_WARNING,
          'StockMovement',
          movement.id,
          tenantId,
          actorId,
          'DIRECTOR',
          {
            material_id: materialId,
            material_code: material.code,
            requested: dto.quantity,
            available_before: balanceBefore,
            new_balance: newBalance,
          },
        );
      }

      await this.maybePublishLowStock(manager, tenantId, actorId, material);

      return movement;
    });
  }

  async recordCorrection(
    tenantId: string,
    actorId: string,
    materialId: string,
    dto: RecordCorrectionDto,
  ): Promise<StockMovementView> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const material = await this.lockMaterialOrFail(
        manager,
        tenantId,
        materialId,
      );
      const balanceBefore = await this.computeBalance(materialId, manager);
      const type: StockMovementType =
        dto.correction_type === 'POSITIVE'
          ? 'CORRECTION_POSITIVE'
          : 'CORRECTION_NEGATIVE';
      const isNegative = type === 'CORRECTION_NEGATIVE';
      const newBalance = isNegative
        ? balanceBefore - dto.quantity
        : balanceBefore + dto.quantity;

      if (isNegative && balanceBefore < dto.quantity) {
        const config = await this.tenantConfigService.get(tenantId);
        if (config.stock_negative_mode === 'HARD_BLOCK') {
          throw new InsufficientStockError(
            materialId,
            dto.quantity,
            balanceBefore,
          );
        }
      }

      const config = await this.tenantConfigService.get(tenantId);
      const isFlagged =
        isNegative &&
        config.stock_negative_mode === 'WARNING' &&
        newBalance < 0;

      const movementId = uuidv7();
      const timestampResult = await manager.query<{ ts: Date }[]>(
        `SELECT clock_timestamp() AS ts`,
      );
      const timestamp = timestampResult[0].ts;

      await this.insertMovementAudit(
        manager,
        tenantId,
        movementId,
        'STOCK_CORRECTION_RECORDED',
        actorId,
        { balance: balanceBefore },
        {
          type,
          material_id: materialId,
          correction_type: dto.correction_type,
          quantity: dto.quantity,
          correction_reason: dto.correction_reason,
          movement_date: dto.movement_date,
          new_balance: newBalance,
          is_flagged: isFlagged,
        },
      );

      const movement = await this.insertMovement(
        manager,
        tenantId,
        actorId,
        materialId,
        type,
        dto.quantity,
        material.unit,
        {
          movement_date: dto.movement_date,
          note: dto.note,
          correction_reason: dto.correction_reason,
          is_flagged: isFlagged,
        },
        movementId,
        timestamp,
      );

      this.eventPublisher.publish(
        type === 'CORRECTION_POSITIVE'
          ? EventNames.STOCK_CORRECTION_POSITIVE
          : EventNames.STOCK_CORRECTION_NEGATIVE,
        'StockMovement',
        movement.id,
        tenantId,
        actorId,
        'DIRECTOR',
        {
          material_id: materialId,
          material_code: material.code,
          correction_type: dto.correction_type,
          quantity: dto.quantity,
          correction_reason: dto.correction_reason,
          movement_date: dto.movement_date,
          is_flagged: isFlagged,
        },
      );

      if (isFlagged) {
        this.eventPublisher.publish(
          EventNames.NEGATIVE_STOCK_WARNING,
          'StockMovement',
          movement.id,
          tenantId,
          actorId,
          'DIRECTOR',
          {
            material_id: materialId,
            material_code: material.code,
            correction_type: dto.correction_type,
            quantity: dto.quantity,
            available_before: balanceBefore,
            new_balance: newBalance,
          },
        );
      }

      await this.maybePublishLowStock(manager, tenantId, actorId, material);

      return movement;
    });
  }

  async listMovements(
    tenantId: string,
    materialId: string,
    query: ListMovementsQueryDto,
  ): Promise<{ data: StockMovementView[]; total: number }> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const countResult = await manager.query<{ count: string }[]>(
        `SELECT COUNT(*)::text AS count
         FROM stock_movements
         WHERE tenant_id = $1 AND material_id = $2`,
        [tenantId, materialId],
      );
      const total = Number.parseInt(countResult[0].count, 10);

      const movements = await manager.query<StockMovementView[]>(
        `SELECT id, tenant_id, material_id, type, quantity, unit_snapshot,
                supplier_name, destination, movement_date::text AS movement_date,
                note, photo_urls, correction_reason, is_flagged, recorded_by, created_at
         FROM stock_movements
         WHERE tenant_id = $1 AND material_id = $2
         ORDER BY created_at DESC
         LIMIT $3 OFFSET $4`,
        [tenantId, materialId, query.limit, query.offset],
      );

      return { data: movements, total };
    });
  }

  async computeBalance(
    materialId: string,
    manager: EntityManager,
  ): Promise<number> {
    const tenantId = this.getTenantId(manager);
    const result = await manager.query<{ balance: number | string }[]>(
      `SELECT COALESCE(${stockBalanceSumCase.trim()}, 0) AS balance
         FROM stock_movements
        WHERE tenant_id = $1 AND material_id = $2`,
      [tenantId, materialId],
    );
    const raw = result[0]?.balance ?? 0;
    return typeof raw === 'string' ? Number.parseFloat(raw) : Number(raw);
  }

  private getTenantId(manager: EntityManager): string {
    const raw = (manager.queryRunner?.data as { tenantId?: unknown } | undefined)
      ?.tenantId;
    if (typeof raw === 'string') {
      return raw;
    }
    throw new Error('Tenant context is missing from EntityManager');
  }

  private async lockMaterialOrFail(
    manager: EntityManager,
    tenantId: string,
    materialId: string,
  ): Promise<{
    id: string;
    code: string;
    unit: string;
    min_quantity: number | null;
  }> {
    const rows = await manager.query<
      {
        id: string;
        code: string;
        unit: string;
        min_quantity: number | null;
        is_active: boolean;
      }[]
    >(
      `SELECT id, code, unit, min_quantity, is_active
       FROM materials
       WHERE tenant_id = $1 AND id = $2
       FOR UPDATE`,
      [tenantId, materialId],
    );
    const material = rows[0];
    if (!material) {
      throw new MaterialNotFoundError(materialId);
    }
    if (!material.is_active) {
      throw new MaterialInactiveError(materialId);
    }
    return material;
  }

  private async insertMovement(
    manager: EntityManager,
    tenantId: string,
    actorId: string,
    materialId: string,
    type: StockMovementType,
    quantity: number,
    unitSnapshot: string,
    options: {
      movement_date: string;
      supplier_name?: string;
      destination?: string;
      note?: string;
      photo_urls?: string[];
      correction_reason?: string;
      is_flagged?: boolean;
    },
    movementId: string,
    timestamp: Date,
  ): Promise<StockMovementView> {
    await manager.query(
      `INSERT INTO stock_movements
         (id, tenant_id, material_id, type, quantity, unit_snapshot,
          supplier_name, destination, movement_date, note, photo_urls,
          correction_reason, is_flagged, recorded_by, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
               $11::jsonb, $12, $13, $14, $15)`,
      [
        movementId,
        tenantId,
        materialId,
        type,
        quantity,
        unitSnapshot,
        options.supplier_name ?? null,
        options.destination ?? null,
        options.movement_date,
        options.note ?? null,
        JSON.stringify(options.photo_urls ?? []),
        options.correction_reason ?? null,
        options.is_flagged ?? false,
        actorId,
        timestamp,
      ],
    );

    return {
      id: movementId,
      tenant_id: tenantId,
      material_id: materialId,
      type,
      quantity,
      unit_snapshot: unitSnapshot,
      supplier_name: options.supplier_name ?? null,
      destination: options.destination ?? null,
      movement_date: options.movement_date,
      note: options.note ?? null,
      photo_urls: options.photo_urls ?? [],
      correction_reason: options.correction_reason ?? null,
      is_flagged: options.is_flagged ?? false,
      recorded_by: actorId,
      created_at: timestamp,
    };
  }

  private async insertMovementAudit(
    manager: EntityManager,
    tenantId: string,
    movementId: string,
    action:
      | 'STOCK_RECEIPT_RECORDED'
      | 'STOCK_ISSUANCE_RECORDED'
      | 'STOCK_CORRECTION_RECORDED',
    actorId: string,
    beforeState: Record<string, unknown>,
    afterState: Record<string, unknown>,
  ): Promise<void> {
    await manager.query(
      `INSERT INTO audit_events
         (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
          before_state, after_state, ip_address, user_agent)
       VALUES ($1, $2, 'STOCK_MOVEMENT', $3, $4, $5, 'DIRECTOR',
          $6::jsonb, $7::jsonb, $8, $9)`,
      [
        uuidv7(),
        tenantId,
        movementId,
        action,
        actorId,
        JSON.stringify(beforeState),
        JSON.stringify(afterState),
        null,
        null,
      ],
    );
  }

  private async maybePublishLowStock(
    manager: EntityManager,
    tenantId: string,
    actorId: string,
    material: { id: string; code: string; min_quantity: number | null },
  ): Promise<void> {
    if (material.min_quantity === null) {
      return;
    }

    const balance = await this.computeBalance(material.id, manager);
    if (balance < material.min_quantity) {
      this.eventPublisher.publish(
        EventNames.LOW_STOCK_ALERT,
        'Material',
        material.id,
        tenantId,
        actorId,
        'DIRECTOR',
        {
          material_id: material.id,
          material_code: material.code,
          balance,
          min_quantity: material.min_quantity,
        },
      );
    }
  }
}
