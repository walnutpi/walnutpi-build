#!/bin/bash
set -e

PATH_PWD="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

mv set-language /usr/bin/
chmod +x /usr/bin/set-language
mv completion-set-language  /etc/bash_completion.d/set-language

bash_str="source /etc/bash_completion.d/set-language"
if ! grep -q  ${bash_str}  /etc/bash.bashrc; then
    echo ${bash_str} >> /etc/bash.bashrc
fi


echo -e "\033[32m[ok]\033[0m"
