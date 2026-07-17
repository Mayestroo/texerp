export class DateOutOfWindowError extends Error {
  constructor(public readonly allowed_from: string) {
    super(`Record date out of window; allowed from ${allowed_from}`);
  }
}
