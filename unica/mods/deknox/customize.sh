# Fix SDHMS crash loop: siop_default.xml references OverheatComplexType.DEX which doesn't exist in the enum
DECODE_APK "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk" || return 1
_SDHMS_XML="$APKTOOL_DIR/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk/assets/siop_default.xml"
if grep -q '<DEX ' "$_SDHMS_XML" 2>/dev/null; then
    LOG "- Removing unsupported DEX overheat complex type from SDHMS siop_default.xml"
    sed -i '/<DEX /d' "$_SDHMS_XML"
else
    LOG "- siop_default.xml: DEX entry not found (already removed or not present)"
fi
unset _SDHMS_XML

# Nuke Knox HDM version (HdmManager method body differs in t2s vs S26U)
DECODE_APK "system" "system/priv-app/SecSettings/SecSettings.apk" || return 1
_HDM_SMALI="$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/smali_classes3/com/samsung/android/knox/hdm/HdmManager.smali"
LOG "- Nuking getHdmVersion() in /system/system/priv-app/SecSettings/SecSettings.apk/HdmManager.smali"
python3 - "$_HDM_SMALI" << 'PYEOF'
import sys, re
path = sys.argv[1]
with open(path) as f:
    content = f.read()
old = re.search(
    r'(\.method public static getHdmVersion\(\)Ljava/lang/String;\n    \.locals \d+\n\n'
    r'    sget-object v0, Lcom/samsung/android/knox/hdm/HdmManager;->TAG:Ljava/lang/String;\n\n'
    r'    const-string v1, "getHdmVersion\(\) on HdmManager\.java"\n\n'
    r'    invoke-static \{v0, v1\}, Landroid/util/Log;->d\(Ljava/lang/String;Ljava/lang/String;\)I\n)'
    r'.*?(\n    return-object v0\n\.end method)',
    content, re.DOTALL
)
if not old:
    print('WARNING: getHdmVersion pattern not found', file=sys.stderr)
    sys.exit(1)
new_body = (old.group(1) +
    '\n    const/4 v0, 0x0' +
    old.group(2))
content = content[:old.start()] + new_body + content[old.end():]
content = re.sub(
    r'(\.method public static getHdmVersion\(\)Ljava/lang/String;\n    )\.locals \d+',
    r'\1.locals 2',
    content, count=1
)
with open(path, 'w') as f:
    f.write(content)
PYEOF
[ $? -ne 0 ] && { LOG "\033[0;31m! ERROR: HdmManager getHdmVersion() fix failed\033[0m"; return 1; }
unset _HDM_SMALI

# Nuke Knox DualDAR and HDM version in SecSettingsIntelligence
DECODE_APK "system" "system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk" || return 1
_SSI_DIR="$APKTOOL_DIR/system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk"
LOG "- Nuking getDualDARVersion() in /system/system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk"
python3 - "$_SSI_DIR/smali_classes2/com/samsung/android/knox/ddar/DualDARPolicy.smali" << 'PYEOF'
import sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()
old = '    const-string v0, "1.9.0"\n\n    return-object v0\n.end method'
new = '    const/4 v0, 0x0\n\n    return-object v0\n.end method'
if old not in content:
    print('WARNING: DualDARPolicy getDualDARVersion pattern not found', file=sys.stderr)
    sys.exit(1)
with open(path, 'w') as f:
    f.write(content.replace(old, new, 1))
PYEOF
[ $? -ne 0 ] && { LOG "\033[0;31m! ERROR: SecSettingsIntelligence DualDARPolicy fix failed\033[0m"; return 1; }

LOG "- Nuking getHdmVersion() in /system/system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk"
python3 - "$_SSI_DIR/smali_classes2/com/samsung/android/knox/hdm/HdmManager.smali" << 'PYEOF'
import sys, re
path = sys.argv[1]
with open(path) as f:
    content = f.read()
old = re.search(
    r'(\.method public static getHdmVersion\(\)Ljava/lang/String;\n    \.locals \d+\n\n'
    r'    sget-object v0, Lcom/samsung/android/knox/hdm/HdmManager;->TAG:Ljava/lang/String;\n\n'
    r'    const-string v1, "getHdmVersion\(\) on HdmManager\.java"\n\n'
    r'    invoke-static \{v0, v1\}, Landroid/util/Log;->d\(Ljava/lang/String;Ljava/lang/String;\)I\n)'
    r'.*?(\n    return-object v0\n\.end method)',
    content, re.DOTALL
)
if not old:
    print('WARNING: getHdmVersion pattern not found', file=sys.stderr)
    sys.exit(1)
new_body = (old.group(1) +
    '\n    const/4 v0, 0x0' +
    old.group(2))
content = content[:old.start()] + new_body + content[old.end():]
content = re.sub(
    r'(\.method public static getHdmVersion\(\)Ljava/lang/String;\n    )\.locals \d+',
    r'\1.locals 2',
    content, count=1
)
with open(path, 'w') as f:
    f.write(content)
PYEOF
[ $? -ne 0 ] && { LOG "\033[0;31m! ERROR: SecSettingsIntelligence HdmManager fix failed\033[0m"; return 1; }
unset _SSI_DIR

# Nuke Knox DualDAR and HDM version in knoxsdk.jar
DECODE_APK "system" "system/framework/knoxsdk.jar" || return 1
_KNOX_DIR="$APKTOOL_DIR/system/framework/knoxsdk.jar"
LOG "- Nuking getDualDARVersion() in /system/system/framework/knoxsdk.jar"
python3 - "$_KNOX_DIR/smali/com/samsung/android/knox/ddar/DualDARPolicy.smali" << 'PYEOF'
import sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()
old = '    const-string v0, "1.9.0"\n\n    return-object v0\n.end method'
new = '    const/4 v0, 0x0\n\n    return-object v0\n.end method'
if old not in content:
    print('WARNING: knoxsdk DualDARPolicy getDualDARVersion pattern not found', file=sys.stderr)
    sys.exit(1)
with open(path, 'w') as f:
    f.write(content.replace(old, new, 1))
PYEOF
[ $? -ne 0 ] && { LOG "\033[0;31m! ERROR: knoxsdk DualDARPolicy fix failed\033[0m"; return 1; }

LOG "- Nuking getHdmVersion() in /system/system/framework/knoxsdk.jar"
python3 - "$_KNOX_DIR/smali/com/samsung/android/knox/hdm/HdmManager.smali" << 'PYEOF'
import sys, re
path = sys.argv[1]
with open(path) as f:
    content = f.read()
old = re.search(
    r'(\.method public static greylist getHdmVersion\(\)Ljava/lang/String;\n    \.locals \d+\n\n'
    r'    sget-object v0, Lcom/samsung/android/knox/hdm/HdmManager;->TAG:Ljava/lang/String;\n\n'
    r'    const-string v1, "getHdmVersion\(\) on HdmManager\.java"\n\n'
    r'    invoke-static \{v0, v1\}, Landroid/util/Log;->d\(Ljava/lang/String;Ljava/lang/String;\)I\n)'
    r'.*?(\n    return-object v0\n\.end method)',
    content, re.DOTALL
)
if not old:
    print('WARNING: knoxsdk getHdmVersion pattern not found', file=sys.stderr)
    sys.exit(1)
new_body = (old.group(1) +
    '\n    const/4 v0, 0x0' +
    old.group(2))
content = content[:old.start()] + new_body + content[old.end():]
content = re.sub(
    r'(\.method public static greylist getHdmVersion\(\)Ljava/lang/String;\n    )\.locals \d+',
    r'\1.locals 2',
    content, count=1
)
with open(path, 'w') as f:
    f.write(content)
PYEOF
[ $? -ne 0 ] && { LOG "\033[0;31m! ERROR: knoxsdk HdmManager fix failed\033[0m"; return 1; }
unset _KNOX_DIR

# Nuke Knox DualDAR and HDM version in StorageManager
DECODE_APK "system_ext" "priv-app/StorageManager/StorageManager.apk" || return 1
_SM_DIR="$APKTOOL_DIR/system_ext/priv-app/StorageManager/StorageManager.apk"
LOG "- Nuking getDualDARVersion() in /system_ext/priv-app/StorageManager/StorageManager.apk"
python3 - "$_SM_DIR/smali/com/samsung/android/knox/ddar/DualDARPolicy.smali" << 'PYEOF'
import sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()
old = '    const-string v0, "1.9.0"\n\n    return-object v0\n.end method'
new = '    const/4 v0, 0x0\n\n    return-object v0\n.end method'
if old not in content:
    print('WARNING: StorageManager DualDARPolicy getDualDARVersion pattern not found', file=sys.stderr)
    sys.exit(1)
with open(path, 'w') as f:
    f.write(content.replace(old, new, 1))
PYEOF
[ $? -ne 0 ] && { LOG "\033[0;31m! ERROR: StorageManager DualDARPolicy fix failed\033[0m"; return 1; }

LOG "- Nuking getHdmVersion() in /system_ext/priv-app/StorageManager/StorageManager.apk"
python3 - "$_SM_DIR/smali/com/samsung/android/knox/hdm/HdmManager.smali" << 'PYEOF'
import sys, re
path = sys.argv[1]
with open(path) as f:
    content = f.read()
old = re.search(
    r'(\.method public static getHdmVersion\(\)Ljava/lang/String;\n    \.locals \d+\n\n'
    r'    sget-object v0, Lcom/samsung/android/knox/hdm/HdmManager;->TAG:Ljava/lang/String;\n\n'
    r'    const-string v1, "getHdmVersion\(\) on HdmManager\.java"\n\n'
    r'    invoke-static \{v0, v1\}, Landroid/util/Log;->d\(Ljava/lang/String;Ljava/lang/String;\)I\n)'
    r'.*?(\n    return-object v0\n\.end method)',
    content, re.DOTALL
)
if not old:
    print('WARNING: StorageManager getHdmVersion pattern not found', file=sys.stderr)
    sys.exit(1)
new_body = (old.group(1) +
    '\n    const/4 v0, 0x0' +
    old.group(2))
content = content[:old.start()] + new_body + content[old.end():]
content = re.sub(
    r'(\.method public static getHdmVersion\(\)Ljava/lang/String;\n    )\.locals \d+',
    r'\1.locals 2',
    content, count=1
)
with open(path, 'w') as f:
    f.write(content)
PYEOF
[ $? -ne 0 ] && { LOG "\033[0;31m! ERROR: StorageManager HdmManager fix failed\033[0m"; return 1; }
unset _SM_DIR

# KnoxGuard
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxGuard"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.kgclient.xml"

# DualDAR
DELETE_FROM_WORK_DIR "system" "system/bin/dualdard"
DELETE_FROM_WORK_DIR "system" "system/etc/init/dualdard.rc"

# Blockchain
DELETE_FROM_WORK_DIR "system" "system/app/BlockchainBasicKit"
DELETE_FROM_WORK_DIR "system" "system/framework/service-samsung-blockchain.jar"
DELETE_FROM_WORK_DIR "system" "system/etc/sysconfig/preinstalled-packages-com.samsung.android.coldwalletservice.xml"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_FRAMEWORK_SUPPORT_BLOCKCHAIN_SERVICE" --delete

# MPOS
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.knox.mpos.xml"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxMposAgent"

# eSE COS
DELETE_FROM_WORK_DIR "system" "system/bin/sem_daemon"
DELETE_FROM_WORK_DIR "system" "system/etc/init/sem_early.rc"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.sem.factoryapp.xml"
DELETE_FROM_WORK_DIR "system" "system/lib64/libsec_sem.so"
DELETE_FROM_WORK_DIR "system" "system/lib64/libsec_semAidl.so"
DELETE_FROM_WORK_DIR "system" "system/lib64/libsec_semTlc.so"
DELETE_FROM_WORK_DIR "system" "system/lib64/vendor.samsung.hardware.security.sem-V1-ndk.so"
DELETE_FROM_WORK_DIR "system" "system/priv-app/SEMFactoryApp"

# HDM
DELETE_FROM_WORK_DIR "system" "system/priv-app/HdmApk"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.hdmapp.xml"

# WSM
DELETE_FROM_WORK_DIR "system" "system/etc/public.libraries-wsm.samsung.txt"
DELETE_FROM_WORK_DIR "system" "system/lib64/libhal.wsm.samsung.so"
DELETE_FROM_WORK_DIR "system" "system/lib64/vendor.samsung.hardware.security.wsm.service-V1-ndk.so"

# Knox ZeroTrust
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.knox.zt.framework.xml"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxZtFramework"

# Knox Matrix
DELETE_FROM_WORK_DIR "system" "system/bin/fabric_crypto"
DELETE_FROM_WORK_DIR "system" "system/etc/init/fabric_crypto.rc"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/FabricCryptoLib.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.kmxservice.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/vintf/manifest/fabric_crypto_manifest.xml"
DELETE_FROM_WORK_DIR "system" "system/framework/FabricCryptoLib.jar"
DELETE_FROM_WORK_DIR "system" "system/lib64/com.samsung.security.fabric.cryptod-V1-cpp.so"
DELETE_FROM_WORK_DIR "system" "system/lib64/vendor.samsung.hardware.security.fkeymaster-V1-cpp.so"
DELETE_FROM_WORK_DIR "system" "system/lib64/vendor.samsung.hardware.security.fkeymaster-V1-ndk.so"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KmxService"

# Other Knox APKs
DELETE_FROM_WORK_DIR "system" "system/priv-app/KPECore"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxCore"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxERAgent"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxFrameBufferProvider"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxNetworkFilter"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxNeuralNetworkRuntime"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxPushManager"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxSandbox"
DELETE_FROM_WORK_DIR "system" "system/priv-app/knoxanalyticsagent"
DELETE_FROM_WORK_DIR "system" "system/priv-app/knoxvpnproxyhandler"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.knox.vpn.proxyhandler.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.knox.analytics.uploader.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.knox.app.networkfilter.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.knox.er.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.knox.kfbp.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.knox.knnr.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.knox.kpecore.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.knox.pushmanager.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.knox.sandbox.xml"