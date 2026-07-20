import { SetMetadata } from '@nestjs/common';

export const THROTTLE_KEY = 'throttle';

export interface ThrottleConfig {
  limit: number;
  windowSec: number;
  key: 'ip' | 'user' | 'phone' | 'otp_token';
}

export const Throttle = (config: ThrottleConfig): MethodDecorator & ClassDecorator =>
  SetMetadata(THROTTLE_KEY, config);
