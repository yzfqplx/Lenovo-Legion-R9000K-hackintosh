#!/bin/bash
set -e

echo "=== 正在解除 hosts 屏蔽 macOS 系统更新 ==="

sudo sed -i '' '/swscan.apple.com/d' /etc/hosts
sudo sed -i '' '/swdist.apple.com/d' /etc/hosts
sudo sed -i '' '/swcdn.apple.com/d' /etc/hosts
sudo sed -i '' '/gdmf.apple.com/d' /etc/hosts
sudo sed -i '' '/mesu.apple.com/d' /etc/hosts
sudo sed -i '' '/xp.apple.com/d' /etc/hosts
sudo sed -i '' '/# macOS Software Update Block/d' /etc/hosts

echo "刷新 DNS 缓存..."
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# 重新启用通知组件
launchctl enable gui/$(id -u)/com.apple.SoftwareUpdateNotificationManager 2>/dev/null || true

echo "=== ✅ 已恢复系统更新检测功能 ==="
