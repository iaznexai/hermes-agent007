# Hermes Backup Scripts

Simple Bash scripts for backing up and restoring a local Hermes deployment using `rsync` over SSH.

The purpose of these scripts is **disaster recovery**: preserving the Hermes state and deployment configuration so a system can be rebuilt after a hardware failure, operating system reinstall, or migration to another machine.

---

# Features

- Incremental backups using `rsync`
- Timestamped snapshots
- Automatic `latest` symlink
- Restore the newest or any previous snapshot
- Stores normal files and directories (no tar or zip archives)
- SSH transport
- Configuration separated from the scripts
- Safe to publish in a public Git repository

---

# Requirements

The following software must be installed:

- Bash
- rsync
- OpenSSH (ssh)
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
├── .env.example
├── .gitignore
├── README.md
└── docker-compose.two-container.yml
```

Your deployment directory will typically look like this:

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

Create a local configuration file:

```bash
cp backup.conf.example backup.conf
chmod 600 backup.conf
```

Edit `backup.conf`:

```bash
REMOTE_HOST="BACKUP_HOST"
REMOTE_ROOT="/PATH/TO/BACKUPS"

# Optional
HERMES_HOME="${HOME}/.hermes"

# Optional
COMPOSE_FILENAME="docker-compose.two-container.yml"
```

| Variable | Description |
|----------|-------------|
| `REMOTE_HOST` | SSH hostname or SSH alias |
| `REMOTE_ROOT` | Remote directory used to store backups |
| `HERMES_HOME` | Hermes persistent state directory |
| `COMPOSE_FILENAME` | Docker Compose file to back up |

The scripts automatically locate the deployment directory based on their own location.

---

# First-Time Setup

Make the scripts executable:

```bash
chmod 700 backup-hermes.sh
chmod 700 restore-hermes.sh
```

Validate the scripts:

```bash
bash -n backup-hermes.sh
bash -n restore-hermes.sh
```

If ShellCheck is available:

```bash
shellcheck backup-hermes.sh restore-hermes.sh
```

---

# Creating a Backup

Run:

```bash
./backup-hermes.sh
```

The backup includes:

- `.env`
- `docker-compose.two-container.yml`
- Hermes persistent state (`HERMES_HOME`)

A timestamped snapshot is created on the remote host.

Example:

```text
/PATH/TO/BACKUPS/
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

Restore the newest backup:

```bash
./restore-hermes.sh
```

Restore a specific snapshot:

```bash
./restore-hermes.sh 2026-07-24_14-12-05
```

The restore operation replaces:

- Hermes persistent state
- `.env`
- Docker Compose configuration

The script asks for confirmation before overwriting any files.

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

Stop Hermes:

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
3. Clone or download this repository.
4. Create `backup.conf` from `backup.conf.example`.
5. Configure the remote backup location.
6. Run:

```bash
./restore-hermes.sh
```

7. Start Hermes:

```bash
docker compose \
    -f docker-compose.two-container.yml \
    up -d
```

---

# Inspecting Remote Backups

List all snapshots:

```bash
ssh BACKUP_HOST \
    "find /PATH/TO/BACKUPS/snapshots -maxdepth 1 -type d | sort"
```

Show the latest snapshot:

```bash
ssh BACKUP_HOST \
    "readlink -f /PATH/TO/BACKUPS/latest"
```

Display snapshot sizes:

```bash
ssh BACKUP_HOST \
    "du -sh /PATH/TO/BACKUPS/snapshots/*"
```

---

# Preview a Backup

Preview what would be transferred without copying any files:

```bash
rsync -avzn \
    "${HOME}/.hermes/" \
    BACKUP_HOST:/PATH/TO/BACKUPS/test/
```

Preview deployment files:

```bash
rsync -avzn \
    .env \
    docker-compose.two-container.yml \
    BACKUP_HOST:/PATH/TO/BACKUPS/test/
```

The `-n` (`--dry-run`) option performs no writes.

---

# Security

Never commit:

- `.env`
- `backup.conf`
- SSH private keys
- API keys
- Passwords
- Tokens

Recommended `.gitignore`:

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

Before publishing changes, review them carefully.

If using Git locally:

```bash
git diff --cached
```

---

# Notes

- The scripts use `rsync` for file synchronization.
- `-z` compresses data only during network transfer.
- Backups are stored as regular files and directories.
- Docker images and containers are intentionally **not** backed up.
- Containers can be recreated from the Compose configuration after restoring the Hermes state.

---

# License

Apache-2.0 License.
