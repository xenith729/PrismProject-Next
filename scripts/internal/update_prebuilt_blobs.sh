#!/usr/bin/env bash
# Copyright (c) 2025 Salvo Giangreco
# SPDX-License-Identifier: GPL-3.0-or-later

# [
source "$SRC_DIR/scripts/utils/firmware_utils.sh" || exit 1

DEVICE=""
MODEL=""
CSC=""
IMEI=""
LATEST_FIRMWARE=""

UPDATE_BLOBS()
{
    local BLOBS
    local PREBUILTS_DIR="$SRC_DIR/prebuilts/samsung/$DEVICE"
    local FILE_PATH

    if [ -d "$PREBUILTS_DIR/system" ]; then
        BLOBS+="$(find "$PREBUILTS_DIR/system" ! -type d)"
        BLOBS="${BLOBS//$PREBUILTS_DIR/system}"
    fi
    if [ -d "$PREBUILTS_DIR/product" ]; then
        [ "$BLOBS" ] && BLOBS+=$'\n'
        BLOBS+="$(find "$PREBUILTS_DIR/product" ! -type d)"
        BLOBS="${BLOBS//$PREBUILTS_DIR\//}"
    fi
    if [ -d "$PREBUILTS_DIR/vendor" ]; then
        [ "$BLOBS" ] && BLOBS+=$'\n'
        BLOBS+="$(find "$PREBUILTS_DIR/vendor" ! -type d)"
        BLOBS="${BLOBS//$PREBUILTS_DIR\//}"
    fi
    if [ -d "$PREBUILTS_DIR/system_ext" ]; then
        [ "$BLOBS" ] && BLOBS+=$'\n'
        BLOBS+="$(find "$PREBUILTS_DIR/system_ext" ! -type d)"
        BLOBS="${BLOBS//$PREBUILTS_DIR\//}"
    fi
    BLOBS="$(LC_ALL=C sort <<< "$BLOBS")"

    for i in $BLOBS; do
        if [[ "$i" == *.[0-9][0-9] ]]; then
            [[ "$i" == *".00" ]] || continue
            i="${i%.*}"
        fi
        FILE_PATH="$PREBUILTS_DIR/${i//system\/system\//system/}"

        if [ ! -f "$FW_DIR/${MODEL}_${CSC}/$i" ]; then
            LOGE "파일이 존재하지 않습니다: ${FW_DIR//$SRC_DIR\//}/${MODEL}_${CSC}/$i"
            exit 1
        fi

        LOG "- prebuilts/samsung/$DEVICE/$i 업데이트 중..."

        if [ ! -L "$FW_DIR/${MODEL}_${CSC}/$i" ] && \
                [ "$(wc -c "$FW_DIR/${MODEL}_${CSC}/$i" | cut -d " " -f 1)" -gt "52428800" ]; then
            EVAL "rm \"$FILE_PATH.\"*" || exit 1
            EVAL "split -d -b 52428800 \"$FW_DIR/${MODEL}_${CSC}/$i\" \"$FILE_PATH.\"" || exit 1
        else
            EVAL "cp -a \"$FW_DIR/${MODEL}_${CSC}/$i\" \"$FILE_PATH\"" || exit 1
        fi
    done

    EVAL "cp -a \"$FW_DIR/${MODEL}_${CSC}/.extracted\" \"$PREBUILTS_DIR/.current\"" || exit 1
}
# ]

if [[ "$#" != "2" ]]; then
    echo "사용 예제: update_prebuilt_blobs <디바이스> <펌웨어>" >&2
    exit 1
fi

DEVICE="$1"
shift
if [ ! -d "$SRC_DIR/prebuilts/samsung/$DEVICE" ]; then
    LOGE "폴더가 존재하지 않습니다: prebuilts/samsung/$DEVICE"
    exit 1
fi

PARSE_FIRMWARE_STRING "$1" || exit 1

LATEST_FIRMWARE="$(GET_LATEST_FIRMWARE "$MODEL" "$CSC")"
if [ ! "$LATEST_FIRMWARE" ]; then
    LOGE "최신 펌웨어 정보를 가져오지 못했습니다."
    exit 1
fi

LOG_STEP_IN true "update_prebuilt_blobs 시작: prebuilts/samsung/$DEVICE"
LOG "- 현재 펌웨어: $(cat "$SRC_DIR/prebuilts/samsung/$DEVICE/.current" 2> /dev/null)"
LOG "- 사용 가능한 최신 펌웨어: $LATEST_FIRMWARE"

if [[ "$LATEST_FIRMWARE" == "$(cat "$SRC_DIR/prebuilts/samsung/$DEVICE/.current" 2> /dev/null)" ]]; then
    LOG_STEP_IN
    LOG "\033[0;33m! 아무 작업도 하지 않음\033[0m"
    exit 0
fi

LOG_STEP_OUT

LOG_STEP_IN true "펌웨어 다운로드 중..."
"$SRC_DIR/scripts/download_fw.sh" --ignore-source --ignore-target "$MODEL/$CSC/${IMEI:=$SERIAL_NO}" || exit 1
LOG_STEP_OUT

LOG_STEP_IN true "펌웨어 압축 해제 중..."
"$SRC_DIR/scripts/extract_fw.sh" --ignore-source --ignore-target "$MODEL/$CSC/${IMEI:=$SERIAL_NO}" || exit 1
LOG_STEP_OUT

LOG_STEP_IN true "블롭 업데이트 중..."
UPDATE_BLOBS || exit 1

exit 0
