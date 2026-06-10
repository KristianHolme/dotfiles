#!/usr/bin/env bash
set -Eeuo pipefail

# Firefly III backup script
# - Backs up configs from ~/Firefly3 (as a tarball)
# - Dumps the MariaDB database from container firefly_iii_db
# Usage: dotfiles-firefly-backup.sh [DEST_DIR]
# - If DEST_DIR not provided, defaults to ~/Firefly3/backup/<timestamp>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

timestamp() { date +"%Y%m%d-%H%M%S"; }

FIRE3_HOME="${FIRE3_HOME:-$HOME/Firefly3}"
COMPOSE_FILE="$FIRE3_HOME/docker-compose.yml"
DB_ENV_FILE="$FIRE3_HOME/.db.env"
CONTAINER_DB="${FIREFLY_DB_CONTAINER:-firefly_iii_db}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: $0 [DEST_DIR]

Back up Firefly III files and MariaDB dump. Optional destination; default is
timestamped dir under ~/Firefly3/backup/.
EOF
    exit 0
fi

DEST_INPUT="${1:-}"
if [[ -z "$DEST_INPUT" ]]; then
    DEST_ROOT="$FIRE3_HOME/backup"
    mkdir -p "$DEST_ROOT"
    DEST_DIR="$DEST_ROOT/$(timestamp)"
else
    # Use provided path; if it's a directory, create timestamped subdir
    if [[ -d "$DEST_INPUT" ]]; then
        DEST_DIR="$DEST_INPUT/$(timestamp)"
    else
        DEST_DIR="$DEST_INPUT"
    fi
fi
mkdir -p "$DEST_DIR"

ensure_cmd docker tar

if [[ ! -f "$COMPOSE_FILE" ]]; then
    log_error "Compose file not found: $COMPOSE_FILE"
    exit 1
fi

# Load DB credentials from .db.env (compose uses this file)
if [[ ! -f "$DB_ENV_FILE" ]]; then
    log_error "DB env file not found: $DB_ENV_FILE"
    exit 1
fi
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

log_info "Backing up Firefly3 files from $FIRE3_HOME → $DEST_DIR"

# Create configs tarball (exclude backup dir itself)
tar --exclude "backup" -C "$FIRE3_HOME" -czf "$DEST_DIR/firefly3_files.tgz" .

# Dump database
DB_DUMP="$DEST_DIR/firefly_db.sql"
log_info "Dumping database $DB_NAME from container $CONTAINER_DB"
docker exec "$CONTAINER_DB" mariadb-dump -u"$DB_USER" --password="$DB_PASS" "$DB_NAME" >"$DB_DUMP"

log_success "Backup completed at $DEST_DIR"
echo "$DEST_DIR"
