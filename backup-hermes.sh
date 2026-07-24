#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/backup.conf"

[[ -f "$CONFIG_FILE" ]] || {
    echo "Error: configuration file not found: $CONFIG_FILE" >&2
    echo "Copy backup.conf.example to backup.conf and edit it." >&2
    exit 1
}

# shellcheck source=/dev/null
source "$CONFIG_FILE"

: "${REMOTE_HOST:?REMOTE_HOST is not configured in backup.conf}"
: "${REMOTE_ROOT:?REMOTE_ROOT is not configured in backup.conf}"

HERMES_HOME="${HERMES_HOME:-${HOME}/.hermes}"
COMPOSE_FILENAME="${COMPOSE_FILENAME:-docker-compose.two-container.yml}"

[[ "$REMOTE_HOST" =~ ^[A-Za-z0-9._@-]+$ ]] || {
    echo "Error: REMOTE_HOST contains unsupported characters." >&2
    exit 1
}

[[ "$REMOTE_ROOT" =~ ^/[A-Za-z0-9._/-]+$ ]] || {
    echo "Error: REMOTE_ROOT must be an absolute path using only letters, numbers, '.', '_', '-', and '/'." >&2
    exit 1
}

[[ "$COMPOSE_FILENAME" != */* ]] || {
    echo "Error: COMPOSE_FILENAME must be a filename, not a path." >&2
    exit 1
}

ENV_FILE="${SCRIPT_DIR}/.env"
COMPOSE_FILE="${SCRIPT_DIR}/${COMPOSE_FILENAME}"

TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
REMOTE_SNAPSHOT="${REMOTE_ROOT}/snapshots/${TIMESTAMP}"

for command_name in rsync ssh; do
    command -v "$command_name" >/dev/null 2>&1 || {
        echo "Error: $command_name is not installed." >&2
        exit 1
    }
done

[[ -d "$HERMES_HOME" ]] || {
    echo "Error: Hermes directory not found: $HERMES_HOME" >&2
    exit 1
}

[[ -f "$ENV_FILE" ]] || {
    echo "Error: environment file not found: $ENV_FILE" >&2
    exit 1
}

[[ -f "$COMPOSE_FILE" ]] || {
    echo "Error: Compose file not found: $COMPOSE_FILE" >&2
    exit 1
}

echo "Creating remote backup directory..."

ssh "$REMOTE_HOST" \
    "umask 077 && mkdir -p \
    '${REMOTE_SNAPSHOT}/deployment' \
    '${REMOTE_SNAPSHOT}/hermes-home'"

echo "Backing up deployment files..."

rsync \
    -az \
    --protect-args \
    "$ENV_FILE" \
    "$COMPOSE_FILE" \
    "${REMOTE_HOST}:${REMOTE_SNAPSHOT}/deployment/"

echo "Backing up Hermes state..."

rsync \
    -azH \
    --delete \
    --numeric-ids \
    --protect-args \
    "${HERMES_HOME}/" \
    "${REMOTE_HOST}:${REMOTE_SNAPSHOT}/hermes-home/"

echo "Recording backup metadata..."

{
    echo "created_at=$(date --iso-8601=seconds)"
    echo "hostname=$(hostname)"
    echo "source_hermes_home=${HERMES_HOME}"
    echo "source_deployment=${SCRIPT_DIR}"
} |
ssh "$REMOTE_HOST" \
    "cat > '${REMOTE_SNAPSHOT}/backup-info.txt' &&
     touch '${REMOTE_SNAPSHOT}/BACKUP_COMPLETE' &&
     ln -sfn '${REMOTE_SNAPSHOT}' '${REMOTE_ROOT}/latest'"

echo
echo "Backup completed successfully."
echo "Backup ID: ${TIMESTAMP}"
echo "Destination: ${REMOTE_HOST}:${REMOTE_SNAPSHOT}"