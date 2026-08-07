#!/usr/bin/env bash
#
# Lotus Installer for Linux Mint / Ubuntu
# Version: 3.1 (Fixed Lag & Frontend Modules)
#

set -e

GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
NC="\033[0m"

echo -e "${BLUE}"
echo "======================================="
echo "     Lotus Installer v3.1"
echo "======================================="
echo -e "${NC}"

# 1. Kiểm tra kết nối HTTP đến Repository
echo -e "${YELLOW}Checking connection to Lotus Repository...${NC}"
if ! curl -s --connect-timeout 5 https://fcitx5-lotus.pages.dev/ >/dev/null; then
    echo -e "${RED}Cannot connect to fcitx5-lotus repository! Check your internet connection.${NC}"
    exit 1
fi

# 2. Kiểm tra hệ điều hành & Ubuntu Codename
if [ ! -f /etc/os-release ]; then
    echo -e "${RED}Unsupported operating system.${NC}"
    exit 1
fi

source /etc/os-release

# Lấy UBUNTU_CODENAME (hỗ trợ Linux Mint, Pop!_OS, Element) hoặc VERSION_CODENAME
CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"

if [ -z "$CODENAME" ]; then
    echo -e "${RED}Cannot detect Ubuntu codename.${NC}"
    exit 1
fi

echo -e "${GREEN}Detected OS: ${PRETTY_NAME}${NC}"
echo -e "${GREEN}Codename: ${CODENAME}${NC}"

# 3. Tắt IBus nếu đang chạy để tránh xung đột gây lag
echo
echo -e "${YELLOW}Stopping IBus if running...${NC}"
pkill -f ibus-daemon >/dev/null 2>&1 || true
if command -v ibus >/dev/null 2>&1; then
    ibus exit >/dev/null 2>&1 || true
fi

# 4. Cài đặt các gói phụ thuộc và Module Frontend (Bắt buộc để hết LAG)
echo
echo -e "${YELLOW}Installing Fcitx5 and Frontend modules...${NC}"

sudo apt update

sudo apt install -y \
    curl \
    gnupg2 \
    fcitx5 \
    fcitx5-config-qt \
    fcitx5-frontend-gtk2 \
    fcitx5-frontend-gtk3 \
    fcitx5-frontend-gtk4 \
    fcitx5-frontend-qt5 \
    fcitx5-module-x11 \
    im-config

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

# 6. Cấu hình biến môi trường toàn diện (Systemd, X11, Profile)
echo
echo -e "${YELLOW}Configuring input method environment variables...${NC}"

im-config -n fcitx5

# Cấu hình systemd user environment
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/fcitx5.conf <<EOF
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
EOF

# Ghi thêm vào ~/.xprofile để đảm bảo ăn biến môi trường trên Linux Mint X11
XPROFILE="$HOME/.xprofile"
ENV_VARS="export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export SDL_IM_MODULE=fcitx"

if [ -f "$XPROFILE" ]; then
    if ! grep -q "GTK_IM_MODULE=fcitx" "$XPROFILE"; then
        echo -e "\n# Fcitx5 Config\n$ENV_VARS" >> "$XPROFILE"
    fi
else
    echo -e "# Fcitx5 Config\n$ENV_VARS" > "$XPROFILE"
fi

# 7. Cấu hình Autostart
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/fcitx5.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Fcitx5
Exec=fcitx5 -d
X-GNOME-Autostart-enabled=true
NoDisplay=false
EOF

# 8. Khởi động lại Fcitx5
pkill -9 fcitx5 >/dev/null 2>&1 || true
sleep 1
nohup fcitx5 -d >/dev/null 2>&1 &

echo
echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN} Lotus installed and configured!      ${NC}"
echo -e "${GREEN}=======================================${NC}"
echo
echo "Please LOG OUT and LOG BACK IN to apply all GTK/Qt environment modules."
