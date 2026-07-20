import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { Response } from 'express';
import { InvalidReportDateRangeError } from '../application/errors/invalid-report-date-range.error';
import { InvalidReportGroupByError } from '../application/errors/invalid-report-group-by.error';

type ReportsApplicationError = InvalidReportDateRangeError | InvalidReportGroupByError;

@Catch(InvalidReportDateRangeError, InvalidReportGroupByError)
@Injectable()
export class ReportsExceptionFilter
  implements ExceptionFilter<ReportsApplicationError>
{
  catch(exception: ReportsApplicationError, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();

    if (exception instanceof InvalidReportDateRangeError) {
      this.send(
        response,
        HttpStatus.BAD_REQUEST,
        'VALIDATION_ERROR',
        exception.message,
      );
      return;
    }

    this.send(
      response,
      HttpStatus.BAD_REQUEST,
      'VALIDATION_ERROR',
      exception.message,
    );
  }

  private send(
    response: Response,
    status: HttpStatus,
    code: string,
    message: string,
  ): void {
    response.status(status).json({
      success: false,
      error: { code, message },
    });
  }
}
