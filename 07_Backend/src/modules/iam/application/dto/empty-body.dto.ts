import { IsIn } from 'class-validator';

export class EmptyBodyDto {
  @IsIn([undefined])
  private readonly __emptyBodyMarker?: never;
}
