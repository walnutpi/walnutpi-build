
FROM ubuntu:22.04

# 以无交互的方式安装软件
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update
RUN apt-get install -y gcc-aarch64-linux-gnu 
RUN apt-get install -y debian-archive-keyring curl whiptail bc qemu-user-static debootstrap kpartx git bison flex swig libssl-dev device-tree-compiler u-boot-tools make python3 python3-dev
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

