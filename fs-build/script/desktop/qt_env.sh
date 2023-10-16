#!/bin/bash
set -e

# bash_str="export DISPLAY=:0.0"
# if ! grep -q  ${bash_str}  /etc/bash.bashrc; then
#     echo ${bash_str} >> /etc/bash.bashrc
# fi

bash_str="export QT_X11_NO_MITSHM=1"
if ! grep -q  ${bash_str}  /etc/bash.bashrc; then
    echo ${bash_str} >> /etc/bash.bashrc
fi
