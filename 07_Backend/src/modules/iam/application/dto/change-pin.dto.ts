import { IsString, Length, Matches } from 'class-validator';

export class ChangePinDto {
  @IsString()
  @Length(4, 4)
  @Matches(/^[0-9]{4}$/, { message: 'PIN must be exactly 4 digits' })
  current_pin!: string;

  @IsString()
  @Length(4, 4)
  @Matches(/^[0-9]{4}$/, { message: 'PIN must be exactly 4 digits' })
  new_pin!: string;
}
