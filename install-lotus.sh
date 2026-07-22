#!/usr/bin/env bash
#
# Zalo Installer for Linux Mint: version 2.0
# Author: Long Nguyen
#
sudo apt update
sudo apt install curl gnupg2 fcitx5 fcitx5-config-qt im-config -y

CODENAME=$(grep '^UBUNTU_CODENAME=' /etc/os-release | cut -d'=' -f2)

sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://fcitx5-lotus.pages.dev/pubkey.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/fcitx5-lotus.gpg

echo "deb [signed-by=/etc/apt/keyrings/fcitx5-lotus.gpg] https://fcitx5-lotus.pages.dev/apt/$CODENAME $CODENAME main" | sudo tee /etc/apt/sources.list.d/fcitx5-lotus.list

sudo apt update
sudo apt install fcitx5-lotus -y
im-config -n fcitx5 
echo
echo "done, reboot or lougout"
