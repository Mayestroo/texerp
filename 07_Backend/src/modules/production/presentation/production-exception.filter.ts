import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { Response } from 'express';
import { DateOutOfWindowError } from '../application/errors/date-out-of-window.error';
import { DuplicateEntryError } from '../application/errors/duplicate-entry.error';
import { OperationInactiveError } from '../application/errors/operation-inactive.error';
import { OperationNotFoundError } from '../application/errors/operation-not-found.error';
import { WorkerNotActiveError } from '../application/errors/worker-not-active.error';

type ProductionApplicationError =
  | OperationNotFoundError
  | OperationInactiveError
  | DuplicateEntryError
  | WorkerNotActiveError
  | DateOutOfWindowError;

@Catch(
  OperationNotFoundError,
  OperationInactiveError,
  DuplicateEntryError,
  WorkerNotActiveError,
  DateOutOfWindowError,
)
@Injectable()
export class ProductionExceptionFilter
  implements ExceptionFilter<ProductionApplicationError>
{
  catch(exception: ProductionApplicationError, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();
    if (exception instanceof OperationNotFoundError) {
      this.send(
        response,
        HttpStatus.NOT_FOUND,
        'OPERATION_NOT_FOUND',
        'Operatsiya topilmadi',
      );
      return;
    }
    if (exception instanceof OperationInactiveError) {
      this.send(
        response,
        HttpStatus.BAD_REQUEST,
        'OPERATION_INACTIVE',
        'Operatsiya faol emas',
      );
      return;
    }
    if (exception instanceof DuplicateEntryError) {
      this.send(
        response,
        HttpStatus.CONFLICT,
        'DUPLICATE_ENTRY',
        'Bu ish uchun yuborilgan yozuv allaqachon mavjud',
        { existing_entry_id: exception.existing_entry_id },
      );
      return;
    }
    if (exception instanceof WorkerNotActiveError) {
      this.send(
        response,
        HttpStatus.BAD_REQUEST,
        'WORKER_NOT_ACTIVE',
        'Ishchi faol emas',
      );
      return;
    }
    this.send(
      response,
      HttpStatus.BAD_REQUEST,
      'DATE_OUT_OF_WINDOW',
      'Sana ruxsat etilgan oraliqdan tashqarida',
      { allowed_from: exception.allowed_from },
    );
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
