#!/usr/bin/env bash
set -e

sudo systemctl stop "fcitx5-lotus-server@$(whoami).service" 2>/dev/null || true

# Gỡ Lotus trước
sudo dpkg --purge --force-all fcitx5-lotus 2>/dev/null || true

# Gỡ toàn bộ package Fcitx5
FCITX5_PKGS=$(dpkg-query -W -f='${binary:Package} ${db:Status-Status}\n' 2>/dev/null \
  | awk '$1 ~ /^fcitx5($|-)/ && $2 == "installed" {print $1}')

if [ -n "$FCITX5_PKGS" ]; then
    echo "$FCITX5_PKGS" | xargs sudo apt purge -y
fi

# Xóa cấu hình người dùng
rm -rf ~/.config/fcitx5
rm -rf ~/.cache/fcitx5

# Xóa cấu hình hệ thống
sudo rm -rf /etc/fcitx5

# Xóa cấu hình im-config liên quan Fcitx5
sudo rm -f /etc/X11/xinit/xinputrc

# Xóa repository Lotus
sudo rm -f /etc/apt/sources.list.d/fcitx5-lotus.list
sudo rm -f /etc/apt/keyrings/fcitx5-lotus.gpg

# Dọn package còn sót
sudo dpkg --configure -a
sudo apt autoremove -y
sudo apt autoclean

echo
echo "===== KIEM TRA ====="
echo "Fcitx5 packages:"
dpkg-query -W -f='${binary:Package} ${db:Status-Status}\n' 2>/dev/null \
  | grep '^fcitx5' || echo "Khong con package fcitx5"

echo
echo "Lotus:"
dpkg-query -W -f='${binary:Package} ${db:Status-Status}\n' 2>/dev/null \
  | grep 'fcitx5-lotus' || echo "Khong con fcitx5-lotus"

echo
echo "Fcitx5 config:"
[ -d ~/.config/fcitx5 ] && echo "Con ~/.config/fcitx5" || echo "Da xoa ~/.config/fcitx5"

echo
echo "===== HOAN TAT ====="
