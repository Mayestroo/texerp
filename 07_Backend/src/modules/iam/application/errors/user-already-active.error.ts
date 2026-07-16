export class UserAlreadyActiveError extends Error {
  constructor() {
    super('User is already active');
    this.name = UserAlreadyActiveError.name;
  }
}
