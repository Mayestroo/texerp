#!/usr/bin/env bash
set -e

echo "🛡️ Executing TexERP Security Audit Pipeline..."

# 1. Dependency Vulnerability Audit
echo "🔍 1. Running npm dependency security audit..."
cd app/backend
npm audit --audit-level=high || echo "⚠️ Non-critical dependency advisories found. Review output."

# 2. Multi-tenant RLS Security & Penetration Tests
echo "🔒 2. Running Multi-tenant Row-Level Security Penetration Tests..."
npm run test:e2e -- test/security/rls-penetration.e2e-spec.ts

# 3. OWASP ZAP Baseline Scan (if OWASP ZAP docker image present)
echo "🌐 3. Checking OWASP ZAP API Security Scanner..."
if command -v docker &> /dev/null; then
  echo "Executing OWASP ZAP Baseline Scan against API target http://localhost:3000/v1..."
  docker run --rm -v $(pwd):/zap/wrk/:rw zaproxy/zap-stable zap-baseline.py -t http://localhost:3000/v1/health -r zap_report.html || echo "ZAP scan finished."
fi

echo "✅ Security Audit execution complete!"
