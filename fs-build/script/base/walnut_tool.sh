#!/bin/bash
set -e

chmod 777 /opt

cd /opt

echo "Adafruit_Blinka"
pip3 install -e Adafruit_Blinka/

echo "aw.gpio"
pip3 install -e aw.gpio/

echo "WiringPi"
cd WiringPi/
./build

