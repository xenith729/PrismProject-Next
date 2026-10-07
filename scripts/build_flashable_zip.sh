#!/usr/bin/env bash
# Copyright (c) 2026 Salvo Giangreco
# SPDX-License-Identifier: GPL-3.0-or-later

# [
source "$SRC_DIR/scripts/utils/build_utils.sh" || exit 1

INCREMENTAL=false
SOURCE_ZIP=""
TARGET_ZIP=""
OUTPUT_FILE=""

PREPARE_SCRIPT()
{
    if [[ "$#" == 0 ]]; then
        PRINT_USAGE
        exit 1
    fi

    while [[ "$1" == "-"* ]]; do
        if [[ "$1" == "--incremental" ]] || [[ "$1" == "-i" ]]; then
            INCREMENTAL=true
            shift; SOURCE_ZIP="$1"
        elif [[ "$1" == "--output" ]] || [[ "$1" == "-o" ]]; then
            shift; OUTPUT_FILE="$1"
            if [[ "$OUTPUT_FILE" != *".zip" ]]; then
                LOGE "출력 파일은 \".zip\" 확장자여야 합니다."
                exit 1
            fi
        else
            LOGE "알 수 없는 옵션입니다: $1"
            exit 1
        fi

        shift
    done

    TARGET_ZIP="$1"
    if [ ! "$TARGET_ZIP" ]; then
        PRINT_USAGE
        exit 1
    elif [ ! -f "$TARGET_ZIP" ]; then
        LOGE "파일이 존재하지 않습니다: ${TARGET_ZIP//$SRC_DIR\//}"
        exit 1
    fi

    if [ "$SOURCE_ZIP" ]; then
        if [ ! -f "$SOURCE_ZIP" ]; then
            LOGE "파일이 존재하지 않습니다: ${SOURCE_ZIP//$SRC_DIR\//}"
            exit 1
        fi
    fi

    if [ ! "$OUTPUT_FILE" ]; then
        local TARGET_BUILD_INFO

        EVAL "unzip -p \"$TARGET_ZIP\" \"build_info.txt\"" || exit 1
        TARGET_BUILD_INFO="$(unzip -p "$TARGET_ZIP" "build_info.txt")"

        OUTPUT_FILE="$OUT_DIR/PrismProject-Next_v"
        OUTPUT_FILE+="$(grep "^version" <<< "$TARGET_BUILD_INFO" | cut -d "=" -f 2 -s)"
        OUTPUT_FILE+="_"
        OUTPUT_FILE+="$(grep "^device" <<< "$TARGET_BUILD_INFO" | cut -d "=" -f 2 -s)"
        if $INCREMENTAL; then
            local SOURCE_BUILD_INFO

            EVAL "unzip -p \"$SOURCE_ZIP\" \"build_info.txt\"" || exit 1
            SOURCE_BUILD_INFO="$(unzip -p "$SOURCE_ZIP" "build_info.txt")"

            OUTPUT_FILE+="_INCREMENTAL_"
            OUTPUT_FILE+="$(grep "^timestamp" <<< "$SOURCE_BUILD_INFO" | cut -d "=" -f 2 -s)"
        fi
        if ! $DEBUG || $ROM_IS_OFFICIAL; then
            OUTPUT_FILE+="_signed"
        fi
        OUTPUT_FILE+=".zip"
    fi
}

PRINT_USAGE()
{
    echo "사용 예제: build_flashable_zip [options] <file>" >&2
    echo " -i, --incremental : 주어진 target-files zip을 소스로 사용하여 incremental zip을 생성합니다." >&2
    echo " -o, --output : 출력 zip 경로를 설정합니다, 기본값은 $OUT_DIR 입니다." >&2
}
# ]

PREPARE_SCRIPT "$@"

if $INCREMENTAL; then
    "$SRC_DIR/scripts/internal/build_incremental_ota_zip.sh" "$SOURCE_ZIP" "$TARGET_ZIP" "$OUTPUT_FILE" || exit 1
else
    "$SRC_DIR/scripts/internal/build_full_ota_zip.sh" "$TARGET_ZIP" "$OUTPUT_FILE" || exit 1
fi

exit 0
