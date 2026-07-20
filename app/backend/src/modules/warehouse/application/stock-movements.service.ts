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
import { MaterialNotFoundError } from './errors/material-not-found.error';

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
      const balance = await this.computeBalance(manager, tenantId, materialId);
      const config = await this.tenantConfigService.get(tenantId);
      const wouldGoNegative = balance < dto.quantity;

      if (wouldGoNegative && config.stock_negative_mode === 'HARD_BLOCK') {
        throw new InsufficientStockError(materialId, dto.quantity, balance);
      }

      const isFlagged = wouldGoNegative && config.stock_negative_mode === 'WARNING';

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
            available_before: balance,
            new_balance: balance - dto.quantity,
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
      const balance = await this.computeBalance(manager, tenantId, materialId);
      const type: StockMovementType =
        dto.correction_type === 'POSITIVE'
          ? 'CORRECTION_POSITIVE'
          : 'CORRECTION_NEGATIVE';

      if (type === 'CORRECTION_NEGATIVE' && balance < dto.quantity) {
        const config = await this.tenantConfigService.get(tenantId);
        if (config.stock_negative_mode === 'HARD_BLOCK') {
          throw new InsufficientStockError(materialId, dto.quantity, balance);
        }
      }

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
        },
      );

      this.eventPublisher.publish(
        type === 'CORRECTION_POSITIVE'
          ? EventNames.MATERIAL_RECEIVED
          : EventNames.MATERIAL_ISSUED,
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
        },
      );

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

  private async lockMaterialOrFail(
    manager: EntityManager,
    tenantId: string,
    materialId: string,
  ): Promise<{ id: string; code: string; unit: string; min_quantity: number | null }> {
    const rows = await manager.query<
      { id: string; code: string; unit: string; min_quantity: number | null }[]
    >(
      `SELECT id, code, unit, min_quantity
       FROM materials
       WHERE tenant_id = $1 AND id = $2
       FOR UPDATE`,
      [tenantId, materialId],
    );
    const material = rows[0];
    if (!material) {
      throw new MaterialNotFoundError(materialId);
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
  ): Promise<StockMovementView> {
    const movementId = uuidv7();
    const timestampResult = await manager.query<{ ts: Date }[]>(
      `SELECT clock_timestamp() AS ts`,
    );
    const timestamp = timestampResult[0].ts;

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

  private async maybePublishLowStock(
    manager: EntityManager,
    tenantId: string,
    actorId: string,
    material: { id: string; code: string; min_quantity: number | null },
  ): Promise<void> {
    if (material.min_quantity === null) {
      return;
    }

    const balance = await this.computeBalance(manager, tenantId, material.id);
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
