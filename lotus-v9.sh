#!/usr/bin/env bash
set -e

if [ "${EUID}" -eq 0 ]; then
  echo "Hãy chạy script bằng tài khoản desktop bình thường, không chạy bằng sudo."
  echo "Script sẽ tự gọi sudo khi cần."
  exit 1
fi

# Lotus Installer v9 - Safer install + Linux Mint Cinnamon optimizations
# Ubuntu / Linux Mint / Kubuntu / Zorin / TUXEDO OS / Debian
# Based on the official Lotus instructions: https://lotusinputmethod.github.io/

BLUE='\033[1;34m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'

printf '%b\n' "${BLUE}======================================="
printf '%b\n' "     Lotus Installer v9 - Safe Fcitx5 + Lotus"
printf '%b\n' "     Ubuntu / Linux Mint / Kubuntu / Zorin / TUXEDO OS / Debian"
printf '%b\n' "     X11 + Wayland"
printf '%b\n' "=======================================${NC}"

[ -r /etc/os-release ] || { echo "Cannot detect OS"; exit 1; }
. /etc/os-release

OS_ID=${ID:-unknown}
OS_LIKE=${ID_LIKE:-}
CODENAME=${VERSION_CODENAME:-}
BASE_CODENAME=${UBUNTU_CODENAME:-$CODENAME}

case "$OS_ID" in
  ubuntu|kubuntu|linuxmint|zorin)
    FAMILY=ubuntu
    ;;

  tuxedo)
    # TUXEDO OS Legacy = Ubuntu 24.04 LTS / Noble
    if [ "${UBUNTU_CODENAME:-}" = "noble" ] || [ "${VERSION_CODENAME:-}" = "noble" ]; then
      FAMILY=ubuntu
      BASE_CODENAME=noble
    else
      # Future Debian-based TUXEDO OS
      FAMILY=debian
    fi
    ;;

  debian)
    FAMILY=debian
    ;;

  *)
    if printf '%s' "$OS_LIKE" | grep -qi debian; then
      FAMILY=debian
    elif printf '%s %s' "$NAME" "$PRETTY_NAME" | grep -qi tuxedo; then
      if [ "${UBUNTU_CODENAME:-}" = "noble" ] || [ "${VERSION_CODENAME:-}" = "noble" ]; then
        FAMILY=ubuntu
        BASE_CODENAME=noble
      else
        FAMILY=debian
      fi
    else
      printf '%b\n' "${RED}Unsupported OS: ${PRETTY_NAME}${NC}"
      exit 1
    fi
    ;;
esac

SESSION=${XDG_SESSION_TYPE:-unknown}
DESKTOP=${XDG_CURRENT_DESKTOP:-unknown}
printf '%b\n' "Detected OS: ${PRETTY_NAME}"
printf '%b\n' "Codename: ${BASE_CODENAME:-unknown}"
printf '%b\n' "Desktop: ${DESKTOP}"
printf '%b\n' "Session: ${SESSION}"

# Back up existing configuration before changes.
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.local/share/lotus-installer-backups/$STAMP"
mkdir -p "$BACKUP_DIR"
[ ! -d "$HOME/.config/fcitx5" ] || cp -a "$HOME/.config/fcitx5" "$BACKUP_DIR/fcitx5-config" || true
[ ! -d "$HOME/.local/share/fcitx5" ] || cp -a "$HOME/.local/share/fcitx5" "$BACKUP_DIR/fcitx5-data" || true
[ ! -f "$HOME/.profile" ] || cp -a "$HOME/.profile" "$BACKUP_DIR/profile" || true
[ ! -d "$HOME/.config/autostart" ] || cp -a "$HOME/.config/autostart" "$BACKUP_DIR/autostart" || true
echo "Backup cấu hình (nếu có): $BACKUP_DIR"

# Never purge all Fcitx5 packages or erase /etc/fcitx5.
printf '%b\n' "${YELLOW}Checking existing Lotus package...${NC}"
if dpkg-query -W -f='${db:Status-Status}' fcitx5-lotus 2>/dev/null | grep -qE '^(unpacked|half-installed|half-configured|triggers-awaited|triggers-pending)$'; then
  echo "Found an incomplete Lotus package; attempting targeted removal."
  sudo dpkg --remove --force-remove-reinstreq fcitx5-lotus || true
fi
sudo dpkg --configure -a || true

sudo apt-get update

printf '%b\n' "${YELLOW}Stopping IBus for this session...${NC}"
if command -v ibus >/dev/null 2>&1; then ibus exit >/dev/null 2>&1 || true; fi
if command -v pkill >/dev/null 2>&1; then pkill -x ibus-daemon >/dev/null 2>&1 || true; fi

printf '%b\n' "${YELLOW}Installing Fcitx5 dependencies...${NC}"
PACKAGES=(curl gnupg ca-certificates fcitx5 fcitx5-modules fcitx5-config-qt im-config)
# Add frontend packages only when the current distro repository provides them.
for pkg in fcitx5-frontend-gtk2 fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5 fcitx5-frontend-qt6 fcitx5-frontend-all kde-config-fcitx5; do
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    PACKAGES+=("$pkg")
  fi
done
sudo apt-get install -y "${PACKAGES[@]}"

if [ "$FAMILY" = debian ]; then
  case "$CODENAME" in bookworm|trixie) LOTUS_CODENAME=$CODENAME;; *) echo "Unsupported Debian codename: $CODENAME"; exit 1;; esac
else
  LOTUS_CODENAME=$BASE_CODENAME
fi

[ -n "$LOTUS_CODENAME" ] || { echo "Cannot determine Lotus codename"; exit 1; }
printf '%b\n' "${GREEN}Lotus repository codename: ${LOTUS_CODENAME}${NC}"

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://fcitx5-lotus.pages.dev/pubkey.gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/fcitx5-lotus.gpg
printf 'deb [arch=amd64 signed-by=/etc/apt/keyrings/fcitx5-lotus.gpg] https://fcitx5-lotus.pages.dev/apt/%s %s main\n' "$LOTUS_CODENAME" "$LOTUS_CODENAME" | sudo tee /etc/apt/sources.list.d/fcitx5-lotus.list >/dev/null
sudo apt-get update

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

printf '%b\n' "${YELLOW}Downloading Lotus package without configuring it...${NC}"
apt-get download fcitx5-lotus
DEB=$(find . -maxdepth 1 -type f -name 'fcitx5-lotus_*.deb' -print -quit)
[ -n "$DEB" ] || { echo "Lotus .deb not downloaded"; exit 1; }

mkdir unpack
# Extract package and repair the broken maintainer script before dpkg sees it.
dpkg-deb -R "$DEB" unpack
POSTINST=unpack/DEBIAN/postinst

if [ ! -f "$POSTINST" ]; then
  echo "Lotus package has no postinst; aborting safely."; exit 1
fi

printf '%b\n' "${YELLOW}Checking Lotus postinst; patching only the known broken pattern if found...${NC}"

python3 - "$POSTINST" <<'PY'
from pathlib import Path
import re, sys

p = Path(sys.argv[1])
lines = p.read_text().splitlines(keepends=True)
out = []
changed = False
for i, line in enumerate(lines):
    out.append(line)
    if re.search(r'if\s+systemctl\s+enable\s+--now.*fcitx5-lotus-server@.*service.*;\s*then\s*$', line):
        j = i + 1
        while j < len(lines) and not lines[j].strip():
            j += 1
        if j < len(lines) and re.match(r'\s*else\b', lines[j]):
            out.append('        :\n')
            changed = True
if changed:
    p.write_text(''.join(out))
    print("Applied targeted Lotus postinst fix.")
else:
    print("Known broken pattern not found; left postinst unchanged.")
PY

if ! sh -n "$POSTINST"; then
  echo "ERROR: Lotus postinst has a shell syntax error; refusing to install." >&2
  nl -ba "$POSTINST" | sed -n '1,100p' >&2
  exit 1
fi

chmod 0755 "$POSTINST"
if ! sh -n "$POSTINST"; then
  echo "ERROR: Lotus postinst is still syntactically invalid after repair." >&2
  nl -ba "$POSTINST" | sed -n '1,80p' >&2
  exit 1
fi

# Rebuild a local .deb from the version currently downloaded from the configured APT repository.
# Only the maintainer script is changed, and only when the known broken pattern is found.
dpkg-deb -b unpack "$TMP/fcitx5-lotus-fixed.deb" >/dev/null

printf '%b\n' "${YELLOW}Installing repaired Lotus package...${NC}"
# dpkg -i first installs the local repaired package without consulting the broken repository copy.
sudo dpkg -i "$TMP/fcitx5-lotus-fixed.deb" || {
  sudo apt-get -f install -y
  sudo dpkg -i "$TMP/fcitx5-lotus-fixed.deb"
}

# Complete the service setup that the original postinst was intended to perform.
sudo modprobe uinput || true
if command -v udevadm >/dev/null 2>&1; then
  sudo udevadm control --reload-rules || true
  sudo udevadm trigger || true
fi
sudo systemd-sysusers || true
REAL_USER=${SUDO_USER:-$USER}
if command -v systemctl >/dev/null 2>&1; then
  sudo systemctl enable --now "fcitx5-lotus-server@${REAL_USER}.service" || true
fi

# Fcitx5 environment/configuration.
im-config -n fcitx5 >/dev/null 2>&1 || true
mkdir -p "$HOME/.config/environment.d" "$HOME/.config/autostart"

# Add a marked block to ~/.profile once; this is useful for Mint desktop sessions.
PROFILE="$HOME/.profile"
touch "$PROFILE"
if ! grep -q '# >>> Lotus Fcitx5 environment >>>' "$PROFILE"; then
  cat >> "$PROFILE" <<'PROFILE_EOF'

# >>> Lotus Fcitx5 environment >>>
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export SDL_IM_MODULE=fcitx
# Recommended by Lotus for GLFW applications:
export GLFW_IM_MODULE=ibus
# <<< Lotus Fcitx5 environment <<<
PROFILE_EOF
fi

cat > "$HOME/.config/environment.d/90-fcitx5-lotus.conf" <<'EOF2'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus
EOF2

# Create one XDG autostart entry only if one does not already exist.
if [ ! -f "$HOME/.config/autostart/fcitx5.desktop" ]; then
  cat > "$HOME/.config/autostart/fcitx5.desktop" <<'EOF3'
[Desktop Entry]
Type=Application
Name=Fcitx5
Comment=Fcitx5 input method framework
Exec=fcitx5 -d
Terminal=false
X-GNOME-Autostart-enabled=true
EOF3
fi

# Restart Fcitx5 only; do not kill unrelated applications or the desktop shell.
if pgrep -x fcitx5 >/dev/null 2>&1; then
  pkill -TERM -x fcitx5 >/dev/null 2>&1 || true
  sleep 1
fi
fcitx5 -d >/dev/null 2>&1 || true

# Linux Mint-specific reminder.
if [ "${OS_ID}" = "linuxmint" ]; then
  echo "Linux Mint detected: cấu hình môi trường cho Cinnamon đã được thêm."
  echo "Sau khi đăng xuất/đăng nhập, mở fcitx5-configtool và thêm Lotus vào Current Input Method."
fi

if dpkg-query -W -f='${db:Status-Status}' fcitx5-lotus 2>/dev/null | grep -qx installed; then
  printf '%b\n' "${GREEN}======================================="
  printf '%b\n' " Lotus installed successfully"
  printf '%b\n' " Fcitx5 + Lotus: OK"
  printf '%b\n' "=======================================${NC}"
  echo "Log out and log in again before testing."
else
  printf '%b\n' "${RED}Lotus is not fully installed.${NC}"
  exit 1
fi
