
FROM ubuntu:22.04

# 以无交互的方式安装软件
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
    gcc-aarch64-linux-gnu \
    gcc-arm-none-eabi \
    cmake \
    debian-archive-keyring \
    curl \
    whiptail \
    bc \
    qemu-user-static \
    debootstrap \
    kpartx \
    git \
    bison \
    flex \
    swig \
    libssl-dev \
    device-tree-compiler \
    u-boot-tools \
    make \
    python3 \
    python3-dev \
    python3-pip \
    sudo \
    libpam-runtime \
    dosfstools \
    parted  \
    build-essential \
    xz-utils && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 创建用户 pi 密码为 pi
RUN useradd -m -s /bin/bash pi && \
echo "pi:pi" | chpasswd

#  pi 用户运行sudo不需要输入密码
RUN mkdir -p /etc/sudoers.d
RUN echo "pi ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/pi && \
    chmod 0440 /etc/sudoers.d/pi

RUN pip3 install setuptools
