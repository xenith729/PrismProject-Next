# Copyright (c) 2025 Salvo Giangreco
# SPDX-License-Identifier: GPL-3.0-or-later

# PrismProject-Next debloat list
# - Add entries inside the specific partition containing that file (<PARTITION>_DEBLOAT+="")
# - DO NOT add the partition name at the start of any entry (eg. "/system/dpolicy_system")
# - DO NOT add a slash at the start of any entry (eg. "/dpolicy_system")

# Samsung PROCA certificate DB
SYSTEM_DEBLOAT+="
system/etc/proca.db
"

# Recovery restoration script
VENDOR_DEBLOAT+="
recovery-from-boot.p
bin/install-recovery.sh
etc/init/vendor_flash_recovery.rc
"

truncate -s 0 "$WORK_DIR/system/system/etc/vpl_apks_count_list.txt"

# Career Apps
SYSTEM_DEBLOAT+="
system/app/CarrierDefaultApp
system/app/KTAuth_Stub
system/app/KTCustomerService
system/app/KTUsimManager
system/app/LGUMiniCustomerCenter
system/app/LGUplusTsmProxy
system/app/SKTMemberShip_new
system/app/SktUsimService
system/app/TWorld
system/etc/omc-default-permissions
system/etc/permissions/privapp-permissions-com.samsung.android.cidmanager.xml
system/etc/permissions/privapp-permissions-com.sec.android.UsimRegistrationKOR.xml
system/etc/permissions/privapp-permissions-com.samsung.android.app.omcagent.xml
system/etc/permissions/privapp-permissions-com.lguplus.lgugpsnwps
system/etc/permissions/privapp-permissions-com.samsung.hidden.LGU.xml
system/etc/permissions/privapp-permissions-com.kt.olleh.servicemenu.xml
system/etc/permissions/privapp-permissions-com.kt.olleh.storefront.xml
system/etc/permissions/privapp-permissions-com.kt.serviceagent.xml
system/etc/permissions/privapp-permissions-com.samsung.hidden.KT.xml
system/etc/permissions/privapp-permissions-com.skt.hps20client.xml
system/etc/permissions/privapp-permissions-com.skt.prod.dialer.xml
system/etc/permissions/privapp-permissions-com.skt.skaf.A000Z00040.xml
system/etc/permissions/privapp-permissions-com.skt.skaf.OA00018282.xml
system/etc/permissions/privapp-permissions-com.skt.skaf.OA00199800.xml
system/etc/permissions/privapp-permissions-com.skt.t_smart_charge.xml
system/etc/default-permissions/default-permissions-com.lguplus.appstore.xml
system/etc/default-permissions/default-permissions-com.lguplus.lgugpsnwps.xml
system/etc/default-permissions/default-permissions-com.kt.ktauth.xml
system/etc/default-permissions/default-permissions-com.kt.olleh.servicemenu.xml
system/etc/default-permissions/default-permissions-com.kt.olleh.storefront.xml
system/etc/default-permissions/default-permissions-com.kt.serviceagent.xml
system/etc/default-permissions/default-permissions-com.ktshow.cs.xml
system/etc/default-permissions/default-permissions-com.skt.hps20client.xml
system/etc/default-permissions/default-permissions-com.skt.skaf.A000Z00040.xml
system/etc/default-permissions/default-permissions-com.skt.skaf.OA00018282.xml
system/etc/sysconfig/preinstalled-packages-com.samsung.android.cidmanager.xml
system/etc/sysconfig/preinstalled-packages-com.samsung.android.app.omcagent.xml
system/etc/sysconfig/com.lguplus.appstore.xml
system/etc/sysconfig/com.lguplus.lgugpsnwps.xml
system/etc/sysconfig/ktonestore.xml
system/etc/sysconfig/ktserviceagent.xml
system/etc/sysconfig/ktservicemenu.xml
system/etc/sysconfig/ktservicemenu-hiddenapi-package-whitelist.xml
system/etc/sysconfig/sktmembership.xml
system/etc/sysconfig/sktonestore.xml
system/priv-app/CIDManager
system/priv-app/KT114Provider2
system/priv-app/KTHiddenMenu
system/priv-app/KTOneStore
system/priv-app/KTServiceAgent
system/priv-app/KTServiceMenu
system/priv-app/LGUGPSnWPS
system/priv-app/LGUHiddenMenu
system/priv-app/LGUOZStore
system/priv-app/OMCAgent5
system/priv-app/OneStoreService
system/priv-app/SKTHiddenMenu
system/priv-app/SKTOneStore
system/priv-app/SmartPush_64
system/priv-app/TPhoneOnePackage
system/priv-app/TService
system/priv-app/UsimRegistrationKOR
"

# eSIM
[[ "$TARGET_COMMON_SUPPORT_EMBEDDED_SIM" == "false" ]] && SYSTEM_DEBLOAT+="
system/etc/permissions/privapp-permissions-com.samsung.android.app.esimkeystring.xml
system/etc/permissions/privapp-permissions-com.samsung.euicc.xml
system/etc/sysconfig/preinstalled-packages-com.samsung.android.app.esimkeystring.xml
system/etc/sysconfig/preinstalled-packages-com.samsung.euicc.xml
system/priv-app/EsimKeyString
system/priv-app/EuiccService
"

# Samsung Pass
SYSTEM_DEBLOAT+="
system/app/SamsungPassAutofill_v1
system/etc/init/samsung_pass_authenticator_service.rc
system/etc/permissions/authfw.xml
system/etc/permissions/privapp-permissions-com.samsung.android.authfw.xml
system/etc/permissions/privapp-permissions-com.samsung.android.samsungpass.xml
system/etc/permissions/signature-permissions-com.samsung.android.samsungpass.xml
system/etc/permissions/signature-permissions-com.samsung.android.samsungpassautofill.xml
system/etc/sysconfig/samsungauthframework.xml
system/etc/sysconfig/samsungpassapp.xml
system/priv-app/AuthFramework
system/priv-app/SamsungPass
"

# Samsung Wallet
SYSTEM_DEBLOAT+="
system/etc/init/digitalkey_init_ble_tss2.rc
system/etc/permissions/org.carconnectivity.android.digitalkey.rangingintent.xml
system/etc/permissions/org.carconnectivity.android.digitalkey.secureelement.xml
system/etc/permissions/privapp-permissions-com.samsung.android.carkey.xml
system/etc/permissions/privapp-permissions-com.samsung.android.dkey.xml
system/etc/permissions/privapp-permissions-com.samsung.android.spayfw.xml
system/etc/permissions/signature-permissions-com.samsung.android.spay.xml
system/etc/permissions/signature-permissions-com.samsung.android.spayfw.xml
system/etc/sysconfig/digitalkey.xml
system/etc/sysconfig/preinstalled-packages-com.samsung.android.dkey.xml
system/etc/sysconfig/preinstalled-packages-com.samsung.android.spayfw.xml
system/priv-app/DigitalKey
system/priv-app/PaymentFramework
system/priv-app/SamsungCarKeyFw
"
SYSTEM_EXT_DEBLOAT+="
framework/org.carconnectivity.android.digitalkey.rangingintent.jar
framework/org.carconnectivity.android.digitalkey.secureelement.jar
"

# HwModuleTest
SYSTEM_DEBLOAT+="
system/app/FactoryAirCommandManager
system/app/FactoryCameraFB
system/app/HMT
system/app/WlanTest
system/app/BluetoothAgent
system/etc/permissions/privapp-permissions-com.samsung.android.providers.factory.xml
system/etc/permissions/privapp-permissions-com.sec.facatfunction.xml
system/etc/sysconfig/preinstalled-packages-com.sec.android.app.bluetoothagent.xml
system/priv-app/FacAtFunction
system/priv-app/FactoryTestProvider
system/priv-app/SEMFactoryApp
"

# Samsung Knox
SYSTEM_DEBLOAT+="
system/etc/permissions/privapp-permissions-com.skms.android.agent.xml
system/etc/sysconfig/preinstalled-packages-com.samsung.android.bbc.bbcagent.xml
system/etc/sysconfig/preinstalled-packages-com.samsung.android.mdm.xml
system/priv-app/knoxanalyticsagent
system/priv-app/SKMSAgent
system/app/BBCAgent
system/app/Rampart
system/app/MDMApp
system/app/UniversalMDMClient
"

# Samsung Analytics
SYSTEM_DEBLOAT+="
system/app/DsmsAPK
system/etc/permissions/privapp-permissions-com.samsung.android.dqagent.xml
system/etc/permissions/privapp-permissions-com.sec.android.diagmonagent.xml
system/etc/permissions/privapp-permissions-com.sec.android.soagent.xml
system/etc/sysconfig/preinstalled-packages-com.sec.android.soagent.xml
system/priv-app/DeviceQualityAgent38
system/priv-app/DiagMonAgent97
system/priv-app/SOAgent77
"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_CONTEXTSERVICE_ENABLE_SURVEY_MODE" --delete

# Gaming Hub
SYSTEM_DEBLOAT+="
system/etc/permissions/privapp-permissions-com.samsung.android.game.gamehome.xml
system/priv-app/GameHome
"
ADD_TO_WORK_DIR "pa2qxxx" "system" \
    "system/etc/permissions/signature-permissions-com.samsung.android.game.gamehome.xml" \
    0 0 644 "u:object_r:system_file:s0"

# Link to Windows
# Replace full apk with stub apk to save space
SYSTEM_DEBLOAT+="
system/priv-app/YourPhone_P1_5
"
ADD_TO_WORK_DIR "gta9pxxx" "system" "system/priv-app/YourPhone_Stub/YourPhone_Stub.apk" 0 0 644 "u:object_r:system_file:s0"

# Meta
SYSTEM_DEBLOAT+="
system/app/FBAppManager_NS
system/etc/default-permissions/default-permissions-meta.xml
system/etc/permissions/privapp-permissions-meta.xml
system/etc/sysconfig/meta-hiddenapi-package-allowlist.xml
system/priv-app/FBInstaller_NS
system/priv-app/FBServices
"

# SettingsHelper
SYSTEM_DEBLOAT+="
system/etc/permissions/privapp-permissions-com.samsung.android.settingshelper.xml
system/etc/sysconfig/settingshelper.xml
system/priv-app/SHClient
"

# Smart Touch Call
SYSTEM_DEBLOAT+="
system/etc/default-permissions/default-permissions-com.samsung.android.visualars.xml
system/etc/permissions/privapp-permissions-com.samsung.android.visualars.xml
system/priv-app/SmartTouchCall
"

# Software Update
SYSTEM_DEBLOAT+="
system/etc/permissions/privapp-permissions-com.wssyncmldm.xml
system/priv-app/FotaAgent
"

# SVC Agent
SYSTEM_DEBLOAT+="
system/etc/permissions/privapp-permissions-com.samsung.android.svcagent.xml
system/priv-app/SVCAgent
"

# Samsung Visit In
SYSTEM_DEBLOAT+="
system/etc/permissions/com.samsung.feature.ipsgeofence.xml
system/etc/permissions/privapp-permissions-com.samsung.android.ipsgeofence.xml
system/priv-app/IpsGeofence
"

# SamsungPositioning
SYSTEM_DEBLOAT+="
system/etc/sysconfig/preinstalled-packages-com.samsung.android.samsungpositioning.xml
system/etc/permissions/privapp-permissions-com.samsung.android.samsungpositioning.xml
system/priv-app/SamsungPositioning
"

# Smart Tutor
SYSTEM_DEBLOAT+="
system/hidden/SmartTutor
"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_COMMON_CONFIG_SMARTTUTOR_PACKAGES_PATH" --delete

# AppUpdateCenter
SYSTEM_DEBLOAT+="
system/etc/permissions/privapp-permissions-com.samsung.android.app.updatecenter.xml
system/priv-app/AppUpdateCenter
"

# BCService
SYSTEM_DEBLOAT+="
system/etc/permissions/privapp-permissions-com.sec.bcservice.xml
system/priv-app/BCService
"

# CallLogBackup
SYSTEM_DEBLOAT+="
system/etc/permissions/privapp-permissions-com.samsung.android.calllogbackup.xml
system/priv-app/CallLogBackup
"

# Application recommendations
SYSTEM_DEBLOAT+="
system/app/MAPSAgent
"

# Game Optimizing Service
SYSTEM_DEBLOAT+="
system/etc/permissions/privapp-permissions-com.samsung.android.game.gos.xml
system/priv-app/GameOptimizingService
"

# System Tracing
SYSTEM_DEBLOAT+="
system/priv-app/Traceur
"

# Security Policy
SYSTEM_DEBLOAT+="
system/app/AASAservice
"

# Bluetooth Midi Service
SYSTEM_DEBLOAT+="
system/app/BluetoothMidiService
"

# Bookmark Provider
SYSTEM_DEBLOAT+="
system/app/BookmarkProvider
system/app/PartnerBookmarksProvider
"

# Samsung AR Emoji
SYSTEM_DEBLOAT+="
system/etc/permissions/privapp-permissions-com.samsung.android.aremoji.xml
system/priv-app/AREmoji
"

# EnhancedAttestationAgent
SYSTEM_DEBLOAT+="
system/priv-app/EnhancedAttestationAgent
"

# Wi-Fi Guider
SYSTEM_DEBLOAT+="
system/app/WifiGuider
"

# Fast
SYSTEM_DEBLOAT+="
system/app/Fast
"

# Silent Logging
SYSTEM_DEBLOAT+="
system/app/SilentLog
"

# IMS Logging
SYSTEM_DEBLOAT+="
system/etc/sysconfig/preinstalled-packages-com.sec.imslogger
system/etc/permissions/privapp-permissions-com.sec.imslogger.xml
system/priv-app/ImsLogger
"

# Sim App Dialog
SYSTEM_DEBLOAT+="
system/app/SimAppDialog
"

# TalkBack
SYSTEM_DEBLOAT+="
system/app/TalkBack
"

# ccinfo
SYSTEM_DEBLOAT+="
system/app/ccinfo
"

# ChromeCustomizations
SYSTEM_DEBLOAT+="
system/app/ChromeCustomizations
"

# Contacts Widget
SYSTEM_DEBLOAT+="
system/app/EasymodeContactsWidget81
"

# Parental Care
SYSTEM_DEBLOAT+="
system/app/ParentalCare
"

# Samsung Kids
SYSTEM_DEBLOAT+="
system/app/KidsHome_Installer
"

# Language packs
SYSTEM_DEBLOAT+="$(find "$WORK_DIR/system" -type d -name "*TTSVoice*" | sed "s|$WORK_DIR/system/||g")"

# Samsung Language Core
SYSTEM_DEBLOAT+="
system/etc/permissions/signature-permissions-com.samsung.android.offline.languagemodel.xml
system/priv-app/OfflineLanguageModel_stub
"

# Samsung Calendar
SYSTEM_DEBLOAT+="
system/app/SamsungCalendar
"

# Samsung Clock
SYSTEM_DEBLOAT+="
system/app/ClockPackage
"

# Samsung Free
SYSTEM_DEBLOAT+="
system/app/MinusOnePage
"

# Samsung Reminder
SYSTEM_DEBLOAT+="
system/app/SmartReminder
"

# Galaxy Wearable
SYSTEM_DEBLOAT+="
system/app/GearManagerStub
"

# Google Apps
SYSTEM_DEBLOAT+="
system/app/VoiceAccess
system/app/LiveTranscribe
system/app/PlayAutoInstallConfig
system/etc/sysconfig/feature-a11y-preload-voacc.xml
system/etc/sysconfig/feature-a11y-preload.xml
"

PRODUCT_DEBLOAT+="
app/BardShell
app/Chrome64
app/com.google.mainline.adservices
app/com.google.mainline.telemetry
app/DuoStub
app/Gmail2
app/Maps
app/YouTube
priv-app/AndroidDeveloperVerifier
priv-app/FamilyLinkParentalControls
"