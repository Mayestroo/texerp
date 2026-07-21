export class TenantSlugAlreadyExistsError extends Error {
  constructor() {
    super('Tenant slug already exists');
    this.name = TenantSlugAlreadyExistsError.name;
  }
}
