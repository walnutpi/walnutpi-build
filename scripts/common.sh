#!/bin/bash

# 获取sudo运行脚本前是什么用户，然后以那个用户的权限执行指令
run_as_user() {
    local original_user=$(who am i | awk '{print $1}')
    if [  -z $original_user ]; then
        bash -c "$*"
    else
        sudo -u $original_user bash -c "$*"
    fi
}
exit_if_last_error() {
    if [[ $? -ne 0 ]]; then
        echo "上一条命令执行失败，脚本将退出。"
        exit 1
    fi
}

run_as_silent() {
    $@ > /dev/null 2>&1
}


run_slient_when_successfuly() {
    local output
    output=$("$@" 2>&1)
    local exit_status=$?
    if [ $exit_status -ne 0 ]; then
        echo "$output"
    fi
}

create_dir() {
    local directory_path=$1
    if [ ! -d "$directory_path" ]; then
        run_as_user mkdir -p "$directory_path"
    fi
}



run_status() {
    local message=$1
    shift
    local max_retries=5
    local retry_delay=5
    local retries=0
    local start_time=$(date +%s)
    
    while [ $retries -lt $max_retries ]; do
        echo -e -n "...\t$message"
        local output
        output=$("$@" 2>&1)
        local exit_status=$?
        if [ $exit_status -ne 0 ]; then
            echo -e "\r\033[31m[error]\033[0m"
            echo -e "$output"
            echo -e "Retrying in $retry_delay seconds..."
            sleep $retry_delay
            retry_delay=$((retry_delay + 5))
            ((retries++))
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            echo -e "\r\033[32m[ok]\033[0m\t${message}\t${duration}s"
            break
        fi
    done
    
    if [ $retries -eq $max_retries ]; then
        echo -e "\r\033[31m[error]\033[0m\t$message - Maximum retries reached."
        exit $exit_status
    fi
}

run_status_no_retry() {
    local message=$1
    shift
    local start_time=$(date +%s)
    
    echo -e -n "...\t$message"
    local output
    output=$("$@" 2>&1)
    local exit_status=$?
    if [ $exit_status -ne 0 ]; then
        echo -e "\r\033[31m[error]\033[0m"
        echo -e "$output"
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "\r\033[32m[ok]\033[0m\t${message}\t${duration}s"
    fi
    
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
    local dir_name=$(basename "$git_url" .git)
    
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
    
    local dir_name=$(basename "$git_url" .git)
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

cp_file_if_exsit() {
    local file_path_source=$1
    local file_path_desc=$2
    if [ -f $file_path_source ];then
        cp $file_path_source $file_path_desc
    fi
}