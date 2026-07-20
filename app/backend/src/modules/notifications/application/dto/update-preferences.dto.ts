import { ArrayMinSize, IsArray, IsBoolean, IsNotEmpty, IsString, MaxLength, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

class PreferenceItem {
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  notification_type!: string;

  @IsBoolean()
  is_enabled!: boolean;
}

export class UpdatePreferencesDto {
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => PreferenceItem)
  preferences!: PreferenceItem[];
}
