#!/bin/bash
set -e

gcc Python.c -o Python
mv Python /usr/bin/
chmod 4755 /usr/bin/Python
rm Python.c

gcc Python3.c -o Python3
mv Python3 /usr/bin/
chmod 4755 /usr/bin/Python3
rm Python3.c


