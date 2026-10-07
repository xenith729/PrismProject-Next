REPOSITORY="https://github.com/UN1CA/proprietary_vendor_samsung_exynos2100/releases/download"
TARS=(
    # t2sksx (kor_single)
    "G996NKSSCHZA9_KOO_OKR/BL_G996NKSSCHZA9_G996NKSSCHZA9_MQB107175103_REV01_user_low_ship_MULTI_CERT.tar.md5"
    "G996NKSSCHZA9_KOO_OKR/CP_G996NKOSCHZA5_CP32602497_MQB105441439_REV01_user_low_ship_MULTI_CERT.tar.md5"
)

for i in "${TARS[@]}"; do
    LOG "- $(basename "$i") 다운로드 중..."
    DOWNLOAD_FILE "$REPOSITORY/$i" "$TMP_DIR/$(basename "$i")" || return 1
done

while IFS= read -r f; do
    FILE_NAME="$(basename "$f")"
    LOG "- $FILE_NAME 검증 중..."

    FILE_NAME="${FILE_NAME%.md5}"

    # 삼성은 md5sum 결과를 파일 끝에 저장함
    LENGTH="32" # MD5 해시 길이
    LENGTH="$((LENGTH + 2))" # 공백 2개
    LENGTH="$((LENGTH + ${#FILE_NAME}))" # 확장자 제외 파일명 길이
    LENGTH="$((LENGTH + 1))" # 개행 1개

    STORED_HASH="$(tail -c "$LENGTH" "$f" | cut -d " " -f 1 -s)"
    if [ ! "$STORED_HASH" ] || [[ "${#STORED_HASH}" != "32" ]]; then
        LOG "\033[0;31m! 저장된 해시값을 파싱할 수 없습니다\033[0m"
        return 1
    fi

    CALCULATED_HASH="$(head -c-$LENGTH "$f" | md5sum | cut -d " " -f 1 -s)"

    if [[ "$STORED_HASH" != "$CALCULATED_HASH" ]]; then
        LOG "\033[0;31m! 파일이 손상되었습니다\033[0m"
        return 1
    fi

    FILE_NAME="$(basename "$f")"
    LOG "- $FILE_NAME 압축 해제 중..."

    MODEL="$(cut -c4-8 <<< "$FILE_NAME" | sed "s/^/SM-/")"

    if [ ! -d "$TMP_DIR/firmware/$MODEL" ]; then
        EVAL "mkdir -p \"$TMP_DIR/firmware/$MODEL\"" || return 1
    fi

    EVAL "cd \"$TMP_DIR/firmware/$MODEL\"; tar -xf \"$f\"" || return 1
    EVAL "rm -f \"$f\"" || return 1

    if [ -f "$TMP_DIR/firmware/$MODEL/modem_debug.bin.lz4" ]; then
        LOG "- firmware/$MODEL/modem_debug.bin.lz4 삭제 중..."
        EVAL "rm -f \"$TMP_DIR/firmware/$MODEL/modem_debug.bin.lz4\"" || return 1
    fi

    unset FILE_NAME LENGTH STORED_HASH CALCULATED_HASH MODEL
done < <(find "$TMP_DIR" -type f -name "*.md5")

while IFS= read -r f; do
    LOG "- ${f#"$TMP_DIR"/} 압축 해제 중..."
    EVAL "lz4 -d --rm \"$f\" \"${f%.lz4}\"" || return 1
done < <(find "$TMP_DIR" -type f -name "*.lz4")

while IFS= read -r f; do
    LOG "- ${f#"$TMP_DIR"/} 패치 중..."
    # https://android.googlesource.com/platform/system/core/+/refs/tags/android-15.0.0_r1/fastboot/fastboot.cpp#1129
    EVAL "printf \"\x03\" | dd of=\"$f\" bs=1 seek=123 count=1 conv=notrunc" || return 1
done < <(find "$TMP_DIR" -type f -name "vbmeta.img")

unset REPOSITORY TARS
