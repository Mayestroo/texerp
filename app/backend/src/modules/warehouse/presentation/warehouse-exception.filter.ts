import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { Response } from 'express';
import { InsufficientStockError } from '../application/errors/insufficient-stock.error';
import { MaterialCodeExistsError } from '../application/errors/material-code-exists.error';
import { MaterialNotFoundError } from '../application/errors/material-not-found.error';

type WarehouseApplicationError =
  | MaterialNotFoundError
  | MaterialCodeExistsError
  | InsufficientStockError;

@Catch(MaterialNotFoundError, MaterialCodeExistsError, InsufficientStockError)
@Injectable()
export class WarehouseExceptionFilter
  implements ExceptionFilter<WarehouseApplicationError>
{
  catch(exception: WarehouseApplicationError, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();

    if (exception instanceof MaterialNotFoundError) {
      this.send(
        response,
        HttpStatus.NOT_FOUND,
        'MATERIAL_NOT_FOUND',
        'Material topilmadi',
        { material_id: exception.material_id },
      );
      return;
    }

    if (exception instanceof MaterialCodeExistsError) {
      this.send(
        response,
        HttpStatus.CONFLICT,
        'MATERIAL_CODE_EXISTS',
        'Bunday kodli material allaqachon mavjud',
        { code: exception.code },
      );
      return;
    }

    if (exception instanceof InsufficientStockError) {
      this.send(
        response,
        HttpStatus.UNPROCESSABLE_ENTITY,
        'INSUFFICIENT_STOCK',
        'Omborda yetarli material mavjud emas',
        {
          material_id: exception.material_id,
          requested: exception.requested,
          available: exception.available,
        },
      );
      return;
    }
  }

  private send(
    response: Response,
    status: HttpStatus,
    code: string,
    message: string,
    details?: Record<string, unknown>,
  ): void {
    response.status(status).json({
      success: false,
      error: { code, message, ...(details ?? {}) },
    });
  }
}
