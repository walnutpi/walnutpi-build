欢迎加入核桃派的qq群`677173708`

# walnutpi-build
本项目用于构建系统镜像，我们发布的所有系统镜像都是用这个构建出来的。
- 在ubuntu22.04上运行，或使用docker运行
- 运行时要从github下载东西，请确保网络畅通

## 构建镜像
clone项目到本地
```shell
git clone -b main --depth 1 https://github.com/walnutpi/walnutpi-build.git
```

运行本脚本前先安装好两个软件
```shell
sudo apt install whiptail bc
```

运行构建脚本
```shell
cd walnutpi-build
sudo ./build.sh

# 如果本机有安装docker，建议使用本项目下的docker.sh，它可以创建一个docker环境运行指定脚本，比如使用docker来运行build.sh
# sudo ./docker.sh ./build.sh
```

在命令行出来的界面里，按`Esc`退出，`上下方向键`选择,按`回车`确认
1. 选择板子型号
2. 选择系统版本
3. 选择系统类型

主要支持的列表如下，没在表里的选项都是测试使用的，不保证功能

| 板子型号 | 系统版本 | 系统类型 |
| -------- | -------- | -------- |
| walnutpi-1b | debian12 | server |
| walnutpi-1b | debian12 | desktop |
| walnutpi-2b | debian12 | server |
| walnutpi-2b | debian12 | desktop |
| Cybercam | debian12 | server |

## 单独构建某个组件
| 脚本名称 | 功能 | 输出路径 |
| -------- | -------- | -------- |
| ./scripts/boot/build.sh | 单独编译boot | output/板名/boot/ 路径下生成 boot.bin bootbin-xxx.deb,configtxt-xxx.deb |
| ./scripts/kernel/build.sh | 单独编译kernel | output/板名/kernel/ kernel-dtb-xxx.deb, kernel-modules-xxx.deb kernel-image-xxx.deb kernel-headers-xxx.deb |
| ./scripts/rootfs/build.sh | 单独编译rootfs | output/板名/ rootfs-xxx.tar.gz|
| scripts/image/build.sh | 将output/板名/下的输出结果打包成镜像 | output/xxx.img|


## 修改配置
在board文件夹下是各个板子的配置文件
### 修改系统的预装软件
以walnut2b，debian12为例，配置文件位于 **board/walnutpi-2b/debian12** 下，有5个文件：apt-base, apt-desktop, pip, wpi-base, wpi-desktop

apt-base 和 apt-desktop 文件用于设置构建系统时会安装的软件，apt-base是server版和desktop版本系统都会安装的软件，apt-desktop

pip 文件用于设置构建系统时会安装的python库

wpi-base 和 wpi-desktop 文件也是用于设置构建系统时会安装的软件，但不同的是这些软件会从 apt.walnutpi.con 下载，这些包的内容都是我们制作的系统配置或是我们制作的库，我们将其存放在一个项目中 -> [wpi-update-server](https://github.com/walnutpi/wpi-update-server)

### 修改boot kernel
需要去 **source** 文件夹下找到使用的对应源码，进行修改
