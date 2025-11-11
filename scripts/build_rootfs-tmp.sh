

add_file_to_tmp_rootfs() {
    local source_file=$1
    local dest_path=$2
    if [[ -f "$source_file" ]]; then
        if [[ -d "$dest_path" ]]; then
            rm -r "$dest_path"
        fi
        mkdir -p "$dest_path"
        run_status "copy $(basename $source_file) to $dest_path" cp "$source_file" "$dest_path"
    fi
}

add_emmc_burn_file(){
    local source_file=$1
    add_file_to_tmp_rootfs ${source_file} "${TMP_rootfs_build}/opt/burn"
}
