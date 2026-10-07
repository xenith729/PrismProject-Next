#!/usr/bin/env bash
# Copyright (c) 2025 Salvo Giangreco
# SPDX-License-Identifier: GPL-3.0-or-later

shopt -s nullglob

# [
source "$SRC_DIR/scripts/utils/build_utils.sh" || exit 1

GENERATE_OTA_INFO()
{
    local FILE="$1"
    local BUILD_INFO
    local DATE
    local ID

    EVAL "unzip -p \"$FILE\" \"build_info.txt\"" || exit 1
    BUILD_INFO="$(unzip -p "$FILE" "build_info.txt")"

    DATE="$(date +"%s")"
    ID="$(sha256sum "$FILE" | cut -d " " -f 1 -s)"
    ID="$ID $DATE"
    ID="$(sha256sum <<< "$ID" | cut -d " " -f 1 -s)"

    {
        echo    '    {'
        echo -n '      "datetime": '
        echo -n "$(grep "^timestamp" <<< "$BUILD_INFO" | cut -d "=" -f 2)"
        echo    ','
        echo -n '      "device": "'
        echo -n "$(grep "^device" <<< "$BUILD_INFO" | cut -d "=" -f 2 -s)"
        echo    '",'
        echo -n '      "filename": "'
        echo -n "$(basename "$FILE")"
        echo    '",'
        echo -n '      "id": "'
        echo -n "$ID"
        echo    '",'
        echo -n '      "patch": "'
        echo -n "$(grep "^security_patch_version" <<< "$BUILD_INFO" | cut -d "=" -f 2 -s)"
        echo    '",'
        echo -n '      "size": '
        echo -n "$(wc -c "$FILE" | cut -d " " -f 1 -s)"
        echo    ','
        echo    '      "urls": ["INSERTURLHERE"],'
        echo -n '      "version": "'
        echo -n "$(grep "^version" <<< "$BUILD_INFO" | cut -d "=" -f 2 -s)"
        echo    '",'
        echo -n '      "incremental": '
        grep "^incremental" <<< "$BUILD_INFO" | cut -d "=" -f 2 -s
        echo    '    },'
    } >> "$MANIFEST_FILE"
}

MANIFEST_FILE="$SRC_DIR/manifest.json"
# ]

if [ "$#" != 1 ]; then
    echo "사용 예제: generate_ota_manifest <zip 파일 경로>" >&2
    exit 1
fi

if [ ! -d "$1" ]; then
    LOGE "폴더가 존재하지 않습니다: $1"
    exit 1
fi

if ! find "$1" -maxdepth 1 -type f | grep -q ".zip"; then
    LOGE "$1 에서 업데이트 파일을 찾을 수 없습니다."
    exit 1
fi

LOG_STEP_IN "- OTA 매니페스트 생성 중..."

[ -f "$MANIFEST_FILE" ] && rm -f "$MANIFEST_FILE"
touch "$MANIFEST_FILE"
{
    echo '{'
    echo '  "response": ['
} >> "$MANIFEST_FILE"
for f in "$1/"*.zip; do
    LOG "- $(basename "$f")"
    GENERATE_OTA_INFO "$f"
done
{
    echo '  ]'
    echo '}'
} >> "$MANIFEST_FILE"
sed -i '
    $x;$G;/\(.*\),/!H;//!{$!d
};  $!x;$s//\1/;s/^\n//' "$MANIFEST_FILE"

LOG_STEP_OUT
LOG "\n$MANIFEST_FILE 에 OTA 매니페스트가 저장되었습니다."

exit 0
