#!/usr/bin/env bash
# Copyright (c) 2025 Salvo Giangreco
# SPDX-License-Identifier: GPL-3.0-or-later

# [
source "$SRC_DIR/scripts/utils/firmware_utils.sh" || exit 1
source "$TOOLS_DIR/venv/bin/activate" || exit 1

FORCE=false

FIRMWARES=()
MODEL=""
CSC=""
IMEI=""
SERIAL_NO=""
LATEST_FIRMWARE=""
ZIP_FILE=""

PREPARE_SCRIPT()
{
    local EXTRA_FIRMWARES=()
    local IGNORE_SOURCE=false
    local IGNORE_TARGET=false

    while [ "$#" != 0 ]; do
        if [[ "$1" == "--force" ]] || [[ "$1" == "-f" ]]; then
            FORCE=true
        elif [[ "$1" == "--ignore-source" ]]; then
            IGNORE_SOURCE=true
        elif [[ "$1" == "--ignore-target" ]]; then
            IGNORE_TARGET=true
        elif [[ "$1" == "-"* ]]; then
            LOGE "알 수 없는 옵션입니다: $1"
            PRINT_USAGE
            exit 1
        else
            EXTRA_FIRMWARES+=("$1")
        fi

        shift
    done

    if ! $IGNORE_SOURCE; then
        _CHECK_NON_EMPTY_PARAM "SOURCE_FIRMWARE" "$SOURCE_FIRMWARE" || exit 1
        FIRMWARES+=("$SOURCE_FIRMWARE")
        IFS=':' read -r -a SOURCE_EXTRA_FIRMWARES <<< "$SOURCE_EXTRA_FIRMWARES"
        if [ "${#SOURCE_EXTRA_FIRMWARES[@]}" -ge 1 ]; then
            FIRMWARES+=("${SOURCE_EXTRA_FIRMWARES[@]}")
        fi
    fi

    if ! $IGNORE_TARGET; then
        _CHECK_NON_EMPTY_PARAM "TARGET_FIRMWARE" "$TARGET_FIRMWARE" || exit 1
        FIRMWARES+=("$TARGET_FIRMWARE")
        IFS=':' read -r -a TARGET_EXTRA_FIRMWARES <<< "$TARGET_EXTRA_FIRMWARES"
        if [ "${#TARGET_EXTRA_FIRMWARES[@]}" -ge 1 ]; then
            FIRMWARES+=("${TARGET_EXTRA_FIRMWARES[@]}")
        fi
    fi

    if [ "${#EXTRA_FIRMWARES[@]}" -ge 1 ]; then
        FIRMWARES+=("${EXTRA_FIRMWARES[@]}")
    fi
}

PRINT_USAGE()
{
    echo "사용 예제: download_fw [옵션] <펌웨어>" >&2
    echo " --ignore-source : 소스 펌웨어 플래그 파싱을 건너 뜁니다." >&2
    echo " --ignore-target : 타겟 펌웨어 플래그 파싱을 건너 뜁니다." >&2
    echo " -f, --force : 강제로 펌웨어를 다운로드합니다." >&2
}

VERIFY_ODIN_PACKAGES()
{
    local FILE_NAME
    local LENGTH
    local STORED_HASH
    local CALCULATED_HASH

    while IFS= read -r f; do
        FILE_NAME="$(basename "$f")"
        LOG_STEP_IN "- $FILE_NAME 검증 중..."

        FILE_NAME="${FILE_NAME%.md5}"

        # Samsung은 파일명 끝에 md5sum을 저장합니다.
        LENGTH="32" # MD5 해시 길이
        LENGTH="$((LENGTH + 2))" # 공백 문자 2개
        LENGTH="$((LENGTH + ${#FILE_NAME}))" # .md5 확장자를 제외한 파일 이름
        LENGTH="$((LENGTH + 1))" # 줄 바꿈 문자 1개

        STORED_HASH="$(tail -c "$LENGTH" "$f" | cut -d " " -f 1 -s)"
        if [ ! "$STORED_HASH" ] || [[ "${#STORED_HASH}" != "32" ]]; then
            LOG "\033[0;31m! 예상 해시를 파싱할 수 없습니다\033[0m"
            exit 1
        fi

        CALCULATED_HASH="$(head -c-$LENGTH "$f" | md5sum | cut -d " " -f 1 -s)"

        if [[ "$STORED_HASH" != "$CALCULATED_HASH" ]]; then
            LOG "\033[0;31m! 파일이 손상되었습니다\033[0m"
            exit 1
        fi

        LOG_STEP_OUT
    done < <(find "$ODIN_DIR/${MODEL}_${CSC}" -type f -name "*.md5")
}
# ]

PREPARE_SCRIPT "$@"

for i in "${FIRMWARES[@]}"; do
    PARSE_FIRMWARE_STRING "$i" || exit 1

    LATEST_FIRMWARE="$(GET_LATEST_FIRMWARE "$MODEL" "$CSC")"
    if [ ! "$LATEST_FIRMWARE" ]; then
        LOGE "최신 펌웨어 정보를 불러올 수 없습니다."
        exit 1
    fi

    LOG_STEP_IN "- $MODEL $CSC 펌웨어 작업 중..."
    LOG "- 다운로드된 펌웨어: $(cat "$ODIN_DIR/${MODEL}_${CSC}/.downloaded" 2> /dev/null)"
    LOG "- 추출된 펌웨어: $(cat "$FW_DIR/${MODEL}_${CSC}/.extracted" 2> /dev/null)"
    LOG "- 사용 가능한 최신 펌웨어: $LATEST_FIRMWARE"

    LOG_STEP_IN

    if ! $FORCE; then
        # 펌웨어가 추출되었으며 FUS의 버전과 같거나 더 높은 경우 건너 뜁니다.
        if [ -f "$FW_DIR/${MODEL}_${CSC}/.extracted" ]; then
            if COMPARE_SEC_BUILD_VERSION "$(cat "$FW_DIR/${MODEL}_${CSC}/.extracted")" "$LATEST_FIRMWARE"; then
                LOG "\033[0;33m! 이 펌웨어는 이미 추출되었습니다, 건너뜁니다\033[0m"
                LOG_STEP_OUT; LOG_STEP_OUT
                continue
            fi
        fi

        # 펌웨어가 다운로드된 경우 건너 뜁니다.
        if [ -f "$ODIN_DIR/${MODEL}_${CSC}/.downloaded" ]; then
            if ! COMPARE_SEC_BUILD_VERSION "$(cat "$ODIN_DIR/${MODEL}_${CSC}/.downloaded")" "$LATEST_FIRMWARE"; then
                LOG "\033[0;33m! 더 새로운 펌웨어를 다운로드할 수 있습니다. 덮어쓰려면 --force 플래그를 사용하세요\033[0m"
            else
                LOG "\033[0;33m! 이 펌웨어는 이미 다운로드되었습니다\033[0m"
            fi
            LOG_STEP_OUT; LOG_STEP_OUT
            continue
        fi
    fi

    LOG "- 펌웨어 다운로드 중..."
    [ -f "$ODIN_DIR/${MODEL}_${CSC}/.downloaded" ] && rm -rf "$ODIN_DIR/${MODEL}_${CSC}"
    mkdir -p "$ODIN_DIR/${MODEL}_${CSC}"
    # Anan의 samloader는 로그를 현재 작업 디렉토리에 저장하므로 잠시 OUT_DIR로 이동합니다.
    (
    cd "$OUT_DIR" || exit 1
    samloader -m "$MODEL" -r "$CSC" -i "$IMEI" -s "$SERIAL_NO" download -O "$ODIN_DIR/${MODEL}_${CSC}" 1> /dev/null || exit 1
    )

    ZIP_FILE="$(find "$ODIN_DIR/${MODEL}_${CSC}" -name "*.zip" | sort -r | head -n 1)"
    if [ ! "$ZIP_FILE" ] || [ ! -f "$ZIP_FILE" ]; then
        LOG "\033[0;31m! 다운로드 실패\033[0m"
        exit 1
    fi

    LOG "- $(basename "$ZIP_FILE") 추출 중..."
    EVAL "unzip -o \"$ZIP_FILE\" -d \"$ODIN_DIR/${MODEL}_${CSC}\" && rm -rf \"$ZIP_FILE\"" || exit 1

    VERIFY_ODIN_PACKAGES

    echo -n "$LATEST_FIRMWARE" > "$ODIN_DIR/${MODEL}_${CSC}/.downloaded"

    LOG_STEP_OUT; LOG_STEP_OUT
done

deactivate

exit 0
