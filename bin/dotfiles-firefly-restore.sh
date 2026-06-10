#!/usr/bin/env bash
set -Eeuo pipefail

# Firefly III restore script
# Restores from a backup directory produced by dotfiles-firefly-backup.sh
# Usage: dotfiles-firefly-restore.sh <BACKUP_DIR>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

FIRE3_HOME="${FIRE3_HOME:-$HOME/Firefly3}"
COMPOSE_FILE="$FIRE3_HOME/docker-compose.yml"
DB_ENV_FILE="$FIRE3_HOME/.db.env"
CONTAINER_DB="${FIREFLY_DB_CONTAINER:-firefly_iii_db}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: $0 <BACKUP_DIR>

Restore Firefly III from a backup directory produced by dotfiles-firefly-backup.sh.
EOF
    exit 0
fi

SRC_DIR="${1:-}"
if [[ -z "$SRC_DIR" ]]; then
    log_error "Provide the backup directory path (e.g., ~/Firefly3/backup/<timestamp>)"
    exit 1
fi
if [[ ! -d "$SRC_DIR" ]]; then
    log_error "Backup directory not found: $SRC_DIR"
    exit 1
fi

ensure_cmd docker tar

FILES_ARCHIVE="$SRC_DIR/firefly3_files.tgz"
DB_DUMP="$SRC_DIR/firefly_db.sql"

if [[ ! -f "$DB_DUMP" ]]; then
    log_error "Database dump not found at $DB_DUMP"
    exit 1
fi

###########
# Restore files (if compose/env missing, extract first)
###########
if [[ ! -f "$COMPOSE_FILE" || ! -f "$DB_ENV_FILE" ]]; then
    if [[ -f "$FILES_ARCHIVE" ]]; then
        log_info "Extracting files archive to $FIRE3_HOME"
        mkdir -p "$FIRE3_HOME"
        tar -xzf "$FILES_ARCHIVE" -C "$FIRE3_HOME"
    else
        log_error "Compose/env missing and files archive not found: $FILES_ARCHIVE"
        exit 1
    fi
fi

# Re-evaluate paths after potential extraction
COMPOSE_FILE="$FIRE3_HOME/docker-compose.yml"
DB_ENV_FILE="$FIRE3_HOME/.db.env"
if [[ ! -f "$COMPOSE_FILE" ]]; then
    log_error "Compose file still not found after extraction: $COMPOSE_FILE"
    exit 1
fi
if [[ ! -f "$DB_ENV_FILE" ]]; then
    log_error "DB env file still not found after extraction: $DB_ENV_FILE"
    exit 1
fi

# Load DB credentials from .db.env
# shellcheck disable=SC1090
set -a
source "$DB_ENV_FILE"
set +a || true
DB_USER="${MYSQL_USER:-firefly}"
DB_NAME="${MYSQL_DATABASE:-firefly}"
DB_PASS="${MYSQL_PASSWORD:-}"
if [[ -z "$DB_PASS" ]]; then
    log_error "MYSQL_PASSWORD not set in $DB_ENV_FILE"
    exit 1
fi

###########
# Bring up DB and restore dump
###########
log_info "Starting DB container via docker compose"
(cd "$FIRE3_HOME" && docker compose -f "$COMPOSE_FILE" up -d db)

# Wait for DB to be ready
log_info "Waiting for database readiness..."
for i in {1..60}; do
    if docker exec "$CONTAINER_DB" mariadb -u"$DB_USER" --password="${DB_PASS}" -e "SELECT 1" "$DB_NAME" >/dev/null 2>&1; then
        break
    fi
    sleep 2
done

if ! docker exec "$CONTAINER_DB" mariadb -u"$DB_USER" --password="${DB_PASS}" -e "SELECT 1" "$DB_NAME" >/dev/null 2>&1; then
    log_error "Database not ready after waiting; cannot restore."
    exit 1
fi

log_info "Restoring database $DB_NAME into $CONTAINER_DB"
cat "$DB_DUMP" | docker exec -i "$CONTAINER_DB" mariadb -u"$DB_USER" --password="$DB_PASS" "$DB_NAME"

###########
# Start full stack
###########
log_info "Starting full stack"
(cd "$FIRE3_HOME" && docker compose -f "$COMPOSE_FILE" up -d)

log_success "Restore completed from $SRC_DIR"
