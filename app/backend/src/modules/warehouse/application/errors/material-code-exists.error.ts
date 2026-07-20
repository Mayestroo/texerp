export class MaterialCodeExistsError extends Error {
  constructor(public readonly code: string) {
    super(`Material code already exists: ${code}`);
  }
}
