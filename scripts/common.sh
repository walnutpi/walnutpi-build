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

# run_status() {
#     echo -e  -n "...\t$1"
#     shift
#     output=$("$@" 2>&1)
#     exit_status=$?
#     if [ $exit_status -ne 0 ]; then
#         echo -e "\r\033[31m[error]\033[0m"
#         echo -e $output
#         exit 1
#     else
#         echo -e "\r\033[32m[ok]\033[0m"
#     fi
# }
run_status() {
    local message=$1
    shift
    set +e
    while true; do
        echo -e  -n "...\t$message"
        output=$("$@" 2>&1)
        exit_status=$?
        if [ $exit_status -ne 0 ]; then
            echo -e "\r\033[31m[error]\033[0m"
            echo -e $output
            sleep 3
        else
            echo -e "\r\033[32m[ok]\033[0m"
            break
        fi
    done
    set -e
}

run_status_piped() {
    echo -e  -n "...\t$1"
    shift
    output=$(eval "$@" 2>&1)
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
        echo -e "\r\033[31m[error]\033[0m"
        echo -e $output
        exit 1
    else
        echo -e "\r\033[32m[ok]\033[0m"
    fi
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

_try_command() {
    set +e
    "$@" >/dev/null 2>&1
    set -e
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