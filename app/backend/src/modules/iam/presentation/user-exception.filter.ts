import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { Response } from 'express';
import { CannotCreateDirectorError } from '../application/errors/cannot-create-director.error';
import { CannotDeactivateSelfError } from '../application/errors/cannot-deactivate-self.error';
import { EmptyUpdateError } from '../application/errors/empty-update.error';
import { PhoneAlreadyExistsError } from '../application/errors/phone-already-exists.error';
import { UserAlreadyActiveError } from '../application/errors/user-already-active.error';
import { UserAlreadyDeactivatedError } from '../application/errors/user-already-deactivated.error';
import { UserNotFoundError } from '../application/errors/user-not-found.error';
import { WorkerCodeAlreadyExistsError } from '../application/errors/worker-code-already-exists.error';

type UserApplicationError =
  | UserNotFoundError
  | PhoneAlreadyExistsError
  | WorkerCodeAlreadyExistsError
  | CannotCreateDirectorError
  | EmptyUpdateError
  | CannotDeactivateSelfError
  | UserAlreadyDeactivatedError
  | UserAlreadyActiveError;

@Catch(
  UserNotFoundError,
  PhoneAlreadyExistsError,
  WorkerCodeAlreadyExistsError,
  CannotCreateDirectorError,
  EmptyUpdateError,
  CannotDeactivateSelfError,
  UserAlreadyDeactivatedError,
  UserAlreadyActiveError,
)
@Injectable()
export class UserExceptionFilter implements ExceptionFilter<UserApplicationError> {
  catch(exception: UserApplicationError, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();

    if (exception instanceof UserNotFoundError) {
      response.status(HttpStatus.NOT_FOUND).json({
        success: false,
        error: { code: 'USER_NOT_FOUND', message: 'Foydalanuvchi topilmadi' },
      });
      return;
    }
    if (exception instanceof PhoneAlreadyExistsError) {
      response.status(HttpStatus.CONFLICT).json({
        success: false,
        error: {
          code: 'PHONE_ALREADY_EXISTS',
          message: 'Telefon raqami allaqachon ro\u2018yxatdan o\u2018tgan',
        },
      });
      return;
    }
    if (exception instanceof CannotCreateDirectorError) {
      response.status(HttpStatus.BAD_REQUEST).json({
        success: false,
        error: {
          code: 'CANNOT_CREATE_DIRECTOR',
          message: 'Direktor boshqa direktor yarata olmaydi',
        },
      });
      return;
    }
    if (exception instanceof EmptyUpdateError) {
      response.status(HttpStatus.BAD_REQUEST).json({
        success: false,
        error: {
          code: 'EMPTY_UPDATE',
          message: 'Yangilash maydonlari berilmagan',
        },
      });
      return;
    }
    if (exception instanceof CannotDeactivateSelfError) {
      response.status(HttpStatus.BAD_REQUEST).json({
        success: false,
        error: {
          code: 'CANNOT_DEACTIVATE_SELF',
          message: "Direktor o'zini nofaol qila olmaydi",
        },
      });
      return;
    }
    if (exception instanceof UserAlreadyDeactivatedError) {
      response.status(HttpStatus.BAD_REQUEST).json({
        success: false,
        error: {
          code: 'USER_ALREADY_DEACTIVATED',
          message: 'Foydalanuvchi allaqachon nofaol',
        },
      });
      return;
    }
    if (exception instanceof UserAlreadyActiveError) {
      response.status(HttpStatus.BAD_REQUEST).json({
        success: false,
        error: {
          code: 'USER_ALREADY_ACTIVE',
          message: 'Foydalanuvchi allaqachon faol',
        },
      });
      return;
    }

    response.status(HttpStatus.CONFLICT).json({
      success: false,
      error: {
        code: 'WORKER_CODE_ALREADY_EXISTS',
        message: 'Ishchi kodi allaqachon mavjud',
      },
    });
  }
}
