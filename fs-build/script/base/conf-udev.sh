#!/bin/bash
set -e

mv 99-dev-pi.rules /etc/udev/rules.d/

chmod 644 /etc/udev/rules.d/99-dev-pi.rules