export class PlanNameAlreadyExistsError extends Error {
  constructor() {
    super('Subscription plan name already exists');
    this.name = PlanNameAlreadyExistsError.name;
  }
}
