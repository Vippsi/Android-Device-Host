#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="novnc-scrcpy.service"
BASE_DIR="/opt/device-host"
LOG_DIR="/var/log/device-host"
UNIT_PATH="/etc/systemd/system/${SERVICE_NAME}"

echo "== Device Host uninstall =="
echo
echo "This will:"
echo "  - stop + disable: ${SERVICE_NAME}"
echo "  - remove systemd unit: ${UNIT_PATH}"
echo "  - delete directory: ${BASE_DIR}"
echo "  - delete logs:      ${LOG_DIR}"
echo
echo "⚠️  This is destructive and cannot be undone."

# Require root
if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo)"
  exit 1
fi

echo
read -r -p "Type exactly: DELETE device-host  > " CONFIRM

if [[ "${CONFIRM}" != "DELETE device-host" ]]; then
  echo "Confirmation did not match. Aborting."
  exit 1
fi

echo
echo "Proceeding..."

# Stop/disable service if present
if systemctl list-unit-files | grep -q "^${SERVICE_NAME}"; then
  systemctl stop "${SERVICE_NAME}" || true
  systemctl disable "${SERVICE_NAME}" || true
fi

# Remove unit file if present
if [[ -f "${UNIT_PATH}" ]]; then
  rm -f "${UNIT_PATH}"
fi

# Reload systemd
systemctl daemon-reload
systemctl reset-failed || true

# Remove installed directories
rm -rf "${BASE_DIR}"
rm -rf "${LOG_DIR}"

echo "✅ Uninstalled."
