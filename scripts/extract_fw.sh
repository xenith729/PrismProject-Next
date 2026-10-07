#!/usr/bin/env bash
# Copyright (c) 2025 Salvo Giangreco
# SPDX-License-Identifier: GPL-3.0-or-later

# [
source "$SRC_DIR/scripts/utils/firmware_utils.sh" || exit 1

FORCE=false

FIRMWARES=()
MODEL=""
CSC=""
LATEST_FIRMWARE=""
DOWNLOADED_FIRMWARE=""
BL_TAR=""
AP_TAR=""

TMP_DIR="$(mktemp -d)"

EXTRACT_AVB_BINARIES()
{
    if FILE_EXISTS_IN_TAR "$BL_TAR" "vbmeta.img" || FILE_EXISTS_IN_TAR "$BL_TAR" "vbmeta.img.lz4"; then
        LOG_STEP_IN "- AVB 바이너리 추출 중..."

        mkdir -p "$FW_DIR/${MODEL}_${CSC}/avb"

        EXTRACT_FILE_FROM_TAR "$BL_TAR" "vbmeta.img" || exit 1
        mv -f "$FW_DIR/${MODEL}_${CSC}/vbmeta.img" "$FW_DIR/${MODEL}_${CSC}/avb/vbmeta.img"

        [ -f "$FW_DIR/${MODEL}_${CSC}/avb/vbmeta_patched.img" ] && rm -rf "$FW_DIR/${MODEL}_${CSC}/avb/vbmeta_patched.img"
        LOG "- vbmeta_patched.img 생성 중..."
        EVAL "cp -a \"$FW_DIR/${MODEL}_${CSC}/avb/vbmeta.img\" \"$FW_DIR/${MODEL}_${CSC}/avb/vbmeta_patched.img\"" || exit 1
        # https://android.googlesource.com/platform/system/core/+/refs/tags/android-15.0.0_r1/fastboot/fastboot.cpp#1129
        EVAL "printf \"\x03\" | dd of=\"$FW_DIR/${MODEL}_${CSC}/avb/vbmeta_patched.img\" bs=1 seek=123 count=1 conv=notrunc" || exit 1

        LOG_STEP_OUT
    fi
}

EXTRACT_KERNEL_BINARIES()
{
    local FILES="boot.img dt.img dtbo.img init_boot.img vendor_boot.img recovery.img"

    LOG_STEP_IN "- 커널 바이너리 추출 중..."

    mkdir -p "$FW_DIR/${MODEL}_${CSC}/kernel"
    for f in $FILES; do
        [ -f "$FW_DIR/${MODEL}_${CSC}/${f}_metadata.txt" ] && rm -f "$FW_DIR/${MODEL}_${CSC}/${f}_metadata.txt"

        EXTRACT_FILE_FROM_TAR "$AP_TAR" "$f" || exit 1
        [ -f "$FW_DIR/${MODEL}_${CSC}/$f" ] || continue
        mv -f "$FW_DIR/${MODEL}_${CSC}/$f" "$FW_DIR/${MODEL}_${CSC}/kernel/$f"

        STORE_KERNEL_IMAGE_METADATA "$FW_DIR/${MODEL}_${CSC}/kernel/$f"
    done

    LOG_STEP_OUT
}

EXTRACT_OS_PARTITIONS()
{
    # https://android.googlesource.com/platform/build/+/refs/tags/android-15.0.0_r1/tools/releasetools/common.py#131
    local FILES="system.img vendor.img product.img system_ext.img odm.img vendor_dlkm.img odm_dlkm.img system_dlkm.img"

    LOG_STEP_IN "- OS 파티션 추출 중..."

    [ -f "$FW_DIR/${MODEL}_${CSC}/os_partitions_metadata.txt" ] && rm -f "$FW_DIR/${MODEL}_${CSC}/os_partitions_metadata.txt"

    if FILE_EXISTS_IN_TAR "$AP_TAR" "super.img" || FILE_EXISTS_IN_TAR "$AP_TAR" "super.img.lz4"; then
        EXTRACT_FILE_FROM_TAR "$AP_TAR" "super.img" || exit 1
        UNSPARSE_IMAGE "$FW_DIR/${MODEL}_${CSC}/super.img" || exit 1

        LOG "- super.img 압축 해제 중..."

        STORE_OS_PARTITION_METADATA "$FW_DIR/${MODEL}_${CSC}/super.img"

        # shellcheck disable=SC2013
        for p in $(grep "partition_list" "$FW_DIR/${MODEL}_${CSC}/os_partitions_metadata.txt" | cut -d "=" -f 2 -s); do
            if grep -q "virtual_ab" "$FW_DIR/${MODEL}_${CSC}/os_partitions_metadata.txt"; then
                # 가상 A/B 디바이스의 경우, A 파티션만 추출합니다.
                EVAL "lpunpack -p \"${p}_a\" \"$FW_DIR/${MODEL}_${CSC}/super.img\" \"$FW_DIR/${MODEL}_${CSC}\"" || exit 1
                mv -f "$FW_DIR/${MODEL}_${CSC}/${p}_a.img" "$FW_DIR/${MODEL}_${CSC}/${p}.img"
            else
                EVAL "lpunpack -p \"${p}\" \"$FW_DIR/${MODEL}_${CSC}/super.img\" \"$FW_DIR/${MODEL}_${CSC}\"" || exit 1
            fi
        done

        rm -f "$FW_DIR/${MODEL}_${CSC}/super.img"
    else
        for f in $FILES; do
            EXTRACT_FILE_FROM_TAR "$AP_TAR" "$f" || exit 1
            [ -f "$FW_DIR/${MODEL}_${CSC}/$f" ] || continue
            UNSPARSE_IMAGE "$FW_DIR/${MODEL}_${CSC}/$f" || exit 1
            STORE_OS_PARTITION_METADATA "$FW_DIR/${MODEL}_${CSC}/$f"
        done
    fi

    local PARTITION
    for f in $FILES; do
        PARTITION="${f%.img}"

        [ -f "$FW_DIR/${MODEL}_${CSC}/$f" ] || continue

        if ! sudo -n -v &> /dev/null; then
            LOG "\033[0;33m! 사용자에게 sudo 비밀번호를 요청합니다\033[0m"
            if ! sudo -v 2> /dev/null; then
                LOGE "OS 파티션을 추출하기 위해 루트 권한이 필요합니다."
                exit 1
            fi
        fi

        LOG "- $(basename "$f") 압축 해제 중..."

        mkdir -p "$FW_DIR/${MODEL}_${CSC}/$PARTITION"
        sudo umount "$FW_DIR/${MODEL}_${CSC}/$f" &> /dev/null
        if [[ "$(GET_IMAGE_FILE_SYSTEM "$FW_DIR/${MODEL}_${CSC}/$f")" == "erofs" ]]; then
            EVAL "sudo env \"PATH=$PATH\" fuse.erofs \"$FW_DIR/${MODEL}_${CSC}/$f\" \"$TMP_DIR\"" || exit 1
        else
            EVAL "sudo mount -o ro \"$FW_DIR/${MODEL}_${CSC}/$f\" \"$TMP_DIR\"" || exit 1
        fi
        EVAL "sudo cp -a -T \"$TMP_DIR\" \"$FW_DIR/${MODEL}_${CSC}/$PARTITION\"" || exit 1
        sudo chown -hR "$(whoami):$(whoami)" "$FW_DIR/${MODEL}_${CSC}/$PARTITION"
        [ -d "$FW_DIR/${MODEL}_${CSC}/$PARTITION/lost+found" ] && rm -rf "$FW_DIR/${MODEL}_${CSC}/$PARTITION/lost+found"

        LOG "- $(basename "$f")의 fs_config/file_context 생성 중..."

        EVAL "sudo find \"$TMP_DIR\" | sudo xargs -I \"{}\" -P \"$(nproc)\" stat -c \"%n %u %g %a capabilities=0x0\" \"{}\" > \"$FW_DIR/${MODEL}_${CSC}/fs_config-$PARTITION\"" || exit 1
        EVAL "sudo find \"$TMP_DIR\" | sudo xargs -I \"{}\" -P \"$(nproc)\" sh -c 'echo \"\$1 \$(getfattr -n security.selinux --only-values -h --absolute-names \"\$1\")\"' \"sh\" \"{}\" > \"$FW_DIR/${MODEL}_${CSC}/file_context-$PARTITION\"" || exit 1
        sort -o "$FW_DIR/${MODEL}_${CSC}/fs_config-$PARTITION" "$FW_DIR/${MODEL}_${CSC}/fs_config-$PARTITION"
        sort -o "$FW_DIR/${MODEL}_${CSC}/file_context-$PARTITION" "$FW_DIR/${MODEL}_${CSC}/file_context-$PARTITION"
        # https://source.android.com/docs/core/architecture/partitions/system-as-root
        if [[ "$PARTITION" == "system" ]] && [ -d "$FW_DIR/${MODEL}_${CSC}/system/system" ]; then
            sed -i -e "s|$TMP_DIR |/ |g" -e "s|$TMP_DIR||g" "$FW_DIR/${MODEL}_${CSC}/file_context-$PARTITION"
            sed -i -e "s|$TMP_DIR | |g" -e "s|$TMP_DIR/||g" "$FW_DIR/${MODEL}_${CSC}/fs_config-$PARTITION"
        else
            sed -i "s|$TMP_DIR|/$PARTITION|g" "$FW_DIR/${MODEL}_${CSC}/file_context-$PARTITION"
            sed -i -e "s|$TMP_DIR | |g" -e "s|$TMP_DIR|$PARTITION|g" "$FW_DIR/${MODEL}_${CSC}/fs_config-$PARTITION"
        fi
        sed -i -e "s|\.|\\\.|g" -e "s|\+|\\\+|g" -e "s|\[|\\\[|g" \
            -e "s|\]|\\\]|g" -e "s|\*|\\\*|g" "$FW_DIR/${MODEL}_${CSC}/file_context-$PARTITION"

        # # TODO: 파일 capability를 확인하는 방법은 아직 찾지 못했으므로, 현재는 알려진 파일에만 설정
        if [ -f "$FW_DIR/${MODEL}_${CSC}/fs_config-system" ]; then
            grep -q "run-as" "$FW_DIR/${MODEL}_${CSC}/fs_config-system" && \
                sed -i "$(sed -n "/run-as/=" "$FW_DIR/${MODEL}_${CSC}/fs_config-system") s/0x0/0xc0/g" "$FW_DIR/${MODEL}_${CSC}/fs_config-system"
            grep -q "simpleperf_app_runner" "$FW_DIR/${MODEL}_${CSC}/fs_config-system" && \
                sed -i "$(sed -n "/simpleperf_app_runner/=" "$FW_DIR/${MODEL}_${CSC}/fs_config-system") s/0x0/0xc0/g" "$FW_DIR/${MODEL}_${CSC}/fs_config-system"
        fi

        EVAL "sudo umount \"$TMP_DIR\"" || exit 1
        rm -f "$FW_DIR/${MODEL}_${CSC}/$f"
    done

    LOG_STEP_OUT
}

GET_IMAGE_FILE_SYSTEM()
{
    # https://android.googlesource.com/platform/external/e2fsprogs/+/refs/tags/android-15.0.0_r1/lib/ext2fs/ext2_fs.h#83
    if [[ "$(READ_BYTES_AT "$1" "1080" "2")" == "ef53" ]]; then
        echo "ext4"
    # https://android.googlesource.com/platform/external/f2fs-tools/+/refs/tags/android-15.0.0_r1/include/f2fs_fs.h#395
    elif [[ "$(READ_BYTES_AT "$1" "1024" "4")" == "f2f52010" ]]; then
        echo "f2fs"
    # https://android.googlesource.com/platform/external/erofs-utils/+/refs/tags/android-15.0.0_r1/include/erofs_fs.h#12
    elif [[ "$(READ_BYTES_AT "$1" "1024" "4")" == "e0f5e1e2" ]]; then
        echo "erofs"
    fi
}

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
    echo "사용 예제: extract_fw [옵션] <펌웨어>" >&2
    echo " --ignore-source : 소스 펌웨어 플래그 파싱을 건너 뜁니다." >&2
    echo " --ignore-target : 타겟 펌웨어 플래그 파싱을 건너 뜁니다." >&2
    echo " -f, --force : 강제로 펌웨어를 추출합니다." >&2
}

STORE_KERNEL_IMAGE_METADATA()
{
    local FILE="$1"

    if [ ! -f "$FILE" ]; then
        LOGE "파일이 존재하지 않습니다: ${FILE//$SRC_DIR\//}"
        exit 1
    fi

    if avbtool info_image --image "$FILE" &> /dev/null; then
        echo "partition_size=$(wc -c "$FILE" | cut -d " " -f 1)" >> "$FW_DIR/${MODEL}_${CSC}/${f}_metadata.txt"
    fi

    if [[ "$f" == *"boot.img" ]] || [[ "$f" == "recovery.img" ]]; then
        local INFO
        INFO="$(unpack_bootimg --boot_img "$FW_DIR/${MODEL}_${CSC}/kernel/$f" --out "$TMP_DIR" 2>&1)"
        # shellcheck disable=SC2181
        if [ $? -ne 0 ]; then
            EVAL "unpack_bootimg --boot_img \"$FW_DIR/${MODEL}_${CSC}/kernel/$f\" --out \"$TMP_DIR\""
            exit 1
        fi
        rm -rf "${TMP_DIR:?}/"*

        while IFS= read -r l; do
            if [[ "$l" == *"command line args"* ]]; then
                {
                    echo -n "cmdline="
                    cut -d ":" -f 2- <<< "$l" | awk '{$1=$1;print}'
                } >> "$FW_DIR/${MODEL}_${CSC}/${f}_metadata.txt"
            elif [[ "$l" == *"dtb address"* ]]; then
                {
                    echo -n "dtb_offset="
                    tr -d " " <<< "$l" | cut -d ":" -f 2-
                } >> "$FW_DIR/${MODEL}_${CSC}/${f}_metadata.txt"
            elif [[ "$l" == *"header version"* ]]; then
                {
                    echo -n "header_version="
                    tr -d " " <<< "$l" | cut -d ":" -f 2-
                } >> "$FW_DIR/${MODEL}_${CSC}/${f}_metadata.txt"
            elif [[ "$l" == *"kernel load address"* ]]; then
                {
                    echo -n "kernel_offset="
                    tr -d " " <<< "$l" | cut -d ":" -f 2-
                } >> "$FW_DIR/${MODEL}_${CSC}/${f}_metadata.txt"
            elif [[ "$l" == *"kernel tags load address"* ]]; then
                {
                    echo -n "tags_offset="
                    tr -d " " <<< "$l" | cut -d ":" -f 2-
                } >> "$FW_DIR/${MODEL}_${CSC}/${f}_metadata.txt"
            elif [[ "$l" == *"os patch level"* ]]; then
                {
                    echo -n "os_patch_level="
                    tr -d " " <<< "$l" | cut -d ":" -f 2-
                } >> "$FW_DIR/${MODEL}_${CSC}/${f}_metadata.txt"
            elif [[ "$l" == *"os version"* ]]; then
                {
                    echo -n "os_version="
                    tr -d " " <<< "$l" | cut -d ":" -f 2-
                } >> "$FW_DIR/${MODEL}_${CSC}/${f}_metadata.txt"
            elif [[ "$l" == *"page size"* ]]; then
                {
                    echo -n "pagesize="
                    tr -d " " <<< "$l" | cut -d ":" -f 2-
                } >> "$FW_DIR/${MODEL}_${CSC}/${f}_metadata.txt"
            elif [[ "$l" == *"product name"* ]]; then
                {
                    echo -n "board="
                    tr -d " " <<< "$l" | cut -d ":" -f 2-
                } >> "$FW_DIR/${MODEL}_${CSC}/${f}_metadata.txt"
            elif [[ "$l" == *"ramdisk load address"* ]]; then
                {
                    echo -n "ramdisk_offset="
                    tr -d " " <<< "$l" | cut -d ":" -f 2-
                } >> "$FW_DIR/${MODEL}_${CSC}/${f}_metadata.txt"
            fi
        done <<< "$INFO"
    fi
}

STORE_OS_PARTITION_METADATA()
{
    local FILE="$1"

    if [ ! -f "$FILE" ]; then
        LOGE "파일이 존재하지 않습니다: ${FILE//$SRC_DIR\//}"
        exit 1
    fi

    local PARTITION_SIZE
    PARTITION_SIZE="$(wc -c "$FILE" | cut -d " " -f 1)"

    if [[ "$FILE" == *"super.img" ]]; then
        local LPDUMP
        LPDUMP="$(lpdump "$FILE" 2>&1)"
        # shellcheck disable=SC2181
        if [ $? -ne 0 ]; then
            EVAL "lpdump \"$FILE\""
            exit 1
        fi

        local GROUP_NAME
        GROUP_NAME="$(grep -F "Group: " <<< "$LPDUMP" | tr -d " " | cut -d ":" -f 2 | sed -e "s/_a$//" -e "s/_b$//" | sort -u)"

        {
            echo "use_dynamic_partitions=true"
            if grep -q -w "virtual_ab_device" <<< "$LPDUMP"; then
                echo "virtual_ab=true"
            fi
            echo "super_partition_size=$PARTITION_SIZE"
            echo "super_partition_group=$GROUP_NAME"
            echo -n "super_${GROUP_NAME}_group_size="
            grep -F "Maximum size: " <<< "$LPDUMP" | tr -d " " | cut -d ":" -f 2 | sed "s/bytes//" | sort -n -r | head -n 1
            echo -n "super_${GROUP_NAME}_partition_list="
            grep -F "Name: " <<< "$LPDUMP" | tr -d " " | cut -d ":" -f 2 | sed -e "s/_a$//" -e "s/_b$//" -e "/default/d" -e "/$GROUP_NAME/d" | awk '!visited[$0]++' | tr "\n" " " | xargs
        } > "$FW_DIR/${MODEL}_${CSC}/os_partitions_metadata.txt"
    else
        echo "$(basename "${FILE%.img}")_size=$PARTITION_SIZE" >> "$FW_DIR/${MODEL}_${CSC}/os_partitions_metadata.txt"
    fi
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
        # 펌웨어가 이미 추출된 경우 건너 뜁니다.
        if [ -f "$FW_DIR/${MODEL}_${CSC}/.extracted" ]; then
            if ! COMPARE_SEC_BUILD_VERSION "$(cat "$FW_DIR/${MODEL}_${CSC}/.extracted")" "$LATEST_FIRMWARE"; then
                if [ -f "$ODIN_DIR/${MODEL}_${CSC}/.downloaded" ] && \
                        ! COMPARE_SEC_BUILD_VERSION "$(cat "$FW_DIR/${MODEL}_${CSC}/.extracted")" "$(cat "$ODIN_DIR/${MODEL}_${CSC}/.downloaded")"; then
                    LOG "\033[0;33m! 더 새로운 펌웨어가 다운로드되었습니다, 덮어쓰려면 --force 플래그를 사용하세요\033[0m"
                else
                    LOG "\033[0;33m! 더 새로운 펌웨어를 다운로드할 수 있습니다\033[0m"
                fi
            else
                LOG "\033[0;33m! 이 펌웨어는 이미 추출되었습니다\033[0m"
            fi

            LOG_STEP_OUT; LOG_STEP_OUT
            continue
        fi
    fi

    # 펌웨어가 다운로드되지 않은 경우 중단
    if [ ! -f "$ODIN_DIR/${MODEL}_${CSC}/.downloaded" ]; then
        LOG "\033[0;31m! 펌웨어가 다운로드되지 않았습니다\033[0m"
        exit 1
    fi

    [ -f "$FW_DIR/${MODEL}_${CSC}/.extracted" ] && rm -rf "$FW_DIR/${MODEL}_${CSC}"
    mkdir -p "$FW_DIR/${MODEL}_${CSC}"

    DOWNLOADED_FIRMWARE="$(cat "$ODIN_DIR/${MODEL}_${CSC}/.downloaded")"

    BL_TAR="$(find "$ODIN_DIR/${MODEL}_${CSC}" -name "BL_$(cut -d "/" -f 1 -s <<< "$DOWNLOADED_FIRMWARE")*.md5" | sort -r | head -n 1)"
    AP_TAR="$(find "$ODIN_DIR/${MODEL}_${CSC}" -name "AP_$(cut -d "/" -f 1 -s <<< "$DOWNLOADED_FIRMWARE")*.md5" | sort -r | head -n 1)"

    if [ ! "$BL_TAR" ]; then
        LOG "\033[0;31m! BL tar를 찾을 수 없습니다\033[0m"
        exit 1
    elif [ ! "$AP_TAR" ]; then
        LOG "\033[0;31m! AP tar를 찾을 수 없습니다\033[0m"
        exit 1
    fi

    EXTRACT_KERNEL_BINARIES
    EXTRACT_OS_PARTITIONS
    EXTRACT_AVB_BINARIES

    echo -n "$DOWNLOADED_FIRMWARE" > "$FW_DIR/${MODEL}_${CSC}/.extracted"

    if [ -n "$GITHUB_ACTIONS" ]; then
        rm -rf "$ODIN_DIR/${MODEL}_${CSC}"
    fi

    LOG_STEP_OUT; LOG_STEP_OUT
done

rm -rf "$TMP_DIR"

exit 0
