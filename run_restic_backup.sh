#!/bin/bash

# Restic Backup Script
# This script performs automated backups using Restic with configuration from repo file (like test.repo)
# Logs all operations to /var/log/restic/[include-filename].log

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration - use environment variables with defaults
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/restic"
INCLUDE_FILE="${RESTIC_INCLUDE_FILE:-$SCRIPT_DIR/test.include}"
EXCLUDE_FILE="${RESTIC_EXCLUDE_FILE:-$SCRIPT_DIR/exclude.patterns}"
REPO_FILE="${RESTIC_REPO_FILE:-$SCRIPT_DIR/test.repo}"
IGNORE_CERT="${RESTIC_IGNORE_CERT:-false}"

# Generate log file name based on include file name
INCLUDE_BASENAME=$(basename "$INCLUDE_FILE" .include)
LOG_FILE="$LOG_DIR/${INCLUDE_BASENAME}.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    cleanup_environment
    exit 1
}

# Cleanup environment variables
cleanup_environment() {
    log "INFO" "Cleaning up environment variables..."
    unset RESTIC_REPOSITORY
    unset RESTIC_PASSWORD_FILE
    unset RESTIC_REST_USERNAME
    unset RESTIC_REST_PASSWORD
    unset RESTIC_READ_CONCURRENCY
    unset RESTIC_IGNORE_CERT
    unset RESTIC_KEEP_DAILY
    unset RESTIC_KEEP_WEEKLY
    unset RESTIC_KEEP_MONTHLY
    unset RESTIC_KEEP_YEARLY
    log "INFO" "Environment cleanup completed"
}

# Check if running as root for log directory creation
check_permissions() {
    if [[ ! -d "$LOG_DIR" ]]; then
        if [[ $EUID -eq 0 ]]; then
            log "INFO" "Creating log directory: $LOG_DIR"
            mkdir -p "$LOG_DIR"
            chmod 755 "$LOG_DIR"
        else
            log "WARNING" "Log directory $LOG_DIR does not exist and script is not running as root"
            log "WARNING" "Logging will be attempted but may fail"
        fi
    fi
}

# Validate required files
validate_files() {
    local missing_files=()
    
    if [[ ! -f "$REPO_FILE" ]]; then
        missing_files+=("$REPO_FILE")
    fi
    
    if [[ ! -f "$INCLUDE_FILE" ]]; then
        missing_files+=("$INCLUDE_FILE")
    fi
    
    if [[ ! -f "$EXCLUDE_FILE" ]]; then
        missing_files+=("$EXCLUDE_FILE")
    fi
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        error_exit "Missing required files: ${missing_files[*]}"
    fi
}


# Load repository configuration
load_repo_config() {
    log "INFO" "Loading repository configuration from $REPO_FILE"
    if [[ -f "$REPO_FILE" ]]; then
        # Change to script directory to ensure relative paths work
        cd "$SCRIPT_DIR"
        log "INFO" "Changed to script directory: $SCRIPT_DIR"
        
        # Source the repo file to load environment variables
        source "$REPO_FILE"
        
        # Explicitly export all RESTIC_ variables
        export RESTIC_REPOSITORY
        export RESTIC_PASSWORD_FILE
        export RESTIC_REST_USERNAME
        export RESTIC_REST_PASSWORD
        export RESTIC_READ_CONCURRENCY
        export RESTIC_IGNORE_CERT
        
        # Set retention policy defaults if not specified in repo file
        RESTIC_KEEP_DAILY="${RESTIC_KEEP_DAILY:-7}"
        RESTIC_KEEP_WEEKLY="${RESTIC_KEEP_WEEKLY:-4}"
        RESTIC_KEEP_MONTHLY="${RESTIC_KEEP_MONTHLY:-12}"
        RESTIC_KEEP_YEARLY="${RESTIC_KEEP_YEARLY:-7}"
        
        # Override IGNORE_CERT if set in repo file
        if [[ -n "${RESTIC_IGNORE_CERT:-}" ]]; then
            IGNORE_CERT="$RESTIC_IGNORE_CERT"
            log "INFO" "Certificate validation setting from repo file: $IGNORE_CERT"
        fi
        
        # Debug: Show loaded environment variables
        log "INFO" "Loaded RESTIC_REPOSITORY: ${RESTIC_REPOSITORY:-not set}"
        log "INFO" "Loaded RESTIC_PASSWORD_FILE: ${RESTIC_PASSWORD_FILE:-not set}"
        log "INFO" "Loaded RESTIC_REST_USERNAME: ${RESTIC_REST_USERNAME:-not set}"
        
        # Verify password file exists
        if [[ -n "${RESTIC_PASSWORD_FILE:-}" ]]; then
            if [[ -f "$RESTIC_PASSWORD_FILE" ]]; then
                log "INFO" "Password file exists: $RESTIC_PASSWORD_FILE"
            else
                log "WARNING" "Password file not found: $RESTIC_PASSWORD_FILE"
            fi
        fi
        
        log "INFO" "Repository configuration loaded successfully"
    else
        error_exit "Repository file $REPO_FILE not found"
    fi
}

# Initialize repository if needed
init_repository() {
    log "INFO" "Checking repository initialization..."
    
    local restic_cmd="restic"
    if [[ "$IGNORE_CERT" == "true" || "$IGNORE_CERT" == "1" ]]; then
        restic_cmd="$restic_cmd --insecure-tls"
        log "INFO" "Using --insecure-tls for certificate validation"
    fi
    
    log "INFO" "Testing repository connection with: $restic_cmd snapshots"
    if ! $restic_cmd snapshots &>/dev/null; then
        log "INFO" "Repository not initialized. Initializing..."
        log "INFO" "Running: $restic_cmd init"
        if $restic_cmd init; then
            log "INFO" "Repository initialized successfully"
        else
            log "ERROR" "Repository initialization failed. Check your repository URL and credentials."
            log "ERROR" "Repository URL: ${RESTIC_REPOSITORY:-not set}"
            log "ERROR" "Password file: ${RESTIC_PASSWORD_FILE:-not set}"
            error_exit "Failed to initialize repository"
        fi
    else
        log "INFO" "Repository already initialized"
    fi
}

# Perform backup
perform_backup() {
    log "INFO" "Starting backup process..."
    
    local backup_cmd="restic backup"
    
    # Add include file if it exists and has content
    if [[ -f "$INCLUDE_FILE" ]] && [[ -s "$INCLUDE_FILE" ]] && ! grep -q '^#' "$INCLUDE_FILE" || grep -v '^#' "$INCLUDE_FILE" | grep -q .; then
        backup_cmd="$backup_cmd --files-from $INCLUDE_FILE"
        log "INFO" "Using include file: $INCLUDE_FILE"
    else
        log "WARNING" "Include file is empty or contains only comments. Backup may not include expected files."
    fi
    
    # Add exclude file
    if [[ -f "$EXCLUDE_FILE" ]]; then
        backup_cmd="$backup_cmd --exclude-file=$EXCLUDE_FILE"
        log "INFO" "Using exclude file: $EXCLUDE_FILE"
    fi
    
    # Add additional options
    backup_cmd="$backup_cmd --verbose --one-file-system"
    
    # Add certificate validation option if requested
    if [[ "$IGNORE_CERT" == "true" || "$IGNORE_CERT" == "1" ]]; then
        backup_cmd="$backup_cmd --insecure-tls"
        log "INFO" "Ignoring invalid/self-signed certificates (--insecure-tls)"
    fi
    
    log "INFO" "Executing backup command: $backup_cmd"
    
    if $backup_cmd; then
        log "INFO" "Backup completed successfully"
    else
        error_exit "Backup failed"
    fi
}

# Cleanup old snapshots
cleanup_snapshots() {
    log "INFO" "Starting cleanup of old snapshots..."
    log "INFO" "Retention policy: daily=${RESTIC_KEEP_DAILY}, weekly=${RESTIC_KEEP_WEEKLY}, monthly=${RESTIC_KEEP_MONTHLY}, yearly=${RESTIC_KEEP_YEARLY}"
    
    local restic_cmd="restic"
    if [[ "$IGNORE_CERT" == "true" || "$IGNORE_CERT" == "1" ]]; then
        restic_cmd="$restic_cmd --insecure-tls"
    fi
    
    # Use configurable retention policy
    if $restic_cmd forget --keep-daily "$RESTIC_KEEP_DAILY" --keep-weekly "$RESTIC_KEEP_WEEKLY" --keep-monthly "$RESTIC_KEEP_MONTHLY" --keep-yearly "$RESTIC_KEEP_YEARLY" --prune; then
        log "INFO" "Cleanup completed successfully"
    else
        log "WARNING" "Cleanup failed or no snapshots to clean"
    fi
}

# Show backup statistics
show_stats() {
    log "INFO" "Backup statistics:"
    
    local restic_cmd="restic"
    if [[ "$IGNORE_CERT" == "true" || "$IGNORE_CERT" == "1" ]]; then
        restic_cmd="$restic_cmd --insecure-tls"
    fi
    
    $restic_cmd stats --mode raw-data | while read -r line; do
        log "INFO" "  $line"
    done
}

# Main execution
main() {
    log "INFO" "=== Restic Backup Script Started ==="
    log "INFO" "Script directory: $SCRIPT_DIR"
    log "INFO" "Include file: $INCLUDE_FILE"
    log "INFO" "Exclude file: $EXCLUDE_FILE"
    log "INFO" "Repository file: $REPO_FILE"
    log "INFO" "Log file: $LOG_FILE"
    log "INFO" "Ignore certificates: $IGNORE_CERT"
    
    # Check permissions and create log directory
    check_permissions
    
    # Validate required files
    validate_files
    
    # Load repository configuration
    load_repo_config
    
    # Initialize repository if needed
    init_repository
    
    # Perform backup
    perform_backup
    
    # Cleanup old snapshots
    cleanup_snapshots
    
    # Show statistics
    show_stats
    
    log "INFO" "=== Restic Backup Script Completed Successfully ==="
    
    # Cleanup environment variables
    cleanup_environment
}

# Run main function
main "$@"