#!/bin/bash

echo "════════════════════════════════════════════════════"
echo "    Mac mini 安装 adb 工具"
echo "════════════════════════════════════════════════════"
echo ""

# 检查 Homebrew
if ! command -v brew &> /dev/null; then
    echo "⏳ Homebrew 未安装，正在安装..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # 添加到 PATH（Apple Silicon Mac）
    if [[ $(uname -m) == 'arm64' ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "✅ Homebrew 已安装"
fi

echo ""
echo "⏳ 安装 Android Platform Tools (包含 adb)..."
brew install android-platform-tools

echo ""
echo "════════════════════════════════════════════════════"
echo "✅ 安装完成！"
echo "════════════════════════════════════════════════════"
echo ""
echo "验证安装："
adb version

echo ""
echo "════════════════════════════════════════════════════"
echo "📱 下一步："
echo "════════════════════════════════════════════════════"
echo "1. 用数据线连接手机和电脑"
echo "2. 手机上允许 USB 调试"
echo "3. 运行: adb devices"
echo "4. 运行: adb logcat | grep A/BoxService"
echo ""

