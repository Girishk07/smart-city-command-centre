#!/usr/bin/env bash

set -u

PROJECT="$HOME/smart-city-command-centre"
TEST_DIR="$PROJECT/tests"
REPORT_DIR="$PROJECT/reports"
LOGROTATE="/etc/logrotate.d/smart-city-command-centre"
MONITOR="$PROJECT/bin/Logging & Monitoring.sh"
BACKUP_SCRIPT="$PROJECT/bin/Archival & Backup.sh"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$REPORT_DIR"

REPORT="$REPORT_DIR/module4_test_report_${TIMESTAMP}.txt"
RESULTS="$REPORT_DIR/module4_test_results.log"

PASS=0
FAIL=0
WARN=0

exec > >(tee "$REPORT" "$RESULTS") 2>&1

pass() {
    echo "[PASS] $1"
    PASS=$((PASS + 1))
}

fail() {
    echo "[FAIL] $1"
    FAIL=$((FAIL + 1))
}

warn() {
    echo "[WARN] $1"
    WARN=$((WARN + 1))
}

echo "=================================================="
echo " SMART CITY COMMAND CENTRE"
echo " MODULE 4: REPORTS, TESTING & SECURITY"
echo "=================================================="
echo "Date: $(date)"
echo "Project: $PROJECT"

# 1. Project structure
echo
echo "===== 1. PROJECT STRUCTURE ====="

for path in \
    "$PROJECT/bin" \
    "$PROJECT/config" \
    "$PROJECT/logs" \
    "$PROJECT/data" \
    "$PROJECT/archive" \
    "$PROJECT/backup" \
    "$PROJECT/reports" \
    "$PROJECT/tests"
do
    if [ -d "$path" ]; then
        pass "Directory exists: ${path##*/}"
    else
        fail "Missing directory: $path"
    fi
done

# 2. Shell script syntax
echo
echo "===== 2. SCRIPT SYNTAX ====="

for script in "$MONITOR" "$BACKUP_SCRIPT" \
              "$PROJECT/bin/configure_access.sh" \
              "$PROJECT/bin/setup_users_groups.sh"
do
    if [ -f "$script" ]; then
        if bash -n "$script"; then
            pass "Syntax valid: $(basename "$script")"
        else
            fail "Syntax error: $(basename "$script")"
        fi
    else
        warn "Script not found: $(basename "$script")"
    fi
done

# 3. Configuration
echo
echo "===== 3. CONFIGURATION ====="

CONFIG="$PROJECT/config/command_centre.conf"

if [ -s "$CONFIG" ]; then
    pass "Main configuration exists and is not empty"
else
    fail "Main configuration missing or empty"
fi

if [ -f "$PROJECT/config/smartcity.cron" ]; then
    pass "Cron configuration file exists"
else
    fail "Cron configuration file missing"
fi

# 4. Department logs
echo
echo "===== 4. DEPARTMENT LOGS ====="

for department in traffic water power waste safety healthcare; do
    file="$PROJECT/logs/$department.log"

    if [ -s "$file" ]; then
        pass "Department log exists and contains data: $department"
    else
        fail "Department log missing or empty: $department"
    fi
done

if [ -f "$PROJECT/logs/administrator_alerts.log" ]; then
    pass "Administrator alerts log exists"
else
    warn "Administrator alerts log does not exist"
fi

# 5. Monitoring history
echo
echo "===== 5. MONITORING DATA ====="

for file in \
    "$PROJECT/data/collected_logs.log" \
    "$PROJECT/data/storage_history.csv" \
    "$PROJECT/data/performance_history.csv"
do
    if [ -s "$file" ]; then
        pass "Monitoring data exists: $(basename "$file")"
    else
        fail "Monitoring data missing or empty: $(basename "$file")"
    fi
done

# 6. Archive and backup integrity
echo
echo "===== 6. ARCHIVE AND BACKUP INTEGRITY ====="

ARCHIVE_COUNT=0
for file in "$PROJECT"/archive/department_logs_*.tar.gz; do
    [ -f "$file" ] || continue
    ARCHIVE_COUNT=$((ARCHIVE_COUNT + 1))

    if tar -tzf "$file" >/dev/null 2>&1; then
        pass "Archive integrity: $(basename "$file")"
    else
        fail "Corrupt archive: $(basename "$file")"
    fi
done

if [ "$ARCHIVE_COUNT" -eq 0 ]; then
    warn "No department archives available for testing"
fi

BACKUP_COUNT=0
LATEST_BACKUP=""

for file in "$PROJECT"/backup/command_centre_backup_*.tar.gz; do
    [ -f "$file" ] || continue
    BACKUP_COUNT=$((BACKUP_COUNT + 1))

    if tar -tzf "$file" >/dev/null 2>&1; then
        pass "Backup integrity: $(basename "$file")"
        if [ -z "$LATEST_BACKUP" ] || [ "$file" -nt "$LATEST_BACKUP" ]; then
            LATEST_BACKUP="$file"
        fi
    else
        fail "Corrupt backup: $(basename "$file")"
    fi
done

if [ "$BACKUP_COUNT" -eq 0 ]; then
    warn "No project backups available for testing"
fi

# 7. Permissions and security
echo
echo "===== 7. PERMISSIONS AND SECURITY ====="

if [ -r "$PROJECT/config/command_centre.conf" ]; then
    pass "Current user can read project configuration"
else
    fail "Current user cannot read project configuration"
fi

if [ -r "$PROJECT/logs/traffic.log" ]; then
    pass "Current user can read department logs"
else
    fail "Current user cannot read department logs"
fi

if [ -w "$PROJECT/reports" ]; then
    pass "Current user can write reports"
else
    fail "Current user cannot write reports"
fi

for script in "$MONITOR" "$BACKUP_SCRIPT"; do
    if [ -f "$script" ]; then
        MODE=$(stat -c '%a' "$script")
        if (( (8#$MODE & 0002) == 0 )); then
            pass "Script is not world-writable: $(basename "$script")"
        else
            fail "Script is world-writable: $(basename "$script")"
        fi
    fi
done

if command -v getfacl >/dev/null 2>&1; then
    if getfacl -cp "$PROJECT" >/dev/null 2>&1; then
        pass "Project access-control list can be inspected"
    else
        warn "Could not inspect project access-control list"
    fi
else
    warn "getfacl is unavailable; ACL details were not checked"
fi

# 8. Logrotate
echo
echo "===== 8. LOG ROTATION ====="

if [ -f "$LOGROTATE" ]; then
    if sudo logrotate --debug "$LOGROTATE" >/dev/null 2>&1; then
        pass "Logrotate debug validation passed"
    else
        fail "Logrotate debug validation failed"
    fi
else
    fail "Logrotate configuration is missing"
fi

# 9. Cron
echo
echo "===== 9. SCHEDULED AUTOMATION ====="

CURRENT_CRON=$(crontab -l 2>/dev/null || true)

if printf '%s\n' "$CURRENT_CRON" |
   grep -Fq '/bin/Logging\ \&\ Monitoring.sh'; then
    pass "Monitoring Cron job is installed"
else
    fail "Monitoring Cron job is missing"
fi

if printf '%s\n' "$CURRENT_CRON" |
   grep -Fq '/bin/Archival\ \&\ Backup.sh'; then
    pass "Backup Cron job is installed"
else
    fail "Backup Cron job is missing"
fi

if systemctl is-active --quiet cron; then
    pass "Cron service is active"
else
    fail "Cron service is inactive"
fi

# 10. Existing monitoring execution
echo
echo "===== 10. MONITORING EXECUTION ====="

if [ -s "$PROJECT/logs/cron_execution.log" ]; then
    pass "Cron execution log exists and is not empty"

    if grep -q 'SYSTEM USAGE' "$PROJECT/logs/cron_execution.log"; then
        pass "Monitoring summary found in Cron execution log"
    else
        warn "Monitoring summary not found in Cron execution log"
    fi
else
    warn "Cron execution log is missing or empty"
fi

# 11. Retention policy configuration
echo
echo "===== 11. RETENTION POLICY ====="

if grep -Fq -- '-mmin +43200 -print -delete' "$BACKUP_SCRIPT"; then
    pass "30-day archive/backup retention command is present"
else
    fail "Expected 30-day retention command is missing"
fi

# Final summary
echo
echo "=================================================="
echo " MODULE 4 TEST REPORT SUMMARY"
echo "=================================================="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo "WARN: $WARN"

if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
    echo "RESULT: ALL TESTS PASSED"
elif [ "$FAIL" -eq 0 ]; then
    echo "RESULT: TESTS PASSED WITH WARNINGS"
else
    echo "RESULT: FIXES REQUIRED"
fi

echo
echo "Report: $REPORT"
echo "Results log: $RESULTS"
echo
echo "Testing completed. No original logs, archives, or backups were deleted."
