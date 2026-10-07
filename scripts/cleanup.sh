#!/usr/bin/env bash
# Copyright (c) 2023 Salvo Giangreco
# SPDX-License-Identifier: GPL-3.0-or-later

# [
source "$SRC_DIR/scripts/utils/log_utils.sh"

PRINT_USAGE()
{
    echo "사용 예제: cleanup <유형> (<유형>...)" >&2
    echo " - all ($OUT_DIR)" >&2
    echo " - odin ($ODIN_DIR)" >&2
    echo " - fw ($FW_DIR)" >&2
    echo " - work_dir ($WORK_DIR)" >&2
    echo " - logs ($OUT_DIR/**.log)" >&2
    echo " - tools ($TOOLS_DIR)" >&2
}
# ]

if [ "$#" == 0 ]; then
    PRINT_USAGE
    exit 1
fi

while [ "$#" != 0 ]; do
    case "$1" in
        "all")
            LOG "- 모두 삭제 중..."
            rm -rf "$OUT_DIR"
            break
            ;;
        "odin")
            LOG "- Odin 펌웨어 디렉토리 삭제 중..."
            rm -rf "$ODIN_DIR"
            ;;
        "fw")
            LOG "- 추출된 펌웨어 디렉토리 삭제 중..."
            rm -rf "$FW_DIR"
            ;;
        "work_dir")
            LOG "- ROM 작업 디렉토리 삭제 중..."
            rm -rf "$(dirname "$WORK_DIR")"
            mkdir -p "$(dirname "$WORK_DIR")"
            ;;
        "logs")
            LOG "- 로그 파일 삭제 중..."
            find "$OUT_DIR" -type f -name "*.log" -delete
            ;;
        "tools")
            LOG "- 종속성 디렉토리 삭제 중..."
            rm -rf "$TOOLS_DIR"
            git submodule foreach --recursive "git clean -f -d -x" &> /dev/null
            ;;
        *)
            LOGE "\"$1\"은(는) 유효하지 않습니다."
            PRINT_USAGE
            exit 1
        ;;
    esac

    shift
done

exit 0
