#!/bin/bash

menustr="walnutpi-build"
backtitle="Walnut Pi building script"

# 继续你的脚本逻辑
show_menu() {
    local title="$1"
    shift
    local options=("$@")
    TTY_X=$(($(stty size | awk '{print $2}') - 6)) # determine terminal width
    TTY_Y=$(($(stty size | awk '{print $1}') - 6)) # determine terminal height
    TTY_Y_WINDOW=$((TTY_Y - 8))
    if [ "$TTY_X" -le 0 ] || [ "$TTY_Y" -le 0 ] || [ "$TTY_Y_WINDOW" -le 0 ]; then
        echo -e "Error: Your terminal is too small \n"
        exit 1
    fi
    whiptail --title "${title}" --backtitle "${backtitle}" --notags \
        --menu "${menustr}" "${TTY_Y}" "${TTY_X}" ${TTY_Y_WINDOW} \
        --cancel-button Exit --ok-button Select "${options[@]}" \
        3>&1 1>&2 2>&3

}

MENU_choose_board() {
    # 获取路径下所有文件夹名作为选项
    local path_board_list=$1
    dirs=$(find ${path_board_list} -mindepth 1 -maxdepth 1 -type d)
    local options=()
    for dir in $dirs; do
        dirname=$(basename "$dir")
        options+=("$dir" "$dirname")
    done
    local titlestr="Choose Board"
    show_menu "${titlestr}" "${options[@]}"
}

MENU_sikp_boot() {
    local titlestr="recompile the bootloader ?"
    local options=(
        "$OPT_NO" "no"
        "$OPT_YES" "yes"
    )
    show_menu "${titlestr}" "${options[@]}"
}

MENU_sikp_kernel() {
    local titlestr="recompile the KERNEL ?"
    local options=(
        "$OPT_NO" "no"
        "$OPT_YES" "yes"
    )
    show_menu "${titlestr}" "${options[@]}"
}

# 传入板级配置路径，只显示存在配置项的os版本
MENU_choose_os() {
    board_conf_dir="$1"
    titlestr="Choose an os version"

    local options=()
    
    local os_configs=(
        "${OPT_os_debian13} debian 13(trixie)"
        "${OPT_os_debian12} debian 12(bookworm)"
        "${OPT_os_debian11} debian 11(bullseye)"
        "${OPT_os_ubuntu22} ubuntu 22.04(Jammy Jellyfish)"
        "${OPT_os_ubuntu24} ubuntu 24.04(Noble Numbat)"
        "${OPT_os_debian12_burn} emmc burner(debian 12)"
    )
    
    for config in "${os_configs[@]}"; do
        set -- $config
        local dir_name="$1"
        shift 1
        local display_text="$*"
        
        if [ -d "${board_conf_dir}/${dir_name}" ]; then
            options+=("$dir_name" "$display_text")
        fi
    done

    show_menu "${titlestr}" "${options[@]}"
}

MENU_choose_rootfs_type() {
    titlestr="Server or Graphics"
    options+=("$OPT_rootfs_server" "server")
    options+=("$OPT_rootfs_desktop" "desktop")
    show_menu "${titlestr}" "${options[@]}"
}

MENU_choose_img_file() {
    titlestr="choose an img file"
    for file in $PATH_OUTPUT/*.img; do
        local creation_time=$(stat -c %Y "$file")
        options+=("$creation_time:$file")
    done

    IFS=$'\n' sorted_options=($(for item in "${options[@]}"; do echo "$item"; done | sort -r | cut -d: -f2))
    unset IFS

    options=()
    for file in "${sorted_options[@]}"; do
        local name=$(basename "$file")
        options+=("$name" "$name")
    done

    show_menu "${titlestr}" "${options[@]}"
}
