import { EventEmitter2 } from '@nestjs/event-emitter';
import { DomainEventPublisher } from './domain-event-publisher';
import { DomainEvent } from './domain-event';

type EmitFn = (channel: string, envelope: unknown) => boolean;

describe('DomainEventPublisher', () => {
  let publisher: DomainEventPublisher;
  let eventEmitter: jest.Mocked<EventEmitter2>;
  let emitMock: jest.MockedFunction<EmitFn>;

  beforeEach(() => {
    emitMock = jest.fn();
    eventEmitter = { emit: emitMock } as unknown as jest.Mocked<EventEmitter2>;
    publisher = new DomainEventPublisher(eventEmitter);
  });

  it('publishes an envelope with correct shape', () => {
    publisher.publish(
      'ProductionEntryCreated',
      'ProductionEntry',
      'agg-id',
      'tenant-id',
      'actor-id',
      'WORKER',
      { quantity: 10 },
    );

    expect(emitMock).toHaveBeenCalledTimes(1);
    const call = emitMock.mock.calls[0];
    const channel = call[0];
    const envelope = call[1] as DomainEvent<{ quantity: number }>;

    expect(channel).toBe('ProductionEntryCreated');
    expect(envelope.event_type).toBe('ProductionEntryCreated');
    expect(envelope.aggregate_type).toBe('ProductionEntry');
    expect(envelope.aggregate_id).toBe('agg-id');
    expect(envelope.tenant_id).toBe('tenant-id');
    expect(envelope.actor_id).toBe('actor-id');
    expect(envelope.actor_role).toBe('WORKER');
    expect(envelope.payload).toEqual({ quantity: 10 });
    expect(envelope.occurred_at).toMatch(/^\d{4}-\d{2}-\d{2}T/);
    expect(envelope.event_id).toMatch(/^[0-9a-f]{8}-/); // UUIDv7 shape
    expect(envelope.metadata.causation_id).toBeNull();
    expect(envelope.metadata.correlation_id).toMatch(/^[0-9a-f]{8}-/);
  });

  it('uses provided correlationId', () => {
    publisher.publish(
      'PayrollFinalized',
      'PayrollPeriod',
      'agg-id',
      'tenant-id',
      'actor-id',
      'ACCOUNTANT',
      {},
      'my-correlation-id',
    );

    const call = emitMock.mock.calls[0];
    const envelope = call[1] as DomainEvent<Record<string, never>>;

    expect(envelope.metadata.correlation_id).toBe('my-correlation-id');
  });

  it('uses provided causationId', () => {
    publisher.publish(
      'PayrollFinalized',
      'PayrollPeriod',
      'agg-id',
      'tenant-id',
      'actor-id',
      'ACCOUNTANT',
      {},
      undefined,
      'my-causation-id',
    );

    const call = emitMock.mock.calls[0];
    const envelope = call[1] as DomainEvent<Record<string, never>>;

    expect(envelope.metadata.causation_id).toBe('my-causation-id');
  });
});
