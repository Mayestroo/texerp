import { HttpException, HttpStatus } from '@nestjs/common';

export class MaterialInactiveError extends HttpException {
  constructor(public readonly material_id: string) {
    super(
      {
        success: false,
        error: { code: 'MATERIAL_INACTIVE', message: 'Material nofaol' },
      },
      HttpStatus.BAD_REQUEST,
    );
  }
}
