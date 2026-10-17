SOURCE_FIRMWARE_PATH="$(cut -d "/" -f 1 -s <<< "$SOURCE_FIRMWARE")_$(cut -d "/" -f 2 -s <<< "$SOURCE_FIRMWARE")"
TARGET_FIRMWARE_PATH="$(cut -d "/" -f 1 -s <<< "$TARGET_FIRMWARE")_$(cut -d "/" -f 2 -s <<< "$TARGET_FIRMWARE")"
SOURCE_FIRMWARE_ROOT="$FW_DIR/$SOURCE_FIRMWARE_PATH"
TARGET_FIRMWARE_ROOT="$FW_DIR/$TARGET_FIRMWARE_PATH"

DELETE_FROM_WORK_DIR "system" "system/saiv"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/saiv" 0 0 755 "u:object_r:system_file:s0"

# SEC_PRODUCT_FEATURE_VISION_CONFIG_FACE_RECOGNITION_SOLUTION
SOURCE_VISION_CONFIG_FACE_RECOGNITION_SOLUTION="$(GET_FLOATING_FEATURE_CONFIG "$FW_DIR/$SOURCE_FIRMWARE_PATH/system/system/etc/floating_feature.xml" "SEC_FLOATING_FEATURE_GALLERY_CONFIG_FACE_CLUSTER_VERSION")"
TARGET_VISION_CONFIG_FACE_RECOGNITION_SOLUTION="$(GET_FLOATING_FEATURE_CONFIG "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/etc/floating_feature.xml" "SEC_FLOATING_FEATURE_GALLERY_CONFIG_FACE_CLUSTER_VERSION")"
if [[ "$(GET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_GALLERY_CONFIG_FACE_CLUSTER_VERSION")" == "$SOURCE_VISION_CONFIG_FACE_RECOGNITION_SOLUTION" ]]; then
    if [[ "$TARGET_VISION_CONFIG_FACE_RECOGNITION_SOLUTION" != "$SOURCE_VISION_CONFIG_FACE_RECOGNITION_SOLUTION" ]] || \
            [ "$TARGET_PLATFORM_SDK_VERSION" -lt "$SOURCE_PLATFORM_SDK_VERSION" ]; then
        if [ -d "$WORK_DIR/system/system/saiv/face/cluster_pb" ]; then
            DELETE_FROM_WORK_DIR "system" "system/saiv/face/cluster_pb"
        fi
        ADD_TO_WORK_DIR "$SOURCE_FIRMWARE" "system" "system/saiv/face/cluster_pb" 0 0 755 "u:object_r:system_file:s0"
    fi
fi

# SEC_PRODUCT_FEATURE_SAIV_CONFIG_MIDAS
TARGET_SAIV_CONFIG_MIDAS="$(GET_FLOATING_FEATURE_CONFIG  "$TARGET_FIRMWARE_ROOT/system/system/etc/floating_feature.xml"  "SEC_FLOATING_FEATURE_SAIV_CONFIG_MIDAS")"
if [ "$TARGET_SAIV_CONFIG_MIDAS" ] && [ -s "$WORK_DIR/vendor/etc/midas/midas_config.json" ] &&  grep -q '"t2s"' "$WORK_DIR/vendor/etc/midas/midas_config.json"; then
    SET_FLOATING_FEATURE_CONFIG  "SEC_FLOATING_FEATURE_SAIV_CONFIG_MIDAS"  "$TARGET_SAIV_CONFIG_MIDAS"
else
    LOGW "타겟 MIDAS 매니페스트를 사용할 수 없습니다. MIDAS를 비활성화하는 중..."
    SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_SAIV_CONFIG_MIDAS" --delete
fi

# Android 17의 UnifiedDetector가 타겟 NPU를 인식할 수 있도록 수정
UNIFIED_INFO="$WORK_DIR/vendor/etc/saiv/image_understanding/db/unified_detector/model.info"
TARGET_AIC_DETECTOR="$WORK_DIR/vendor/etc/saiv/image_understanding/db/aic_detector/aic_detector_cnn.tflite"
TARGET_AIC_CLASSIFIER="$WORK_DIR/vendor/etc/saiv/image_understanding/db/aic_classifier/aic_classifier_cnn.tflite"
if [ -s "$SOURCE_FIRMWARE_ROOT/vendor/etc/saiv/image_understanding/db/unified_detector/model.info" ] && \
        [ -s "$TARGET_AIC_DETECTOR" ] && [ -s "$TARGET_AIC_CLASSIFIER" ]; then
    ADD_TO_WORK_DIR "$SOURCE_FIRMWARE" "vendor" \
        "etc/saiv/image_understanding/db/unified_detector/model.info" \
        0 0 644 "u:object_r:vendor_configs_file:s0"
    EVAL "printf '%s\n' '[
{
\"model\": \"ud_detector.tflite\",
\"model_type\": \"npu\",
\"precision\": \"qasymm8\",
\"latency\": \"1\",
\"compiler\": \"ENN4.13.0_S21\",
\"model_path\": \"/vendor/etc/saiv/image_understanding/db/aic_detector/aic_detector_cnn.tflite\"
},
{
\"model\": \"ud_classifier.tflite\",
\"model_type\": \"npu\",
\"precision\": \"qasymm8\",
\"latency\": \"1\",
\"compiler\": \"ENN4.13.0_S21\",
\"model_path\": \"/vendor/etc/saiv/image_understanding/db/aic_classifier/aic_classifier_cnn.tflite\"
}
]' > \"$UNIFIED_INFO\""
else
    LOGW "타겟과 호환되는 UnifiedDetector 모델이 없습니다; 갤러리 이미지 태그를 비활성화하는 중..."
    SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_GALLERY_CONFIG_IMAGE_TAGGER_VERSION" --delete
    if [ -d "${UNIFIED_INFO%/*}" ]; then
        DELETE_FROM_WORK_DIR "vendor" "etc/saiv/image_understanding/db/unified_detector"
    fi
fi

if [ ! -f "$TARGET_FIRMWARE_ROOT/vendor/lib64/libPetDetector_v1.camera.samsung.so" ]; then
    SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_GALLERY_CONFIG_PET_CLUSTER_VERSION" "None"
fi

# libDeepDocRectify가 타겟의 모델을 사용할 수 있도록 수정
SOURCE_DEWARP_INFO="$SOURCE_FIRMWARE_ROOT/vendor/etc/saiv/image_understanding/db/doc_rectifier/doc_rectifier_cnn.info"
TARGET_DEWARP_MODEL="$WORK_DIR/vendor/saiv/image_understanding/db/smartscan_rectifier/deep_dewarp_cnn.onnx"
WORK_DEWARP_INFO="$WORK_DIR/vendor/etc/saiv/image_understanding/db/doc_rectifier/doc_rectifier_cnn.info"
if [[ "$(GET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_CAMERA_DOCUMENTSCAN_SOLUTIONS")" == *"AI_DEWARPING"* ]]; then
    if [ -s "$SOURCE_DEWARP_INFO" ] && [ -s "$TARGET_DEWARP_MODEL" ]; then
        ADD_TO_WORK_DIR "$SOURCE_FIRMWARE" "vendor" \
            "etc/saiv/image_understanding/db/doc_rectifier/doc_rectifier_cnn.info" \
            0 0 644 "u:object_r:vendor_configs_file:s0"
        EVAL "printf '%s\n' '{
\"version_id\": \"v2\",
\"pcmodel\": \"2.5\",
\"model_type\": \"cpu\",
\"precision\": \"float32\",
\"model_path\": \"/vendor/saiv/image_understanding/db/smartscan_rectifier/deep_dewarp_cnn.onnx\"
}' > \"$WORK_DEWARP_INFO\""
    else
        LOGW "타겟과 호환되는 Android 17 문서 보정 모델이 없습니다; AI 문서 보정을 비활성화하는 중..."
        FEATURE="SEC_FLOATING_FEATURE_CAMERA_DOCUMENTSCAN_SOLUTIONS"
        VALUE="$(GET_FLOATING_FEATURE_CONFIG "$FEATURE" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -Fvx 'AI_DEWARPING' | paste -sd ',')"
        if [ "$VALUE" ]; then
            SET_FLOATING_FEATURE_CONFIG "$FEATURE" "$VALUE"
        else
            SET_FLOATING_FEATURE_CONFIG "$FEATURE" --delete
        fi
    fi
fi

# Android 17 ImageCropper 모델 추가
ADD_TO_WORK_DIR "$SOURCE_FIRMWARE" "system" "system/saiv/imageCropper/sce_detector_cnn.tflite" 0 0 644 "u:object_r:system_file:s0"

unset SOURCE_FIRMWARE_PATH TARGET_FIRMWARE_PATH \
    SOURCE_VISION_CONFIG_FACE_RECOGNITION_SOLUTION TARGET_VISION_CONFIG_FACE_RECOGNITION_SOLUTION \
    TARGET_SAIV_CONFIG_MIDAS \
    UNIFIED_INFO TARGET_AIC_DETECTOR TARGET_AIC_CLASSIFIER \
    SOURCE_DEWARP_INFO TARGET_DEWARP_MODEL WORK_DEWARP_INFO \
    FEATURE VALUE
