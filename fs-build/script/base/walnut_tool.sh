#!/bin/bash
set -e

run_as_client_try3() {
    local max_attempts=3
    local attempt=0
    local success=0

    while [[ $attempt -lt $max_attempts && $success -eq 0 ]]; do
        output=$("$@" 2>&1)
        if [ $? -eq 0 ]; then
            success=1
        else
            attempt=$((attempt + 1))
        fi
    done

    if [[ $success -eq 0 ]]; then
        echo "$output"
    fi
}

chmod 777 /opt

cd /opt

run_as_client_try3 git clone https://github.com/sc-bin/aw.gpio.git
run_as_client_try3 git clone https://github.com/walnutpi/Adafruit_Blinka.git
run_as_client_try3 git clone https://github.com/walnutpi/WiringPi.git


echo "Adafruit_Blinka"
pip3 install -e Adafruit_Blinka/
echo "aw.gpio"
pip3 install -e aw.gpio/
echo "WiringPi"
cd WiringPi/
./build


