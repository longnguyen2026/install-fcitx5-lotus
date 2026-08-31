#!/usr/bin/env bash
set -e

echo "===== REMOVE FCITX5 + LOTUS ====="

# Dừng Lotus
sudo systemctl stop "fcitx5-lotus-server@$(whoami).service" 2>/dev/null || true
sudo systemctl disable "fcitx5-lotus-server@$(whoami).service" 2>/dev/null || true

# Gỡ Lotus trước
sudo dpkg --purge --force-all fcitx5-lotus 2>/dev/null || true

# Gỡ toàn bộ package Fcitx5
FCITX5_PKGS=$(dpkg-query -W -f='${binary:Package} ${db:Status-Status}\n' 2>/dev/null \
  | awk '$1 ~ /^fcitx5($|-)/ && $2 == "installed" {print $1}')

if [ -n "$FCITX5_PKGS" ]; then
    echo "Removing:"
    echo "$FCITX5_PKGS"
    echo "$FCITX5_PKGS" | xargs sudo apt purge -y
fi

# Xóa cấu hình Fcitx5 của user
rm -rf "$HOME/.config/fcitx5"
rm -rf "$HOME/.cache/fcitx5"

# Xóa cấu hình hệ thống Fcitx5
sudo rm -rf /etc/fcitx5

# Xóa im-config
sudo rm -f /etc/X11/xinit/xinputrc

# Xóa Lotus repository + key
sudo rm -f /etc/apt/sources.list.d/fcitx5-lotus.list
sudo rm -f /etc/apt/keyrings/fcitx5-lotus.gpg

# Xóa các file service còn sót nếu có
sudo rm -f /etc/systemd/system/fcitx5-lotus-server@.service
sudo systemctl daemon-reload

# Dọn dependency không còn cần
sudo apt autoremove -y
sudo apt autoclean

echo
echo "===== KIEM TRA ====="

echo
echo "Fcitx5 packages:"
if dpkg-query -W -f='${binary:Package} ${db:Status-Status}\n' 2>/dev/null \
    | grep -q '^fcitx5'; then
    dpkg-query -W -f='${binary:Package} ${db:Status-Status}\n' 2>/dev/null \
        | grep '^fcitx5'
else
    echo "Khong con package fcitx5"
fi

echo
echo "Lotus:"
if dpkg-query -W -f='${binary:Package} ${db:Status-Status}\n' 2>/dev/null \
    | grep -q 'fcitx5-lotus'; then
    dpkg-query -W -f='${binary:Package} ${db:Status-Status}\n' 2>/dev/null \
        | grep 'fcitx5-lotus'
else
    echo "Khong con fcitx5-lotus"
fi

echo
echo "Lotus repository:"
if [ -f /etc/apt/sources.list.d/fcitx5-lotus.list ]; then
    echo "Van con repository Lotus"
else
    echo "Da xoa repository Lotus"
fi

echo
echo "Lotus key:"
if [ -f /etc/apt/keyrings/fcitx5-lotus.gpg ]; then
    echo "Van con Lotus key"
else
    echo "Da xoa Lotus key"
fi

echo
echo "Fcitx5 config:"
if [ -d "$HOME/.config/fcitx5" ]; then
    echo "Con ~/.config/fcitx5"
else
    echo "Da xoa ~/.config/fcitx5"
fi

echo
echo "===== HOAN TAT ====="
