#!/bin/bash
set -e

chmod 777 -R  backgroud/
cp -r backgroud/. /usr/share/backgrounds/
rm -r backgroud/

chmod 777 -R  icons
cp  -r icons/. /usr/share/pixmaps/
rm -r icons/

cp -r config/. /root/.config/
chmod 777 -R  /root/.config/
cp -r config/. /home/pi/.config/
chmod 777 -R  /home/pi/.config/
rm -r config/

cp -r local/. /root/.local/
chmod 777 -R  /root/.local/
cp -r local/. /home/pi/.local/
chmod 777 -R  /home/pi/.local/
rm -r local/
