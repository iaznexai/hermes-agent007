# Hermes Backup Scripts

Simple Bash scripts for backing up and restoring a local Hermes deployment using `rsync` over SSH.

The goal is **disaster recovery**: preserving the Hermes state and deployment configuration so a system can be rebuilt after hardware failure, OS reinstallation, or migration to a new machine.

---

# Features

- Incremental backups using `rsync`
- Timestamped snapshots
- `latest` symlink automatically updated after successful backups
- Restore the latest snapshot or any previous snapshot
- Stores normal files and directories (no archive files)
- Uses SSH for transport
- Configuration kept separate from the scripts
- Safe for public repositories

---

# Requirements

The following programs must be available:

- Bash
- rsync
- ssh
- Docker
- Docker Compose

The backup destination must be reachable over SSH.

---

# Repository Layout

```text
.
├── backup-hermes.sh
├── restore-hermes.sh
├── backup.conf.example
├── .gitignore
└── README.md
```

Your deployment directory will normally also contain:

```text
.
├── .env
├── docker-compose.two-container.yml
├── backup-hermes.sh
├── restore-hermes.sh
├── backup.conf
└── README.md
```

---

# Configuration

Copy the example configuration:

```bash
cp backup.conf.example backup.conf
chmod 600 backup.conf
```

Edit `backup.conf`:

```bash
REMOTE_HOST="<backup-host>"
REMOTE_ROOT="<backup-root>"

# Optional
HERMES_HOME="${HOME}/.hermes"

# Optional
COMPOSE_FILENAME="docker-compose.two-container.yml"
```

| Variable | Description |
|-----------|-------------|
| `REMOTE_HOST` | SSH hostname or SSH alias |
| `REMOTE_ROOT` | Remote directory where backups are stored |
| `HERMES_HOME` | Hermes persistent state directory |
| `COMPOSE_FILENAME` | Docker Compose file name |

The scripts automatically determine the deployment directory from their own location.

---

# First-Time Setup

Make the scripts executable.

```bash
chmod 700 backup-hermes.sh
chmod 700 restore-hermes.sh
```

Validate the scripts:

```bash
bash -n backup-hermes.sh
bash -n restore-hermes.sh
```

If ShellCheck is installed:

```bash
shellcheck backup-hermes.sh restore-hermes.sh
```

---

# Creating a Backup

Run:

```bash
./backup-hermes.sh
```

The script backs up:

- `.env`
- `docker-compose.two-container.yml`
- `${HERMES_HOME}`

A timestamped snapshot is created on the remote host.

Example:

```text
<backup-root>/
├── latest
└── snapshots/
    ├── 2026-07-24_14-12-05/
    ├── 2026-07-25_18-31-40/
    └── ...
```

Each snapshot contains:

```text
deployment/
├── .env
└── docker-compose.two-container.yml

hermes-home/

backup-info.txt
BACKUP_COMPLETE
```

---

# Restoring

Restore the latest backup:

```bash
./restore-hermes.sh
```

Restore a specific snapshot:

```bash
./restore-hermes.sh 2026-07-24_14-12-05
```

The script restores:

- Hermes state
- `.env`
- Docker Compose configuration

The restore requires confirmation before overwriting existing files.

---

# Starting Hermes

After restoring:

```bash
docker compose \
    -f docker-compose.two-container.yml \
    up -d
```

---

# Recommended Backup Workflow

Before making major system changes:

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

---

# Migrating to a New Machine

1. Install Docker.
2. Install Docker Compose.
3. Clone this repository.
4. Create `backup.conf`.
5. Run:

```bash
./restore-hermes.sh
```

6. Start Hermes:

```bash
docker compose \
    -f docker-compose.two-container.yml \
    up -d
```

---

# Inspecting Remote Backups

List snapshots:

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

# Testing Without Copying Data

Preview a backup:

```bash
rsync -avzn \
    "${HOME}/.hermes/" \
    <backup-host>:<backup-root>/test/
```

Preview deployment files:

```bash
rsync -avzn \
    .env \
    docker-compose.two-container.yml \
    <backup-host>:<backup-root>/test/
```

No files are transferred when using `-n`.

---

# Security

The following files should **never** be committed:

- `.env`
- `backup.conf`
- SSH keys
- API keys
- Passwords
- Tokens

A recommended `.gitignore`:

```gitignore
.env
.env.*
!.env.example

backup.conf

*.pem
*.key
id_rsa
id_ed25519

snapshots/
latest
```

Before committing, review staged changes:

```bash
git diff --cached
```

---

# Notes

- The scripts use `rsync`.
- `-z` compresses data **during transfer only**.
- Backups are stored as regular files and directories rather than archive files.
- Docker images and containers are **not** backed up.
- Docker recreates containers from the Compose file.
- The Hermes state is restored from the backed-up data.

---

# License

Apache-2.0
