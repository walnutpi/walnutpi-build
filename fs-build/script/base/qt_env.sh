#!/bin/bash
set -e

# bash_str="export DISPLAY=:0.0"

echo "export QT_X11_NO_MITSHM=1" >> /etc/bash.bashrc

cat > /etc/bash.bashrc << EOF
if grep -q "^os_type=server" /etc/WalnutPi-release; then
    export QT_QPA_PLATFORM="linuxfb:fb=/dev/fb0"
fi

EOF