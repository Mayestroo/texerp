import { IsIn, IsOptional, IsString, Length, Matches } from 'class-validator';

export class CreateUserDto {
  @IsString()
  @Length(2, 255)
  full_name!: string;

  @Matches(/^\+998\d{9}$/)
  phone!: string;

  @Matches(/^[A-Za-z0-9_-]{1,20}$/)
  worker_code!: string;

  @IsIn(['WORKER', 'FOREMAN', 'ACCOUNTANT', 'DIRECTOR'])
  role!: 'WORKER' | 'FOREMAN' | 'ACCOUNTANT' | 'DIRECTOR';

  @Matches(/^\d{4}$/)
  initial_pin!: string;

  @IsOptional()
  @IsIn(['uz', 'ru'])
  language?: 'uz' | 'ru';
}
