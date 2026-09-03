#!/usr/bin/env bash
# Cron daily: 0 2 * * * /path/to/backup.sh
# NFR §2.4 — sao lưu định kỳ, giữ 14-30 ngày.
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/var/backups/lt-arc}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
DB_CONTAINER="${DB_CONTAINER:-infra-postgres-1}"
DB_NAME="${DB_NAME:-lt_arc}"
DB_USER="${DB_USER:-postgres}"

mkdir -p "$BACKUP_DIR"
STAMP=$(date +%Y%m%d_%H%M%S)
FILE="$BACKUP_DIR/lt_arc_${STAMP}.sql.gz"

docker exec "$DB_CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$FILE"
echo "Backup written to $FILE"

find "$BACKUP_DIR" -name "lt_arc_*.sql.gz" -mtime +"$RETENTION_DAYS" -delete
