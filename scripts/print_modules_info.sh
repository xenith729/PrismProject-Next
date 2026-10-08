#!/usr/bin/env bash
# Copyright (c) 2023 Salvo Giangreco
# SPDX-License-Identifier: GPL-3.0-or-later

# [
source "$SRC_DIR/scripts/utils/log_utils.sh"

PRINT_MODULE_INFO()
{
    local MODPATH="$1"
    local MODNAME
    local MODAUTH
    local MODDESC

    if [ ! -d "$MODPATH" ]; then
        LOGE "폴더가 존재하지 않습니다: $MODPATH"
        exit 1
    fi

    if [ -d "$MODPATH/$TARGET_OS_SINGLE_SYSTEM_IMAGE" ]; then
        MODPATH="$MODPATH/$TARGET_OS_SINGLE_SYSTEM_IMAGE"
    fi

    if [ ! -f "$MODPATH/module.prop" ]; then
        LOGE "파일이 존재하지 않습니다: $MODPATH/module.prop"
        exit 1
    elif [ -f "$MODPATH/disable" ]; then
        return 0
    else
        MODNAME="$(grep "^name" "$MODPATH/module.prop" | sed "s/name=//")"
        MODAUTH="$(grep "^author" "$MODPATH/module.prop" | sed "s/author=//")"
        MODDESC="$(grep "^description" "$MODPATH/module.prop" | sed "s/description=//")"
    fi

    ((MODULES_COUNT+=1))

    LOG "-- 모듈 $MODULES_COUNT:"
    LOG "이름: $MODNAME"
    LOG "제작자: $MODAUTH"
    [ "$MODDESC" ] && LOG "설명: $MODDESC"
}
#]

if [ "$#" -gt 0 ]; then
    echo "사용 예제: print_modules_info" >&2
    echo "이 스크립트는 어떤 인수도 받지 않습니다." >&2
    exit 1
fi

MODULES_COUNT=0

while read -r i; do
    PRINT_MODULE_INFO "$i"
done <<< "$(find "$SRC_DIR/unica/patches" -mindepth 1 -maxdepth 1 -type d)"

while read -r i; do
    PRINT_MODULE_INFO "$i"
done <<< "$(find "$SRC_DIR/unica/mods" -mindepth 1 -maxdepth 1 -type d)"

while read -r i; do
    PRINT_MODULE_INFO "$i"
done <<< "$(find "$SRC_DIR/target/$TARGET_CODENAME/patches" -mindepth 1 -maxdepth 1 -type d)"

exit 0
