#!/bin/bash
set -e

chmod 777 /opt

cd /opt

echo "start to clone aw.gpio"
if [[ ! -d "aw.gpio" ]]; then
    git clone https://github.com/sc-bin/aw.gpio.git
fi
echo "start to clone blinka"
if [[ ! -d "Adafruit_Blinka" ]]; then
    git clone https://github.com/walnutpi/Adafruit_Blinka.git
fi
echo "start to clone WiringPi"
if [[ ! -d "WiringPi" ]]; then
    git clone https://github.com/walnutpi/WiringPi.git
fi


echo "Adafruit_Blinka"
pip3 install -e Adafruit_Blinka/

echo "aw.gpio"
pip3 install -e aw.gpio/

echo "WiringPi"
cd WiringPi/
./build

