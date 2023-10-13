#!/bin/bash
set -e

echo "修改管理员密码"
password="root"
echo "$USER:$password" | chpasswd
cp .bashrc /root/

echo "创建pi用户"
useradd -m pi
echo "pi:pi" |  chpasswd
usermod -aG sudo pi
cp .bashrc /home/pi/
sed -i 's|/home/pi:/bin/sh|/home/pi:/bin/bash|g' /etc/passwd

echo "Defaults rootpw" |  tee -a /etc/sudoers
echo "pi ALL=(ALL) NOPASSWD:ALL" |  tee -a /etc/sudoers
echo "Defaults !env_reset" |  tee -a /etc/sudoers


# 赋予权限
chown pi:pi /home/pi/
chmod u+s /bin/su
chown pi:pi /home/pi/.bashrc
chown root:root /usr/bin/sudo
chmod 4755 /usr/bin/sudo

rm .bashrc


