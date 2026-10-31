# Lenovo Legion R9000K (2021) Hackintosh EFI (macOS 15.8.1 Sequoia)

本 EFI 针对联想拯救者 R9000K 2021（Legion 7 16ACHg6 / AMD Ryzen 9 5900HX & Ryzen 7 5800H + Vega 8 核显 + RTX 3070/3080 独显 + 16 英寸 2.5K 165Hz 高刷屏）进行深度适配。

---

## 目录
1. [硬件环境与配置基线](#1-硬件环境与配置基线)
2. [睡眠唤醒黑屏深度排查全景报告（核心备忘录）](#2-睡眠唤醒黑屏深度排查全景报告核心备忘录)
3. [六大不可逾越的配置红线](#3-六大不可逾越的配置红线)
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
6. **独显 `_STA = 0` 隐身屏蔽引发的根桥脱节死锁**：
   - **教训**：在 Commit `b69bdc0` 中，尝试通过注入 `Method (_STA, 0)` 将独显从 ACPI 树中隐藏。结果物理 PCIe 链路（RTX 3070）仍然通电，`AppleACPIPCI` 枚举物理 PCI 设备时发现缺少 ACPI 电源管理描述符，导致冷启动进入 OpenCore 或系统时直接死锁卡死，唤醒时根桥亦因无法管理下级设备而崩溃。
   - **铁律**：严禁对链路已通电且训练的 PCIe 桥设备注入 `_STA = 0`。
7. **`gpuswitch 2` 自动显卡切换陷阱（入睡整整卡顿 90 秒）**：
   - **教训**：系统因检测到核显与未驱动独显，自动激活了 `gpuswitch 2`。入睡时 `IOGraphicsFamily` 广播通知所有 Framebuffer，独显上的 `IONDRVFramebuffer`（Index 1）因缺乏原生驱动无法应答，导致系统入睡卡滞整整 90 秒，触发 `graphics notify timeout (1, 1)`，并进而击溃核显 SMU 固件状态（`event_id=0xc0201`）。
   - **解决**：在 NVRAM 注入 Apple 原生 `gpu-power-prefs = <01 00 00 00>` 并在系统层锁定 `sudo pmset -a gpuswitch 0`，彻底关闭自动显卡切换仲裁。
8. **`config.plist` 中的 `PciRoot(0x1)` 虚假路径陷阱**：
   - **教训**：此前在 `DeviceProperties` 中配置的设备均位于 `PciRoot(0x1)` 下。根据 IORegistry 严谨审查，本机全部设备（核显、NVMe、独显）的 ACPI 根桥全为 `PCI0`（`_UID = 0`），即 `PciRoot(0x0)`，导致此前注入的属性完全失效。
   - **解决**：已将所有路径修正为真实的 `PciRoot(0x0)`。

---

### 2.3 唤醒黑屏的三大核心根因（最新真实日志确诊数据）

#### 核心根因 1：独显未屏蔽导致双 Framebuffer 争夺与 AGPM 死锁
- **设备树实测证据（IORegistry）**：
  在系统 `IORegistry` 设备树中审查发现，`GFX0@0`（NVIDIA RTX 独显 `10de:2560`，ACPI 路径 `\_SB.PCI0.GPP0.PEGP`）上挂载了：
  - `IONDRVFramebuffer`
  - `AppleMCCSControlModule`
  - `AppleUpstreamUserClientDriver`
  - `AGPM` (AppleGraphicsPowerManagement)
  其伴生独显音频控制器 `HDAU@0,1`（`10de:228e`，`\_SB.PCI0.GPP0.NHDA`）也挂载了 `AppleHDAController`。
- **日志确诊数据（入睡与唤醒阶段）**：
  ```text
  2026-10-31 18:06:41.513023+0800 kernel: PMRD: kIOMessageSystemCapabilityChange[14] to com.apple.driver.AGPM
  2026-10-31 18:06:41.513025+0800 kernel: PMRD: kIOMessageSystemCapabilityChange[15] to com.apple.driver.AGPM
  2026-10-31 18:07:39.993214+0800 kernel: PMRD: kIOMessageSystemCapabilityChange[14] to com.apple.driver.AGPM
  2026-10-31 18:07:39.993216+0800 kernel: PMRD: kIOMessageSystemCapabilityChange[15] to com.apple.driver.AGPM
  ```
- **解决机制（路线 A 演进与落地）**：
  最初尝试 `_DSM` 伪装时，开机内核日志暴露了联想原厂固件为支持 Advanced Optimus 已存在原生 `_DSM`，导致抛出 `AE_ALREADY_EXISTS` 异常并丢弃补丁。随后尝试 `Method (_STA, 0)` 隐身屏蔽法，虽然抹除了 ACPI 节点，但物理 PCIe 链路依然通电，导致 `AppleACPIPCI` 与根桥 `GPP0` 电源状态脱节而在开机/唤醒时卡死。
  最终确立**纯软件层面的单显卡锁定与环境隔离方案**（完全规避触摸硬件物理电源轨）：
  1. 在 `config.plist` NVRAM 注入 Apple 原生 `gpu-power-prefs = <01 00 00 00>`，强制锁定 Integrated GPU 独占模式，阻断系统级独显调度；
  2. 在系统层执行 `sudo pmset -a gpuswitch 0`，将电源管理器永久锁定为仅集成显卡，彻底消除 `gpuswitch 2` 自动双显卡切换仲裁死锁；
  3. 将 `config.plist` 中 `SSDT-GPU-DISABLE.aml` 设为 `Enabled: False`，彻底消除 `AE_ALREADY_EXISTS` 报错与桥设备仲裁风险。

#### 核心根因 2：`darkwake=1` 引发电源门控强行钳制屏幕与 Framebuffer（致命诱因！）
- **日志确诊数据（2026-10-31 18:07:40 - 18:07:46）**：
  ```text
  2026-10-31 18:07:40.160526+0800 kernel: PMRD: power clamped IODisplayWrangler 10000046b, ps 4->0, cflags 0x9)
  2026-10-31 18:07:41.046686+0800 kernel: PMRD: power clamped ATY,RadeonFramebuffer 1000004b0, ps 2->1, cflags 0x9)
  2026-10-31 18:07:41.213918+0800 kernel: PMRD: power clamped ATY,RadeonFramebuffer 1000004b0, ps 2->1, cflags 0x2011)
  2026-10-31 18:07:41.213923+0800 kernel: PMRD: dark wake power clamped after 1221 ms
  2026-10-31 18:07:41.840881+0800 kernel: PMRD: power clamped IODisplayWrangler 10000046b, ps 4->0, cflags 0x2)
  ... 5002ms 之后 ...
  2026-10-31 18:07:46.168188+0800 kernel: (AMDRadeonX5000) [6:0:0]: Timestamp 0xeb9 on channel 12 VMPT is not expired; stamp: 0xea8 -> 0xea8; HW stamps: read 0x2384 -> 0x2384, sent 0x2386; wait time 5002ms, ret 0xe00002d6
  2026-10-31 18:07:46.168257+0800 kernel: (AMDRadeonX5000) [6:0:0]: HW Channel 11 SDMA0 is occupied by channel 24 stamp 4340
  2026-10-31 18:07:46.770023+0800 kernel: (AMDRadeonX5000) [6:0:0]: channel 24 SDMA0 is hung! (lastReadTimestamp=0x000010f3)
  CLKS: dcfclk,dcfclk_deep_sleep,dispclk,dppclk,fclk,socclk: 0,0,0,0,0,0
  CLK1_CLK3_ALLOW_DS,1,dcf_deep_sleep_allow
  ```
- **技术机制剖析**：
  1. `darkwake=1` 诱使 macOS 认为机器唤醒只是为了执行后台任务（DarkWake），电源管理模块 `IOPMrootDomain` 强行将 `IODisplayWrangler` 钳制在 `ps 0`（屏幕关闭），同时将核显 `ATY,RadeonFramebuffer` 钳制在 `ps 1`（低功耗限制状态）；
  2. 核显驱动进入深度休眠逻辑，所有底层时钟全部停摆归零（`CLKS: 0,0,0,0,0,0`），并允许深度休眠（`dcf_deep_sleep_allow=1`）；
  3. 与此同时，系统渲染服务（WindowServer）试图提交显存映射任务至 SDMA0 / VMPT 通道，由于时钟被停摆，SDMA0 无法执行任何传输指令，等待 5002ms 后超时死锁，驱动被迫发起 `FullAsicReset 1`，而 APU 无法完成独显级总线重置，显卡直接彻底报废黑屏；
  4. **解决**：引导参数必须设置 **`darkwake=0`**，禁止暗中唤醒，任何唤醒立即执行 Full Wake，将显示协调器释放至 `ps 4`，核显时钟瞬间满血解冻。

#### 核心根因 3：运行态背光 UID 滞后（0.88% 极暗黑屏）
- **实测证据**：
  在当前开机运行态的 `ioreg -p IOACPIPlane -n PNLF -l` 中，`_UID = "14"`、`AppleRestoreBacklight = 16`（最大 1808）。这是由于此前更新的 `SSDT-PNLF.aml`（`_UID = 19`）尚未同步进 EFI 分区并在开机时重置 NVRAM 导致的。同步 EFI 并重置 NVRAM 后此问题自动恢复。

---

### 2.4 Commit `7c06650` 开机进不去的原因反思
- 在 Commit `7c06650` 中，尝试通过修改 `NootedRed` 二进制直接改写内嵌 XML（将 `CAIL_DisableAllClockGating`、`CAIL_DisablePowerGating` 等粗暴改为 1），并直接在 `PciRoot(0x1)` 上注入 `class-code = 0xFFFFFFFF`。
- **导致进不去系统的原因**：
  1. `CAIL_DisableAllClockGating=1` 破坏了 NootedRed 在系统开机冷启动阶段针对 `AMDRadeonX5000` 初始化时钟树的预期状态，触发驱动内核断言恐慌；
  2. 在无 WhateverGreen 的环境下直接给 PCIe 桥下的显卡注入伪装 `class-code: 0xFFFFFFFF`，导致 macOS 原生 `IOPCIFamily` 发生枚举遍历异常；
  3. 现已执行 `git revert`，代码库已回滚至稳定、可正常开机进入系统的基线状态。

---

### 2.5 Commit `b69bdc0` (`_STA=0`) 开机卡死与唤醒失败深度复盘
- 在 Commit `b69bdc0` 中，尝试利用 `Method (_STA, 0)` 将独显 `\_SB.PCI0.GPP0.PEGP` 从 ACPI 命名空间中隐藏，导致机器“**唤醒不了，而且开机还进不来，换成 fe695b1 才进得来**”。
- **深层物理机制**：
  1. **ACPI 与物理 PCIe 链路脱节**：`_STA = 0` 仅对 ACPI 解析层生效，但根桥 `GPP0` 下方的物理 PCIe 硬件链路（RTX 3070 `10de:2560`）依然通电且处于已训练状态（PCI 配置空间依然返回 `class-code 030000`）；
  2. **总线枚举仲裁死锁（冷启动卡死）**：`AppleACPIPCI` 遍历物理 PCI 配置空间时，读取到物理设备存在，却无法在 ACPI 设备树中获取对应的电源管理描述符（`_PR0/_PS0/_PS3`）。当桥设备 `GPP0` 尝试进行链路协商与功耗仲裁时陷入死锁，机器无法开机；
  3. **唤醒死锁**：从 S3 睡眠唤醒时，`GPP0` 无法对其下级物理设备执行 ACPI 电源状态恢复，直接触发系统总线死锁。
- **结论**：严禁对通电已训练的下级 PCIe 桥设备注入 `_STA = 0`。当前本地已完全基于 `fe695b1` 基线重置。

---

### 2.6 真实统一系统日志（Unified Log）23:50~23:52 秒级死锁铁证链
通过调取真实控制台系统日志，揭示了睡眠唤醒黑屏的完整诱因链条：
```text
【T+0.00s | 23:50:28】用户点击菜单栏「睡眠」
kernel: PMRD: dark wake entry
kernel: PMRD: DarkWake: sleepASAP 1, clamshell closed 0, disabled 1/0, desktopMode 0, ac 1

【T+15.0s | 23:50:43】WindowServer 响应超时！
kernel: PM notification timeout (pid 158, WindowServer) (took 15+ seconds to respond)

【T+91.0s | 23:51:59.669】整整卡滞 90 秒！IOGraphicsFamily 报告 Framebuffer 1 硬件超时！
kernel: PM priority notification timeout (com.apple.iokit.IOGraphicsFamily)
kernel: (IOGraphicsFamily) graphics notify timeout (1, 1)

【T+91.02s | 23:51:59.689】核显 Vega 8 的 SMU 与 GC 发生致命崩溃！
kernel: (AMDRadeonX6000Framebuffer) [6:0:0] [PPLIB] checkTtlErrorMessage() !!! TTL ERROR MESSAGE: 
{12179422023:[6:0:0] Error SW_IP_CLIENT_ID__SMU: event_id=0xc0201 event_info:type=3 hw_id=0}
{12307407428:[6:0:0] Error SW_IP_CLIENT_ID__GC: event_id=0xc0100201 event_info:type=3 hw_id=0}

【T+91.50s | 23:52:00.176】系统终于被迫进入睡眠状态（延迟了整整 92 秒！）
kernel: PMRD: === FINISH (ON_STATE->SLEEP_STATE, 9->0, 0x40c2) gen 2, msg 5, tag 5e0067

【T+115.0s | 23:52:23】硬件唤醒，但核显时钟已经全部归零报废！
kernel: (AMDRadeonX6000Framebuffer) [6:0:0][GPUCAP] refresh() --- Family: 142, Device: 0x1638
kernel: CLKS: dcfclk,dcfclk_deep_sleep,dispclk,dppclk,fclk,socclk: 0,0,0,0,0,0
kernel: CLK1_CLK3_ALLOW_DS,1,dcf_deep_sleep_allow

【T+125.0s | 23:52:33】用户多次轻按键盘（ITE 8258 正常产生击键事件），但屏幕全黑！
kernel: PMRD: Requesting full wake due to dark wake activity tickle
kernel: (AMDRadeonX5000) [6:0:0]: channel 24 SDMA0 is hung! (lastReadTimestamp=0x000010f3)
kernel: (IOAcceleratorFamily2) Trying to restart GPU (AMD Radeon RX Vega 8)...
kernel: DumpGPURestart(1043)
```

- **死锁原因定性**：
  1. **Framebuffer 1 超时**：Index 1 为独显上的 `IONDRVFramebuffer`。因缺乏驱动，它无法应答休眠广播，整整卡死入睡 90 秒；
  2. **SMU 固件击溃**：超时的入睡过程破坏了核显 PowerPlay 状态，SMU 抛出 `0xc0201`，底层显示时钟全 0；
  3. **`gpuswitch 2` 自动切换陷阱**：macOS 误以为本设备支持自动双显卡切换，试图在休眠唤醒时调度两张显卡，诱发雪崩。
  4. **根本方案**：通过注入 `gpu-power-prefs = <01 00 00 00>` 及执行 `sudo pmset -a gpuswitch 0` 锁定单显卡模式，同时修正 `PciRoot(0x0)` 路径，彻底根除双显卡仲裁。

---

## 3. 六大不可逾越的配置红线

在后续任何调试与修复中，必须无条件遵循以下 6 条红线：

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
6. **【绝对红线】严禁对通电已训练的下级 PCIe 桥设备注入 `_STA = 0`**：
   - 在 PCIe 物理硬件链路依然通电握手的情况下（如根桥 `GPP0` 下方的 RTX 3070），严禁使用 ACPI `_STA = 0` 盲目抹除 ACPI 设备节点。这会导致 `AppleACPIPCI` 与根桥硬件脱节，直接造成开机冷启动死锁及唤醒崩溃。必须采用纯软件层（`gpu-power-prefs` 与 `pmset gpuswitch 0`）隔离方案。

---

## 4. 修复实施进展与行动状态

### 路线 A：以非侵入方式安全隔离 NVIDIA 独显（✅ 已完成落地）
- **实施方案**：
  1. 在 `OC/config.plist` 的 `DeviceProperties -> Add` 中对独显及其伴生音频节点（`PciRoot(0x0)/Pci(0x1,0x1)/Pci(0x0,0x0)` 及 `.../Pci(0x0,0x1)`）注入 `class-code: 0xFFFFFFFF`、`name: #display`、`IOName: #display`，从驱动匹配源头彻底阻断 `IONDRVSupport.kext` 挂载 `IONDRVFramebuffer`，根除休眠 90 秒超时；
  2. 在 `OC/config.plist` 的 `NVRAM -> Add -> 7C436110-AB2A-4BBB-A880-FE41995C9F82` 中注入 `gpu-power-prefs = <01 00 00 00>`（并在 `Delete` 数组中添加对应项），开机强制锁定单显卡模式；
  3. 在 `boot-args` 中追加 `-wegnoegpu` 辅助参数；
  4. 保持禁用报错的 `SSDT-GPU-DISABLE.aml`（设为 `Enabled: False`），消除 `AE_ALREADY_EXISTS` 报错与总线冲突；
  5. 进入 macOS 后执行 `sudo pmset -a gpuswitch 0`，将系统 `GPUSwitch` 设为 0（仅集成显卡），彻底终结 `gpuswitch 2` 导致的多卡仲裁死锁。

### 路线 B：解决 Vega 8 唤醒显示时钟解冻（✅ 已完成落地）
- **实施方案**：
  1. 引导参数保持 **`darkwake=0`**，禁止暗中唤醒，任何唤醒立即执行 Full Wake，将显示协调器释放至 `ps 4`；
  2. 保持 `-NRedDPDelay` 提供 165Hz 高刷屏 eDP 链路握手缓冲；
  3. 清理已废弃与无效的启动参数。

### 路线 C：BIOS 固件与电源管理协同（按需核对）
- **检查项**：
  1. 使用 UMAF 工具进 BIOS 检查：
     - 确保睡眠模式为真正的 **S3 (Suspend to RAM)**，而非 Modern Standby (S0ix)；
     - 确保集成显卡显存 **UMA Frame Buffer Size** 固定为 **2GB 或 4GB**（切勿保持 Auto 或 512MB）；
     - 确保开启 **Above 4G Decoding** 并关闭 **CSM**。
  2. 系统电源参数优化：配置 `sudo pmset -a gpuswitch 0 hibernatemode 0 standby 0 powernap 0 tcpkeepalive 0`。

---

## 5. 系统当前各项硬件功能状态

- ✅ **图形加速与显示**：Vega 8 核显正常驱动，Metal 3 支持，满血 2.5K 165Hz 高刷新率，Retina HiDPI 正常工作。
- ✅ **物理键盘与触摸板**：内置键盘（ITE 8258）正常打字与灯控，I2C 触摸板多指手势丝滑。
- ✅ **网络连接**：Intel AX200 Wi-Fi 正常上网，蓝牙 5.2 正常连接配对，Realtek 千兆有线网卡即插即用。
- ✅ **声音与外放**：ALC287 耳机正常，Cirrus Logic CS35L41 双智能功放驱动机身扬声器正常发声。
- ✅ **电池与传感器**：电池电量与充放电状态正常，CPU 各核心温度与功耗实时监控正常。
- ⏳ **睡眠与唤醒**：入睡正常，单显卡模式已锁定，等待同步 EFI 并测试验证。

---

## 6. 当前引导参数与重要设置说明

当前基线 `boot-args`：
```text
keepsyms=1 debug=0x100 -vi2c-force-polling -v alcid=13 revpatch=sbvmm -NRedDisplayFix -NRedVideoFix -NRedDPDelay -amfipassbeta -btlfxboardid -cirrusssid=0x17AA3847 tlbto_us=0 darkwake=0 -wegnoegpu
```

> [!IMPORTANT]
> **生效与验证步骤**：
> 1. 执行 `./scripts/sync_efi.sh` 将仓库中最新的 `OC/config.plist` 同步至引导分区；
> 2. 在 macOS 终端执行电源模式锁定：
>    ```bash
>    sudo pmset -a gpuswitch 0
>    ```
> 3. 重启机器测试唤醒与开机流畅度。
> 3. 进入系统后，在终端验证：
>    - `ioreg -p IOService -c IONDRVFramebuffer` 结果应为空（独显已彻底静默）；
>    - `ioreg -p IOACPIPlane -n PNLF -l | grep UID` 应显示 `_UID = "19"`；
> 4. 点击苹果菜单 ->「睡眠」，观察呼吸灯进入平缓闪烁后，轻按任意键测试唤醒亮屏。
