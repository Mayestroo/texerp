export class CannotDeactivateSelfError extends Error {
  constructor() {
    super('A Director cannot deactivate themselves');
    this.name = CannotDeactivateSelfError.name;
  }
}
