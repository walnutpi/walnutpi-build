#!/bin/bash
set -e

run_as_client_try_many () {
    local max_attempts=5
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

    echo "$output"
}

chmod 777 /opt

cd /opt

echo "start to clone aw.gpio"
run_as_client_try_many  git clone https://github.com/sc-bin/aw.gpio.git
echo "start to clone blinka"
run_as_client_try_many  git clone https://github.com/walnutpi/Adafruit_Blinka.git
echo "start to clone WiringPi"
run_as_client_try_many  git clone https://github.com/walnutpi/WiringPi.git


echo "Adafruit_Blinka"
run_as_client_try_many  pip3 install -e Adafruit_Blinka/
echo "aw.gpio"
run_as_client_try_many  pip3 install -e aw.gpio/
echo "WiringPi"
cd WiringPi/
run_as_client_try_many  ./build

echo "end"
