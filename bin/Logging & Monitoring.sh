#!/usr/bin/env bash

set -Eeuo pipefail

# ==========================================================
# PROJECT: SMART CITY COMMAND CENTRE
# MODULE: LOGGING AND MONITORING
# DESCRIPTION:
#   1. Configuration management
#   2. Department log generation
#   3. Log collection
#   4. Disk and inode monitoring
#   5. CPU and memory monitoring
#   6. Monitoring history
#   7. Administrator alerts
#   8. Alert testing
# ==========================================================


# ==========================================================
# 1. PROJECT CONFIGURATION
# ==========================================================

PROJECT="/home/girish/smart-city-command-centre"

CONFIG="$PROJECT/config/command_centre.conf"
LOGS="$PROJECT/logs"
DATA="$PROJECT/data"
ARCHIVE="$PROJECT/archive"
REPORTS="$PROJECT/reports"
BACKUP="$PROJECT/backup"

ALERTS="$LOGS/administrator_alerts.log"
COLLECTED="$DATA/collected_logs.log"

STORAGE_HISTORY="$DATA/storage_history.csv"
PERFORMANCE_HISTORY="$DATA/performance_history.csv"

DEPARTMENTS=(traffic water power waste safety healthcare)


# ==========================================================
# 2. VALIDATE PROJECT ENVIRONMENT
# ==========================================================

echo
echo "=========================================================="
echo "          SMART CITY COMMAND CENTRE"
echo "          LOGGING AND MONITORING SYSTEM"
echo "=========================================================="

if [[ ! -d "$PROJECT" ]]; then
    echo "ERROR: Project directory does not exist."
    exit 1
fi

for directory in config logs data archive reports backup bin tests docs; do
    if [[ ! -d "$PROJECT/$directory" ]]; then
        mkdir -p "$PROJECT/$directory"
    fi
done

echo "PASS: Project directories verified."


# ==========================================================
# 3. CREATE CONFIGURATION IF MISSING
# ==========================================================

if [[ ! -f "$CONFIG" ]]; then
    cat > "$CONFIG" <<'EOF'
# Smart City Command Centre Configuration

PROJECT_DIR="/home/girish/smart-city-command-centre"

LOG_DIR="${PROJECT_DIR}/logs"
DATA_DIR="${PROJECT_DIR}/data"
ARCHIVE_DIR="${PROJECT_DIR}/archive"
REPORT_DIR="${PROJECT_DIR}/reports"
BACKUP_DIR="${PROJECT_DIR}/backup"

DISK_WARNING=80
DISK_CRITICAL=90

INODE_WARNING=80
INODE_CRITICAL=90

CPU_WARNING=80
CPU_CRITICAL=90

MEMORY_WARNING=80
MEMORY_CRITICAL=90

LOG_RETENTION_DAYS=30

COLLECTION_INTERVAL=5
MONITORING_INTERVAL=5
REPORT_INTERVAL=15

ARCHIVE_TIME="01:30"
BACKUP_TIME="02:00"

DEPARTMENTS="traffic water power waste safety healthcare"
EOF

    echo "PASS: Configuration file created."
else
    echo "PASS: Existing configuration preserved."
fi


# ==========================================================
# 4. LOAD MONITORING THRESHOLDS
# ==========================================================

DISK_WARNING=80
DISK_CRITICAL=90

INODE_WARNING=80
INODE_CRITICAL=90

CPU_WARNING=80
CPU_CRITICAL=90

MEMORY_WARNING=80
MEMORY_CRITICAL=90

# Load configuration variables.
# shellcheck disable=SC1090
source "$CONFIG"

# Ensure the department list is an array.
DEPARTMENTS=(traffic water power waste safety healthcare)

echo "PASS: Monitoring thresholds loaded."


# ==========================================================
# 5. PREPARE LOG AND HISTORY FILES
# ==========================================================

for department in "${DEPARTMENTS[@]}"; do
    touch "$LOGS/${department}.log"
done

touch "$ALERTS"
touch "$COLLECTED"

if [[ ! -s "$STORAGE_HISTORY" ]]; then
    printf 'timestamp,disk_percent,inode_percent\n' \
        > "$STORAGE_HISTORY"
fi

if [[ ! -s "$PERFORMANCE_HISTORY" ]]; then
    printf 'timestamp,cpu_percent,memory_percent\n' \
        > "$PERFORMANCE_HISTORY"
fi

echo "PASS: Department logs and history files prepared."


# ==========================================================
# 6. DEFINE ALERT FUNCTION
# ==========================================================

check_threshold() {
    local label="$1"
    local value="$2"
    local warning="$3"
    local critical="$4"
    local timestamp="$5"

    if (( value >= critical )); then
        printf '[%s] CRITICAL: %s usage is %s%%\n' \
            "$timestamp" "$label" "$value" \
            | tee -a "$ALERTS"

    elif (( value >= warning )); then
        printf '[%s] WARNING: %s usage is %s%%\n' \
            "$timestamp" "$label" "$value" \
            | tee -a "$ALERTS"

    else
        printf 'OK: %s usage is %s%%\n' "$label" "$value"
    fi
}


# ==========================================================
# 7. GENERATE DEPARTMENT LOGS
# ==========================================================

echo
echo "[1/6] GENERATING DEPARTMENT LOGS"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

declare -A SAMPLE_MESSAGES=(
    [traffic]="Traffic signal status checked"
    [water]="Water supply status checked"
    [power]="Power grid status checked"
    [waste]="Waste collection status checked"
    [safety]="Public safety status checked"
    [healthcare]="Healthcare service status checked"
)

for department in "${DEPARTMENTS[@]}"; do
    printf '[%s] [%s] INFO: %s\n' \
        "$TIMESTAMP" \
        "${department^^}" \
        "${SAMPLE_MESSAGES[$department]-}" \
        >> "$LOGS/${department}.log"

    echo "Generated: ${department}.log"
done

echo "PASS: Logs generated for all six departments."


# ==========================================================
# 8. COLLECT DEPARTMENT LOGS
# ==========================================================

echo
echo "[2/6] COLLECTING DEPARTMENT LOGS"

{
    echo
    echo "=========================================================="
    echo "Log collection timestamp: $TIMESTAMP"
    echo "=========================================================="

    for department in "${DEPARTMENTS[@]}"; do
        echo
        echo "Department: ${department^^}"

        if [[ -s "$LOGS/${department}.log" ]]; then
            tail -n 5 "$LOGS/${department}.log"
        else
            echo "WARNING: No log entries available."
        fi
    done

} >> "$COLLECTED"

echo "PASS: Department logs collected."


# ==========================================================
# 9. MONITOR DISK AND INODE USAGE
# ==========================================================

echo
echo "[3/6] MONITORING DISK AND INODE USAGE"

DISK_PERCENT=$(
    df -P "$PROJECT" |
    awk 'NR==2 {gsub(/%/, "", $5); print $5}'
)

INODE_PERCENT=$(
    df -Pi "$PROJECT" |
    awk 'NR==2 {gsub(/%/, "", $5); print $5}'
)

if [[ ! "$DISK_PERCENT" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Unable to determine disk usage."
    exit 1
fi

if [[ ! "$INODE_PERCENT" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Unable to determine inode usage."
    exit 1
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

printf '%s,%s,%s\n' \
    "$TIMESTAMP" "$DISK_PERCENT" "$INODE_PERCENT" \
    >> "$STORAGE_HISTORY"

check_threshold \
    "Disk" \
    "$DISK_PERCENT" \
    "$DISK_WARNING" \
    "$DISK_CRITICAL" \
    "$TIMESTAMP"

check_threshold \
    "Inode" \
    "$INODE_PERCENT" \
    "$INODE_WARNING" \
    "$INODE_CRITICAL" \
    "$TIMESTAMP"

echo "PASS: Disk and inode monitoring completed."


# ==========================================================
# 10. MONITOR CPU USAGE
# ==========================================================

echo
echo "[4/6] MONITORING CPU USAGE"

read_cpu() {
    awk '
        /^cpu / {
            idle = $5 + $6
            total = 0

            for (i = 2; i <= NF; i++) {
                total += $i
            }

            print total, idle
        }
    ' /proc/stat
}

read -r TOTAL1 IDLE1 < <(read_cpu)

sleep 1

read -r TOTAL2 IDLE2 < <(read_cpu)

TOTAL_DIFF=$((TOTAL2 - TOTAL1))
IDLE_DIFF=$((IDLE2 - IDLE1))

TOTAL_DIFF=$((TOTAL2 - TOTAL1))
IDLE_DIFF=$((IDLE2 - IDLE1))

if (( TOTAL_DIFF > 0 )); then
    CPU_PERCENT=$(( (TOTAL_DIFF - IDLE_DIFF) * 100 / TOTAL_DIFF ))
else
    CPU_PERCENT=0
fi

if (( CPU_PERCENT < 0 || CPU_PERCENT > 100 )); then
    echo "ERROR: Invalid CPU measurement."
    exit 1
fi
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

check_threshold \
    "CPU" \
    "$CPU_PERCENT" \
    "$CPU_WARNING" \
    "$CPU_CRITICAL" \
    "$TIMESTAMP"

echo "PASS: CPU monitoring completed."


# ==========================================================
# 11. MONITOR MEMORY USAGE
# ==========================================================

echo
echo "[5/6] MONITORING MEMORY USAGE"

MEMORY_PERCENT=$(
    free | awk '
        /^Mem:/ {
            if ($2 > 0) {
                printf "%.0f", (($2 - $7) / $2) * 100
            } else {
                print 0
            }
        }
    '
)

if [[ ! "$MEMORY_PERCENT" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Unable to determine memory usage."
    exit 1
fi

if (( MEMORY_PERCENT > 100 )); then
    echo "ERROR: Invalid memory measurement."
    exit 1
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

check_threshold \
    "Memory" \
    "$MEMORY_PERCENT" \
    "$MEMORY_WARNING" \
    "$MEMORY_CRITICAL" \
    "$TIMESTAMP"

printf '%s,%s,%s\n' \
    "$TIMESTAMP" "$CPU_PERCENT" "$MEMORY_PERCENT" \
    >> "$PERFORMANCE_HISTORY"

echo "PASS: CPU and memory history recorded."


# ==========================================================
# 12. OPTIONAL SIMULATED ALERT TEST
# ==========================================================

if [[ "${TEST_ALERTS:-0}" == "1" ]]; then

    echo
    echo "=========================================================="
    echo "SIMULATED ALERT TEST"
    echo "=========================================================="

    TEST_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    printf '[%s] WARNING: TEST - Simulated disk threshold alert\n' \
        "$TEST_TIMESTAMP" | tee -a "$ALERTS"

    printf '[%s] CRITICAL: TEST - Simulated CPU threshold alert\n' \
        "$TEST_TIMESTAMP" | tee -a "$ALERTS"

    echo "PASS: Simulated test alerts recorded."
    echo "NOTE: These are test entries, not actual system alerts."

fi


# ==========================================================
# 13. DISPLAY MONITORING SUMMARY
# ==========================================================

echo
echo "[6/6] DISPLAYING MONITORING SUMMARY"

echo
echo "---------------- SYSTEM USAGE ----------------"

printf 'Disk usage:   %s%%\n' "$DISK_PERCENT"
printf 'Inode usage:  %s%%\n' "$INODE_PERCENT"
printf 'CPU usage:    %s%%\n' "$CPU_PERCENT"
printf 'Memory usage: %s%%\n' "$MEMORY_PERCENT"

echo
echo "---------------- DEPARTMENT LOGS ----------------"

for department in "${DEPARTMENTS[@]}"; do
    printf '  %-12s %s\n' \
        "$department" "$LOGS/${department}.log"
done

echo
echo "---------------- OUTPUT FILES ----------------"

printf 'Configuration:        %s\n' "$CONFIG"
printf 'Collected logs:       %s\n' "$COLLECTED"
printf 'Storage history:      %s\n' "$STORAGE_HISTORY"
printf 'Performance history:  %s\n' "$PERFORMANCE_HISTORY"
printf 'Administrator alerts: %s\n' "$ALERTS"

echo
echo "=========================================================="
echo " LOGGING AND MONITORING EXECUTION COMPLETED"
echo "=========================================================="
