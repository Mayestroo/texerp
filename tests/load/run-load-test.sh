#!/usr/bin/env bash
set -e

TARGET_URL=${1:-"http://localhost:3000/v1"}

echo "🔥 Executing TexERP k6 Load Test against ${TARGET_URL}..."

if command -v k6 &> /dev/null; then
  TARGET_URL=$TARGET_URL k6 run tests/load/k6-payroll-load.js
else
  echo "🐳 Running k6 via Docker container..."
  docker run --rm -i -e TARGET_URL=$TARGET_URL grafana/k6 run - < tests/load/k6-payroll-load.js
fi

echo "✅ Load test execution completed!"
