#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Resolve repo root relative to this script location
# ------------------------------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

# ------------------------------------------------------------
# Load environment config (repo-root/config/device-host.env)
# ------------------------------------------------------------
ENV_FILE="${ENV_FILE:-$REPO_DIR/config/device-host.env}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

# ------------------------------------------------------------
# Config (env overrides; defaults if unset)
# ------------------------------------------------------------
DISPLAY_NUM="${DISPLAY_NUM:-:99}"
SCREEN="${SCREEN:-380x720x24}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
VNC_PORT="${VNC_PORT:-5900}"
LOG_DIR="${LOG_DIR:-/var/log/device-host}"

# ------------------------------------------------------------
# Setup
# ------------------------------------------------------------
mkdir -p "$LOG_DIR"

log() {
  echo "[$(date +%H:%M:%S)] $*"
}

export DISPLAY="$DISPLAY_NUM"

# ------------------------------------------------------------
# Start Xvfb
# ------------------------------------------------------------
log "Starting Xvfb on DISPLAY=$DISPLAY (screen=$SCREEN)"
Xvfb "$DISPLAY" -screen 0 "$SCREEN" -nolisten tcp -ac \
  >"$LOG_DIR/xvfb.log" 2>&1 &
sleep 1

# ------------------------------------------------------------
# Start lightweight window manager
# ------------------------------------------------------------
log "Starting openbox"
openbox >"$LOG_DIR/openbox.log" 2>&1 &
sleep 1

# ------------------------------------------------------------
# Verify Android device via ADB
# ------------------------------------------------------------
log "Checking ADB"
adb start-server >/dev/null 2>&1 || true
adb devices

if ! adb devices | awk 'NR>1 && $2=="device"{found=1} END{exit !found}'; then
  log "❌ No authorized Android device found"
  exit 1
fi

# ------------------------------------------------------------
# Start scrcpy
# ------------------------------------------------------------
log "Starting scrcpy"
scrcpy --fullscreen --stay-awake --turn-screen-off \
  >"$LOG_DIR/scrcpy.log" 2>&1 &
sleep 2

# ------------------------------------------------------------
# Start x11vnc (local only)
# ------------------------------------------------------------
log "Starting x11vnc on localhost:$VNC_PORT"
x11vnc -display "$DISPLAY" -forever -shared -nopw \
  -localhost -rfbport "$VNC_PORT" \
  >"$LOG_DIR/x11vnc.log" 2>&1 &
sleep 1

# ------------------------------------------------------------
# Start noVNC (web access)
# ------------------------------------------------------------
log "Starting noVNC on 0.0.0.0:$NOVNC_PORT"
websockify --web /usr/share/novnc \
  "$NOVNC_PORT" "localhost:$VNC_PORT" \
  >"$LOG_DIR/novnc.log" 2>&1 &

# ------------------------------------------------------------
# Ready
# ------------------------------------------------------------
HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
log "✅ READY → http://${HOST_IP}:${NOVNC_PORT}/vnc.html"

# Keep process alive
wait
