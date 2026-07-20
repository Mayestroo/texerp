import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { Response } from 'express';
import { AdjustmentNotFoundError } from '../application/errors/adjustment-not-found.error';
import { CalculationAlreadyRunningError } from '../application/errors/calculation-already-running.error';
import { ConfirmationRequiredError } from '../application/errors/confirmation-required.error';
import { EmptyPayrollPeriodUpdateError } from '../application/errors/empty-payroll-period-update.error';
import { InvalidDateRangeError } from '../application/errors/invalid-date-range.error';
import { PeriodAlreadyFinalizedError } from '../application/errors/period-already-finalized.error';
import { PeriodFinalizedError } from '../application/errors/period-finalized.error';
import { PeriodNotCalculatedError } from '../application/errors/period-not-calculated.error';
import { PeriodNotDraftOrCalculatedError } from '../application/errors/period-not-draft-or-calculated.error';
import { PeriodNotFoundError } from '../application/errors/period-not-found.error';
import { PeriodOverlapError } from '../application/errors/period-overlap.error';
import { WorkerNotInPeriodError } from '../application/errors/worker-not-in-period.error';
import { ExportNotFoundError } from '../application/errors/export-not-found.error';

type PayrollApplicationError =
  | PeriodNotFoundError
  | PeriodOverlapError
  | InvalidDateRangeError
  | PeriodNotDraftOrCalculatedError
  | CalculationAlreadyRunningError
  | PeriodFinalizedError
  | WorkerNotInPeriodError
  | AdjustmentNotFoundError
  | PeriodNotCalculatedError
  | ConfirmationRequiredError
  | PeriodAlreadyFinalizedError
  | ExportNotFoundError
  | EmptyPayrollPeriodUpdateError;

@Catch(
  PeriodNotFoundError,
  PeriodOverlapError,
  InvalidDateRangeError,
  PeriodNotDraftOrCalculatedError,
  CalculationAlreadyRunningError,
  PeriodFinalizedError,
  WorkerNotInPeriodError,
  AdjustmentNotFoundError,
  PeriodNotCalculatedError,
  ConfirmationRequiredError,
  PeriodAlreadyFinalizedError,
  ExportNotFoundError,
  EmptyPayrollPeriodUpdateError,
)
@Injectable()
export class PayrollExceptionFilter
  implements ExceptionFilter<PayrollApplicationError>
{
  catch(exception: PayrollApplicationError, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();
    if (exception instanceof PeriodNotFoundError) {
      this.send(
        response,
        HttpStatus.NOT_FOUND,
        'PERIOD_NOT_FOUND',
        'Hisob-kitob davri topilmadi',
      );
      return;
    }
    if (exception instanceof PeriodOverlapError) {
      this.send(
        response,
        HttpStatus.CONFLICT,
        'PERIOD_OVERLAP',
        'Hisob-kitob davri mavjud davr bilan kesishadi',
        { existing_period_id: exception.existing_period_id },
      );
      return;
    }
    if (exception instanceof InvalidDateRangeError) {
      this.send(
        response,
        HttpStatus.BAD_REQUEST,
        'INVALID_DATE_RANGE',
        "Boshlanish sanasi tugash sanasidan oldin bo'lishi kerak",
      );
      return;
    }
    if (exception instanceof PeriodNotDraftOrCalculatedError) {
      this.send(
        response,
        HttpStatus.BAD_REQUEST,
        'PERIOD_NOT_DRAFT_OR_CALCULATED',
        'Hisob-kitob davri DRAFT yoki CALCULATED holatida bo\'lishi kerak',
        { current_status: exception.current_status },
      );
      return;
    }
    if (exception instanceof CalculationAlreadyRunningError) {
      this.send(
        response,
        HttpStatus.CONFLICT,
        'CALCULATION_ALREADY_RUNNING',
        'Hisob-kitob allaqachon bajarilmoqda',
      );
      return;
    }
    if (exception instanceof PeriodFinalizedError) {
      this.send(
        response,
        HttpStatus.BAD_REQUEST,
        'PERIOD_FINALIZED',
        "Yakunlangan hisob-kitob davrini o'zgartirib bo'lmaydi",
      );
      return;
    }
    if (exception instanceof WorkerNotInPeriodError) {
      this.send(
        response,
        HttpStatus.BAD_REQUEST,
        'WORKER_NOT_IN_PERIOD',
        'Ishchi ushbu hisob-kitob davriga tegishli emas',
      );
      return;
    }
    if (exception instanceof AdjustmentNotFoundError) {
      this.send(
        response,
        HttpStatus.NOT_FOUND,
        'ADJUSTMENT_NOT_FOUND',
        'Tuzatma topilmadi',
      );
      return;
    }
    if (exception instanceof PeriodNotCalculatedError) {
      this.send(
        response,
        HttpStatus.BAD_REQUEST,
        'PERIOD_NOT_CALCULATED',
        'Hisob-kitob davri hali hisoblanmagan',
        { current_status: exception.current_status },
      );
      return;
    }
    if (exception instanceof ConfirmationRequiredError) {
      this.send(
        response,
        HttpStatus.BAD_REQUEST,
        'CONFIRMATION_REQUIRED',
        'Yakunlash uchun tasdiqlash talab qilinadi',
      );
      return;
    }
    if (exception instanceof PeriodAlreadyFinalizedError) {
      this.send(
        response,
        HttpStatus.BAD_REQUEST,
        'PERIOD_ALREADY_FINALIZED',
        'Hisob-kitob davri allaqachon yakunlangan',
      );
      return;
    }
    if (exception instanceof ExportNotFoundError) {
      this.send(
        response,
        HttpStatus.NOT_FOUND,
        'EXPORT_NOT_FOUND',
        'Hisob-kitob eksporti topilmadi',
      );
      return;
    }
    this.send(
      response,
      HttpStatus.BAD_REQUEST,
      'EMPTY_UPDATE',
      'Yangilash uchun maydonlar yo\'q',
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
