export class TenantNotFoundError extends Error {
  constructor() {
    super('Tenant not found');
    this.name = TenantNotFoundError.name;
  }
}
