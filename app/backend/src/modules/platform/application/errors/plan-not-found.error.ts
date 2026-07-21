export class PlanNotFoundError extends Error {
  constructor() {
    super('Subscription plan not found');
    this.name = PlanNotFoundError.name;
  }
}
