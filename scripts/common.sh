#!/bin/bash


exit_if_last_error() {
    if [[ $? -ne 0 ]]; then
        echo "上一条命令执行失败，脚本将退出。"
        exit 1
    fi
}


run_client_when_successfuly() {
    output=$("$@" 2>&1)
    if [ $? -ne 0 ]; then
        echo "$output"
    fi
}

run_as_client() {
    $@ > /dev/null 2>&1
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


run_as_client_try3() {
    local max_attempts=3
    local attempt=0
    local success=0
    
    while [[ $attempt -lt $max_attempts && $success -eq 0 ]]; do
        output=$("$@" 2>&1)
        if [ $? -eq 0 ]; then
            success=1
        else
            attempt=$((attempt + 1))
        fi
    done
    
    if [[ $success -eq 0 ]]; then
        echo "$output"
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
    local path="$1"
    local git_url="$2"
    local dir_name=$(basename "$git_url" .git)

    if [[ ! -z "$SUDO_USER" ]]; then
        user="$SUDO_USER"
    else
        user="$USER"
    fi

    sudo -u "$user" bash << EOF
        cd "$path"
        if [ -d "$dir_name" ]; then
            cd "$dir_name"
            git pull
        else
            git clone "$git_url"
        fi
EOF
}