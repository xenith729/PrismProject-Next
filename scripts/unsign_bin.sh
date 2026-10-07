#!/usr/bin/env bash
# Copyright (c) 2023 Salvo Giangreco
# SPDX-License-Identifier: GPL-3.0-or-later

# [
source "$SRC_DIR/scripts/utils/build_utils.sh" || exit 1
# ]

if [ "$#" == 0 ]; then
    echo "사용 예제: unsign_bin <이미지> (<이미지>...)" >&2
    exit 1
fi

while [ "$#" != 0 ]; do
    if [ ! -f "$1" ]; then
        LOGE "파일이 존재하지 않습니다: $1"
        exit 1
    else
        if avbtool info_image --image "$1" &> /dev/null; then
            LOG "- $(basename "$1")에서 AVB 푸터 제거 중..."
            avbtool erase_footer --image "$1"
        fi
        if head "$1" | grep -q "SignerVer"; then
            LOG "- $(basename "$1")에서 삼성 헤더 서명 제거 중..."
            dd if="/dev/zero" of="$1" bs=256 seek=0 count=1 conv=notrunc &> /dev/null
            dd if="/dev/zero" of="$1" bs=256 seek=3 count=1 conv=notrunc &> /dev/null
        fi
        if tail "$1" | grep -q "SignerVer02"; then
            LOG "- $(basename "$1")에서 삼성 푸터 서명 제거 중..."
            truncate -s -512 "$1"
        fi
        if tail "$1" | grep -q "SignerVer03"; then
            LOG "- $(basename "$1")에서 삼성 푸터 서명 제거 중..."
            truncate -s -784 "$1"
        fi
    fi

    shift
done

exit 0
