#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_DIR="/home/girish/smart-city-command-centre"
ADMIN_GROUP="citycentre_admin"
OPS_GROUP="city_ops"
ADMIN_USER="cityadmin"
OPS_USER="opstest"

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: Run with sudo."
    exit 1
fi

if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "ERROR: Project directory does not exist."
    exit 1
fi

echo "=== Smart City Command Centre: Module 2 ==="

echo
echo "=== 1. Create missing administrator group ==="

if getent group "$ADMIN_GROUP" >/dev/null; then
    echo "$ADMIN_GROUP already exists."
else
    groupadd "$ADMIN_GROUP"
    echo "Created $ADMIN_GROUP."
fi

echo
echo "=== 2. Verify operator group ==="

if getent group "$OPS_GROUP" >/dev/null; then
    echo "$OPS_GROUP exists."
else
    echo "ERROR: Expected operator group is missing."
    exit 1
fi

echo
echo "=== 3. Create administrator account if missing ==="

if id "$ADMIN_USER" >/dev/null 2>&1; then
    echo "$ADMIN_USER already exists; preserving its account settings."
else
    adduser --disabled-password --gecos "" "$ADMIN_USER"
    echo "Created $ADMIN_USER."
    echo "Set its password interactively using: sudo passwd $ADMIN_USER"
fi

echo
echo "=== 4. Configure administrator group membership ==="

if id -nG "$ADMIN_USER" | tr ' ' '\n' | grep -Fxq "$ADMIN_GROUP"; then
    echo "$ADMIN_USER is already a member of $ADMIN_GROUP."
else
    usermod -aG "$ADMIN_GROUP" "$ADMIN_USER"
    echo "Added $ADMIN_USER to $ADMIN_GROUP."
fi

echo
echo "=== 5. Preserve and verify operator account ==="

if id "$OPS_USER" >/dev/null 2>&1; then
    id "$OPS_USER"
    echo "Operator account preserved."
else
    echo "ERROR: $OPS_USER does not exist; no operator account created."
    exit 1
fi

echo
echo "=== 6. Final verification ==="

id "$ADMIN_USER"
id "$OPS_USER"
getent group "$ADMIN_GROUP"
getent group "$OPS_GROUP"

echo
echo "Module 2 administrator setup completed."
echo "Project directory permissions have not been changed."
