#!/bin/bash
set -e

PATH_PWD="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

mv set-device /usr/bin/
chmod +x /usr/bin/set-device

mv completion-set-device  /etc/bash_completion.d/set-device
chmod +x /etc/bash_completion.d/set-device
# source /etc/bash_completion.d/set-device

bash_str="source /etc/bash_completion.d/set-device"
if ! grep -q  ${bash_str}  /etc/bash.bashrc; then
    echo ${bash_str} >> /etc/bash.bashrc
fi
