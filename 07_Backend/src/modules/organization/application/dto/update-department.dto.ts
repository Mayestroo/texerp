import {
  IsBoolean,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
  ValidateIf,
} from 'class-validator';

export class UpdateDepartmentDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  name?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(30)
  code?: string;

  @ValidateIf((_object, value) => value !== undefined)
  @IsUUID()
  foreman_id?: string;

  @IsOptional()
  @IsBoolean()
  is_active?: boolean;
}
