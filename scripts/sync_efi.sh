#!/usr/bin/env bash
set -e

# ==============================================================================
# Lenovo Legion R9000K EFI 同步与备份脚本
# ==============================================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=========================================================="
echo "  联想拯救者 R9000K (2021) Hackintosh EFI 同步工具"
echo "=========================================================="
echo "源仓库路径: $REPO_DIR"

EFI_DEV="/dev/disk0s1"

# 自动检测挂载点
EFI_MOUNT=$(mount | grep "$EFI_DEV" | awk -F ' on ' '{print $2}' | awk -F ' \\(' '{print $1}')

if [ -z "$EFI_MOUNT" ]; then
    echo "未检测到已挂载的分区，正在尝试挂载 $EFI_DEV ..."
    if [ "$(id -u)" -eq 0 ]; then
        mkdir -p "/Volumes/EFI"
        mount -t msdos "$EFI_DEV" "/Volumes/EFI"
        EFI_MOUNT="/Volumes/EFI"
    else
        if ! diskutil mount "$EFI_DEV"; then
            sudo mkdir -p "/Volumes/EFI"
            sudo mount -t msdos "$EFI_DEV" "/Volumes/EFI"
            EFI_MOUNT="/Volumes/EFI"
        else
            EFI_MOUNT=$(mount | grep "$EFI_DEV" | awk -F ' on ' '{print $2}' | awk -F ' \\(' '{print $1}')
        fi
    fi
fi

echo "EFI 挂载点: $EFI_MOUNT"

# 1. 备份当前 EFI 分区中的现有配置
BACKUP_NAME="EFI_backup_$(date +%Y%m%d_%H%M%S)"
BACKUP_PATH="$EFI_MOUNT/$BACKUP_NAME"
echo "正在为当前引导分区创建备份: $BACKUP_NAME ..."
mkdir -p "$BACKUP_PATH"

if [ -d "$EFI_MOUNT/EFI/OC" ]; then
    cp -R "$EFI_MOUNT/EFI/OC" "$BACKUP_PATH/"
fi
if [ -d "$EFI_MOUNT/EFI/BOOT" ]; then
    cp -R "$EFI_MOUNT/EFI/BOOT" "$BACKUP_PATH/"
fi

# 2. 同步仓库最新的 ACPI 表、config.plist 以及 NootedRed.kext
echo "正在同步最新 ACPI 表和 config.plist ..."
mkdir -p "$EFI_MOUNT/EFI/OC/ACPI"
cp -f "$REPO_DIR/OC/config.plist" "$EFI_MOUNT/EFI/OC/config.plist"
cp -f "$REPO_DIR/OC/ACPI/"*.aml "$EFI_MOUNT/EFI/OC/ACPI/"

echo "正在同步 NootedRed.kext 驱动 ..."
mkdir -p "$EFI_MOUNT/EFI/OC/Kexts"
rm -rf "$EFI_MOUNT/EFI/OC/Kexts/NootedRed.kext"
cp -R "$REPO_DIR/OC/Kexts/NootedRed.kext" "$EFI_MOUNT/EFI/OC/Kexts/"

# 3. 清理可能产生的 .DS_Store / ._* 垃圾文件
find "$EFI_MOUNT/EFI" \( -name ".DS_Store" -o -name "._*" \) -delete 2>/dev/null || true

echo "----------------------------------------------------------"
echo "✅ EFI 同步与当前配置备份完成！"
echo "当前备份路径: $BACKUP_PATH"
echo "剩余空间情况:"
df -h "$EFI_MOUNT"
echo "提示: 重启后在 OpenCore 选单界面执行一次【Reset NVRAM】。"
echo "=========================================================="

