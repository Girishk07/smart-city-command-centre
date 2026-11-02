#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT="/home/girish/smart-city-command-centre"
ADMIN="cityadmin"
OPS="opstest"

echo "========================================"
echo " Smart City Command Centre"
echo " Module 2: Access Control"
echo "========================================"

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: Run with sudo."
    exit 1
fi

# Verify accounts and directories.
for account in girish "$ADMIN" "$OPS"; do
    id "$account" >/dev/null 2>&1 || {
        echo "ERROR: Missing account: $account"
        exit 1
    }
done

for directory in bin config logs data archive reports backup tests docs; do
    [[ -d "$PROJECT/$directory" ]] || {
        echo "ERROR: Missing directory: $PROJECT/$directory"
        exit 1
    }
done

# Verify ACL utilities are installed.
command -v setfacl >/dev/null 2>&1 || {
    echo "ERROR: setfacl is unavailable. Install the acl package first."
    exit 1
}

command -v getfacl >/dev/null 2>&1 || {
    echo "ERROR: getfacl is unavailable. Install the acl package first."
    exit 1
}

echo
echo "=== 1. Allow administrator to traverse developer home ==="

setfacl -m "u:${ADMIN}:--x" /home/girish

echo "Administrator home-directory traversal configured."

echo
echo "=== 2. Configure administrator access ==="

# Give cityadmin access to the project root.
setfacl -m "u:${ADMIN}:rwx" "$PROJECT"

# Give cityadmin access to existing project subdirectories.
for directory in bin config logs data archive reports backup tests docs; do
    setfacl -m "u:${ADMIN}:rwx" "$PROJECT/$directory"
done

echo "Administrator access configured."

echo
echo "=== 3. Configure operator log access ==="

# Allow read/traverse access to existing log directories.
find "$PROJECT/logs" -type d \
    -exec setfacl -m "u:${OPS}:r-x" {} \;

# Allow read-only access to existing log files.
find "$PROJECT/logs" -type f \
    -exec setfacl -m "u:${OPS}:r--" {} \;

echo "Operator access configured for existing logs."

echo
echo "=== 4. Verify configuration ==="

printf '\n--- Developer home ---\n'
getfacl -p /home/girish

printf '\n--- Project root ---\n'
getfacl -p "$PROJECT"

printf '\n--- Logs directory ---\n'
getfacl -p "$PROJECT/logs"

printf '\n--- Account memberships ---\n'
id "$ADMIN"
id "$OPS"

echo
echo "Access configuration completed."
echo "Project ownership has not been changed."
