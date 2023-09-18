#!/bin/bash
set -e

wget https://downloads.realvnc.com/download/file/viewer.files/VNC-Viewer-7.6.0-Linux-ARM64.deb
dpkg -i VNC-Viewer-7.6.0-Linux-ARM64.deb
rm VNC-Viewer-7.6.0-Linux-ARM64.deb

