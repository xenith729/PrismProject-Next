#!/usr/bin/env bash
# Copyright (c) 2025 Salvo Giangreco
# SPDX-License-Identifier: GPL-3.0-or-later

# [
source "$SRC_DIR/scripts/utils/build_utils.sh" || exit 1

FRAMEWORK_DIR="$TOOLS_DIR/apktool/framework"
FRAMEWORK_TAG="$(GET_PROP "system" "ro.build.version.incremental")"

FORCE=false
JOBS="1"
PARTITION=""
FILE=""

HEAP_SIZE=""
THREAD_COUNT=""
INPUT_FILE=""
OUTPUT_PATH=""

BUILD()
{
    if [ ! -d "$OUTPUT_PATH" ]; then
        LOGE "폴더가 존재하지 않습니다: ${OUTPUT_PATH//$SRC_DIR\//}"
        exit 1
    fi

    LOG "- Building ${INPUT_FILE//$WORK_DIR/}"

    # 원본 META-INF 복사
    mkdir -p "$OUTPUT_PATH/build/apk"
    cp -a "$OUTPUT_PATH/original/META-INF" "$OUTPUT_PATH/build/apk/META-INF"

    # --shorten-resource-paths와 함께 APK 빌드 (https://developer.android.com/tools/aapt2#optimize_options)
    EVAL "apktool -JXmx${HEAP_SIZE}m b -j \"$THREAD_COUNT\" -p \"$FRAMEWORK_DIR\" -srp \"$OUTPUT_PATH\"" || exit 1

    local FILE_NAME
    FILE_NAME="$(basename "$INPUT_FILE")"

    if [[ "$INPUT_FILE" == *".apk" ]]; then
        local CERT_PREFIX="aosp"
        $ROM_IS_OFFICIAL && CERT_PREFIX="unica"

        LOG "- ${INPUT_FILE//$WORK_DIR/} 서명 중..."
        EVAL "signapk \"$SRC_DIR/security/${CERT_PREFIX}_platform.x509.pem\" \"$SRC_DIR/security/${CERT_PREFIX}_platform.pk8\" \"$OUTPUT_PATH/dist/$FILE_NAME\" \"$OUTPUT_PATH/dist/temp.apk\"" || exit 1
        mv -f "$OUTPUT_PATH/dist/temp.apk" "$OUTPUT_PATH/dist/$FILE_NAME"
    else
        LOG "- ${INPUT_FILE//$WORK_DIR/} Zipalign 중..."
        EVAL "zipalign -p 4 \"$OUTPUT_PATH/dist/$FILE_NAME\" \"$OUTPUT_PATH/dist/temp\"" || exit 1
        mv -f "$OUTPUT_PATH/dist/temp" "$OUTPUT_PATH/dist/$FILE_NAME"
    fi

    mkdir -p "$(dirname "$INPUT_FILE")"
    mv -f "$OUTPUT_PATH/dist/$FILE_NAME" "$INPUT_FILE"
    rm -rf "$OUTPUT_PATH/build" && rm -rf "$OUTPUT_PATH/dist"

    if [ -d "${INPUT_FILE%/*}/oat" ]; then
        DELETE_FROM_WORK_DIR "$PARTITION" "${FILE%/*}/oat"
    fi
    if [ -f "${INPUT_FILE%/*}/$FILE_NAME.prof" ]; then
        DELETE_FROM_WORK_DIR "$PARTITION" "${FILE%/*}/$FILE_NAME.prof"
    fi
    if [ -f "${INPUT_FILE%/*}/$FILE_NAME.bprof" ]; then
        DELETE_FROM_WORK_DIR "$PARTITION" "${FILE%/*}/$FILE_NAME.bprof"
    fi
}

DECODE()
{
    if [ ! -f "$INPUT_FILE" ]; then
        LOGE "파일이 존재하지 않습니다: ${INPUT_FILE//$WORK_DIR/}"
        exit 1
    elif [ -d "$OUTPUT_PATH" ]; then
        if $FORCE; then
            rm -rf "$OUTPUT_PATH"
        else
            LOGE "출력 디렉토리가 이미 존재합니다. 덮어쓰려면 --force 플래그를 사용하세요: (${OUTPUT_PATH//$SRC_DIR\//})"
            exit 1
        fi
    fi

    if [[ "$(READ_BYTES_AT "$INPUT_FILE" "0" "4")" != "04034b50" ]]; then
        LOGE "파일이 유효하지 않습니다: ${INPUT_FILE//$WORK_DIR/}"
        exit 1
    fi

    LOG "- ${INPUT_FILE//$WORK_DIR/} 디코딩 중..."

    # --no-debug-info 옵션을 사용하여 APK를 디코딩하며, 다음 옵션으로 DEX 파일을 디스어셈블합니다:
    # - synthetic accessor 주석 비활성화
    # - 디버그 정보 비활성화
    # - .registers 대신 .locals 지시문 사용
    # - 레이블에 순차적인 번호 지정 방식 사용
    EVAL "apktool -JXmx${HEAP_SIZE}m d --no-debug-info -j \"$THREAD_COUNT\" -o \"$OUTPUT_PATH\" -p \"$FRAMEWORK_DIR\" -t \"$FRAMEWORK_TAG\" \"$INPUT_FILE\"" || exit 1
}

PREPARE_SCRIPT()
{
    local MEM_TOTAL_MB
    local MAX_THREADS

    if [[ "$#" == 0 ]]; then
        PRINT_USAGE
        exit 1
    fi

    ACTION="$1"
    if [[ "$ACTION" != "decode" ]] && [[ "$ACTION" != "d" ]] && \
            [[ "$ACTION" != "build" ]] && [[ "$ACTION" != "b" ]]; then
        PRINT_USAGE
        exit 1
    fi

    shift

    while [[ "$1" == "-"* ]]; do
        if [[ "$1" == "--force" ]] || [[ "$1" == "-f" ]]; then
            FORCE=true
        elif [[ "$1" == "--jobs" ]] || [[ "$1" == "-j" ]]; then
            shift; JOBS="$1"
            if ! [[ "$JOBS" =~ ^[1-9][0-9]*$ ]]; then
                LOGE "동시에 실행할 인스턴스 수가 유효하지 않습니다: $JOBS"
                exit 1
            fi
        else
            LOGE "알 수 없는 옵션입니다: $1"
            exit 1
        fi

        shift
    done

    MEM_TOTAL_MB="$(awk '/MemTotal/ { print int($2 / 1024) }' /proc/meminfo)"

    if [ "$JOBS" -gt "1" ]; then
        # 요청된 인스턴스 간에 전체 시스템 메모리의 3/4을 분배
        HEAP_SIZE="$(bc -l <<< "scale=0; (($MEM_TOTAL_MB * 3) / 4) / $JOBS")"
        [ "$HEAP_SIZE" -lt "1024" ] && HEAP_SIZE="1024"

        MAX_THREADS="$(bc -l <<< "scale=0; $(nproc) / $JOBS")"
        [ "$MAX_THREADS" -lt "1" ] && MAX_THREADS="1"
        [ -n "$GITHUB_ACTIONS" ] && MAX_THREADS="1"

        # 힙 크기(GB)의 절반보다 많은 스레드를 사용하지 않음
        THREAD_COUNT="$(bc -l <<< "scale=0; $HEAP_SIZE / (1024 * 2)")"
        [ "$THREAD_COUNT" -gt "$MAX_THREADS" ] && THREAD_COUNT="$MAX_THREADS"
        [ "$THREAD_COUNT" -lt "1" ] && THREAD_COUNT="1"
    else
        # https://github.com/iBotPeaches/Apktool/blob/main/scripts/linux/apktool#L61
        HEAP_SIZE="1024"

        MAX_THREADS="$(nproc)"
        [ -n "$GITHUB_ACTIONS" ] && MAX_THREADS="1"

        # 전체 시스템 메모리(GB)의 절반보다 많은 스레드를 사용하지 않음
        THREAD_COUNT="$(bc -l <<< "scale=0; $MEM_TOTAL_MB / (1024 * 2)")"
        [ "$THREAD_COUNT" -gt "$MAX_THREADS" ] && THREAD_COUNT="$MAX_THREADS"
        [ "$THREAD_COUNT" -lt "1" ] && THREAD_COUNT="1"
    fi

    PARTITION="$1"
    if [ ! "$PARTITION" ]; then
        PRINT_USAGE
        exit 1
    elif ! IS_VALID_PARTITION_NAME "$PARTITION"; then
        LOGE "\"$PARTITION\"은(는) 유효한 파티션 이름이 아닙니다"
        exit 1
    fi

    shift

    if [ ! "$1" ]; then
        PRINT_USAGE
        exit 1
    fi

    FILE="$1"
    while [[ "${FILE:0:1}" == "/" ]]; do
        FILE="${FILE:1}"
    done

    local FILE_PATH="$WORK_DIR"
    case "$PARTITION" in
        "system_ext")
            if $TARGET_OS_BUILD_SYSTEM_EXT_PARTITION; then
                FILE_PATH+="/system_ext"
            else
                FILE_PATH+="/system/system/system_ext"
            fi
            ;;
        *)
            FILE_PATH+="/$PARTITION"
            ;;
    esac
    FILE_PATH+="/$FILE"

    INPUT_FILE="$FILE_PATH"
    OUTPUT_PATH="$APKTOOL_DIR/$PARTITION/${FILE//system\//}"
}

PRINT_USAGE()
{
    echo "사용 예제: apktool d[ecode]/b[uild] [옵션] <파티션> <파일>" >&2
    echo " -f, --force : 출력 디렉토리를 강제로 삭제" >&2
    echo " -j, --jobs : 동시에 실행할 인스턴스 수 지정" >&2
}
# ]

ACTION=""

PREPARE_SCRIPT "$@"

if [ ! "$FRAMEWORK_TAG" ]; then
    LOGE "이 스크립트를 사용하기 전에 작업 디렉토리가 구성되어야 합니다."
    exit 1
elif [ ! -f "$FRAMEWORK_DIR/1-$FRAMEWORK_TAG.apk" ]; then
    LOGW "framework-res.apk for \"$FRAMEWORK_TAG\" not found, installing"
    EVAL "apktool if -p \"$FRAMEWORK_DIR\" -t \"$FRAMEWORK_TAG\" \"$WORK_DIR/system/system/framework/framework-res.apk\"" || exit 1
fi

case "$ACTION" in
    "d" | "decode")
        DECODE
        ;;
    "b" | "build")
        BUILD
        ;;
esac

exit 0
