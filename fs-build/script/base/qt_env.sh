#!/bin/bash
set -e

# bash_str="export DISPLAY=:0.0"

echo "export QT_X11_NO_MITSHM=1" >> /etc/bash.bashrc

if grep -q "^os_type=server" /etc/WalnutPi-release; then
cat >> /etc/bash.bashrc << EOF
if pgrep "Xorg" > /dev/null
then
    export DISPLAY=:0
    export QT_QPA_PLATFORM=""
else
    export QT_QPA_PLATFORM="linuxfb:fb=/dev/fb0"
fi

EOF
fi
