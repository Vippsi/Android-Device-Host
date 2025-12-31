# Android Device Host

A **headless Android device host** that mirrors a physical Android device over the network using **scrcpy + noVNC**.

---

## Installation

### Quick Install

```bash
git clone <repo-url>
cd android-device-host
sudo ./install.sh
```

### Install as Specific User (Optional)

```bash
sudo ./install.sh --user android-dev
```

## Uninstallation

```bash
sudo ./uninstall.sh
```

You will be prompted to type `DELETE device-host` to confirm removal.

## Configuration

Configuration is loaded from `config/device-host.env`. 

Example:

```env
DISPLAY_NUM=:99
SCREEN=380x720x24
NOVNC_PORT=6080
VNC_PORT=5900
LOG_DIR=/var/log/device-host
```

## Usage

### Access the Device

Open your browser and navigate to:

```
http://<host-ip>:6080/vnc.html
```

### Service Management

| Action       | Command                                       |
| ------------ | --------------------------------------------- |
| Check status | `systemctl status novnc-scrcpy.service`       |
| View logs    | `journalctl -u novnc-scrcpy.service -f`       |
| Restart      | `sudo systemctl restart novnc-scrcpy.service` |
| Stop         | `sudo systemctl stop novnc-scrcpy.service`    |

## Requirements

- Physical Android device with USB debugging enabled
- Headless server (no monitor required)
