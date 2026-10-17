# 전원 끌 때 화면 잠금 활성화
SMALI_PATCH "system" "system/framework/framework.jar" \
    "smali_classes6/com/samsung/android/globalactions/util/SystemPropertiesWrapper.smali" "return" \
    'isBrazilianCountryISO()Z' 'true'
SMALI_PATCH "system_ext" "priv-app/SystemUI/SystemUI.apk" \
    "smali_classes2/smali/com/android/systemui/bixby2/controller/DeviceController.smali" "return" \
    'isSupportPowerOffLock()Z' 'true'

# 설정 앱에서 원격 관리 타일 숨기기
SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "smali_classes4/com/samsung/android/settings/homepage/TopLevelRemoteSupportPreferenceController.smali" "return" \
    'getAvailabilityStatus()I' '3'
