#!/bin/bash
set -e

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")
REAL_UID=$(id -u "$REAL_USER")

echo "=== 正在解除屏蔽 macOS 系统更新 ==="

# 1. 恢复 hosts
sudo sed -i '' '/swscan.apple.com/d' /etc/hosts
sudo sed -i '' '/swdist.apple.com/d' /etc/hosts
sudo sed -i '' '/swdownload.apple.com/d' /etc/hosts
sudo sed -i '' '/swcdn.apple.com/d' /etc/hosts
sudo sed -i '' '/updates-http.cdn-apple.com/d' /etc/hosts
sudo sed -i '' '/updates.cdn-apple.com/d' /etc/hosts
sudo sed -i '' '/gdmf.apple.com/d' /etc/hosts
sudo sed -i '' '/mesu.apple.com/d' /etc/hosts
sudo sed -i '' '/xp.apple.com/d' /etc/hosts
sudo sed -i '' '/appldnld.apple.com/d' /etc/hosts
sudo sed -i '' '/# macOS Software Update Block/d' /etc/hosts

# 2. 恢复 Clash Verge
CLASH_VERGE_DIR="$REAL_HOME/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"
MERGE_YAML="$CLASH_VERGE_DIR/profiles/Merge.yaml"
if [ -f "$MERGE_YAML" ]; then
    cat << 'EOF' > "$MERGE_YAML"
# Profile Enhancement Merge Template for Clash Verge

profile:
  store-selected: true
EOF
    chown "$REAL_USER" "$MERGE_YAML" 2>/dev/null || true
    pkill -HUP -f "verge-mihomo" 2>/dev/null || true
fi

# 3. 解锁目录和文件
chflags -R nouchg /Library/Updates 2>/dev/null || true
chmod 755 /Library/Updates 2>/dev/null || true

chflags nouchg /Library/Preferences/com.apple.SoftwareUpdate.plist 2>/dev/null || true
rm -f /Library/Preferences/com.apple.SoftwareUpdate.plist 2>/dev/null || true

# 4. 移除 SQLite 触发器
DB_PATH="$REAL_HOME/Library/CoreFollowUp/items.db"
if [ -f "$DB_PATH" ]; then
    sqlite3 "$DB_PATH" "DROP TRIGGER IF EXISTS block_su_items; DROP TRIGGER IF EXISTS block_su_actions;" 2>/dev/null || true
fi

# 5. 刷新 DNS 缓存
dscacheutil -flushcache
killall -HUP mDNSResponder 2>/dev/null || true

# 6. 重启更新服务
launchctl kickstart -k system/com.apple.softwareupdated 2>/dev/null || true
sudo -u "$REAL_USER" launchctl enable "gui/$REAL_UID/com.apple.SoftwareUpdateNotificationManager" 2>/dev/null || true

echo "=== ✅ 已恢复系统更新检测功能 ==="
