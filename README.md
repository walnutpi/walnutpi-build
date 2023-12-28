walnutpi-build
======
为核桃派编译系统镜像。有问题可以加qq群`677173708`
- 需要在ubuntu22.04上运行
- toolchain会在运行时从清华源下载
- 运行时要从github下载东西，请确保网络畅通

本项目在`2023-10-23`的`v1.2版本`之后，进行了一次大改，将所有配置脚本都做成独立deb包存放到另一个项目 -> [walnutpi-debs](https://github.com/walnutpi/walnutpi-debs) ,在运行本项目进行构建时，会从我们假设的apt服务器那边下载这些配置包


0. 运行本脚本前先安装好两个软件
```
sudo apt install whiptail bc
```

1. clone
------
```
git clone -b main --depth 1 https://github.com/walnutpi/walnutpi-build.git
```

2. run
------
```
sudo ./build.sh
```
在命令行出来的界面里，按`Esc`退出，`上下方向键`选择,按`回车`确认
![run_build.sh](.pictures/run_build.gif)

第一个页面是选择板子，按回车确认，目前支持
- walnutpi-1b

------
![choose](.pictures/Compilation_Options.png)
- image: 自动构建完整镜像。生成一个`IMG_xxx.img镜像`文件输出到output目录
- U-boot bin: 仅编译ubuntu项目，将编译结果输出到output目录
- Kernel bin: 编译linux项目，并制作一个deb包。包的内容包括驱动模块、设备树、/boot文件夹下应有的所有数据。
- Rootfs tar: 构建一个可用的rootfs，装好所需软件，驱动，各种配置，压缩成一个`rootfs_xxx.tar`输出到output目录

------
![choose](.pictures/choose_server_desktop.png)
- server: 无桌面，启动快，基本功能都可以玩。
- desktop: 在server版本基础上安装了xfce4桌面，预装了用于编程办公的桌面应用，玩法更多。



