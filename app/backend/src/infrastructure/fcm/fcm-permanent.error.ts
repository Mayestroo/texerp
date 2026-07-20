export class FcmPermanentError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'FcmPermanentError';
    Object.setPrototypeOf(this, FcmPermanentError.prototype);
  }
}
