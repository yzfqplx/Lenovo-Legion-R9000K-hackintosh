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
  - **`AMFIPass.kext` (v1.4.1) 与 `-amfipassbeta`**: 
    - 采用 OCLP/Acidanthera 官方 Lilu 动态 Hook 插件，替代粗暴全局关闭 AMFI 的 `amfi=0x80` 参数。
    - **核心优势**：在内核层精准放行 NootedRed 1.0.1 在 WindowServer 进程中对 `AMDRadeonX5000MTLDriver` 驱动内存页的代码修改，避免触发 `SIGKILL (Invalid Page)` 崩溃。
    - **完整保留原生权限**：微信、腾讯会议、Zoom 等第三方软件请求麦克风、摄像头（TCC 隐私权限）时能正常弹出授权窗口并调用外设；VS Code、Chrome、网盘等 Electron 应用原生稳定运行，无需额外注入 `ipc_control_port_options=0`。
  - **`csr-active-config: 03080000` (AwgAAA==)**: 配合 AMFIPass 放行代码签名策略覆盖（Executable Policy Override）。

### 3. CPU 电源管理与传感器监控
- **Lilu**: 1.7.2（全面支持 macOS 15 内核 Hook 与防崩溃）。
- **VirtualSMC**: 1.3.8（含 SMCBatteryManager / SMCLightSensor）。
- **AMDRyzenCPUPowerManagement & SMCAMDProcessor**: 
  - 支持 Ryzen 5800H 8 核 16 线程的功耗、频率与各个核心温度读取监控；
  - *注：macOS 系统全新安装或跨版本升级阶段，如遇 NMI 中断超时，可临时禁用该两项驱动，进入系统后再行开启。*
- **温度与功耗监控方式**：
  1. **Stats（菜单栏实时监控，已安装运行）**：
     - 位置：`/Applications/Stats.app`，常驻屏幕右上角菜单栏。
     - 点击菜单栏图标可展开查看：CPU 各核心温度、Vega 核显温度、风扇转速、电池健康度与充放电功率。
  2. **AMD Power Gadget（AMD 专属深度监控工具，已安装）**：
     - 位置：`/Applications/AMD Power Gadget.app`。
     - 专为 `AMDRyzenCPUPowerManagement` 与 `SMCAMDProcessor` 打造，图形化实时呈现每个物理核心的温度走势、频率曲线（MHz）以及瞬时功耗（Watts）。
- **AppleALC**: 1.9.8。
- **RestrictEvents**: 1.1.6。
- **RealtekRTL8111**: 3.0.0。

### 4. 网卡驱动与网络解决方案
- **无线网卡（Intel Wi-Fi 6 AX200）**：
  - 内置 `itlwm.kext` (v2.3.0)，完美兼容 macOS 15 Sequoia，不受系统无线架构改动影响。
  - 搭配 **HeliPort** 客户端，在顶部菜单栏像原生系统一样搜索、连接 Wi-Fi，并支持开机自启。
- **蓝牙（Intel AX200 Bluetooth）**：
  - 配置 `IntelBluetoothFirmware.kext` (v2.4.0) + `IntelBTPatcher.kext` (v2.4.0) + `BlueToolFixup.kext` (v2.7.2) 全面启用。
  - 启动参数添加 **`-btlfxboardid`**：让 `BlueToolFixup` 跳过苹果白名单机型 Board-ID 检查，使得当前机型定义能够无条件接管 Monterey/Ventura/Sonoma/Sequoia 的 BlueTool 蓝牙电源控制。
  - NVRAM 已注入 `bluetoothExternalDongleFailed` 与 `bluetoothInternalControllerInfo`，确保系统冷启动及休眠唤醒后蓝牙开关状态恢复正常。
- **有线网卡（Realtek RTL8168/8111）**：
  - 已配置最新版 `RealtekRTL8111.kext` (v3.0.0)，插上网线即插即用。

### 5. 声卡与机身外放解决方案
- **声卡主芯片**：Realtek ALC287（硬件 ID: VEN_10EC, DEV_0287）。
- **编解码驱动**：AppleALC 1.9.8，`boot-args` 注入专属布局 `alcid=13`（备选布局 ID：`11`、`21`、`69`），3.5mm 耳机输出、内建麦克风输入完美驱动。
- **机身自带外放功放（重大突破）**：
  - 拯救者 R9000K / Legion 7 原厂外放扬声器硬件连接在 **Cirrus Logic CS35L41** 智能数字功放（ACPI 节点 `CLSA0100`，挂载于 AMD I2C 总线 `AMDI0010` 的 `0x40` 与 `0x41` 地址）。
  - **定制版 I2C 总线支持（VoodooI2C & VoodooI2CHID）**：采用作者定制分支（`hoaug-tran/VoodooI2C:main`），导出 `VoodooI2CTransferToAddress` 接口，解决标准版 VoodooI2C 缺失寻址传输导致系统在 `'SPKR'` 处超时卡死（busy timeout 60s）的问题。
  - **CirrusAudioFixup.kext (v1.1.1 原版官方构建)**：
    - 使用作者官方发布的原始构建版本（MD5: `ef555dcdbce1852511b231b3c27ba7df`），内置针对联想 Y760 / Legion 7 (Subsystem ID `17AA:3847`) 的原厂 DSP 固件（`cs35l41-dsp1-spk-prot-17aa3847.wmfw`）与扬声器硬件保护调音（`LS639` Tuning）。
    - 搭配 `-cirruslegacyprobe` 启动参数放行双功放硬件探测，无须任何二进制 Patch。
  - **当前启动参数**：`-cirrusro -cirrusdbg -cirrusssid=0x17AA3847 -cirruslegacyprobe`（官方 Step 4 只读安全探测模式，待检测验证通过后移除 `-cirrusro` 即可开启正式声音播放）。

---

## 当前完整启动参数（boot-args）

```text
keepsyms=1 debug=0x100 -vi2c-force-polling -v alcid=13 revpatch=sbvmm -NRedDPDelay -wegnoegpu -NRedGLFix -NRedVDA -NRedVCNNoGfxOff -amfipassbeta -btlfxboardid -cirrusro -cirrusdbg -cirrusssid=0x17AA3847 -cirruslegacyprobe
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
