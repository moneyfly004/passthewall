#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==========================================="
echo "开始构建 APK (Debug)"
echo "==========================================="
echo "工作目录: $SCRIPT_DIR"
echo ""

if ! command -v flutter &> /dev/null; then
    echo "错误: 未找到 Flutter 命令"
    echo "请确保 Flutter 已安装并添加到 PATH"
    exit 1
fi

echo "Flutter 版本:"
flutter --version | head -2
echo ""

echo "1. 清理项目..."
flutter clean

echo ""
echo "2. 获取依赖..."
flutter pub get

echo ""
echo "3. 运行代码生成..."
dart run build_runner build --delete-conflicting-outputs || echo "代码生成完成（可能有警告）"

echo ""
echo "4. 分析代码..."
flutter analyze --no-fatal-infos 2>&1 | grep -E "error •" | head -10 || echo "未发现错误"

echo ""
echo "5. 开始构建 APK..."
echo "开始时间: $(date)"
flutter build apk --debug
echo "结束时间: $(date)"

echo ""
echo "==========================================="
echo "构建完成！"
echo "==========================================="

if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
    echo "✓ APK 构建成功！"
    ls -lh build/app/outputs/flutter-apk/app-debug.apk
    echo ""
    echo "所有 APK 文件:"
    ls -lh build/app/outputs/flutter-apk/*.apk 2>/dev/null || true
else
    echo "✗ APK 构建失败，请检查错误信息"
    exit 1
fi
echo ""

