# Disable app compaction
# Guard the patch as the source firmware might have this already disabled
LOG "- Applying \"Disable app compaction\" to /system/system/framework/services.jar"
APPLY_PATCH "system" "system/framework/services.jar" \
    "$MODPATH/appcompactor/services.jar/0001-Disable-app-compaction.patch" &> /dev/null || true

# Disable FM Radio country restrictions
if [[ "$(GET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_FMRADIO_CONFIG_CHIP_VENDOR")" != "0" ]]; then
    SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_FMRADIO_CONFIG_AVOID_REGION" --delete

    SMALI_PATCH "system" "system/framework/samsungfmradiolib.jar" \
        "smali/com/samsung/frameworks/fmradio/FMRadioImpl.smali" "return" \
        'isRadioNotSupportedInRegion()Z' \
        'false'
fi

# 빌드 번호 수정
VALUE="$(GET_PROP "$WORK_DIR/system/system/build.prop" "ro.build.display.id")"
SET_PROP "system" "ro.build.display.id" "PrismProject-Next $ROM_VERSION for $TARGET_CODENAME ($VALUE)"

# 설정에서 배터리 규제 정보 표시
# SEM_BATTERY_PROPERTY_IC_AUTHENTICATION_RESULT 지원 필요
if [ "$(GET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_BATTERY_SUPPORT_BSOH_SETTINGS")" ]; then
    SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_BATTERY_SUPPORT_BSOH_SETTINGS" --delete
fi
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_SETTINGS_ENABLE_EU_BATTERY_REGULATORY" "true"

# One UI 마이너 버전 항상 표시
SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "smali_classes4/com/samsung/android/settings/deviceinfo/softwareinfo/OneUIVersionPreferenceController.smali" "replace" \
    'isDeviceWithMicroVersion()Z' \
    'move-result p0' \
    'const/4 p0, 0x1'

# 디바이스 순정 모델 번호 표시
SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "smali_classes4/com/samsung/android/settings/deviceinfo/aboutphone/ModelNameGetter.smali" "replace" \
    'getModelName()Ljava/lang/String;' \
    'ro.product.model' \
    'ro.boot.em.model'

# build.prop 트윅
SET_PROP_IF_DIFF() {
    local PARTITION="$1"
    local KEY="$2"
    local VALUE="$3"

    local CUR_VALUE
    CUR_VALUE="$(GET_PROP "$PARTITION" "$KEY")"

    if [[ -z "$CUR_VALUE" || "$CUR_VALUE" != "$VALUE" ]]; then
        SET_PROP "$PARTITION" "$KEY" "$VALUE"
    fi
}

# vendor 파티션 최적화 트윅 적용
SET_PROP_IF_DIFF "vendor" "ro.apex.updatable" "true"
SET_PROP_IF_DIFF "vendor" "ro.incremental.enable" "yes"
SET_PROP_IF_DIFF "vendor" "ro.hwui.use_vulkan" "true"
SET_PROP_IF_DIFF "vendor" "debug.hwui.use_hint_manager" "true"
SET_PROP_IF_DIFF "vendor" "persist.sys.fuse.passthrough.enable" "true"
SET_PROP_IF_DIFF "system" "persist.device_config.activity_manager_native_boot.use_freezer" "true"