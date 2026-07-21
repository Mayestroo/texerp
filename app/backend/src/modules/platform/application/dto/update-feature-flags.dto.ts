import { IsBoolean, IsObject, IsString } from 'class-validator';

export class FeatureFlagEntry {
  @IsString()
  feature_key!: string;

  @IsBoolean()
  is_enabled!: boolean;
}

export class UpdateFeatureFlagsDto {
  @IsObject()
  flags!: Record<string, boolean>;
}
