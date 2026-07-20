export interface DomainEvent<T = Record<string, unknown>> {
  event_id: string;
  event_type: string;
  aggregate_type: string;
  aggregate_id: string;
  tenant_id: string | null;
  actor_id: string;
  actor_role: string;
  occurred_at: string;
  payload: T;
  metadata: {
    correlation_id: string;
    causation_id: string | null;
  };
}
