#!/bin/bash
set -e

echo "=== 正在配置 hosts 屏蔽 macOS 系统更新 ==="

# 检查是否已存在规则
if grep -q "swscan.apple.com" /etc/hosts; then
    echo "提示: /etc/hosts 中已存在屏蔽规则，无需重复写入。"
else
    echo "1. 备份 /etc/hosts 到 /etc/hosts.bak..."
    sudo cp /etc/hosts /etc/hosts.bak
    echo "2. 向 /etc/hosts 写入屏蔽域名..."
    sudo tee -a /etc/hosts >/dev/null << 'EOF'

# macOS Software Update Block
127.0.0.1 swscan.apple.com
127.0.0.1 swdist.apple.com
127.0.0.1 swcdn.apple.com
127.0.0.1 gdmf.apple.com
127.0.0.1 mesu.apple.com
127.0.0.1 xp.apple.com
EOF
    echo "   已成功添加到 /etc/hosts"
fi

echo "3. 刷新 DNS 缓存..."
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

echo "4. 清理旧的系统更新缓存文件..."
sudo rm -f /Library/Preferences/com.apple.SoftwareUpdate.plist 2>/dev/null || true
rm -f ~/Library/Preferences/com.apple.SoftwareUpdate.plist 2>/dev/null || true

echo "5. 清除设置小红点角标及关闭自动检查..."
defaults write com.apple.systempreferences AttentionPrefBundleIDs -dict
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false
defaults write com.apple.SoftwareUpdate AutomaticDownload -bool false

# 禁用更新通知常驻进程并重启相关 UI 进程
launchctl disable gui/$(id -u)/com.apple.SoftwareUpdateNotificationManager 2>/dev/null || true
killall SoftwareUpdateNotificationManager 2>/dev/null || true
killall followupd 2>/dev/null || true
killall Dock 2>/dev/null || true

echo "=== ✅ 全部完成！系统更新已被彻底屏蔽，设置小红点已消除 ==="
