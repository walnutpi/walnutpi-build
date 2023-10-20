#!/bin/bash
set -e
# 检查文件是否存在
if [ ! -f /etc/lightdm/lightdm.conf ]; then
    exit 1
fi

# 替换文件中的内容
sudo sed -i 's/^#autologin-user=.*/autologin-user=pi/g' /etc/lightdm/lightdm.conf
sudo sed -i 's/^#autologin-user-timeout=.*/autologin-user-timeout=0/g' /etc/lightdm/lightdm.conf
