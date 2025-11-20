# walnutpi-build
为核桃派构建系统镜像，我们发布的所有镜像都是用这个做出来的。有问题可以加qq群`677173708`
- 在ubuntu22.04上运行，或使用docker运行
- 运行时要从github下载东西，请确保网络畅通

## 构建镜像
运行本脚本前先安装好两个软件
```shell
sudo apt install whiptail bc
```

clone项目到本地
```shell
git clone -b main --depth 1 https://github.com/walnutpi/walnutpi-build.git
```

运行构建脚本
```shell
cd walnutpi-build
sudo ./build.sh

# 如果本机有安装docker，建议使用docker-build.sh
# sudo ./docker-build.sh
```

在命令行出来的界面里，按`Esc`退出，`上下方向键`选择,按`回车`确认

1. 选择板子，按回车确认，目前支持
    - walnutpi-1b
    - walnutpi-2b
2. 选择系统版本，目前主要维护 debian12，其他系统版本都处于测试阶段
3. 选择系统类型，目前支持
    - server: 无桌面。
    - desktop: 在server版本基础上安装了xfce4桌面，预装了用于编程办公的桌面应用。


## 修改配置
在board文件夹下是各个板子的配置文件
### 修改系统的预装软件
以walnut2b，debian12为例，配置文件位于 **board/walnutpi-2b/debian12** 下，有5个文件：apt-base, apt-desktop, pip, wpi-base, wpi-desktop

apt-base 和 apt-desktop 文件用于设置构建系统时会安装的软件，apt-base是server版和desktop版本系统都会安装的软件，apt-desktop

pip 文件用于设置构建系统时会安装的python库

wpi-base 和 wpi-desktop 文件也是用于设置构建系统时会安装的软件，但不同的是这些软件会从 apt.walnutpi.con 下载，这些包的内容都是我们制作的系统配置或是我们制作的库，我们将其存放在一个项目中 -> [wpi-update-server](https://github.com/walnutpi/wpi-update-server)

