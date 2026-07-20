import { IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

export class CreateDepartmentDto {
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  name!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(30)
  code!: string;

  @IsUUID()
  foreman_id!: string;
}
