#!/bin/bash
set -e
sed -i 's/_proc.kill()/_proc.terminate()/g' /usr/lib/python3/dist-packages/thonny/running.py
