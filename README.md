# Hermes Backup & Restore

This repository contains helper scripts to back up and restore a local Hermes deployment.

The objective is **disaster recovery**—being able to rebuild the Hermes environment on another machine after a disk failure, OS reinstall, or migration.

## What is backed up

The backup consists of:

- `.env`
- `docker-compose.two-container.yml`
- Hermes home directory (`<hermes-home>`)

The Hermes home directory contains the persistent Hermes state (profiles, skills, memory, configuration, sessions, etc.).

Docker images and containers are **not** backed up because they can be recreated from Docker Compose.

---

## Repository Layout

```text
hermes/
├── backup-hermes.sh
├── restore-hermes.sh
├── docker-compose.two-container.yml
├── .env
└── README.md
```

Replace the placeholders below with values appropriate for your environment.

| Placeholder | Example |
|------------|---------|
| `<deployment-dir>` | Directory containing the compose file and scripts |
| `<hermes-home>` | Hermes persistent state directory |
| `<backup-host>` | SSH hostname or alias |
| `<backup-root>` | Remote backup directory |

---

## Configuration

Inside both scripts, update the following values:

```bash
REMOTE_HOST="<backup-host>"
REMOTE_ROOT="<backup-root>"
HERMES_HOME="<hermes-home>"
```

The scripts automatically determine the deployment directory from their own location.

---

## First-time setup

Make both scripts executable.

```bash
chmod 700 backup-hermes.sh
chmod 700 restore-hermes.sh
```

Copy the scripts to the remote backup location (optional but recommended):

```bash
rsync -av \
    backup-hermes.sh \
    restore-hermes.sh \
    <backup-host>:<backup-root>/
```

---

## Running a backup

From the deployment directory:

```bash
./backup-hermes.sh
```

Each execution creates a timestamped snapshot.

Example:

```text
<backup-root>/
└── snapshots/
    ├── 2026-07-24_14-12-05/
    ├── 2026-07-25_09-30-11/
    └── ...
```

A `latest` symbolic link is updated after every successful backup.

---

## Restoring

Restore the latest backup:

```bash
./restore-hermes.sh
```

Restore a specific backup:

```bash
./restore-hermes.sh 2026-07-24_14-12-05
```

After restoring, recreate the containers:

```bash
docker compose \
    -f docker-compose.two-container.yml \
    up -d
```

---

## Recommended migration procedure

Before formatting a machine or migrating to another host:

Stop the containers:

```bash
docker compose \
    -f docker-compose.two-container.yml \
    stop
```

Create a backup:

```bash
./backup-hermes.sh
```

Restart Hermes:

```bash
docker compose \
    -f docker-compose.two-container.yml \
    start
```

On the new machine:

1. Install Docker and Docker Compose.
2. Restore the backup.
3. Start the containers:

```bash
docker compose \
    -f docker-compose.two-container.yml \
    up -d
```

---

## Inspecting remote backups

List all snapshots:

```bash
ssh <backup-host> \
    "find <backup-root>/snapshots -maxdepth 1 -type d | sort"
```

Show the latest snapshot:

```bash
ssh <backup-host> \
    "readlink -f <backup-root>/latest"
```

Show snapshot sizes:

```bash
ssh <backup-host> \
    "du -sh <backup-root>/snapshots/*"
```

---

## Testing without copying data

Verify what would be transferred:

```bash
rsync -avzn \
    <hermes-home>/ \
    <backup-host>:<backup-root>/test/
```

Verify deployment files:

```bash
rsync -avzn \
    .env \
    docker-compose.two-container.yml \
    <backup-host>:<backup-root>/test/
```

---

## Notes

- The scripts use `rsync`.
- Network traffic is compressed during transfer (`-z`).
- The destination stores normal files and directories rather than compressed archives.
- Timestamped snapshots make it easy to restore any previous version.
- Docker containers themselves are not backed up.
- Do not commit `.env` or other secrets to version control.
