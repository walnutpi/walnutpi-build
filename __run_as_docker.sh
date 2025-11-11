#!/bin/bash

DOCKER_IMAGE_NAME=walnutpi-build:1.1
CONTAINER_NAME="walnutpi-build-$(date +%s)"

echo_red() {
    echo -e -n "\r\033[31m$1\033[0m"
}
echo_green() {
    echo -e -n "\r\033[32m$1\033[0m"
}
echo_blue() {
    echo -e -n "\r\033[36m$1\033[0m"
}

echo_green "[创建镜像] \t"
if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${DOCKER_IMAGE_NAME}$"; then
    echo "'$DOCKER_IMAGE_NAME' 已存在"
else
    echo "'$DOCKER_IMAGE_NAME' 不存在，开始构建..."
    docker build -t $DOCKER_IMAGE_NAME .
fi

# 判断是否传入参数
if [ $# -eq 0 ]; then
    # 没有传入参数，进入交互模式
    echo_green "[进入容器]\t"
    echo "启动交互式容器..."
    
    docker run --name "$CONTAINER_NAME" \
    --privileged \
    --network host \
    -v /etc/hosts:/etc/hosts:ro \
    -v /etc/resolv.conf:/etc/resolv.conf:ro \
    -v /etc/localtime:/etc/localtime:ro \
    -v "$(pwd):$(pwd)" \
    -w "$(pwd)" \
    -it --rm "$DOCKER_IMAGE_NAME" bash
else
    # 传入了参数，将所有参数作为命令执行
    RUN_COMMAND="$@"
    echo_green "[运行]\t"
    echo "$RUN_COMMAND"
    
    docker run --name "$CONTAINER_NAME" \
    --privileged \
    --network host \
    -v /etc/hosts:/etc/hosts:ro \
    -v /etc/resolv.conf:/etc/resolv.conf:ro \
    -v /etc/localtime:/etc/localtime:ro \
    -v "$(pwd):$(pwd)" \
    -w "$(pwd)" \
    -it --rm "$DOCKER_IMAGE_NAME" bash -c "$RUN_COMMAND"
fi