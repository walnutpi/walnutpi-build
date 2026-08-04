#!/bin/sh
if [ -d "/tmp-boot/dtb" ] && [ -d "/boot/" ]; then
    cd "/tmp-boot/dtb" || exit 1
    find . -type f | while read relpath; do
        relpath=${relpath#./}
        target_path="/boot/$relpath"
        if [ -f "$target_path" ]; then
            rm -f "$target_path"
        fi
    done
    cd - >/dev/null 2>&1
fi
