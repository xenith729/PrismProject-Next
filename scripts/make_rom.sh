#!/usr/bin/env bash
# Copyright (c) 2025 Salvo Giangreco
# SPDX-License-Identifier: GPL-3.0-or-later

# [
source "$SRC_DIR/scripts/utils/build_utils.sh" || exit 1

FORCE=false
BUILD_ROM=false
BUILD_TARGET_FILES=true
BUILD_FLASHABLE_ZIP=false

START_TIME="$(date +%s)"

SOURCE_FIRMWARE_PATH="$(cut -d "/" -f 1 -s <<< "$SOURCE_FIRMWARE")_$(cut -d "/" -f 2 -s <<< "$SOURCE_FIRMWARE")"
TARGET_FIRMWARE_PATH="$(cut -d "/" -f 1 -s <<< "$TARGET_FIRMWARE")_$(cut -d "/" -f 2 -s <<< "$TARGET_FIRMWARE")"

BUILD_APKS()
{
    local MAX_JOBS
    MAX_JOBS="$(nproc)"
    [ "$MAX_JOBS" -gt "8" ] && MAX_JOBS="8"

    if [ -d "$APKTOOL_DIR" ]; then
        LOG_STEP_IN true "APK/JAR 빌드 중"

        # shellcheck disable=SC2016
        find "$APKTOOL_DIR" -type d \( -name "*.apk" -o -name "*.jar" \) -print0 | xargs -0 -I "{}" -P "$MAX_JOBS" \
            bash -c '
                FILE="${1/$APKTOOL_DIR\//}"
                PARTITION="$(cut -d "/" -f 1 -s <<< "$FILE")"
                [[ "$PARTITION" != "system" ]] && FILE="$(cut -d "/" -f 2- -s <<< "$FILE")"
                "$SRC_DIR/scripts/apktool.sh" b -j "$2" "$PARTITION" "$FILE"
            ' "bash" "{}" "$MAX_JOBS" || exit 1

        LOG_STEP_OUT
    fi
}

GET_WORK_DIR_HASH()
{
    if [ "${TARGET_PLATFORM//none/}" ] && [ -d "$SRC_DIR/platform/$TARGET_PLATFORM" ]; then
        find "$SRC_DIR/unica" "$SRC_DIR/platform/$TARGET_PLATFORM" "$SRC_DIR/target/$TARGET_CODENAME" -type f -print0 | \
            sort -z | xargs -0 sha1sum | sha1sum | cut -d " " -f 1
    else
        find "$SRC_DIR/unica" "$SRC_DIR/target/$TARGET_CODENAME" -type f -print0 | \
            sort -z | xargs -0 sha1sum | sha1sum | cut -d " " -f 1
    fi
}

PREPARE_SCRIPT()
{
    while [[ "$#" != 0 ]]; do
        if [[ "$1" == "--force" ]] || [[ "$1" == "-f" ]]; then
            FORCE=true
        elif [[ "$1" == "--no-target-files" ]] || [[ "$1" == "-x" ]]; then
            BUILD_TARGET_FILES=false
            BUILD_FLASHABLE_ZIP=false
        elif [[ "$1" == "--build-rom-zip" ]] || [[ "$1" == "-z" ]]; then
            BUILD_TARGET_FILES=true
            BUILD_FLASHABLE_ZIP=true
        else
            if [[ "$1" == "-"* ]]; then
                LOGE "알 수 없는 옵션입니다: $1"
            fi
            PRINT_USAGE
            exit 1
        fi

        shift
    done
}

# shellcheck disable=SC2317,SC2329
PRINT_BUILD_OUTCOME()
{
    local EXIT_CODE="$?"
    local END_TIME
    local ESTIMATED

    END_TIME="$(date +%s)"
    ESTIMATED="$((END_TIME - START_TIME))"

    if [[ "$EXIT_CODE" != "0" ]]; then
        echo -n -e '\n\033[1;31m'"빌드 실패 "
    else
        echo -n -e '\n\033[1;32m'"빌드 완료 "
    fi
    echo -e "소요 시간: $((ESTIMATED / 3600))시간 $(((ESTIMATED / 60) % 60))분 $((ESTIMATED % 60))초."'\033[0m\n'
}

PRINT_USAGE()
{
    echo "사용 예제: make_rom [옵션]" >&2
    echo " -f, --force : ROM 강제 빌드" >&2
    echo " -x, --no-target-files : target-files zip을 빌드하지 않음" >&2
    echo " -z, --build-rom-zip : 플래시 가능한 zip 빌드" >&2
}
# ]

PREPARE_SCRIPT "$@"

if $FORCE; then
    BUILD_ROM=true
else
    if [ -f "$WORK_DIR/.completed" ]; then
        if [[ "$(cat "$WORK_DIR/.completed")" == "$(GET_WORK_DIR_HASH)" ]]; then
            LOGW "빌드 환경에서 변경 사항이 감지되지 않았습니다"
            BUILD_ROM=false
        else
            LOGW "빌드 환경에서 변경 사항이 감지되었습니다"
            BUILD_ROM=true
        fi
    else
        BUILD_ROM=true
    fi
fi

trap 'PRINT_BUILD_OUTCOME' EXIT
trap 'echo' INT

if $BUILD_ROM; then
    [ -d "$APKTOOL_DIR" ] && rm -rf "$APKTOOL_DIR"
    [ -f "$WORK_DIR/.completed" ] && rm -f "$WORK_DIR/.completed"

    if [ ! -f "$FW_DIR/$SOURCE_FIRMWARE_PATH/.extracted" ] || [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/.extracted" ]; then
        if [ ! -f "$ODIN_DIR/$SOURCE_FIRMWARE_PATH/.downloaded" ] || [ ! -f "$ODIN_DIR/$TARGET_FIRMWARE_PATH/.downloaded" ]; then
            LOG_STEP_IN true "필요한 펌웨어 다운로드 중..."
            "$SRC_DIR/scripts/download_fw.sh" || exit 1
            LOG_STEP_OUT
        fi
        LOG_STEP_IN true "필요한 펌웨어 압축 해제 중..."
        "$SRC_DIR/scripts/extract_fw.sh" || exit 1
        LOG_STEP_OUT
    fi

    LOG_STEP_IN true "작업 디렉터리 생성 중..."
    "$SRC_DIR/scripts/internal/create_work_dir.sh" || exit 1
    LOG_STEP_OUT

    if [ -d "$SRC_DIR/platform/$TARGET_PLATFORM/patches" ]; then
        LOG_STEP_IN true "플랫폼 패치 적용 중..."
        "$SRC_DIR/scripts/internal/apply_modules.sh" "$SRC_DIR/platform/$TARGET_PLATFORM/patches" || exit 1
        LOG_STEP_OUT
    fi
    if [ -d "$SRC_DIR/target/$TARGET_CODENAME/patches" ]; then
        LOG_STEP_IN true "기기 패치 적용 중..."
        "$SRC_DIR/scripts/internal/apply_modules.sh" "$SRC_DIR/target/$TARGET_CODENAME/patches" || exit 1
        LOG_STEP_OUT
    fi
    if [ -d "$SRC_DIR/unica/patches" ]; then
        LOG_STEP_IN true "ROM 패치 적용 중..."
        "$SRC_DIR/scripts/internal/apply_modules.sh" "$SRC_DIR/unica/patches" || exit 1
        LOG_STEP_OUT
    fi

    if [ -d "$SRC_DIR/unica/mods" ]; then
        LOG_STEP_IN true "ROM 모드 적용 중..."
        "$SRC_DIR/scripts/internal/apply_modules.sh" "$SRC_DIR/unica/mods" || exit 1
        LOG_STEP_OUT
    fi

    BUILD_APKS

    echo -n "$(GET_WORK_DIR_HASH)" > "$WORK_DIR/.completed"
fi

if $BUILD_TARGET_FILES || $BUILD_FLASHABLE_ZIP; then
    ZIP_FILE_NAME="${TARGET_CODENAME}_"
    if [ "$(GET_PROP "system" "ro.prismproject.version")" ]; then
        ZIP_FILE_NAME+="$(GET_PROP "system" "ro.prismproject.version")"
    else
        ZIP_FILE_NAME+="$ROM_VERSION"
    fi
    ZIP_FILE_NAME+="-target_files.zip"

    if [ ! -f "$OUT_DIR/$ZIP_FILE_NAME" ]; then
        LOG_STEP_IN true "target-files zip 생성 중..."
        "$SRC_DIR/scripts/internal/create_target_files_zip.sh" "$OUT_DIR/$ZIP_FILE_NAME" || exit 1
        LOG_STEP_OUT
    else
        LOGW "파일이 이미 존재합니다: ${OUT_DIR//$SRC_DIR\//}/$ZIP_FILE_NAME"
    fi

    if $BUILD_FLASHABLE_ZIP; then
        LOG_STEP_IN true "플래시 가능한 zip 생성 중..."
        "$SRC_DIR/scripts/build_flashable_zip.sh" "$OUT_DIR/$ZIP_FILE_NAME" || exit 1
        LOG_STEP_OUT
    fi
fi

exit 0
