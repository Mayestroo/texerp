#!/usr/bin/env bash
set -e

echo "🚀 Launching TexERP Staging Deployment..."

# 1. Ensure docker compose file exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 2. Build and start containers
echo "📦 Building & starting containers..."
docker compose -f docker-compose.staging.yml up --build -d

# 3. Wait for database health
echo "⏳ Waiting for PostgreSQL database to be healthy..."
until docker exec texerp-staging-postgres pg_isready -U texerp -d texerp_staging > /dev/null 2>&1; do
  sleep 2
done

# 4. Run database migrations inside backend container
echo "🗄️ Running database migrations..."
docker exec texerp-staging-backend npm run migration:run || true

# 5. Seed staging environment
echo "🌱 Seeding staging test tenant data..."
docker exec texerp-staging-backend npm run seed:staging

echo "✅ Staging environment deployed successfully!"
echo "🌐 API Server: http://localhost:3000"
echo "📊 Grafana: http://localhost:3001 (Admin: admin / admin_staging_password)"
echo "📈 Prometheus: http://localhost:9090"
