export class PlatformUserNotFoundError extends Error {
  constructor() {
    super('Platform user not found');
    this.name = PlatformUserNotFoundError.name;
  }
}
