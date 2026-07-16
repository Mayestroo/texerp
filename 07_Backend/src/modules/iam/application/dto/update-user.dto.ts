import {
  IsIn,
  IsOptional,
  IsString,
  IsUrl,
  Length,
  ValidateIf,
} from 'class-validator';

export class UpdateUserDto {
  @ValidateIf((_object, value: unknown) => value !== undefined)
  @IsString()
  @Length(2, 255)
  full_name?: string;

  @ValidateIf((_object, value: unknown) => value !== undefined)
  @IsIn(['uz', 'ru'])
  language?: 'uz' | 'ru';

  @IsOptional()
  @IsUrl()
  avatar_url?: string | null;
}
