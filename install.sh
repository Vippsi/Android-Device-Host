#!/usr/bin/env bash
set -euo pipefail

echo "== Device Host install =="

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo)"
  exit 1
fi

# -----------------------------
# Defaults / args
# -----------------------------
DEFAULT_USER="${SUDO_USER:-$(logname 2>/dev/null || echo ubuntu)}"
USER_NAME="$DEFAULT_USER"
CREATE_USER="true"

BASE_DIR="/opt/device-host"
LOG_DIR="/var/log/device-host"

usage() {
  cat <<EOF
Usage: sudo ./install.sh [--user USERNAME] [--no-create-user]

Options:
  --user USERNAME        Run services as this user (default: $DEFAULT_USER)
  --no-create-user       Fail if user does not exist (do not auto-create)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      USER_NAME="${2:-}"
      if [[ -z "$USER_NAME" ]]; then
        echo "Missing value for --user"
        usage
        exit 1
      fi
      shift 2
      ;;
    --no-create-user)
      CREATE_USER="false"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1"
      usage
      exit 1
      ;;
  esac
done

echo "Using user: $USER_NAME"
echo "Install dir: $BASE_DIR"
echo "Log dir:     $LOG_DIR"

# -----------------------------
# Ensure user exists (optional)
# -----------------------------
if ! id "$USER_NAME" >/dev/null 2>&1; then
  if [[ "$CREATE_USER" == "true" ]]; then
    echo "User '$USER_NAME' does not exist — creating..."
    adduser --disabled-password --gecos "" "$USER_NAME"
  else
    echo "User '$USER_NAME' does not exist. Re-run without --no-create-user or choose an existing user."
    exit 1
  fi
fi

# -----------------------------
# Install packages (minimal set)
# -----------------------------
apt update
apt install -y \
  adb \
  scrcpy \
  xvfb \
  openbox \
  x11vnc \
  novnc \
  websockify

# -----------------------------
# Create directories + permissions
# -----------------------------
mkdir -p "$BASE_DIR" "$BASE_DIR/scripts" "$BASE_DIR/config" "$LOG_DIR"
chown -R "$USER_NAME:$USER_NAME" "$BASE_DIR" "$LOG_DIR"

# Helpful group for USB device access on many distros
if getent group plugdev >/dev/null 2>&1; then
  usermod -aG plugdev "$USER_NAME" || true
fi

# -----------------------------
# Copy files from repo into /opt
# -----------------------------
# scripts
cp -a ./scripts/. "$BASE_DIR/scripts/"
chmod +x "$BASE_DIR/scripts/"*.sh

# config (optional)
if [[ -f ./config/device-host.env ]]; then
  cp -a ./config/device-host.env "$BASE_DIR/config/device-host.env"
  chown "$USER_NAME:$USER_NAME" "$BASE_DIR/config/device-host.env"
fi

# -----------------------------
# Install systemd service with templating
# -----------------------------
# Replace __USER__ and __BASE_DIR__ placeholders
sed -e "s|__USER__|$USER_NAME|g" \
    -e "s|__BASE_DIR__|$BASE_DIR|g" \
    ./systemd/novnc-scrcpy.service \
  > /etc/systemd/system/novnc-scrcpy.service

systemctl daemon-reload
systemctl enable --now novnc-scrcpy.service

echo
echo "✅ Installed and started: novnc-scrcpy.service"
echo "   noVNC: http://<host-ip>:6080/vnc.html"
echo
echo "Useful commands:"
echo "  systemctl status novnc-scrcpy.service --no-pager"
echo "  journalctl -u novnc-scrcpy.service -f"
