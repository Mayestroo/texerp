export interface AccessTokenClaims {
  sub: string;
  tenant_id: string;
  role: 'WORKER' | 'FOREMAN' | 'ACCOUNTANT' | 'DIRECTOR';
  phone: string;
  jti: string;
  sid: string;
  iat: number;
  exp: number;
}
