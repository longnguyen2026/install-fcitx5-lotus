#!/usr/bin/env bash
#
# Lotus Installer for Ubuntu / Linux Mint / Kubuntu / Zorin OS / Debian
# Version: 7.0
# Supports: X11 + Wayland
#

set -e

GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
NC="\033[0m"

echo -e "${BLUE}"
echo "======================================="
echo "     Lotus Installer v7.0"
echo "     Ubuntu / Mint / Kubuntu / Zorin OS / Debian"
echo "     X11 + Wayland"
echo "======================================="
echo -e "${NC}"

# ------------------------------------------------------------
# 1. Check Internet / Lotus repository
# ------------------------------------------------------------
echo -e "${YELLOW}Checking connection to Lotus Repository...${NC}"

if ! curl -fsS --connect-timeout 8 https://fcitx5-lotus.pages.dev/ >/dev/null; then
    echo -e "${RED}Cannot connect to fcitx5-lotus repository!${NC}"
    echo "Check your Internet connection and try again."
    exit 1
fi

# ------------------------------------------------------------
# 2. Detect OS
# ------------------------------------------------------------
if [ ! -f /etc/os-release ]; then
    echo -e "${RED}Cannot detect operating system.${NC}"
    exit 1
fi

source /etc/os-release

OS_ID="${ID:-unknown}"
OS_LIKE="${ID_LIKE:-}"
CODENAME="${VERSION_CODENAME:-}"
UBUNTU_CODENAME_VALUE="${UBUNTU_CODENAME:-}"

# Linux Mint / Ubuntu based systems
if [ -n "$UBUNTU_CODENAME_VALUE" ]; then
    BASE_CODENAME="$UBUNTU_CODENAME_VALUE"
elif [ -n "$CODENAME" ]; then
    BASE_CODENAME="$CODENAME"
else
    BASE_CODENAME=""
fi

case "$OS_ID" in
    ubuntu)
        FAMILY="ubuntu"
        ;;
    linuxmint)
        FAMILY="ubuntu"
        ;;
    kubuntu)
        FAMILY="ubuntu"
        ;;
    zorin)
        # Zorin OS is Ubuntu-based and uses the Ubuntu codename.
        FAMILY="ubuntu"
        ;;
    debian)
        FAMILY="debian"
        ;;
    *)
        if echo "$OS_LIKE" | grep -qi "debian"; then
            FAMILY="debian"
        else
            echo -e "${RED}Unsupported operating system: ${PRETTY_NAME}${NC}"
            exit 1
        fi
        ;;
esac

# ------------------------------------------------------------
# 3. Detect session
# ------------------------------------------------------------
SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
DESKTOP_NAME="${XDG_CURRENT_DESKTOP:-unknown}"

if [ "$SESSION_TYPE" = "wayland" ]; then
    SESSION_MODE="Wayland"
else
    SESSION_MODE="X11"
fi

echo -e "${GREEN}Detected OS: ${PRETTY_NAME}${NC}"
echo -e "${GREEN}OS family: ${FAMILY}${NC}"
echo -e "${GREEN}Codename: ${BASE_CODENAME:-unknown}${NC}"
echo -e "${GREEN}Desktop: ${DESKTOP_NAME}${NC}"
echo -e "${GREEN}Session: ${SESSION_MODE}${NC}"

# ------------------------------------------------------------
# 4. Check apt
# ------------------------------------------------------------
if ! command -v apt >/dev/null 2>&1; then
    echo -e "${RED}APT package manager not found.${NC}"
    exit 1
fi

# ------------------------------------------------------------
# 5. Stop IBus
# ------------------------------------------------------------
echo
echo -e "${YELLOW}Stopping IBus if running...${NC}"

pkill -f ibus-daemon >/dev/null 2>&1 || true

if command -v ibus >/dev/null 2>&1; then
    ibus exit >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------
# 6. Install Fcitx5
# ------------------------------------------------------------
echo
echo -e "${YELLOW}Installing Fcitx5 packages...${NC}"

sudo apt update

PACKAGES=(
    curl
    gnupg
    fcitx5
    fcitx5-modules
    fcitx5-config-qt
    im-config
)

if [ "$FAMILY" = "ubuntu" ]; then

    PACKAGES+=(
        fcitx5-frontend-gtk3
        fcitx5-frontend-gtk4
        fcitx5-frontend-qt5
        fcitx5-frontend-qt6
        kde-config-fcitx5
    )

    # GTK2 is optional on newer Ubuntu/Mint versions
    if apt-cache show fcitx5-frontend-gtk2 >/dev/null 2>&1; then
        PACKAGES+=(fcitx5-frontend-gtk2)
    fi

else
    # Debian 12/13:
    # Do NOT install fcitx5-module-x11 or fcitx5-module-wayland.
    # fcitx5-modules provides the required modules.
    if apt-cache show fcitx5-frontend-all >/dev/null 2>&1; then
        PACKAGES+=(fcitx5-frontend-all)
    else
        PACKAGES+=(
            fcitx5-frontend-gtk3
            fcitx5-frontend-gtk4
            fcitx5-frontend-qt5
            fcitx5-frontend-qt6
        )
    fi

    if apt-cache show kde-config-fcitx5 >/dev/null 2>&1; then
        PACKAGES+=(kde-config-fcitx5)
    fi
fi

if ! sudo apt install -y "${PACKAGES[@]}"; then
    echo
    echo -e "${RED}Failed to install Fcitx5 packages.${NC}"
    echo -e "${YELLOW}Package installation failed. No Lotus repository changes were made.${NC}"
    exit 1
fi

# ------------------------------------------------------------
# 7. Determine Lotus repository codename
# ------------------------------------------------------------
echo
echo -e "${YELLOW}Preparing Lotus repository...${NC}"

if [ "$FAMILY" = "debian" ]; then

    # Debian uses its own codename.
    case "$CODENAME" in
        bookworm|trixie)
            LOTUS_CODENAME="$CODENAME"
            ;;
        *)
            echo -e "${RED}Unsupported Debian codename: ${CODENAME:-unknown}${NC}"
            echo "Supported Debian versions: bookworm, trixie"
            exit 1
            ;;
    esac

else

    # Ubuntu / Linux Mint / Kubuntu
    if [ -z "$BASE_CODENAME" ]; then
        echo -e "${RED}Cannot detect Ubuntu base codename.${NC}"
        exit 1
    fi

    LOTUS_CODENAME="$BASE_CODENAME"
fi

echo -e "${GREEN}Lotus repository codename: ${LOTUS_CODENAME}${NC}"

# ------------------------------------------------------------
# 8. Add Lotus repository
# ------------------------------------------------------------
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://fcitx5-lotus.pages.dev/pubkey.gpg \
    | sudo gpg --dearmor --yes -o /etc/apt/keyrings/fcitx5-lotus.gpg

echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/fcitx5-lotus.gpg] https://fcitx5-lotus.pages.dev/apt/${LOTUS_CODENAME} ${LOTUS_CODENAME} main" \
    | sudo tee /etc/apt/sources.list.d/fcitx5-lotus.list >/dev/null

# ------------------------------------------------------------
# 9. Install Lotus
# ------------------------------------------------------------
echo
echo -e "${YELLOW}Installing Lotus engine...${NC}"

sudo apt update

# Some fcitx5-lotus 3.5.6-1 packages contain a /bin/sh postinst
# with an empty "then" branch:
#     if systemctl ...; then
#     else
#         ...
#     fi
# This is rejected by dash on Ubuntu/Zorin. Patch the installed
# maintainer script before retrying configuration.
patch_lotus_postinst() {
    local POSTINST="/var/lib/dpkg/info/fcitx5-lotus.postinst"

    if [ ! -f "$POSTINST" ]; then
        return 0
    fi

    if sudo grep -qF 'if systemctl enable --now "fcitx5-lotus-server@${REAL_USER}.service" 2>/dev/null; then' "$POSTINST" \
        && sudo grep -qF '            else' "$POSTINST"; then

        echo -e "${YELLOW}Checking Lotus post-install script...${NC}"

        sudo sed -i '/if systemctl enable --now "fcitx5-lotus-server@${REAL_USER}.service"/,+3c\
        if systemctl enable --now "fcitx5-lotus-server@${REAL_USER}.service" 2>/dev/null; then\
            :\
        else\
            printf "%b\\n" "  ${yellow}⚠ Chạy lệnh sau để bật service: sudo systemctl enable --now fcitx5-lotus-server@${REAL_USER}.service${all_off}"\
        fi' "$POSTINST"

        echo -e "${GREEN}Lotus post-install script patched.${NC}"
    fi
}

# IMPORTANT:
# apt may return success when fcitx5-lotus is already the newest version,
# even though the package is unpacked but not configured. Therefore patch
# the maintainer script BEFORE apt install/configure, not only after failure.
patch_lotus_postinst

if ! sudo apt install -y fcitx5-lotus; then
    echo
    echo -e "${YELLOW}APT reported an installation/configuration failure.${NC}"

    # The package can already be unpacked. Repair the postinst and retry.
    patch_lotus_postinst

    echo -e "${YELLOW}Retrying Lotus configuration...${NC}"
    if ! sudo dpkg --configure fcitx5-lotus; then
        echo
        echo -e "${RED}Failed to configure fcitx5-lotus.${NC}"
        echo -e "${YELLOW}Showing the Lotus post-install script for diagnosis:${NC}"
        sudo nl -ba /var/lib/dpkg/info/fcitx5-lotus.postinst | sed -n '1,80p' || true
        exit 1
    fi
fi

# apt can report "already the newest version" while dpkg still has the
# package in an unconfigured state. Always verify and configure explicitly.
if ! dpkg-query -W -f='${Status}' fcitx5-lotus 2>/dev/null | grep -q 'install ok installed'; then
    echo -e "${YELLOW}Lotus is installed but not fully configured. Repairing...${NC}"
    patch_lotus_postinst

    if ! sudo dpkg --configure fcitx5-lotus; then
        echo
        echo -e "${RED}Failed to configure fcitx5-lotus.${NC}"
        echo -e "${YELLOW}Showing the Lotus post-install script for diagnosis:${NC}"
        sudo nl -ba /var/lib/dpkg/info/fcitx5-lotus.postinst | sed -n '1,80p' || true
        exit 1
    fi
fi
    echo
    echo -e "${RED}Failed to install fcitx5-lotus.${NC}"
    echo -e "${YELLOW}The Lotus repository may not provide packages for:${NC}"
    echo "  OS: ${PRETTY_NAME}"
    echo "  Codename: ${LOTUS_CODENAME}"
    exit 1
fi

# ------------------------------------------------------------
# 10. Repair pending packages
# ------------------------------------------------------------
echo
echo -e "${YELLOW}Checking package state...${NC}"
sudo apt --fix-broken install -y

# ------------------------------------------------------------
# 11. Set Fcitx5 as default input method
# ------------------------------------------------------------
echo
echo -e "${YELLOW}Setting Fcitx5 as default input method...${NC}"

if command -v im-config >/dev/null 2>&1; then
    im-config -n fcitx5 || true
fi

# ------------------------------------------------------------
# 12. Environment variables
# ------------------------------------------------------------
echo
echo -e "${YELLOW}Configuring environment variables...${NC}"

mkdir -p "$HOME/.config/environment.d"

cat > "$HOME/.config/environment.d/fcitx5.conf" <<'EOF'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
QT_IM_MODULES=wayland;fcitx;ibus
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
EOF

ENV_VARS='export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export QT_IM_MODULES="wayland;fcitx;ibus"
export XMODIFIERS=@im=fcitx
export SDL_IM_MODULE=fcitx'

for FILE in "$HOME/.xprofile" "$HOME/.profile"; do
    touch "$FILE"

    if ! grep -q "Fcitx5 Environment Variables" "$FILE" 2>/dev/null; then
        {
            echo
            echo "# Fcitx5 Environment Variables"
            echo "$ENV_VARS"
        } >> "$FILE"
    fi
done

# ------------------------------------------------------------
# 13. Autostart Fcitx5
# ------------------------------------------------------------
echo
echo -e "${YELLOW}Configuring Fcitx5 autostart...${NC}"

mkdir -p "$HOME/.config/autostart"

cat > "$HOME/.config/autostart/fcitx5.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Fcitx5
Comment=Fcitx5 Input Method Framework
Exec=fcitx5 -d
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
NoDisplay=false
EOF

# ------------------------------------------------------------
# 14. Start Fcitx5
# ------------------------------------------------------------
echo
echo -e "${YELLOW}Starting Fcitx5...${NC}"

pkill -9 fcitx5 >/dev/null 2>&1 || true
sleep 1
nohup fcitx5 -d >/dev/null 2>&1 &

sleep 2

# ------------------------------------------------------------
# 15. Verify
# ------------------------------------------------------------
echo
echo -e "${YELLOW}Verifying installation...${NC}"

if command -v fcitx5 >/dev/null 2>&1; then
    FCITX_VERSION="$(fcitx5 --version 2>/dev/null | head -n 1 || true)"
    echo -e "${GREEN}Fcitx5: OK${NC}"
    [ -n "$FCITX_VERSION" ] && echo "  $FCITX_VERSION"
else
    echo -e "${RED}Fcitx5 executable not found.${NC}"
fi

if dpkg-query -W -f='${Status}' fcitx5-lotus 2>/dev/null | grep -q 'install ok installed'; then
    LOTUS_VERSION="$(dpkg-query -W -f='${Version}' fcitx5-lotus 2>/dev/null || true)"
    echo -e "${GREEN}Lotus engine: OK${NC}"
    [ -n "$LOTUS_VERSION" ] && echo "  Version: $LOTUS_VERSION"
else
    echo -e "${RED}Lotus engine: NOT FOUND / NOT CONFIGURED${NC}"
fi

if pgrep -x fcitx5 >/dev/null 2>&1; then
    echo -e "${GREEN}Fcitx5 daemon: RUNNING${NC}"
else
    echo -e "${YELLOW}Fcitx5 daemon is not running yet.${NC}"
fi

echo
echo -e "${BLUE}=======================================${NC}"
echo -e "${GREEN} Lotus Installer v7.0 completed!${NC}"
echo -e "${GREEN} X11 + Wayland ready${NC}"
echo -e "${BLUE}=======================================${NC}"
echo
echo "OS       : ${PRETTY_NAME}"
echo "Family   : ${FAMILY}"
echo "Codename : ${LOTUS_CODENAME}"
echo "Session  : ${SESSION_MODE}"
echo
echo -e "${YELLOW}Please LOG OUT and LOG BACK IN to apply all Fcitx5 settings.${NC}"
