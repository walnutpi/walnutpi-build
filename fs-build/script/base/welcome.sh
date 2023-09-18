#!/bin/bash
set -e


echo "开始安装welcome信息"
apt-get install -y toilet  

rm -rf /etc/update-motd.d/*
cp welcome/motd/* /etc/update-motd.d/
cp welcome/font/* /usr/share/figlet/
echo "" > /etc/motd

rm -r welcome