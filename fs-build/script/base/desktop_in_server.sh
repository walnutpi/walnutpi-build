#!/bin/bash

set -e


if grep -q "^os_type=server" /etc/WalnutPi-release; then
    sudo systemctl disable lightdm.service
    cp lightdm-xsession.desktop /usr/share/xsessions/

    file="/etc/lightdm/lightdm.conf"
    # 检查文件是否存在
    if [ ! -f "$file" ]; then
        echo "$file not found!"
        exit 1
    fi
    sed -i 's/^#xserver-command=X/xserver-command=X -s 0 -dpms/g' $file
fi
rm lightdm-xsession.desktop

chmod +x xsession
mv xsession /etc/
chmod +x start
mv start /etc/