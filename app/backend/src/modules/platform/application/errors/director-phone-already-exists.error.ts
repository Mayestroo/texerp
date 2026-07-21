export class DirectorPhoneAlreadyExistsError extends Error {
  constructor() {
    super('Director phone already exists');
    this.name = DirectorPhoneAlreadyExistsError.name;
  }
}
