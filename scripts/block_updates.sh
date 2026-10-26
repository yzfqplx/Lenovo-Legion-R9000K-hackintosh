#!/bin/bash
set -e

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")
REAL_UID=$(id -u "$REAL_USER")

echo "=== 正在执行 macOS 系统更新与红点终极屏蔽 ==="
echo "目标用户: $REAL_USER (UID: $REAL_UID)"

# 1. 配置 hosts 屏蔽域名
if grep -q "swscan.apple.com" /etc/hosts; then
    echo "1. hosts 已包含屏蔽规则。"
else
    echo "1. 写入 /etc/hosts 屏蔽规则..."
    [ ! -f /etc/hosts.bak ] && cp /etc/hosts /etc/hosts.bak
    tee -a /etc/hosts >/dev/null << 'EOF'

# macOS Software Update Block
127.0.0.1 swscan.apple.com
127.0.0.1 swdist.apple.com
127.0.0.1 swdownload.apple.com
127.0.0.1 swcdn.apple.com
127.0.0.1 updates-http.cdn-apple.com
127.0.0.1 updates.cdn-apple.com
127.0.0.1 gdmf.apple.com
127.0.0.1 mesu.apple.com
127.0.0.1 xp.apple.com
127.0.0.1 appldnld.apple.com
EOF
fi

# 2. 拦截 Clash Verge (针对 TUN 模式)
CLASH_VERGE_DIR="$REAL_HOME/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"
if [ -d "$CLASH_VERGE_DIR" ]; then
    echo "2. 配置 Clash Verge TUN 模式拦截规则..."
    if [ -f "$CLASH_VERGE_DIR/dns_config.yaml" ]; then
        sed -i '' 's/use-system-hosts: false/use-system-hosts: true/g' "$CLASH_VERGE_DIR/dns_config.yaml" 2>/dev/null || true
        sed -i '' 's/use-hosts: false/use-hosts: true/g' "$CLASH_VERGE_DIR/dns_config.yaml" 2>/dev/null || true
    fi
    MERGE_YAML="$CLASH_VERGE_DIR/profiles/Merge.yaml"
    if [ -f "$MERGE_YAML" ]; then
        cat << 'EOF' > "$MERGE_YAML"
# Profile Enhancement Merge Template for Clash Verge

prepend-rules:
  - DOMAIN,swscan.apple.com,REJECT
  - DOMAIN,swdist.apple.com,REJECT
  - DOMAIN,swdownload.apple.com,REJECT
  - DOMAIN,swcdn.apple.com,REJECT
  - DOMAIN,updates-http.cdn-apple.com,REJECT
  - DOMAIN,updates.cdn-apple.com,REJECT
  - DOMAIN,gdmf.apple.com,REJECT
  - DOMAIN,mesu.apple.com,REJECT
  - DOMAIN,xp.apple.com,REJECT
  - DOMAIN,appldnld.apple.com,REJECT
  - DOMAIN-SUFFIX,swscan.apple.com,REJECT
  - DOMAIN-SUFFIX,swdist.apple.com,REJECT
  - DOMAIN-SUFFIX,swcdn.apple.com,REJECT
  - DOMAIN-SUFFIX,gdmf.apple.com,REJECT

profile:
  store-selected: true
EOF
        chown "$REAL_USER" "$MERGE_YAML" 2>/dev/null || true
    fi
    # 热重载 Clash 内核
    pkill -HUP -f "verge-mihomo" 2>/dev/null || true
fi

# 3. 刷新 DNS
dscacheutil -flushcache
killall -HUP mDNSResponder 2>/dev/null || true

# 4. 彻底杀死常驻的 softwareupdated 守护进程 (使用 launchctl 强行终止)
echo "3. 终止内存中的更新常驻进程..."
pkill -9 -f "System Settings" 2>/dev/null || true
sudo -u "$REAL_USER" pkill -9 -f "SoftwareUpdateNotificationManager" 2>/dev/null || true
sudo -u "$REAL_USER" pkill -9 -f "followupd" 2>/dev/null || true

launchctl kill SIGKILL system/com.apple.softwareupdated 2>/dev/null || true
launchctl kill 9 system/com.apple.softwareupdated 2>/dev/null || true
launchctl kickstart -k system/com.apple.softwareupdated 2>/dev/null || true

# 5. 永久锁死更新缓存目录与配置文件 (只读锁定，禁止系统写入新更新)
echo "4. 抹除并锁死更新缓存与元数据..."
chflags -R nouchg /Library/Updates 2>/dev/null || true
rm -rf /Library/Updates/* 2>/dev/null || true
chmod 000 /Library/Updates 2>/dev/null || true
chflags uchg /Library/Updates 2>/dev/null || true

chflags nouchg /Library/Preferences/com.apple.SoftwareUpdate.plist 2>/dev/null || true
rm -f /Library/Preferences/com.apple.SoftwareUpdate.plist 2>/dev/null || true
touch /Library/Preferences/com.apple.SoftwareUpdate.plist 2>/dev/null || true
chmod 000 /Library/Preferences/com.apple.SoftwareUpdate.plist 2>/dev/null || true
chflags uchg /Library/Preferences/com.apple.SoftwareUpdate.plist 2>/dev/null || true

rm -f "$REAL_HOME/Library/Preferences/com.apple.SoftwareUpdate.plist" 2>/dev/null || true

# 6. 在 CoreFollowUp 数据库中建立免疫触发器 (核心拦截：绝不让“有软件更新可用”进入数据库)
echo "5. 在系统待办数据库中建立免疫触发器..."
DB_PATH="$REAL_HOME/Library/CoreFollowUp/items.db"
if [ -f "$DB_PATH" ]; then
    sqlite3 "$DB_PATH" << 'EOF'
DELETE FROM items WHERE uuid='com.apple.SoftwareUpdateServices.followup' OR client_identifier LIKE '%softwareupdate%';
DELETE FROM actions WHERE url LIKE '%softwareupdate%' OR url LIKE '%Software-Update%' OR label LIKE '%软件更新%';

CREATE TRIGGER IF NOT EXISTS block_su_items
BEFORE INSERT ON items
FOR EACH ROW
WHEN NEW.uuid = 'com.apple.SoftwareUpdateServices.followup' OR NEW.client_identifier LIKE '%softwareupdate%'
BEGIN
    SELECT RAISE(IGNORE);
END;

CREATE TRIGGER IF NOT EXISTS block_su_actions
BEFORE INSERT ON actions
FOR EACH ROW
WHEN NEW.url LIKE '%softwareupdate%' OR NEW.url LIKE '%Software-Update%' OR NEW.label LIKE '%软件更新%'
BEGIN
    SELECT RAISE(IGNORE);
END;
EOF
    chown "$REAL_USER" "$DB_PATH"* 2>/dev/null || true
fi

# 7. 清除红点并设置偏好
echo "6. 清理偏好设置与小红点角标..."
sudo -u "$REAL_USER" /usr/libexec/PlistBuddy -c "Delete :AttentionPrefBundleIDs" "$REAL_HOME/Library/Preferences/com.apple.systempreferences.plist" 2>/dev/null || true
sudo -u "$REAL_USER" /usr/libexec/PlistBuddy -c "Add :AttentionPrefBundleIDs dict" "$REAL_HOME/Library/Preferences/com.apple.systempreferences.plist" 2>/dev/null || true
sudo -u "$REAL_USER" defaults write com.apple.systempreferences AttentionPrefBundleIDs -dict
sudo -u "$REAL_USER" defaults delete com.apple.systempreferences CurrentExtensionURL 2>/dev/null || true
sudo -u "$REAL_USER" defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false
sudo -u "$REAL_USER" defaults write com.apple.SoftwareUpdate AutomaticDownload -bool false
sudo -u "$REAL_USER" defaults write com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false
sudo -u "$REAL_USER" defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -bool false
sudo -u "$REAL_USER" defaults write com.apple.SoftwareUpdate ConfigDataInstall -bool false

sudo -u "$REAL_USER" launchctl disable "gui/$REAL_UID/com.apple.SoftwareUpdateNotificationManager" 2>/dev/null || true

# 8. 刷新系统 UI
echo "7. 重启 Dock 和配置服务..."
sudo -u "$REAL_USER" killall cfprefsd 2>/dev/null || true
sudo -u "$REAL_USER" killall Dock 2>/dev/null || true

echo "=== ✅ 全部处理完成！已应用免疫机制，更新与小红点已彻底消除 ==="
