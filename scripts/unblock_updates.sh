#!/bin/bash
set -e

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")
REAL_UID=$(id -u "$REAL_USER")

echo "=== 正在完全解除屏蔽，恢复 macOS 系统更新功能 ==="
echo "目标用户: $REAL_USER (UID: $REAL_UID)"

# 1. 恢复 hosts 规则
echo "1. 清理 /etc/hosts 屏蔽规则..."
sed -i '' '/swscan.apple.com/d' /etc/hosts 2>/dev/null || true
sed -i '' '/swdist.apple.com/d' /etc/hosts 2>/dev/null || true
sed -i '' '/swdownload.apple.com/d' /etc/hosts 2>/dev/null || true
sed -i '' '/swcdn.apple.com/d' /etc/hosts 2>/dev/null || true
sed -i '' '/updates-http.cdn-apple.com/d' /etc/hosts 2>/dev/null || true
sed -i '' '/updates.cdn-apple.com/d' /etc/hosts 2>/dev/null || true
sed -i '' '/gdmf.apple.com/d' /etc/hosts 2>/dev/null || true
sed -i '' '/mesu.apple.com/d' /etc/hosts 2>/dev/null || true
sed -i '' '/xp.apple.com/d' /etc/hosts 2>/dev/null || true
sed -i '' '/appldnld.apple.com/d' /etc/hosts 2>/dev/null || true
sed -i '' '/# macOS Software Update Block/d' /etc/hosts 2>/dev/null || true

# 2. 移除大版本更新隐藏描述文件 (如果已安装)
echo "2. 移除大版本更新隐藏描述文件..."
profiles remove -identifier org.stayonsequoia.profile -forced 2>/dev/null || true
profiles remove -identifier org.stayonsequoia.restrictions -forced 2>/dev/null || true

# 3. 恢复 Clash Verge 规则 (若存在)
CLASH_VERGE_DIR="$REAL_HOME/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"
if [ -d "$CLASH_VERGE_DIR" ]; then
    echo "3. 恢复 Clash Verge 规则配置..."
    MERGE_YAML="$CLASH_VERGE_DIR/profiles/Merge.yaml"
    if [ -f "$MERGE_YAML" ]; then
        cat << 'EOF' > "$MERGE_YAML"
# Profile Enhancement Merge Template for Clash Verge

profile:
  store-selected: true
EOF
        chown "$REAL_USER" "$MERGE_YAML" 2>/dev/null || true
    fi
    # 热重载 Clash 内核
    pkill -HUP -f "verge-mihomo" 2>/dev/null || true
fi

# 4. 解锁并恢复更新缓存目录与配置文件
echo "4. 解锁系统更新缓存目录与偏好文件..."
chflags -R nouchg /Library/Updates 2>/dev/null || true
chmod 755 /Library/Updates 2>/dev/null || true

chflags nouchg /Library/Preferences/com.apple.SoftwareUpdate.plist 2>/dev/null || true
chmod 644 /Library/Preferences/com.apple.SoftwareUpdate.plist 2>/dev/null || true
rm -f /Library/Preferences/com.apple.SoftwareUpdate.plist 2>/dev/null || true

# 5. 移除 CoreFollowUp 待办数据库中的免疫触发器
echo "5. 移除待办数据库中的免疫触发器..."
DB_PATH="$REAL_HOME/Library/CoreFollowUp/items.db"
if [ -f "$DB_PATH" ]; then
    sqlite3 "$DB_PATH" << 'EOF'
DROP TRIGGER IF EXISTS block_su_items;
DROP TRIGGER IF EXISTS block_su_actions;
EOF
    chown "$REAL_USER" "$DB_PATH"* 2>/dev/null || true
fi

# 6. 重新启用后台系统更新守护进程与用户通知
echo "6. 重新激活系统更新守护进程与通知..."
launchctl enable system/com.apple.softwareupdated 2>/dev/null || true
launchctl enable system/com.apple.mobile.softwareupdated 2>/dev/null || true
launchctl kickstart -k system/com.apple.softwareupdated 2>/dev/null || true

sudo -u "$REAL_USER" launchctl enable "gui/$REAL_UID/com.apple.SoftwareUpdateNotificationManager" 2>/dev/null || true

# 恢复用户设置自动检查开关
sudo -u "$REAL_USER" defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

# 7. 刷新 DNS 缓存与 UI 进程
echo "7. 刷新 DNS 与桌面配置..."
dscacheutil -flushcache
killall -HUP mDNSResponder 2>/dev/null || true
sudo -u "$REAL_USER" killall cfprefsd 2>/dev/null || true
sudo -u "$REAL_USER" killall Dock 2>/dev/null || true

echo "=== ✅ 全部解除完成！系统已恢复正常的更新检测功能 ==="
