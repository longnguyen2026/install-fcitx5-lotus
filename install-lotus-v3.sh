#!/usr/bin/env bash
#
# Lotus Installer for Ubuntu / Linux Mint / Kubuntu (X11 & Wayland)
# Version: 3.3
#

set -e

GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
NC="\033[0m"

echo -e "${BLUE}"
echo "======================================="
echo "     Lotus Installer v3.3 (X11 + Wayland)"
echo "======================================="
echo -e "${NC}"

# 1. Kiểm tra kết nối Repo
echo -e "${YELLOW}Checking connection to Lotus Repository...${NC}"
if ! curl -s --connect-timeout 5 https://fcitx5-lotus.pages.dev/ >/dev/null; then
    echo -e "${RED}Cannot connect to fcitx5-lotus repository! Check your internet connection.${NC}"
    exit 1
fi

# 2. Kiểm tra OS & Codename
if [ ! -f /etc/os-release ]; then
    echo -e "${RED}Unsupported operating system.${NC}"
    exit 1
fi

source /etc/os-release

# Ubuntu-based systems (including Linux Mint) use UBUNTU_CODENAME
CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"

if [ -z "$CODENAME" ]; then
    echo -e "${RED}Cannot detect Ubuntu base codename.${NC}"
    exit 1
fi

# Detect desktop/session so the same installer works on:
# - Kubuntu / KDE Plasma Wayland
# - Kubuntu / KDE Plasma X11
# - Linux Mint Cinnamon/MATE/Xfce X11
SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
DESKTOP_NAME="${XDG_CURRENT_DESKTOP:-unknown}"

if [ "$SESSION_TYPE" = "wayland" ]; then
    SESSION_MODE="Wayland"
else
    SESSION_MODE="X11"
fi

echo -e "${GREEN}Detected OS: ${PRETTY_NAME}${NC}"
echo -e "${GREEN}Ubuntu base codename: ${CODENAME}${NC}"
echo -e "${GREEN}Desktop: ${DESKTOP_NAME}${NC}"
echo -e "${GREEN}Session: ${SESSION_MODE}${NC}"

# 3. Dọn dẹp IBus
echo
echo -e "${YELLOW}Stopping IBus if running...${NC}"
pkill -f ibus-daemon >/dev/null 2>&1 || true
if command -v ibus >/dev/null 2>&1; then
    ibus exit >/dev/null 2>&1 || true
fi

# 4. Cài đặt Fcitx5 + Modules (GTK2/3/4 + Qt5/6 + Wayland + KDE Settings)
echo
echo -e "${YELLOW}Installing Fcitx5, Wayland & Qt5/Qt6 Frontend modules...${NC}"

sudo apt update

# Danh sách gói mở rộng hỗ trợ cả KDE Wayland
PACKAGES=(
    curl
    gnupg2
    fcitx5
    fcitx5-modules
    fcitx5-config-qt
    fcitx5-frontend-gtk3
    fcitx5-frontend-gtk4
    fcitx5-frontend-qt5
    fcitx5-frontend-qt6
    kde-config-fcitx5
    im-config
)

# GTK2 frontend is optional and is not available on every newer Ubuntu base.
# Install it only when the repository provides it.
if apt-cache show fcitx5-frontend-gtk2 >/dev/null 2>&1; then
    PACKAGES+=(fcitx5-frontend-gtk2)
fi

if ! sudo apt install -y "${PACKAGES[@]}"; then
    echo -e "${RED}Failed to install Fcitx5 packages.${NC}"
    echo -e "${YELLOW}Check the package names and enabled Ubuntu repositories (main/universe).${NC}"
    exit 1
fi

# 5. Thêm Repo Lotus
echo
echo -e "${YELLOW}Adding Lotus repository...${NC}"

sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://fcitx5-lotus.pages.dev/pubkey.gpg \
| sudo gpg --dearmor --yes -o /etc/apt/keyrings/fcitx5-lotus.gpg

echo "deb [signed-by=/etc/apt/keyrings/fcitx5-lotus.gpg] https://fcitx5-lotus.pages.dev/apt/${CODENAME} ${CODENAME} main" \
| sudo tee /etc/apt/sources.list.d/fcitx5-lotus.list >/dev/null

echo
echo -e "${YELLOW}Installing Lotus engine...${NC}"

sudo apt update
sudo apt install -y fcitx5-lotus

# 6. Thiết lập bộ gõ mặc định
im-config -n fcitx5

# 7. Khai báo biến môi trường chuẩn (Hỗ trợ cả X11 & Wayland / Plasma 5 & 6)
echo
echo -e "${YELLOW}Configuring environment variables for X11 & Wayland...${NC}"

mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/fcitx5.conf <<EOF
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
QT_IM_MODULES="wayland;fcitx;ibus"
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
EOF

# X11 + Wayland environment variables.
# Keep the same variables for both sessions so applications launched
# from either desktop environment can find Fcitx5.
ENV_VARS='export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export QT_IM_MODULES="wayland;fcitx;ibus"
export XMODIFIERS=@im=fcitx
export SDL_IM_MODULE=fcitx'

for FILE in "$HOME/.xprofile" "$HOME/.profile"; do
    if [ -f "$FILE" ]; then
        if ! grep -q "GTK_IM_MODULE=fcitx" "$FILE"; then
            echo -e "\n# Fcitx5 Environment Variables\n$ENV_VARS" >> "$FILE"
        fi
    else
        echo -e "# Fcitx5 Environment Variables\n$ENV_VARS" > "$FILE"
    fi
done

# 8. Cấu hình Autostart
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/fcitx5.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Fcitx5
Exec=fcitx5 -d
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
NoDisplay=false
EOF

# 9. Khởi động lại Fcitx5
pkill -9 fcitx5 >/dev/null 2>&1 || true
sleep 1
nohup fcitx5 -d >/dev/null 2>&1 &

echo
echo -e "${BLUE}Fcitx5 configuration:${NC}"
echo -e "  Session detected: ${SESSION_MODE}"
echo -e "  Ubuntu base: ${CODENAME}"
echo -e "  Core modules: fcitx5-modules (Xorg + Wayland)"
echo
echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN} Lotus installed - X11 & Wayland ready!   ${NC}"
echo -e "${GREEN}=======================================${NC}"
echo
echo "Please LOG OUT and LOG BACK IN to apply Fcitx5, Qt/GTK and X11/Wayland settings."
