#!/bin/bash

echo "════════════════════════════════════════════════════"
echo "  Hiddify 完整测试流程"
echo "════════════════════════════════════════════════════"
echo ""

# 检查设备连接
echo "1️⃣ 检查手机连接..."
DEVICE=$(adb devices | grep device$ | awk '{print $1}')
if [ -z "$DEVICE" ]; then
    echo "❌ 手机未连接"
    exit 1
fi
echo "✅ 手机已连接: $DEVICE"
echo ""

# 检查应用是否已安装
echo "2️⃣ 检查 Hiddify 是否已安装..."
INSTALLED=$(adb shell pm list packages | grep app.hiddify.com)
if [ -z "$INSTALLED" ]; then
    echo "❌ Hiddify 未安装"
    echo ""
    echo "请先安装 APK："
    echo "adb install build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk"
    exit 1
fi
echo "✅ Hiddify 已安装"
echo ""

# 检查应用版本
echo "3️⃣ 获取应用信息..."
adb shell dumpsys package app.hiddify.com | grep "versionName" | head -1
echo ""

# 清除旧日志
echo "4️⃣ 清除旧日志..."
adb logcat -c
echo "✅ 日志已清除"
echo ""

echo "════════════════════════════════════════════════════"
echo "  开始监控日志"
echo "════════════════════════════════════════════════════"
echo ""
echo "请在手机上操作 Hiddify："
echo "  1. 打开应用"
echo "  2. 点击连接按钮"
echo ""
echo "下面会显示所有包含以下关键词的日志："
echo "  - hiddify"
echo "  - permission"
echo "  - socket"
echo "  - denied"
echo "  - BoxService"
echo ""
echo "按 Ctrl+C 停止监控"
echo "════════════════════════════════════════════════════"
echo ""

# 监控日志 - 使用多个关键词
adb logcat | grep --line-buffered -iE "hiddify|permission.*denied|socket.*bind|BoxService|CommandServer|A/MainActivity"

