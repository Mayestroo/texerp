export class UserAlreadyDeactivatedError extends Error {
  constructor() {
    super('User is already deactivated');
    this.name = UserAlreadyDeactivatedError.name;
  }
}
