import { CanActivate, ExecutionContext, HttpException, HttpStatus, Injectable, Logger } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { AuthenticatedRequest } from '../../modules/iam/presentation/jwt-auth.guard';
import { THROTTLE_KEY, ThrottleConfig } from './rate-limit.decorator';
import { RateLimitService } from './rate-limit.service';

@Injectable()
export class RateLimitGuard implements CanActivate {
  private readonly logger = new Logger(RateLimitGuard.name);

  constructor(
    private readonly reflector: Reflector,
    private readonly rateLimitService: RateLimitService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const throttleConfig = this.reflector.getAllAndOverride<ThrottleConfig>(THROTTLE_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    const config = throttleConfig ?? this.getDefaultConfig(context);
    if (!config) {
      return true;
    }

    const request = context.switchToHttp().getRequest<Request>();
    const key = this.buildKey(config, request);

    try {
      const { count, ttl } = await this.rateLimitService.increment(key, config.windowSec);

      if (count > config.limit) {
        throw new HttpException(
          {
            success: false,
            error: {
              code: 'RATE_LIMITED',
              message: "Juda ko'p so'rov. Birozdan keyin urinib ko'ring.",
              retry_after_seconds: ttl,
            },
          },
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
    } catch (error) {
      if (error instanceof HttpException) {
        throw error;
      }

      // Fail open when Redis is unavailable rather than blocking traffic.
      this.logger.warn(
        `Rate limit check failed, failing open: ${error instanceof Error ? error.message : String(error)}`,
      );
      return true;
    }

    return true;
  }

  private getDefaultConfig(context: ExecutionContext): ThrottleConfig | null {
    const request = context.switchToHttp().getRequest<Request>();
    const user = (request as AuthenticatedRequest).user;

    if (user?.sub) {
      return { limit: 300, windowSec: 60, key: 'user' };
    }

    return { limit: 60, windowSec: 60, key: 'ip' };
  }

  private buildKey(config: ThrottleConfig, request: Request): string {
    const user = (request as AuthenticatedRequest).user;
    const ip = request.ip || request.socket.remoteAddress || 'unknown';
    const body = request.body as { phone?: string; otp_token?: string } | undefined;

    switch (config.key) {
      case 'ip':
        return `rl:ip:${ip}`;
      case 'user':
        return `rl:user:${user?.sub || ip}`;
      case 'phone':
        return `rl:phone:${body?.phone || ip}`;
      case 'otp_token':
        return `rl:otp:${body?.otp_token || ip}`;
      default:
        return `rl:unknown:${ip}`;
    }
  }
}
