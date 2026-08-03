#!/bin/bash
# 直接放置
configtxt_place() {
    cp -r /tmp-boot/boot-configtxt/* /boot/

}
# walnutpi-1b 20260520 之后的版本增加了screen配置项
# 用于此次升级的补丁
handle_screen_migration() {
    local dest="$1"
    local src="$2"
    
    # 检查src中是否有screen配置项
    local has_screen_in_src=false
    if grep -q "^screen=" "$src"; then
        has_screen_in_src=true
    fi
    
    # 检查dest中是否有screen配置项
    local has_screen_in_dest=false
    if grep -q "^screen=" "$dest"; then
        has_screen_in_dest=true
    fi
    
    # 只有当src中有screen但dest中没有时，才需要迁移
    if $has_screen_in_src && ! $has_screen_in_dest; then
        # 读取dest中的overlays配置项
        local overlays_value=""
        while IFS= read -r line; do
            if [[ "$line" =~ ^overlays=(.*)$ ]]; then
                overlays_value="${BASH_REMATCH[1]}"
                break
            fi
        done < "$dest"
        
        # 根据overlays中的值决定screen的配置
        local new_screen_value=""
        if echo "$overlays_value" | grep -qw "tft35"; then
            new_screen_value="lcd35-st7796"
        elif echo "$overlays_value" | grep -qw "tft15"; then
            new_screen_value="lcd15-st7789"
        fi
        
        # 如果找到了对应的屏幕类型，更新src文件中的screen配置项
        if [ -n "$new_screen_value" ]; then
            sed -i "s/^screen=.*/screen=${new_screen_value}/" "$src"
        fi
    fi
}

# 比较配置
configtxt_compare() {
    dest="/boot/config.txt"
    src="/tmp-boot/boot-configtxt/config.txt"
    
    # 处理screen配置项迁移,针对walnutpi-1b从20260520前版本升级
    handle_screen_migration "$dest" "$src"
    
    # 创建临时文件用于构建新的配置文件
    tmp_file=$(mktemp)
    
    # 读取dest中的配置项到关联数组
    declare -A old_config
    while IFS= read -r line; do
        # 跳过空行和注释行
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # 提取配置项名称和值
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            old_config["$key"]="$value"
        fi
    done < "$dest"
    
    # 遍历src文件，第一行也跳过
    first_line=true
    while IFS= read -r line; do
        # 跳过第一行
        if $first_line; then
            first_line=false
            echo "$line" >> "$tmp_file"
            continue
        fi
        
        # 跳过空行和注释行，直接写入
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            echo "$line" >> "$tmp_file"
            continue
        fi
        
        # 提取配置项名称
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            # 检查dest中是否有相同的配置项
            if [[ -n "${old_config[$key]+x}" ]]; then
                # 有相同配置项，使用dest中的值
                echo "${key}=${old_config[$key]}" >> "$tmp_file"
            else
                # 没有相同配置项，使用src中的值
                echo "$line" >> "$tmp_file"
            fi
        else
            # 不是配置项格式的行，直接写入
            echo "$line" >> "$tmp_file"
        fi
    done < "$src"
    
    # 将新配置写回dest
    cp "$tmp_file" "$dest"
    rm -f "$tmp_file"
}
case "$1" in
    configure)
        old_version="$2"
        new_version="$3"
        echo "Updating from version $old_version to version $new_version"
        if [ ! -f /boot/config.txt ]; then
            configtxt_place
        else
            configtxt_compare
        fi
        
        set-device

        BLOCK_DEVICE=$(findmnt "/" -o SOURCE -n)
        ROOTFS_PARTUUID=$(blkid -s PARTUUID -o value $BLOCK_DEVICE)
        if [ -z "$ROOTFS_PARTUUID" ]; then
            echo "无法解析出uuid"
            exit
        fi
        echo "rootdev=PARTUUID=${ROOTFS_PARTUUID}" | sudo tee -a /boot/config.txt


        ;;
    abort-upgrade|abort-remove|abort-deconfigure)
        ;;

esac
exit 0