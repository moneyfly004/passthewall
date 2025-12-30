#!/bin/bash

echo "════════════════════════════════════════════════════"
echo "    Hiddify 日志监控工具"
echo "════════════════════════════════════════════════════"
echo ""

# 检查手机连接
echo "检查手机连接状态..."
DEVICES=$(adb devices | grep -v "List of devices" | grep device)
if [ -z "$DEVICES" ]; then
    echo "❌ 未检测到手机连接"
    echo ""
    echo "请确保："
    echo "1. 手机已用数据线连接到电脑"
    echo "2. 手机已开启 USB 调试"
    echo "3. 手机上已点击允许 USB 调试"
    echo ""
    echo "然后运行: adb devices"
    exit 1
fi

echo "✅ 手机已连接: $DEVICES"
echo ""
echo "════════════════════════════════════════════════════"
echo "开始监控日志（按 Ctrl+C 停止）"
echo "════════════════════════════════════════════════════"
echo ""

# 清除旧日志
adb logcat -c

# 方式 1：查看所有 Hiddify 相关日志（推荐）
echo "使用过滤器: hiddify|BoxService|CommandServer|permission|socket"
echo ""
adb logcat | grep -iE "hiddify|BoxService|CommandServer|permission|socket|denied"

# 如果没有日志，尝试：
# adb logcat | grep -i hiddify
# 或者查看所有日志：adb logcat

