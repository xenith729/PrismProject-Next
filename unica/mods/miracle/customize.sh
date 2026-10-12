# shellcheck disable=SC2034
SKIPUNZIP=1

if [ ! "$(GET_PROP "system" "ro.prismproject.codename")" ]; then
    LOG "- Patching /system/system/etc/selinux/plat_property_contexts"
    EVAL "echo \"ro.prismproject.codename u:object_r:build_prop:s0 exact string\" >> \"$WORK_DIR/system/system/etc/selinux/plat_property_contexts\""
    # Match latest Samsung's flagship device codename
    ROM_CODENAME="$(basename "$MODPATH")"
    SET_PROP "system" "ro.prismproject.codename" "${ROM_CODENAME^}"
    unset ROM_CODENAME
fi

# 2026 Audio Pack
LOG_STEP_IN "- Adding 2026 Audio Pack"
DELETE_FROM_WORK_DIR "system" "system/hidden/INTERNAL_SDCARD/Music/Samsung/Over_the_Horizon.mp3"
ADD_TO_WORK_DIR "m3qksx" "system" \
    "system/hidden/INTERNAL_SDCARD/Music/Samsung/Over_the_Horizon.m4a" 0 0 644 "u:object_r:system_file:s0"
DELETE_FROM_WORK_DIR "system" "system/media/audio/notifications"
DELETE_FROM_WORK_DIR "system" "system/media/audio/ringtones"
# 갤럭시 A57이 다양한 벨소리를 지원하지 않으므로 항상 ACH 사운드를 사용
ADD_TO_WORK_DIR "m3qksx" "system" "system/etc/ringtones_count_list.txt" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "m3qksx" "system" "system/media/audio/notifications" 0 0 755 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "m3qksx" "system" "system/media/audio/ringtones" 0 0 755 "u:object_r:system_file:s0"
SET_PROP "vendor" "ro.config.ringtone" "ACH_Galaxy_Bells.ogg"
SET_PROP "vendor" "ro.config.notification_sound" "ACH_Brightline.ogg"
SET_PROP "vendor" "ro.config.alarm_alert" "ACH_Morning_Xylophone.ogg"
SET_PROP "vendor" "ro.config.media_sound" "Media_preview_Over_the_horizon.ogg"
SET_PROP "vendor" "ro.config.ringtone_2" "ACH_Atomic_Bell.ogg"
SET_PROP "vendor" "ro.config.notification_sound_2" "ACH_Three_Star.ogg"
ADD_TO_WORK_DIR "m3qksx" "system" \
    "system/media/audio/ui/Media_preview_Over_the_horizon.ogg" 0 0 644 "u:object_r:system_file:s0"
APPLY_PATCH "system" "system/priv-app/SecSoundPicker/SecSoundPicker.apk" \
    "$MODPATH/brandsound/SecSoundPicker.apk/0001-Enable-SUPPORT_SAMSUNG_BRAND_SOUND_ONEUI_7.patch"
LOG_STEP_OUT

# Fix Media Context Analyzer
LOG_STEP_IN "- Fix Media Context Analyzer feature"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_MMFW_CONFIG_MEDIA_CONTEXT_ANALYZER_CORE" "GPU"
LOG_STEP_OUT

# Pet Detector in Galaxy AI
LOG_STEP_IN "- Adding Pet Detector support in Galaxy AI features"
if [ -d "$WORK_DIR/vendor/etc/petdetector/studio_pd" ]; then
    DELETE_FROM_WORK_DIR "vendor" "etc/petdetector/studio_pd"
fi
ADD_TO_WORK_DIR "pa2qxxx" "vendor" "etc/petdetector/studio_pd/config_thresholds.json" 0 0 644 "u:object_r:vendor_configs_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "vendor" "etc/petdetector/studio_pd/studio_pd_cnn.info" 0 0 644 "u:object_r:vendor_configs_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "vendor" "etc/petdetector/studio_pd/studio_pd_cnn.tflite" 0 0 644 "u:object_r:vendor_configs_file:s0"
LOG_STEP_OUT

# Image Description
LOG_STEP_IN "- Adding AI Image Description in Galaxy AI features"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_ACCESSIBILITY_SUPPORT_AI_CORE_IMAGE_DESCRIPTION" "TRUE"
LOG_STEP_OUT

# Multi Control
LOG_STEP_IN "- Adding Multi Control feature"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_FRAMEWORK_SUPPORT_COMPUTER_CONTROL" "TRUE"
LOG_STEP_OUT

# Voice Boost
LOG_STEP_IN "- Adding Voice Boost in SoundAlive features"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_AUDIO_CONFIG_SOUNDALIVE_VERSION" "eq_custom,uhq_onoff,karaoke,adapt,spk_stereo,dvfs_20_percent,dvfs_max_45_percent,voice_boost"
LOG_STEP_OUT

# Video Search
LOG_STEP_IN "- Adding Video Search features"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_MMFW_SUPPORT_VIDEOSERACH" "TRUE"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_MMFW_SUPPORT_VIDEO_SEARCH" "TRUE"