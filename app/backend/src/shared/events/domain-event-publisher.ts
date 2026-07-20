import { Injectable } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { DomainEvent } from './domain-event';
import { DomainEventName } from './event-names';
import { uuidv7 } from '../common/uuid';

@Injectable()
export class DomainEventPublisher {
  constructor(private readonly eventEmitter: EventEmitter2) {}

  publish<T>(
    eventType: DomainEventName,
    aggregateType: string,
    aggregateId: string,
    tenantId: string | null,
    actorId: string,
    actorRole: string,
    payload: T,
    correlationId?: string,
    causationId?: string | null,
  ): void {
    const event: DomainEvent<T> = {
      event_id: uuidv7(),
      event_type: eventType,
      aggregate_type: aggregateType,
      aggregate_id: aggregateId,
      tenant_id: tenantId,
      actor_id: actorId,
      actor_role: actorRole,
      occurred_at: new Date().toISOString(),
      payload,
      metadata: {
        correlation_id: correlationId ?? uuidv7(),
        causation_id: causationId ?? null,
      },
    };
    this.eventEmitter.emit(eventType, event);
  }
}
