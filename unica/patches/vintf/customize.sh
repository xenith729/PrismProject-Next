_LOG() { if $DEBUG; then LOGW "$1"; else ABORT "$1"; fi }

if [ -f "$SRC_DIR/target/$TARGET_CODENAME/vintf/compatibility_matrix.device.xml" ]; then
    LOG "- Adding /system/system/etc/vintf/compatibility_matrix.device.xml"
    EVAL "cp -a \"$SRC_DIR/target/$TARGET_CODENAME/vintf/compatibility_matrix.device.xml\" \"$WORK_DIR/system/system/etc/vintf/compatibility_matrix.device.xml\""
elif [[ "$SOURCE_PLATFORM_SDK_VERSION" == "$TARGET_PLATFORM_SDK_VERSION" ]]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/vintf/compatibility_matrix.device.xml"
else
    _LOG "파일이 존재하지 않습니다: $SRC_DIR/target/$TARGET_CODENAME/vintf/compatibility_matrix.device.xml"
fi

if [ -f "$SRC_DIR/target/$TARGET_CODENAME/vintf/manifest.xml" ]; then
    LOG "- Adding /system/system/etc/vintf/manifest.xml"
    EVAL "cp -a \"$SRC_DIR/target/$TARGET_CODENAME/vintf/manifest.xml\" \"$WORK_DIR/system/system/etc/vintf/manifest.xml\""
elif [[ "$SOURCE_PLATFORM_SDK_VERSION" == "$TARGET_PLATFORM_SDK_VERSION" ]]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/vintf/manifest.xml"
fi

unset -f _LOG
