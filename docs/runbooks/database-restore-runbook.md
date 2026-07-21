# Database Disaster Recovery & Restoration Runbook

This runbook documents step-by-step procedures to recover the TexERP PostgreSQL database from automated S3 backups and perform Point-In-Time Recovery (PITR).

---

## 1. Full Database Restoration from S3 Backup

### Prerequisites
- AWS CLI configured with S3 access to `texerp-database-backups` bucket.
- Access to PostgreSQL server container or host.

### Step 1: Download Latest Compressed Backup
List available S3 backups and download target file:
```bash
aws s3 ls s3://texerp-database-backups/daily-dumps/
aws s3 cp s3://texerp-database-backups/daily-dumps/texerp-db-backup-2026-07-21.sql.gz ./latest-backup.sql.gz
```

### Step 2: Prepare Target PostgreSQL Database
Terminate active client connections and re-create database:
```bash
docker exec -i texerp-staging-postgres psql -U texerp -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'texerp';"
docker exec -i texerp-staging-postgres psql -U texerp -d postgres -c "DROP DATABASE IF EXISTS texerp;"
docker exec -i texerp-staging-postgres psql -U texerp -d postgres -c "CREATE DATABASE texerp OWNER texerp;"
```

### Step 3: Restore Database Dump
Stream decompressed backup directly into `psql`:
```bash
gunzip -c latest-backup.sql.gz | docker exec -i texerp-staging-postgres psql -U texerp -d texerp
```

---

## 2. Point-In-Time Recovery (PITR) Procedure

### Step 1: Stop TexERP Backend API Server
```bash
docker stop texerp-staging-backend
```

### Step 2: Configure `recovery.signal` & Target Time
Create `recovery.signal` in PostgreSQL data directory:
```bash
docker exec -it texerp-staging-postgres touch /var/lib/postgresql/data/recovery.signal
```

Append recovery settings to `postgresql.conf`:
```ini
restore_command = 'cp /var/lib/postgresql/wal_archive/%f %p'
recovery_target_time = '2026-07-21 14:30:00 UTC'
recovery_target_action = 'promote'
```

### Step 3: Restart PostgreSQL Server
```bash
docker restart texerp-staging-postgres
```
PostgreSQL will process WAL files up to `2026-07-21 14:30:00 UTC` and automatically transition to read-write mode upon reaching the target timeline.

---

## 3. Verification & Post-Restoration Check

1. Verify record count and integrity across tenants, users, and audit logs:
```sql
SELECT count(*) FROM tenants;
SELECT count(*) FROM users;
SELECT max(created_at) FROM audit_events;
```
2. Start TexERP API Backend and verify `/v1/health` endpoint returns `200 OK`.
```bash
docker start texerp-staging-backend
curl http://localhost:3000/v1/health
```
