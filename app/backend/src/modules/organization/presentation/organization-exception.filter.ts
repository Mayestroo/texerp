import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { Response } from 'express';
import { DepartmentCodeAlreadyExistsError } from '../application/errors/department-code-already-exists.error';
import { DepartmentHasNoForemanError } from '../application/errors/department-has-no-foreman.error';
import { DepartmentNameAlreadyExistsError } from '../application/errors/department-name-already-exists.error';
import { DepartmentNotFoundError } from '../application/errors/department-not-found.error';
import { EmptyDepartmentUpdateError } from '../application/errors/empty-department-update.error';
import { ForemanNotFoundError } from '../application/errors/foreman-not-found.error';
import { WorkerNotFoundError } from '../application/errors/worker-not-found.error';

type OrganizationApplicationError =
  | DepartmentNotFoundError
  | DepartmentNameAlreadyExistsError
  | DepartmentCodeAlreadyExistsError
  | ForemanNotFoundError
  | WorkerNotFoundError
  | DepartmentHasNoForemanError
  | EmptyDepartmentUpdateError;

@Catch(
  DepartmentNotFoundError,
  DepartmentNameAlreadyExistsError,
  DepartmentCodeAlreadyExistsError,
  ForemanNotFoundError,
  WorkerNotFoundError,
  DepartmentHasNoForemanError,
  EmptyDepartmentUpdateError,
)
@Injectable()
export class OrganizationExceptionFilter implements ExceptionFilter<OrganizationApplicationError> {
  catch(exception: OrganizationApplicationError, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();
    if (exception instanceof DepartmentNotFoundError) {
      this.send(
        response,
        HttpStatus.NOT_FOUND,
        'DEPARTMENT_NOT_FOUND',
        "Bo'lim topilmadi",
      );
      return;
    }
    if (exception instanceof ForemanNotFoundError) {
      this.send(
        response,
        HttpStatus.NOT_FOUND,
        'FOREMAN_NOT_FOUND',
        'Brigadir topilmadi',
      );
      return;
    }
    if (exception instanceof WorkerNotFoundError) {
      this.send(
        response,
        HttpStatus.NOT_FOUND,
        'WORKER_NOT_FOUND',
        'Ishchi topilmadi',
      );
      return;
    }
    if (exception instanceof DepartmentHasNoForemanError) {
      this.send(
        response,
        HttpStatus.BAD_REQUEST,
        'DEPARTMENT_HAS_NO_FOREMAN',
        "Bo'limga faol brigadir biriktirilmagan",
      );
      return;
    }
    if (exception instanceof EmptyDepartmentUpdateError) {
      this.send(
        response,
        HttpStatus.BAD_REQUEST,
        'EMPTY_UPDATE',
        'Yangilash maydonlari berilmagan',
      );
      return;
    }
    if (exception instanceof DepartmentNameAlreadyExistsError) {
      this.send(
        response,
        HttpStatus.CONFLICT,
        'DEPARTMENT_NAME_ALREADY_EXISTS',
        "Bo'lim nomi allaqachon mavjud",
      );
      return;
    }
    this.send(
      response,
      HttpStatus.CONFLICT,
      'DEPARTMENT_CODE_ALREADY_EXISTS',
      "Bo'lim kodi allaqachon mavjud",
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
