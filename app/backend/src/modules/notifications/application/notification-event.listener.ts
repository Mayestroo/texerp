import { Injectable } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { DomainEvent, EventNames } from '../../../shared/events';
import { NotificationsService } from './notifications.service';
import { NotificationTemplatesService } from './notification-templates.service';
import { NotificationPreferencesService } from './notification-preferences.service';

@Injectable()
export class NotificationEventListener {
  constructor(
    private readonly notificationsService: NotificationsService,
    private readonly templatesService: NotificationTemplatesService,
    private readonly preferencesService: NotificationPreferencesService,
  ) {}

  @OnEvent(EventNames.PRODUCTION_ENTRY_APPROVED)
  async handleEntryApproved(event: DomainEvent<Record<string, unknown>>): Promise<void> {
    const { tenant_id, payload } = event;
    if (!tenant_id) return;

    const workerId = this.asString(payload.worker_id);
    if (!workerId) return;

    const template = await this.templatesService.resolveTemplate(tenant_id, 'ENTRY_APPROVED');
    if (!template) return;

    if (!(await this.preferencesService.isEnabled(tenant_id, workerId, 'ENTRY_APPROVED'))) return;

    const vars: Record<string, string> = {
      foreman_name: this.asString(payload.foreman_name),
      operation_name: this.asString(payload.operation_name),
      quantity: this.asString(payload.quantity),
    };

    const titleUz = this.templatesService.interpolate(template.title_uz, vars);
    const titleRu = this.templatesService.interpolate(template.title_ru, vars);
    const bodyUz = this.templatesService.interpolate(template.body_uz, vars);
    const bodyRu = this.templatesService.interpolate(template.body_ru, vars);

    const entryId = this.asString(payload.entry_id);
    await this.notificationsService.createNotification(
      tenant_id,
      workerId,
      'ENTRY_APPROVED',
      titleUz,
      titleRu,
      bodyUz,
      bodyRu,
      { entry_id: entryId, deep_link: entryId ? `/worker/history/${entryId}` : undefined },
    );
  }

  @OnEvent(EventNames.PRODUCTION_ENTRY_REJECTED)
  async handleEntryRejected(event: DomainEvent<Record<string, unknown>>): Promise<void> {
    const { tenant_id, payload } = event;
    if (!tenant_id) return;

    const workerId = this.asString(payload.worker_id);
    if (!workerId) return;

    const template = await this.templatesService.resolveTemplate(tenant_id, 'ENTRY_REJECTED');
    if (!template) return;

    if (!(await this.preferencesService.isEnabled(tenant_id, workerId, 'ENTRY_REJECTED'))) return;

    const vars: Record<string, string> = {
      foreman_name: this.asString(payload.foreman_name),
      reason: this.asString(payload.reason),
    };

    const entryId = this.asString(payload.entry_id);
    await this.notificationsService.createNotification(
      tenant_id,
      workerId,
      'ENTRY_REJECTED',
      this.templatesService.interpolate(template.title_uz, vars),
      this.templatesService.interpolate(template.title_ru, vars),
      this.templatesService.interpolate(template.body_uz, vars),
      this.templatesService.interpolate(template.body_ru, vars),
      { entry_id: entryId },
    );
  }

  @OnEvent(EventNames.PAYROLL_FINALIZED)
  async handlePayrollFinalized(event: DomainEvent<Record<string, unknown>>): Promise<void> {
    const { tenant_id, payload } = event;
    if (!tenant_id) return;

    const template = await this.templatesService.resolveTemplate(tenant_id, 'PAYROLL_FINALIZED');
    if (!template) return;

    const vars: Record<string, string> = {
      period_name: this.asString(payload.period_name),
    };

    const workerIds = payload.worker_ids;
    if (!Array.isArray(workerIds)) return;

    const periodId = this.asString(payload.period_id);
    for (const workerId of workerIds) {
      const id = this.asString(workerId);
      if (!id) continue;

      if (!template.is_critical) {
        if (!(await this.preferencesService.isEnabled(tenant_id, id, 'PAYROLL_FINALIZED'))) {
          continue;
        }
      }

      await this.notificationsService.createNotification(
        tenant_id,
        id,
        'PAYROLL_FINALIZED',
        this.templatesService.interpolate(template.title_uz, vars),
        this.templatesService.interpolate(template.title_ru, vars),
        this.templatesService.interpolate(template.body_uz, vars),
        this.templatesService.interpolate(template.body_ru, vars),
        { period_id: periodId, deep_link: periodId ? `/worker/payroll/${periodId}` : undefined },
      );
    }
  }

  private asString(value: unknown): string {
    if (value === undefined || value === null) return '';
    if (typeof value === 'string') return value;
    if (typeof value === 'number' || typeof value === 'boolean') return String(value);
    return '';
  }
}
