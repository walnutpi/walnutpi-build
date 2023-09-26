#!/bin/bash
set -e

run_as_client() {
    $@ > /dev/null 2>&1
}

git clone https://github.com/walnutpi/hcitools.git

cd hcitools
make
make install