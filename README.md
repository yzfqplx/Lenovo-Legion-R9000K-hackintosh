# Lenovo Legion R9000K (2021) Hackintosh EFI (macOS 15.6 Sequoia 适配版)

本 EFI 针对联想拯救者 R9000K 2021（AMD Ryzen 7 5800H + Vega 8 核显 + Intel AX200 Wi-Fi 6 + Realtek RTL8168 千兆网卡 + Realtek ALC287 声卡）进行了全面升级与适配。

---

## 适配与更新概览

1. **引导系统升级**
   - **OpenCore** 升级至官方最新稳定版 **1.0.8**（完全通过 `ocvalidate` 规范校验，0 警告 0 报错）。
   - 更新 **AMD OS X Vanilla Patches** 至支持 macOS 15.x Sequoia (Kernel 24.x) 的最新 25 项内核补丁，并针对本机的 **Ryzen 7 5800H（8 核心）** 将 CPU 物理核心数准确配置为 `08`。

2. **核心驱动升级**
   - **Lilu**: 升级至 1.7.2（全面支持 macOS 15 内核 Hook 与防崩溃）。
   - **VirtualSMC**: 升级至 1.3.8（含 SMCBatteryManager / SMCLightSensor）。
   - **AppleALC**: 升级至 1.9.8。
   - **NootedRed**: 升级至 0.8.10（适配 macOS 15 Sequoia 下 Vega 8 核显 Metal 硬件加速）。
   - **RestrictEvents**: 升级至 1.1.6。
   - **RealtekRTL8111**: 升级至 3.0.0。

3. **网卡驱动与网络解决方案**
   - **无线网卡（Intel Wi-Fi 6 AX200）**：
     - 已内置 `itlwm.kext` (v2.3.0)，完美兼容 macOS 15 Sequoia，不受系统无线架构改动影响。
     - 仓库根目录已附带 **[HeliPort.dmg](file:///c:/Users/21913/Downloads/Lenovo-Legion-R9000K-hackintosh/HeliPort.dmg)**。进入 macOS 桌面后打开并安装 HeliPort，在顶部菜单栏即可像原生系统一样搜索、连接 Wi-Fi，并支持开机自启。
   - **蓝牙（Intel AX200 Bluetooth）**：
     - 已配置 `IntelBluetoothFirmware.kext` (v2.4.0) + `IntelBTPatcher.kext` (v2.4.0) + `BlueToolFixup.kext` (v2.7.2)。
     - 在 macOS 15 系统设置中可直接搜索、配对蓝牙耳机、键盘、鼠标等设备。
   - **有线网卡（Realtek RTL8168/8111）**：
     - 已配置最新版 `RealtekRTL8111.kext` (v3.0.0)，插上网线即插即用。
   - 已彻底清理旧版无用的 `RtWlanU`、`RtWlanU1827` 及 `NullEthernet` 驱动。

4. **声卡解决方案**
   - **声卡主芯片**：Realtek ALC287（硬件 ID: VEN_10EC, DEV_0287）。
   - **驱动配置**：AppleALC 1.9.8，`boot-args` 默认注入联想专属布局 `alcid=13`（备选布局 ID：`11`、`21`、`69`）。
   - **功能支持**：3.5mm 耳机输出、麦克风输入已完美驱动，系统音频通道正常识别。
   - **自带喇叭外放说明**：联想拯救者 R9000K 的外放喇叭硬件物理连接在独立硬件芯片 **Cirrus Logic CS35L41** 智能功放（`ACPI\CLSA0100`）上。目前 macOS 黑苹果生态全网暂无 CS35L41 固件注入驱动，因此机身外放扬声器发声受硬件架构制约。推荐使用 3.5mm 耳机、蓝牙耳机/音箱或 Type-C/USB 声卡进行日常声音播放。

---

## 注意事项

1. **首次安装/升级 macOS**：
   - 安装阶段如遇核显冲突，可在 `config.plist` 中暂时禁用 `NootedRed.kext`，安装完成后重新启用以开启硬件加速。
2. **机型信息 (SMBIOS)**：
   - 建议在正式使用前使用 GenSMBIOS 生成专属的序列号、MLB 与 UUID（机型推荐：`MacBookPro16,3` 或 `MacBookPro16,1`）。
3. **备份说明**：
   - 原始配置已完整备份在 `OC_backup` 和 `BOOT_backup` 目录中。

