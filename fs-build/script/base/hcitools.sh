#!/bin/bash
set -e

git clone https://github.com/walnutpi/hcitools.git

cd hcitools
make
make install