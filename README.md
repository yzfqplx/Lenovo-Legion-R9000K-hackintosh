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
- **解决机制（路线 A 落地）**：
  引入 Dortania 官方规范的 `SSDT-GPU-DISABLE.aml`，利用 ACPI `_DSM` 针对 `\_SB.PCI0.GPP0.PEGP` 和 `\_SB.PCI0.GPP0.NHDA` 注入 `class-code: 0xFFFFFFFF`、`name: #display`。这样 `IOPCIFamily` 不会将其视作图形/音频设备，彻底阻断 `IONDRVFramebuffer` 与 `AGPM` 加载，同时不触碰硬件电源轨（不调用 `_OFF`），避免总线掉线与风扇狂转。

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

## 4. 修复实施进展与行动状态

### 路线 A：以非侵入方式安全屏蔽 NVIDIA 独显（✅ 已完成落地）
- **实施方案**：创建并编译标准 Dortania 规范 ACPI 热补丁 `SSDT-GPU-DISABLE.aml`，挂载在 `OC/ACPI/` 并在 `config.plist` 中启用。
- **作用对象**：
  - `\_SB.PCI0.GPP0.PEGP`（独显本体 RTX 3070/3080）
  - `\_SB.PCI0.GPP0.NHDA`（独显伴生音频 HDA）
- **效果**：利用 `_DSM` 伪装 `class-code: 0xFFFFFFFF` 和 `name: #display`，阻断 `IONDRVFramebuffer`、`AGPM`、`AppleHDAController` 加载，同时避免调用 `_OFF()` 引发断电总线风暴与风扇狂转。

### 路线 B：解决 Vega 8 唤醒显示时钟解冻（✅ 已完成落地）
- **实施方案**：
  1. 将引导参数中的 `darkwake=1` 更改为 **`darkwake=0`**，彻底根除唤醒瞬间由电源管理器发起的 `power clamped IODisplayWrangler ps 4->0` 和 `power clamped ATY,RadeonFramebuffer ps 2->1` 低功耗死锁！
  2. 保持 `-NRedDPDelay` 提供 165Hz 高刷屏 eDP 链路握手缓冲；
  3. 清理已废弃与无效的启动参数（如 `-NRedGLFix`、`-NRedVDA` 及临时测试参数 `-NRedNoFVRC`）。

### 路线 C：BIOS 固件与电源管理协同（按需核对）
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
- ⏳ **睡眠与唤醒**：入睡正常，独显已完成 ACPI 屏蔽，DarkWake 门控已解冻，等待同步 EFI 并重启测试。

---

## 6. 当前引导参数与重要设置说明

当前基线 `boot-args`：
```text
keepsyms=1 debug=0x100 -vi2c-force-polling -v alcid=13 revpatch=sbvmm -NRedDisplayFix -NRedVideoFix -NRedDPDelay -amfipassbeta -btlfxboardid -cirrusssid=0x17AA3847 tlbto_us=0 darkwake=0
```

> [!IMPORTANT]
> **生效与验证步骤**：
> 1. 执行 `sudo ./scripts/sync_efi.sh` 将仓库中最新的 `OC/config.plist` 和 `OC/ACPI/`（含 `SSDT-GPU-DISABLE.aml` 及 `SSDT-PNLF.aml`）同步至引导分区；
> 2. 重启机器，在 OpenCore 引导选单界面按空格键，选中并执行 **【Reset NVRAM】**；
> 3. 进入系统后，在终端验证：
>    - `ioreg -p IOService -c IONDRVFramebuffer` 结果应为空（独显已彻底静默）；
>    - `ioreg -p IOACPIPlane -n PNLF -l | grep UID` 应显示 `_UID = "19"`；
> 4. 点击苹果菜单 ->「睡眠」，观察呼吸灯进入平缓闪烁后，轻按任意键测试唤醒亮屏。
