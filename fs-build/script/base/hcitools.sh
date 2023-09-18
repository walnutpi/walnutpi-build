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


run_as_client_try3 git clone https://github.com/walnutpi/hcitools.git

cd hcitools
make
make install