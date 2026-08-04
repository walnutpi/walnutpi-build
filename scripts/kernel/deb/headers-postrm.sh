#!/bin/bash
if [ "$1" = "remove" ]  ; then
    if [ -d /usr/src/linux-headers-${version} ]; then
        rm -r /usr/src/linux-headers-${version}
    fi
fi
