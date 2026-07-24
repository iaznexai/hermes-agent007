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

for command_name in rsync ssh; do
    command -v "$command_name" >/dev/null 2>&1 || {
        echo "Error: $command_name is not installed." >&2
        exit 1
    }
done

if [[ $# -gt 1 ]]; then
    echo "Usage: $0 [timestamp|latest]" >&2
    exit 1
fi

BACKUP_NAME="${1:-latest}"

if [[ "$BACKUP_NAME" == "latest" ]]; then
    REMOTE_SOURCE="$(
        ssh "$REMOTE_HOST" \
            "readlink -f '${REMOTE_ROOT}/latest'"
    )"
else
    [[ "$BACKUP_NAME" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]] || {
        echo "Error: invalid backup timestamp: $BACKUP_NAME" >&2
        exit 1
    }

    REMOTE_SOURCE="${REMOTE_ROOT}/snapshots/${BACKUP_NAME}"
fi

[[ -n "$REMOTE_SOURCE" ]] || {
    echo "Error: unable to determine backup source." >&2
    exit 1
}

[[ "$REMOTE_SOURCE" == "${REMOTE_ROOT}/snapshots/"* ]] || {
    echo "Error: resolved backup path is outside the snapshots directory." >&2
    exit 1
}

ssh "$REMOTE_HOST" \
    "test -d '${REMOTE_SOURCE}' &&
     test -f '${REMOTE_SOURCE}/BACKUP_COMPLETE' &&
     test -f '${REMOTE_SOURCE}/deployment/.env' &&
     test -f '${REMOTE_SOURCE}/deployment/${COMPOSE_FILENAME}' &&
     test -d '${REMOTE_SOURCE}/hermes-home'" || {
    echo "Error: backup does not exist, is incomplete, or lacks required files:" >&2
    echo "${REMOTE_HOST}:${REMOTE_SOURCE}" >&2
    exit 1
}

echo "Restore source:"
echo "${REMOTE_HOST}:${REMOTE_SOURCE}"
echo
echo "This will replace:"
echo "  ${HERMES_HOME}"
echo "  ${SCRIPT_DIR}/.env"
echo "  ${SCRIPT_DIR}/${COMPOSE_FILENAME}"
echo

read -r -p "Type RESTORE to continue: " CONFIRM

[[ "$CONFIRM" == "RESTORE" ]] || {
    echo "Restore cancelled."
    exit 1
}

mkdir -p "$HERMES_HOME"

echo "Restoring Hermes state..."

rsync \
    -azH \
    --delete \
    --numeric-ids \
    --protect-args \
    "${REMOTE_HOST}:${REMOTE_SOURCE}/hermes-home/" \
    "${HERMES_HOME}/"

echo "Restoring environment file..."

rsync \
    -az \
    --protect-args \
    "${REMOTE_HOST}:${REMOTE_SOURCE}/deployment/.env" \
    "${SCRIPT_DIR}/.env"

echo "Restoring Compose file..."

rsync \
    -az \
    --protect-args \
    "${REMOTE_HOST}:${REMOTE_SOURCE}/deployment/${COMPOSE_FILENAME}" \
    "${SCRIPT_DIR}/${COMPOSE_FILENAME}"

chmod 600 "${SCRIPT_DIR}/.env"
chmod 600 "${SCRIPT_DIR}/${COMPOSE_FILENAME}"

echo
echo "Restore completed."
echo
echo "Start Hermes with:"
printf "docker compose -f %q up -d\n" \
    "${SCRIPT_DIR}/${COMPOSE_FILENAME}"