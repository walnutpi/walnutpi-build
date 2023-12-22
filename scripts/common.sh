#!/bin/bash

# 获取sudo运行脚本前是什么用户，然后以那个用户的权限执行指令
run_as_user() {
    local original_user=$(who am i | awk '{print $1}')
    sudo -u $original_user bash -c "$*"
}
exit_if_last_error() {
    if [[ $? -ne 0 ]]; then
        echo "上一条命令执行失败，脚本将退出。"
        exit 1
    fi
}

run_as_client() {
    $@ > /dev/null 2>&1
}


run_client_when_successfuly() {
    output=$("$@" 2>&1)
    if [ $? -ne 0 ]; then
        echo "$output"
    fi
}

create_dir() {
    directory_path=$1
    if [ ! -d "$directory_path" ]; then
        run_as_user mkdir -p "$directory_path"
    fi
}



run_status() {
    local message=$1
    shift
    # set +e
    start_time=$(date +%s)
    while true; do
        echo -e  -n "...\t$message"
        output=$("$@" 2>&1)
        exit_status=$?
        if [ $exit_status -ne 0 ]; then
            echo -e "\r\033[31m[error]\033[0m"
            echo -e $output
            sleep 3
        else
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            echo -e "\r\033[32m[ok]\033[0m\t${message}\t${duration}s"
            break
        fi
    done
    # set -e
}


mount_chroot()
{
    local target=$1
    mount -t proc chproc "${target}"/proc
    mount -t sysfs chsys "${target}"/sys
    mount -t devtmpfs chdev "${target}"/dev || mount --bind /dev "${target}"/dev
    mount -t devpts chpts "${target}"/dev/pts
}

umount_chroot()
{
    local target=$1
    while grep -Eq "${target}.*(dev|proc|sys)" /proc/mounts
    do
        umount -l --recursive "${target}"/dev >/dev/null 2>&1
        umount -l "${target}"/proc >/dev/null 2>&1
        umount -l "${target}"/sys >/dev/null 2>&1
        sleep 5
    done
}




clone_url() {
    local git_url="$1"
    dir_name=$(basename "$git_url" .git)
    
    if [ -d "$dir_name" ]; then
        cd "$dir_name"
        run_as_user git config --global --add safe.directory $(pwd)
        echo "pull : $git_url" 
        run_as_user git pull
    else
        echo "clone : $git_url" 
        run_as_user git clone $git_url
    fi
}
clone_branch() {
    local git_url="$1"
    local branch="$2"

    dir_name=$(basename "$git_url" .git)
    [[ -n $3 ]] && dir_name=$3
    
    if [ -d "$dir_name" ]; then
        cd "$dir_name"
        run_as_user git config --global --add safe.directory $(pwd)
        echo "pull : $git_url" 
        run_as_user git pull
    else
        echo "clone : $git_url" 
        run_as_user git clone -b $branch  $git_url $dir_name
    fi
}