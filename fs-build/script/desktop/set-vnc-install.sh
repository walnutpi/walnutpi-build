#!/bin/bash
set -e

PATH_PWD="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

mv set-vnc /usr/bin/
chmod +x /usr/bin/set-vnc

mv completion-set-vnc  /etc/bash_completion.d/set-vnc
chmod +x /etc/bash_completion.d/set-vnc
# source /etc/bash_completion.d/set-vnc

bash_str="source /etc/bash_completion.d/set-vnc"
if ! grep -q  ${bash_str}  /etc/bash.bashrc; then
    echo ${bash_str} >> /etc/bash.bashrc
fi
mv x11vnc.service /lib/systemd/system/
x11vnc -storepasswd pi /etc/x11vnc.pwd