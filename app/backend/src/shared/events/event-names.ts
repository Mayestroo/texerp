export const EventNames = {
  // Production
  PRODUCTION_ENTRY_CREATED: 'ProductionEntryCreated',
  PRODUCTION_ENTRY_APPROVED: 'ProductionEntryApproved',
  PRODUCTION_ENTRY_REJECTED: 'ProductionEntryRejected',
  PRODUCTION_ENTRY_CORRECTED: 'ProductionEntryCorrected',

  // Payroll
  PAYROLL_FINALIZED: 'PayrollFinalized',
  PAYROLL_REOPENED: 'PayrollPeriodReopened',
  PAYROLL_EXPORT_READY: 'PayrollExportReady',

  // Warehouse
  MATERIAL_RECEIVED: 'MaterialReceived',
  MATERIAL_ISSUED: 'MaterialIssued',
  STOCK_CORRECTION_POSITIVE: 'StockCorrectionPositive',
  STOCK_CORRECTION_NEGATIVE: 'StockCorrectionNegative',
  LOW_STOCK_ALERT: 'LowStockAlert',
  NEGATIVE_STOCK_WARNING: 'NegativeStockWarning',

  // Reports
  REPORT_EXPORT_READY: 'ReportExportReady',

  // Platform
  TENANT_CREATED: 'TenantCreated',
  TENANT_UPDATED: 'TenantUpdated',
  TENANT_SUSPENDED: 'TenantSuspended',
  TENANT_REACTIVATED: 'TenantReactivated',
  TENANT_TERMINATED: 'TenantTerminated',
  FEATURE_FLAG_CHANGED: 'FeatureFlagChanged',

  // Settings
  TENANT_SETTINGS_UPDATED: 'TenantSettingsUpdated',

  // IAM
  USER_CREATED: 'UserCreated',
  ACCOUNT_LOCKED: 'AccountLocked',

  // Audit/Impersonation
  IMPERSONATION_SESSION_STARTED: 'ImpersonationSessionStarted',
  IMPERSONATION_SESSION_ENDED: 'ImpersonationSessionEnded',
} as const;

export type DomainEventName = (typeof EventNames)[keyof typeof EventNames];
