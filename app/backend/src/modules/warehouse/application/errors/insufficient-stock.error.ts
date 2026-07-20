export class InsufficientStockError extends Error {
  constructor(
    public readonly material_id: string,
    public readonly requested: number,
    public readonly available: number,
  ) {
    super(
      `Insufficient stock for material ${material_id}: requested ${requested}, available ${available}`,
    );
  }
}
