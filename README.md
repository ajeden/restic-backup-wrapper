# Restic Backup Script

A comprehensive backup script using Restic with configurable repositories, retention policies, and automated cleanup.

## Overview

`run_restic_backup.sh` is a robust backup script that:
- Loads configuration from repository files (`.repo`)
- Performs backups with include/exclude patterns
- Manages retention policies automatically
- Provides detailed logging
- Cleans up environment variables

## Usage

### Basic Usage

```bash
# Use default configuration
./run_restic_backup.sh

# Use custom files
RESTIC_INCLUDE_FILE="./my-backup.include" \
RESTIC_REPO_FILE="./my-repo.repo" \
./run_restic_backup.sh
```

### Environment Variables

| Variable | Default | Description |
|-----------|---------|------------|
| `RESTIC_INCLUDE_FILE` | `./test.include` | Path to include file |
| `RESTIC_EXCLUDE_FILE` | `./exclude.patterns` | Path to exclude file |
| `RESTIC_REPO_FILE` | `./test.repo` | Path to repository config |

## Repository Configuration

Create a `.repo` file with your backup configuration:

```bash
# Repository URL
RESTIC_REPOSITORY=rest:https://p5.siudzinski.net:41902/test

# Authentication
RESTIC_PASSWORD_FILE=test.password
RESTIC_REST_USERNAME=bart
RESTIC_REST_PASSWORD="your-password"

# Performance settings
RESTIC_READ_CONCURRENCY=32

# Certificate handling
RESTIC_IGNORE_CERT=true

# Retention policy (optional)
RESTIC_KEEP_DAILY=7
RESTIC_KEEP_WEEKLY=4
RESTIC_KEEP_MONTHLY=12
RESTIC_KEEP_YEARLY=7
```

## Include Files

Specify what to backup in your `.include` file:

```
# Example include file
/home/user/documents
/var/www/html
/etc/nginx
/opt/important-data
```

## Exclude Patterns

Global exclude patterns in `exclude.patterns`:

```
*.log
*.tmp
*.lrdata
~*
.directory
desktop.ini
.sync_*
Sync.Cache
nextcloud-data/**/files_trashbin
nextcloud-data/**/files_versions
nextcloud-data/**/cache
```

## Logging

### Log Files

- **Location**: `/var/log/restic/[include-filename].log`
- **Format**: `YYYY-MM-DD HH:MM:SS [LEVEL] message`

### Log Levels

- `INFO`: General information
- `WARNING`: Non-critical issues  
- `ERROR`: Critical errors (script exits)

### Example Log Output

```
2025-10-04 14:55:58 [INFO] === Restic Backup Script Started ===
2025-10-04 14:55:58 [INFO] Script directory: /home/bart/restic-bak_Miras
2025-10-04 14:55:58 [INFO] Include file: /home/bart/restic-bak_Miras/test.include
2025-10-04 14:55:58 [INFO] Exclude file: /home/bart/restic-bak_Miras/exclude.patterns
2025-10-04 14:55:58 [INFO] Repository file: /home/bart/restic-bak_Miras/test.repo
2025-10-04 14:55:58 [INFO] Log file: /var/log/restic/test.log
2025-10-04 14:55:58 [INFO] Ignore certificates: false
```

## Retention Policies

### Default Policy

- **Daily**: Keep last 7 daily snapshots
- **Weekly**: Keep last 4 weekly snapshots
- **Monthly**: Keep last 12 monthly snapshots
- **Yearly**: Keep last 7 yearly snapshots

### Custom Policies

Configure in your `.repo` file:

```bash
# Conservative retention (keep more)
RESTIC_KEEP_DAILY=14
RESTIC_KEEP_WEEKLY=8
RESTIC_KEEP_MONTHLY=24
RESTIC_KEEP_YEARLY=10

# Aggressive cleanup (keep less)
RESTIC_KEEP_DAILY=3
RESTIC_KEEP_WEEKLY=2
RESTIC_KEEP_MONTHLY=6
RESTIC_KEEP_YEARLY=2
```

## Script Functions

### Core Functions

- `load_repo_config()`: Load repository configuration
- `init_repository()`: Initialize repository if needed
- `perform_backup()`: Execute backup with include/exclude patterns
- `cleanup_snapshots()`: Remove old snapshots based on retention policy
- `show_stats()`: Display backup statistics
- `cleanup_environment()`: Clean up environment variables

### Error Handling

- Script exits on critical errors
- Comprehensive error logging
- Environment cleanup on exit
- Detailed error messages with context

## Security

### Password Files

- Store repository passwords in separate files
- Use strong, unique passwords
- Set appropriate file permissions: `chmod 600 *.password`
- Never commit password files to version control

### Certificate Handling

For self-signed certificates, set in your `.repo` file:
```bash
RESTIC_IGNORE_CERT=true
```

**Warning**: Only use in trusted environments to avoid man-in-the-middle attacks.

## Troubleshooting

### Common Issues

1. **Line Endings**: Ensure files use Unix line endings (LF)
2. **Permissions**: Script needs execute permissions: `chmod +x run_restic_backup.sh`
3. **Log Directory**: Create log directory: `sudo mkdir -p /var/log/restic`
4. **Password Files**: Check file permissions and content

### Debug Mode

Run with verbose output:
```bash
bash -x ./run_restic_backup.sh
```

### Check Repository Status

```bash
# Test repository connection
restic --insecure-tls snapshots

# Check repository stats
restic --insecure-tls stats
```

## Requirements

- **Restic**: Backup tool
- **Bash**: Shell environment
- **Network Access**: For remote repositories
- **Disk Space**: For local repositories and logs

## Features

- ✅ **Multiple Repository Support**: Configure different backup targets
- ✅ **Configurable Retention**: Set custom retention policies per repository
- ✅ **Certificate Handling**: Support for self-signed certificates
- ✅ **Comprehensive Logging**: Detailed logging with timestamps
- ✅ **Environment Cleanup**: Automatic cleanup of environment variables
- ✅ **Flexible Include/Exclude**: File-based include and exclude patterns
- ✅ **Automated Cleanup**: Automatic removal of old snapshots
- ✅ **Error Handling**: Robust error handling and logging