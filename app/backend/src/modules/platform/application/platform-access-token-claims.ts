export interface PlatformAccessTokenPayload {
  sub: string;
  tenant_id: null;
  role: 'SUPER_ADMIN';
  email: string;
  token_use: 'platform';
  jti: string;
  sid: string;
}

export interface PlatformAccessTokenClaims extends PlatformAccessTokenPayload {
  iat: number;
  exp: number;
}

export interface PlatformImpersonationPayload {
  sub: string;
  tenant_id: string;
  role: 'WORKER' | 'FOREMAN' | 'ACCOUNTANT' | 'DIRECTOR';
  phone: string;
  token_use: 'impersonation';
  impersonation: true;
  jti: string;
  sid: string;
}

export interface PlatformImpersonationClaims extends PlatformImpersonationPayload {
  iat: number;
  exp: number;
}
