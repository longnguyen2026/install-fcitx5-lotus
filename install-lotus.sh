#!/usr/bin/env bash
#
# Lotus Installer for Linux Mint / Ubuntu
# Version: 3.0
# Author: Long Nguyen
#

set -e

GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
NC="\033[0m"

echo -e "${BLUE}"
echo "======================================="
echo "     Lotus Installer v3.0"
echo "======================================="
echo -e "${NC}"

# Kiểm tra Internet
echo -e "${YELLOW}Checking Internet...${NC}"
if ! ping -c1 github.com >/dev/null 2>&1; then
    echo -e "${RED}No Internet connection!${NC}"
    exit 1
fi

# Kiểm tra hệ điều hành
if [ ! -f /etc/os-release ]; then
    echo -e "${RED}Unsupported operating system.${NC}"
    exit 1
fi

source /etc/os-release

CODENAME="${UBUNTU_CODENAME:-}"

if [ -z "$CODENAME" ]; then
    echo -e "${RED}Cannot detect Ubuntu codename.${NC}"
    exit 1
fi

echo -e "${GREEN}Detected: ${PRETTY_NAME}${NC}"
echo -e "${GREEN}Codename: ${CODENAME}${NC}"

echo
echo -e "${YELLOW}Installing required packages...${NC}"

sudo apt update

sudo apt install -y \
    curl \
    gnupg2 \
    fcitx5 \
    fcitx5-config-qt \
    im-config

echo
echo -e "${YELLOW}Adding Lotus repository...${NC}"

sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://fcitx5-lotus.pages.dev/pubkey.gpg \
| sudo gpg --dearmor -o /etc/apt/keyrings/fcitx5-lotus.gpg

echo "deb [signed-by=/etc/apt/keyrings/fcitx5-lotus.gpg] https://fcitx5-lotus.pages.dev/apt/${CODENAME} ${CODENAME} main" \
| sudo tee /etc/apt/sources.list.d/fcitx5-lotus.list >/dev/null

echo
echo -e "${YELLOW}Installing Lotus...${NC}"

sudo apt update
sudo apt install -y fcitx5-lotus

echo
echo -e "${YELLOW}Configuring input method...${NC}"

im-config -n fcitx5

mkdir -p ~/.config/environment.d

cat > ~/.config/environment.d/fcitx5.conf <<EOF
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
EOF

mkdir -p ~/.config/autostart

cat > ~/.config/autostart/fcitx5.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Fcitx5
Exec=fcitx5
X-GNOME-Autostart-enabled=true
NoDisplay=false
EOF

pkill fcitx5 >/dev/null 2>&1 || true
nohup fcitx5 >/dev/null 2>&1 &

echo
echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN} Lotus has been installed successfully.${NC}"
echo -e "${GREEN}=======================================${NC}"
echo
echo "Please log out and log back in,"
echo "or reboot your computer."
echo
