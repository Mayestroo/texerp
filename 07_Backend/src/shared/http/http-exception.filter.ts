import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Response } from 'express';

interface ErrorEnvelope {
  success: false;
  error: {
    code: string;
    message: unknown;
  };
}

function isErrorEnvelope(value: unknown): value is ErrorEnvelope {
  if (!value || typeof value !== 'object') return false;

  const envelope = value as Partial<ErrorEnvelope>;
  return (
    envelope.success === false &&
    !!envelope.error &&
    typeof envelope.error === 'object' &&
    typeof envelope.error.code === 'string' &&
    'message' in envelope.error
  );
}

@Catch(HttpException)
export class HttpExceptionFilter implements ExceptionFilter<HttpException> {
  catch(exception: HttpException, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();
    const status = exception.getStatus();
    const exceptionResponse = exception.getResponse();

    if (isErrorEnvelope(exceptionResponse)) {
      response.status(status).json(exceptionResponse);
      return;
    }

    const message =
      typeof exceptionResponse === 'object' &&
      exceptionResponse !== null &&
      'message' in exceptionResponse
        ? exceptionResponse.message
        : exceptionResponse;

    response.status(status).json({
      success: false,
      error: {
        code:
          status === 400
            ? 'VALIDATION_ERROR'
            : (HttpStatus[status] ?? 'HTTP_ERROR'),
        message,
      },
    });
  }
}
