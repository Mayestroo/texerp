import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { Response } from 'express';
import { PlatformUserNotFoundError } from '../application/errors/platform-user-not-found.error';
import { TenantNotFoundError } from '../application/errors/tenant-not-found.error';
import { PlanNotFoundError } from '../application/errors/plan-not-found.error';
import { TenantSlugAlreadyExistsError } from '../application/errors/tenant-slug-already-exists.error';
import { PlanNameAlreadyExistsError } from '../application/errors/plan-name-already-exists.error';
import { DirectorPhoneAlreadyExistsError } from '../application/errors/director-phone-already-exists.error';

type PlatformApplicationError =
  | PlatformUserNotFoundError
  | TenantNotFoundError
  | PlanNotFoundError
  | TenantSlugAlreadyExistsError
  | PlanNameAlreadyExistsError
  | DirectorPhoneAlreadyExistsError;

@Catch(
  PlatformUserNotFoundError,
  TenantNotFoundError,
  PlanNotFoundError,
  TenantSlugAlreadyExistsError,
  PlanNameAlreadyExistsError,
  DirectorPhoneAlreadyExistsError,
)
@Injectable()
export class PlatformExceptionFilter implements ExceptionFilter<PlatformApplicationError> {
  catch(exception: PlatformApplicationError, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();

    if (exception instanceof PlatformUserNotFoundError) {
      response.status(HttpStatus.NOT_FOUND).json({
        success: false,
        error: {
          code: 'PLATFORM_USER_NOT_FOUND',
          message: 'Platform administrator topilmadi',
        },
      });
      return;
    }

    if (exception instanceof TenantNotFoundError) {
      response.status(HttpStatus.NOT_FOUND).json({
        success: false,
        error: {
          code: 'TENANT_NOT_FOUND',
          message: 'Tenant topilmadi',
        },
      });
      return;
    }

    if (exception instanceof PlanNotFoundError) {
      response.status(HttpStatus.NOT_FOUND).json({
        success: false,
        error: {
          code: 'PLAN_NOT_FOUND',
          message: 'Obuna rejasi topilmadi',
        },
      });
      return;
    }

    if (exception instanceof TenantSlugAlreadyExistsError) {
      response.status(HttpStatus.CONFLICT).json({
        success: false,
        error: {
          code: 'TENANT_SLUG_ALREADY_EXISTS',
          message: 'Tenant slug allaqachon mavjud',
        },
      });
      return;
    }

    if (exception instanceof DirectorPhoneAlreadyExistsError) {
      response.status(HttpStatus.CONFLICT).json({
        success: false,
        error: {
          code: 'DIRECTOR_PHONE_ALREADY_EXISTS',
          message: 'Direktor telefon raqami allaqachon ro‘yxatdan o‘tgan',
        },
      });
      return;
    }

    response.status(HttpStatus.CONFLICT).json({
      success: false,
      error: {
        code: 'PLAN_NAME_ALREADY_EXISTS',
        message: 'Obuna rejasi nomi allaqachon mavjud',
      },
    });
  }
}
