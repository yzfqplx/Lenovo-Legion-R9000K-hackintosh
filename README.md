# Lenovo Legion R9000K (2021) Hackintosh EFI (macOS 15.8.1 Sequoia)

本 EFI 针对联想拯救者 R9000K 2021（Legion 7 16ACHg6 / AMD Ryzen 9 5900HX & Ryzen 7 5800H + Vega 8 核显 + RTX 3070/3080 独显 + 16 英寸 2.5K 165Hz 高刷屏）进行深度适配。

---

## 目录
1. [硬件环境与配置基线](#1-硬件环境与配置基线)
2. [睡眠唤醒黑屏深度排查全景报告（核心备忘录）](#2-睡眠唤醒黑屏深度排查全景报告核心备忘录)
3. [五大不可逾越的配置红线](#3-五大不可逾越的配置红线)
4. [下一次修复启动指南与行动路线图](#4-下一次修复启动指南与行动路线图)
5. [系统当前各项硬件功能状态](#5-系统当前各项硬件功能状态)
6. [当前引导参数与重要设置说明](#6-当前引导参数与重要设置说明)

---

## 1. 硬件环境与配置基线

| 硬件模块 | 硬件规格与型号 | macOS 驱动方案与状态 |
| :--- | :--- | :--- |
| **处理器 (CPU)** | AMD Ryzen 9 5900HX / 7 5800H (8 核 16 线程) | AMD OS X Vanilla Patches (25 项内核补丁，核心数 08) |
| **集成显卡 (iGPU)** | AMD Radeon RX Vega 8 (1002:1638, Rev c5) | NootedRed (0.9.0-pre.13) + Metal 3 + 2GB 显存分配 |
| **独立显卡 (dGPU)** | NVIDIA GeForce RTX 3070/3080 Laptop (10de:2560) | macOS 无驱动支持，需彻底屏蔽避免争夺总线 |
| **内建显示屏** | 16.0 英寸 2560x1600 (16:10) 165Hz 京东方 BOE 面板 | 原生 eDP 驱动，支持 Retina HiDPI 缩放与 165Hz |
| **内存 (RAM)** | 32GB / 64GB DDR4 3200MHz 双通道 | 正常工作 |
| **硬盘 (NVMe SSD)**| WD Blue SN570 / 标配 NVMe SSD | NVMeFix + `ps-max-latency-us = 0` 防止调页断电 |
| **无线网卡与蓝牙** | Intel Wi-Fi 6 AX200 + Bluetooth 5.2 | itlwm + HeliPort / IntelBluetoothFirmware + BlueToolFixup |
| **有线网卡** | Realtek RTL8168/8111 千兆网卡 | RealtekRTL8111.kext 正常驱动 |
| **声卡与扬声器** | Realtek ALC287 + 双 Cirrus Logic CS35L41 智能功放 | AppleALC (alcid=13) + 定制 VoodooI2C + CirrusAudioFixup |
| **物理键盘与触摸板** | ITE 8258 RGB 键盘芯片 + I2C 触摸板 | USBToolBox (HS04 端口) + VoodooI2C HID 多指手势 |
| **操作系统版本** | macOS Sequoia 15.8.1 (Darwin 24.6.0) | OpenCore 1.0.8 (REL-108-2026-09-27) |

---

## 2. 睡眠唤醒黑屏深度排查全景报告（核心备忘录）

### 2.1 故障核心表象
- **入睡正常**：点击菜单栏「睡眠」后，机器能正常完成睡眠流程，电源/呼吸灯进入平缓均匀呼吸闪烁状态（确认成功进入 S3 睡眠）。
- **唤醒黑屏**：轻按键盘按键或按下电源键后，主机指示灯恢复常亮，散热风扇与机身外设已恢复供电运行，甚至可以调节背光或盲敲密码，但**内置 165Hz 屏幕始终处于全黑无信号状态**，屏幕无法重新点亮。

---

### 2.2 已确诊并彻底解决的历史次生问题（切勿走回头路）

1. **秒醒风暴（ACPI GPE 0x19）**：
   - **原因**：AMD Cezanne 芯片组的内置 USB 控制器（`GP17.XHC0` 与 `GP17.XHC1`）所绑定的 GPE 0x19 中断，在休眠瞬间被物理键盘/集线器电平抖动触发，导致机器无法保持睡眠、一睡即醒。
   - **解决**：在 DSDT 中配置全局重命名补丁 `_PRW to XPRW`（保持 `Base: ""`），彻底根除了 GPE 0x19 秒醒风暴。
2. **OpenCore 引导器卡死陷阱**：
   - **教训**：在 OpenCore 的 `ACPI -> Patch` 中，若给二进制补丁添加 `Base: \_SB.PCI0...` 等限定路径，会导致 OpenCore 1.0.8 引导器在显示启动菜单前发生死锁卡死。
   - **铁律**：所有 ACPI 二进制重命名补丁必须保持 `Base: ""`（留空）。
3. **物理键盘失效陷阱**：
   - **教训**：联想拯救者机身内置的 RGB 键盘硬件为 `ITE Device(8258)`，硬件挂载在 `XHC0` 控制器的 **`HS04`** 端口上。前期尝试通过裁剪 USB 端口消除秒醒时误删 `HS04`，导致物理键盘完全瘫痪。
   - **铁律**：`UTBMap.kext` 中 `XHC0` 的 `HS04` 必须永久保持启用。
4. **TSC 跨核心时钟同步选型**：
   - **分析**：用户及部分讨论曾提及 `CpuTscSync.kext`。经源码反编译与 Acidanthera 规范核对，`CpuTscSync` 是专门读取 Intel 专属的 `MSR_IA32_TSC_ADJUST (0x3B)` 寄存器进行时钟对齐的，在 AMD 平台上无效。
   - **结论**：AMD Ryzen 平台必须且只能使用 `AmdTscSync.kext`（v2.0.0，针对 8 核 16 线程精准配置 `IOCPUNumber=15`）。
5. **背光调节 UID 严重偏差**：
   - **分析**：此前 `SSDT-PNLF.aml` 曾被误设置为 Intel 风格的 `_UID = 14`，导致唤醒后 AppleBacklight 将亮度重置为 `16/1808`（0.88% 极暗黑屏，肉眼无法察觉）。
   - **解决**：已恢复 `SSDT-PNLF.aml` 的 `_UID = 19`（`0x13`），匹配 AMD 曲线。在 IORegistry 中验证 `AppleRestoreBacklight = 123`，`ApplePanelRawBrightness = 38930`（最大 65403），证明背光本身数值已恢复正常。

---

### 2.3 唤醒黑屏的两大核心根因（日志确诊数据）

#### 核心根因 1：PCI 根桥路径偏差（`PciRoot(0x1)` vs `PciRoot(0x0)`）导致独显未屏蔽
- **日志与设备树发现**：
  在系统 `IORegistry` 设备树中审查发现，`PCI0` 根桥的 ACPI `_UID` 属性实际为 `"1"`！
  - 真实的 UEFI 路径为：**`PciRoot(0x1)`**。
  - 独立显卡真实路径：`PciRoot(0x1)/Pci(0x1,0x1)/Pci(0x0,0x0)`。
  - 集成显卡真实路径：`PciRoot(0x1)/Pci(0x8,0x1)/Pci(0x0,0x0)`。
- **历史盲区**：
  原 `config.plist` 中的 `DeviceProperties -> Add` 全部将属性注入在 `PciRoot(0x0)` 路径下！导致 OpenCore 在引导阶段根本没有匹配到任何设备，针对独显注入的 `class-code: 0xFFFFFFFF`（伪装屏蔽）从未生效。
- **致命后果**：
  macOS 识别到了未受驱动的 RTX 3080 独显，并自动在其上加载了 **`IONDRVFramebuffer`** 以及 **`AppleGraphicsPowerManagement` (AGPM)**！在机器唤醒时，macOS 电源管理尝试向独显的 `AGPM` 发送唤醒指令并重置显示链路，导致显示总线发生仲裁冲突死锁。

#### 核心根因 2：NootedRed 显卡驱动层电源门控超时（SDMA0 硬件死锁）
- **内核日志确诊数据（2026-10-31 18:07:46 真实日志）**：
  ```text
  AMDRadeonX5000 [6:0:0]: Controller is enabled, finish initialization
  AMDRadeonX5000 [6:0:0]: Timestamp 0xeb9 on channel 12 VMPT is not expired; stamp: 0xea8 -> 0xea8; HW stamps: read 0x2384 -> 0x2384, sent 0x2386; wait time 5002ms, ret 0xe00002d6
  AMDRadeonX5000 [6:0:0]: channel 12 VMPT event timeout; pending stamps [3753..3769]
  AMDRadeonX5000 [6:0:0]: HW Channel 11 SDMA0 is occupied by channel 24 stamp 4340
  AMDRadeonX5000 [6:0:0]: channel 24 SDMA0 is hung! (lastReadTimestamp=0x000010f3)
  AMDRadeonX5000HWLibs AMD Cail: [6:0:0] GPU HangState 0x00000000, HangFlags 0x00000004: IndividualEngineHang 0, NonEngineBlockHang 0, FenceNotRetired 1, PerEngineReset 0, FullAsicReset 1
  Restart Channel: 24 SDMA0
  CLKS: dcfclk,dcfclk_deep_sleep,dispclk,dppclk,fclk,socclk: 0,0,0,0,0,0
  CLK1_CLK3_ALLOW_DS,1,dcf_deep_sleep_allow
  ```
- **技术机制剖析**：
  1. **VMPT**（Virtual Memory Page Table）是 Vega 显卡 MMU 的显存虚拟分页管理通道，macOS 唤醒时需要通过 **SDMA0**（系统直接内存访问引擎）通道提交分页更新。
  2. 硬件时间戳停滞在 `0x2384`，未能执行 `0x2386` 的请求，导致 5002ms 硬件超时。
  3. 日志明确显示底层时钟状态：所有核心显示时钟均为 `0`（`CLKS: 0,0,0,0,0,0`），且处于 `dcf_deep_sleep_allow = 1`（深度睡眠允许）。
  4. 反编译 `NootedRed` 发现其内嵌针对 Cezanne Vega 8 的 CAIL 默认配置为：
     ```xml
     <key>CAIL_DisablePowerGating</key><integer>0</integer>
     <key>CAIL_DisableRlcSmuPGHandshake</key><integer>0</integer>
     ```
     驱动尝试通过独立显卡的 RLC-SMU 握手协议唤醒电源通道，但 APU 不支持该寄存器，握手死锁导致 SDMA0 和时钟无法从门控深度睡眠中苏醒，超时后驱动触发 `FullAsicReset 1`，由于 APU 无法执行独显级的总线重置，显卡直接彻底死锁。

---

### 2.4 Commit `7c06650` 开机进不去的原因反思
- 在 Commit `7c06650` 中，尝试通过修改 `NootedRed` 二进制直接改写内嵌 XML（将 `CAIL_DisableAllClockGating`、`CAIL_DisablePowerGating` 等粗暴改为 1），并直接在 `PciRoot(0x1)` 上注入 `class-code = 0xFFFFFFFF`。
- **导致进不去系统的原因**：
  1. `CAIL_DisableAllClockGating=1` 破坏了 NootedRed 在系统开机冷启动阶段针对 `AMDRadeonX5000` 初始化时钟树的预期状态，触发驱动内核断言恐慌；
  2. 在无 WhateverGreen 的环境下直接给 PCIe 桥下的显卡注入伪装 `class-code: 0xFFFFFFFF`，导致 macOS 原生 `IOPCIFamily` 发生枚举遍历异常；
  3. 现已执行 `git revert`，代码库已回滚至稳定、可正常开机进入系统的基线状态。

---

## 3. 五大不可逾越的配置红线

在后续任何调试与修复中，必须无条件遵循以下 5 条红线：

1. **【绝对红线】严禁改动或禁用 `UTBMap.kext` 中的 `HS04`**：
   - 联想拯救者物理键盘（ITE 8258）挂载在 `XHC0` 的 `HS04` 上。任何修改都会导致机身物理键盘彻底失效。
2. **【绝对红线】严禁在 OpenCore ACPI 二进制补丁中使用 `Base` 限定**：
   - 所有在 `ACPI -> Patch` 中的补丁（如 `_PRW to XPRW`），`Base` 属性必须保持为空字符串 `""`。填写类似 `\_SB.PCI0` 会直接导致 OpenCore 引导器在启动界面前卡死。
3. **【绝对红线】严禁替换 `AmdTscSync.kext` 为 `CpuTscSync.kext`**：
   - 本机为 AMD 处理器，`CpuTscSync` 只支持 Intel 寄存器，使用它会导致多核心时钟失步而崩溃。
4. **【绝对红线】保持 `SSDT-PTSWAK.aml` 与 `SSDT-EXT3-WSC.aml` 处于禁用状态**：
   - 此二者会引入对未驱动独显的总线断电冲击以及 LID0 状态死循环，已被确认为引发总线卡死的诱因。
5. **【绝对红线】保持 `SSDT-PNLF.aml` 的 `_UID = 19`**：
   - 严禁改回 `_UID = 14`，否则唤醒后背光数值会回到 0.88% 的死黑状态。

---

## 4. 下一次修复启动指南与行动路线图

下一次排查唤醒黑屏时，应当沿着以下三条清晰路线逐步推进验证：

### 路线 A：以非侵入方式安全屏蔽 NVIDIA 独显（优先级：最高）
- **现状**：NVIDIA 独显（RTX 3080, `PciRoot(0x1)/Pci(0x1,0x1)/Pci(0x0,0x0)`）目前被加载了 `IONDRVFramebuffer` 和 `AGPM`。
- **任务**：
  1. 测试通过纯 ACPI 方式（如专为双显卡笔记本设计的 `SSDT-NoHybGfx.aml` 或标准的 `_STA = 0` / `_OFF` 安全屏蔽方案）彻底让 macOS 看不到该独显，同时确保不引起风扇满载狂转；
  2. 验证进入系统后，`ioreg` 中再无 `IONDRVFramebuffer` 及独显节点；
  3. 在独显完全干净剥离的情况下，单独测试 S3 睡眠与唤醒。

### 路线 B：解决 Vega 8 唤醒显示时钟解冻（优先级：高）
- **现状**：唤醒时显卡核心时钟全为 0，`dcf_deep_sleep_allow = 1` 导致 SDMA0 超时。
- **任务**：
  1. 绝不通过改写驱动二进制来关时钟门控；
  2. 优先通过 `boot-args` 进行安全调控：
     - 测试 `-NRedDPDelay`（增加 eDP 链路握手延时）；
     - 测试 `-NRedNoFVRC`（绕过显存任务提交挂钩）；
     - 测试 `-NRedDisplayFix`；
  3. 查阅 Linux 内核 `amdgpu` 驱动针对 Cezanne (Renoir/Green Sardine) 平台 S3 唤醒关于 `dcfclk` 深度休眠的配置参数（如 `amdgpu.dcfeaturemask` 对应的机制）。

### 路线 C：BIOS 固件与电源管理协同（优先级：中）
- **检查项**：
  1. 使用 UMAF 工具进 BIOS 检查：
     - 确保睡眠模式为真正的 **S3 (Suspend to RAM)**，而非 Modern Standby (S0ix)；
     - 确保集成显卡显存 **UMA Frame Buffer Size** 固定为 **2GB 或 4GB**（切勿保持 Auto 或 512MB）；
     - 确保开启 **Above 4G Decoding** 并关闭 **CSM**。
  2. 系统电源参数优化：已配置 `pmset -a hibernatemode 0 standby 0 powernap 0 tcpkeepalive 0`。

---

## 5. 系统当前各项硬件功能状态

- ✅ **图形加速与显示**：Vega 8 核显正常驱动，Metal 3 支持，满血 2.5K 165Hz 高刷新率，Retina HiDPI 正常工作。
- ✅ **物理键盘与触摸板**：内置键盘（ITE 8258）正常打字与灯控，I2C 触摸板多指手势丝滑。
- ✅ **网络连接**：Intel AX200 Wi-Fi 正常上网，蓝牙 5.2 正常连接配对，Realtek 千兆有线网卡即插即用。
- ✅ **声音与外放**：ALC287 耳机正常，Cirrus Logic CS35L41 双智能功放驱动机身扬声器正常发声。
- ✅ **电池与传感器**：电池电量与充放电状态正常，CPU 各核心温度与功耗实时监控正常。
- ⏳ **睡眠与唤醒**：入睡正常（平缓呼吸灯），唤醒内屏亮屏正在攻坚排查中。

---

## 6. 当前引导参数与重要设置说明

当前基线 `boot-args`（位于 Commit `150c52d`）：
```text
keepsyms=1 debug=0x100 -vi2c-force-polling -v alcid=13 revpatch=sbvmm -NRedDPDelay -NRedGLFix -NRedVDA -amfipassbeta -btlfxboardid -cirrusssid=0x17AA3847 -utbappleoff tlbto_us=0 -NRedNoFVRC darkwake=1
```

> [!IMPORTANT]
> **下次开工第一步**：
> 1. 先验证系统开机是否恢复正常稳定。
> 2. 参照上方第 4 节的行动路线图，从「路线 A：安全屏蔽 NVIDIA 独显（消除双显卡唤醒总线锁死）」开始着手实施。
