# Lenovo Legion R9000K (2021) Hackintosh EFI (macOS 15.8.1 Sequoia 完美适配版)

本 EFI 针对联想拯救者 R9000K 2021（AMD Ryzen 7 5800H + Vega 8 核显 + RTX 3070 独显 + 16 英寸 2.5K 165Hz 高刷屏 + Intel AX200 Wi-Fi 6 + Realtek RTL8168 千兆网卡 + Realtek ALC287 声卡）进行了全面升级、OTA 支持与核显防黑屏深度适配。

---

## 适配与更新概览

### 1. 引导系统与 OTA 升级支持
- **OpenCore**: 升级至官方最新稳定版 **1.0.8**（通过 `ocvalidate` 规范校验，0 警告 0 报错）。
- **AMD 内核补丁**: 更新 **AMD OS X Vanilla Patches** 至支持 macOS 15.x Sequoia (Kernel 24.x) 的最新 25 项内核补丁，针对 **Ryzen 7 5800H（8 核心 16 线程）** 将 CPU 物理核心数准确配置为 `08`。
- **OTA 在线增量更新**:
  - 配置 `RestrictEvents.kext` (v1.1.6) 配合启动参数 `revpatch=sbvmm`，绕过白苹果 T2 芯片限制，支持直接在「系统设置」中无缝检测并安装 OTA 增量更新。
  - `Misc` -> `Security` -> `SecureBootModel` 配置为 **`Disabled`**，彻底解决 OTA 更新最后系统封签阶段报 `MSU 1130 (img4_firmware_execute failed)` 导致的自动回滚问题。
  - 启用 `PlatformInfo` -> `Generic` -> `AdviseFeatures: true` 配合固件更新支持。

### 2. 核显驱动与显示解决方案（重磅更新）
- **NootedRed**: 升级至最新 **1.0.1** 版本，全面驱动 Vega 8 核显开启 **Metal 3** 硬件图形加速与 2GB 显存分配。
- **硬件级 EDID 注入与防黑屏（锁定 60Hz/120Hz）**:
  - 在 `DeviceProperties` -> `Add` -> `PciRoot(0x0)/Pci(0x8,0x1)/Pci(0x0,0x0)` 注入 `AAPL00,override-no-connect`。
  - 针对本机原装屏幕 **京东方 BOE NE160QDM-NY1（2.5K 165Hz 面板）** 注入专属 60Hz/120Hz 降频时序，彻底解决 165Hz 超高像素时钟（777MHz）导致核显发生 `Restart Channel: 23 GFX` 和 `WindowServer` 卡死黑屏问题。
- **独显彻底屏蔽**:
  - 注入启动参数 `-wegnoegpu`，在内核层彻底屏蔽无驱动的 NVIDIA RTX 3070 Mobile 独显，防止双显卡争夺总线导致内屏黑屏或异常耗电发热。
- **启动参数优化与视频硬解增强**:
  - **`-NRedDPDelay`**: 为 eDP 显示链路握手增加延时缓冲，确保高分屏顺利点亮。
  - **`-NRedGLFix`**: 修复 Chrome、Edge、VS Code 等 Chromium/Electron 核心软件的 OpenGL 渲染白屏与闪烁问题。
  - **`-NRedVDA`**: 激活 AMD APU 硬件视频解码加速（Video Decode Acceleration）。
  - **`-NRedVCNNoGfxOff`**: 防止 VCN 视频解码模块在节能休眠调度时死锁。

### 3. CPU 电源管理与核心驱动
- **Lilu**: 1.7.2（全面支持 macOS 15 内核 Hook 与防崩溃）。
- **VirtualSMC**: 1.3.8（含 SMCBatteryManager / SMCLightSensor）。
- **AMDRyzenCPUPowerManagement & SMCAMDProcessor**: 
  - 支持 Ryzen 5800H 核心功耗与温度读取监控；
  - *注：macOS 系统全新安装或跨版本升级阶段，如遇 NMI 中断超时，可临时禁用该两项驱动，进入系统后再行开启。*
- **AppleALC**: 1.9.8。
- **RestrictEvents**: 1.1.6。
- **RealtekRTL8111**: 3.0.0。

### 4. 网卡驱动与网络解决方案
- **无线网卡（Intel Wi-Fi 6 AX200）**：
  - 内置 `itlwm.kext` (v2.3.0)，完美兼容 macOS 15 Sequoia，不受系统无线架构改动影响。
  - 搭配 **HeliPort** 客户端，在顶部菜单栏像原生系统一样搜索、连接 Wi-Fi，并支持开机自启。
- **蓝牙（Intel AX200 Bluetooth）**：
  - 配置 `IntelBluetoothFirmware.kext` (v2.4.0) + `IntelBTPatcher.kext` (v2.4.0) + `BlueToolFixup.kext` (v2.7.2)。
  - NVRAM 已注入 `bluetoothExternalDongleFailed` 与 `bluetoothInternalControllerInfo`。
- **有线网卡（Realtek RTL8168/8111）**：
  - 已配置最新版 `RealtekRTL8111.kext` (v3.0.0)，插上网线即插即用。

### 5. 声卡解决方案
- **声卡主芯片**：Realtek ALC287（硬件 ID: VEN_10EC, DEV_0287）。
- **驱动配置**：AppleALC 1.9.8，`boot-args` 默认注入联想专属布局 `alcid=13`（备选布局 ID：`11`、`21`、`69`）。
- **功能支持**：3.5mm 耳机输出、麦克风输入完美驱动。
- **机身自带外放说明**：联想拯救者 R9000K 的外放喇叭硬件物理连接在独立硬件芯片 **Cirrus Logic CS35L41** 智能功放（`ACPI\CLSA0100`）上。目前 macOS 黑苹果生态全网暂无 CS35L41 固件注入驱动，推荐使用 3.5mm 耳机、蓝牙耳机/音箱或 Type-C/USB 声卡日常播放音频。

---

## 当前完整启动参数（boot-args）

```text
keepsyms=1 debug=0x100 -vi2c-force-polling -v alcid=13 revpatch=sbvmm -NRedDPDelay -wegnoegpu -NRedGLFix -NRedVDA -NRedVCNNoGfxOff
```

---

## 必看注意事项

1. **BIOS 显存设置（至关重要）**：
   - 开机按 <kbd>F2</kbd> 进入联想 BIOS（或使用 UMAF 工具）；
   - 务必将集成显卡显存 **UMA Frame Buffer Size** 设置为 **2GB 或以上**（切勿保持默认的 512MB 或 Auto，否则 2.5K 分辨率开启硬件加速后易因显存溢出卡死）。
2. **机型信息 (SMBIOS)**：
   - 建议在正式使用前使用 GenSMBIOS 生成专属的序列号、MLB 与 UUID（机型推荐：`MacBookPro16,3`）。
3. **备份说明**：
   - 原始配置已完整备份在 `OC_backup` 和 `BOOT_backup` 目录中；
   - 引导分区中已留存 `config.plist.working` 作为兜底恢复配置。
