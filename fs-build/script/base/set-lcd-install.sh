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


run_as_client_try_many git clone https://github.com/walnutpi/set-lcd.git

cd set-lcd
chmod +x install
./install