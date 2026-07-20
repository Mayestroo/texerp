export class MaterialNotFoundError extends Error {
  constructor(public readonly material_id: string) {
    super(`Material not found: ${material_id}`);
  }
}
