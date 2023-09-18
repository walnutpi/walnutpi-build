#!/bin/bash
set -e

mkdir -p /home/pi/.config/Thonny/
chown -R pi:pi /home/pi/.config/

touch /home/pi/.config/Thonny/backend.log
chown -R pi:pi /home/pi/.config/Thonny/backend.log

touch /home/pi/.config/Thonny/frontend_faults.log
chown -R pi:pi /home/pi/.config/Thonny/frontend_faults.log