#!/bin/bash
set -e

if [[ ! -d "set-lcd" ]]; then
    git clone https://github.com/walnutpi/set-lcd.git
fi


cd set-lcd
chmod +x install
./install