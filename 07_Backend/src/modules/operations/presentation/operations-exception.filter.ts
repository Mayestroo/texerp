import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { Response } from 'express';
import { OperationCodeAlreadyExistsError } from '../application/errors/operation-code-already-exists.error';
import { OperationNameAlreadyExistsError } from '../application/errors/operation-name-already-exists.error';
import { OperationNotFoundError } from '../application/errors/operation-not-found.error';

type OperationsApplicationError =
  | OperationNotFoundError
  | OperationNameAlreadyExistsError
  | OperationCodeAlreadyExistsError;

@Catch(
  OperationNotFoundError,
  OperationNameAlreadyExistsError,
  OperationCodeAlreadyExistsError,
)
@Injectable()
export class OperationsExceptionFilter
  implements ExceptionFilter<OperationsApplicationError>
{
  catch(exception: OperationsApplicationError, host: ArgumentsHost): void {
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
    if (exception instanceof OperationNameAlreadyExistsError) {
      this.send(
        response,
        HttpStatus.CONFLICT,
        'OPERATION_NAME_ALREADY_EXISTS',
        'Operatsiya nomi allaqachon mavjud',
      );
      return;
    }
    this.send(
      response,
      HttpStatus.CONFLICT,
      'OPERATION_CODE_ALREADY_EXISTS',
      'Operatsiya kodi allaqachon mavjud',
    );
  }

  private send(
    response: Response,
    status: HttpStatus,
    code: string,
    message: string,
  ): void {
    response.status(status).json({ success: false, error: { code, message } });
  }
}
