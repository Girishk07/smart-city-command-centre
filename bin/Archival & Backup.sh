#!/usr/bin/env bash

set -Eeuo pipefail

# ==========================================================
# PROJECT: SMART CITY COMMAND CENTRE
# MODULE 3: ARCHIVAL AND BACKUP
# ==========================================================

PROJECT="/home/girish/smart-city-command-centre"
LOG_DIR="$PROJECT/logs"
ARCHIVE_DIR="$PROJECT/archive"
BACKUP_DIR="$PROJECT/backup"
DATA_DIR="$PROJECT/data"
CONFIG_DIR="$PROJECT/config"

RETENTION_DAYS=30
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# ==========================================================
# 1. VALIDATE ENVIRONMENT
# ==========================================================

echo
echo "=========================================================="
echo "       SMART CITY COMMAND CENTRE"
echo "       ARCHIVAL AND BACKUP SYSTEM"
echo "=========================================================="

if [[ ! -d "$PROJECT" ]]; then
    echo "ERROR: Project directory does not exist."
    exit 1
fi

for directory in "$LOG_DIR" "$ARCHIVE_DIR" "$BACKUP_DIR" \
                 "$DATA_DIR" "$CONFIG_DIR"; do
    if [[ ! -d "$directory" ]]; then
        echo "ERROR: Required directory missing: $directory"
        exit 1
    fi
done

echo "PASS: Required directories verified."

# ==========================================================
# 2. ARCHIVE DEPARTMENT LOGS
# ==========================================================

echo
echo "[1/3] ARCHIVING DEPARTMENT LOGS"

ARCHIVE_FILE="$ARCHIVE_DIR/department_logs_${TIMESTAMP}.tar.gz"

LOG_FILES=(
    traffic.log
    water.log
    power.log
    waste.log
    safety.log
    healthcare.log
    administrator_alerts.log
)

AVAILABLE_LOGS=()

for filename in "${LOG_FILES[@]}"; do
    if [[ -f "$LOG_DIR/$filename" ]]; then
        AVAILABLE_LOGS+=("$filename")
    fi
done

if (( ${#AVAILABLE_LOGS[@]} > 0 )); then
    tar -czf "$ARCHIVE_FILE" \
        -C "$LOG_DIR" "${AVAILABLE_LOGS[@]}"

    if tar -tzf "$ARCHIVE_FILE" >/dev/null; then
        echo "PASS: Log archive created and verified."
        echo "Archive: $ARCHIVE_FILE"
    else
        echo "ERROR: Archive verification failed."
        exit 1
    fi
else
    echo "WARNING: No department logs found to archive."
fi

# ==========================================================
# 3. CREATE COMPRESSED PROJECT BACKUP
# ==========================================================

echo
echo "[2/3] CREATING PROJECT BACKUP"

BACKUP_FILE="$BACKUP_DIR/command_centre_backup_${TIMESTAMP}.tar.gz"

tar -czf "$BACKUP_FILE" \
    --exclude='smart-city-command-centre/archive/*' \
    --exclude='smart-city-command-centre/backup/*' \
    -C "$(dirname "$PROJECT")" \
    "$(basename "$PROJECT")"

if tar -tzf "$BACKUP_FILE" >/dev/null; then
    echo "PASS: Project backup created and verified."
    echo "Backup: $BACKUP_FILE"
else
    echo "ERROR: Backup verification failed."
    exit 1
fi

# ==========================================================
# 4. DISPLAY RESULTS
# ==========================================================

echo
echo "[3/3] DISPLAYING ARCHIVAL AND BACKUP RESULTS"

echo
echo "----- Latest Archive -----"
if [[ -f "$ARCHIVE_FILE" ]]; then
    ls -lh "$ARCHIVE_FILE"
fi

echo
echo "----- Latest Backup -----"
ls -lh "$BACKUP_FILE"

echo
echo "----- Backup Contents Preview -----"
tar -tzf "$BACKUP_FILE" | head -n 15

echo
echo "=========================================================="
echo " ARCHIVAL AND BACKUP COMPLETED"
echo "=========================================================="

echo
echo "Retention policy: ${RETENTION_DAYS} days"

echo
echo "===== Applying 30-Day Archive Retention ====="

find "$ARCHIVE_DIR" -maxdepth 1 -type f \
    -name 'department_logs_*.tar.gz' \
    -mmin +43200 -print -delete
find "$BACKUP_DIR" -maxdepth 1 -type f \
    -name 'command_centre_backup_*.tar.gz' \
    -mmin +43200 -print -delete

echo "PASS: Retention cleanup completed."
echo "Only matching archive and backup files older than 30 days are targeted."
echo "Original department logs are preserved."
