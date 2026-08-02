# imx6ull-carmeter

基于 i.MX6ULL 嵌入式 Linux 的车载数字仪表盘（Qt 6 软件渲染）。

- 硬件平台：i.MX6ULL 单核 Cortex-A7 @ 792MHz，512MB 内存（CarMeter-Pro 板）
- 显示：4.3" LCD（800×480），LinuxFB 后端，双缓冲无撕裂
- UI：Qt 6.7 + Qt Quick，纯 QML 绘制仪表指针/刻度/警示灯/数值条
- 数据源：`MockDataSource` 三段状态机（点火自检 → 数据续接 → 实时数据），无 CAN 通信
- 构建：buildroot 2019.02.6 基础系统 + 外部交叉编译 Qt 6（GCC 15 / glibc 2.43 覆盖 rootfs）

```
┌──────────────┐   ┌─────────────┐   ┌─────────────┐
│  PowerOnSelf │   │  数据续接动画  │   │  实时数据    │
│   Test 自检   │ → │ (里程续接)   │ → │  (车速/转速) │
└──────────────┘   └─────────────┘   └─────────────┘
```

## 目录结构

```
.
├── app/                 # carmeter 应用 (Qt 6 C++ + QML)
│   ├── src/             #   main.cpp / Application / io / core / persist
│   ├── qml/             #   仪表 UI (Dashboard, SpeedIndicator, ...)
│   └── resources/       #   图片资源 (指针/刻度/警示灯 PNG)
├── buildroot/           # 根文件系统 (野火 ebf fork 2019.02.6 + 本项目改动)
│   └── board/ebf/imx6ull-carmeter/
│       ├── post-build.sh    # 注入 Qt6 + carmeter + glibc 2.43 + 字体
│       ├── post-image.sh    # 镜像打包 hooks
│       └── rootfs-overlay/  # 板级配置 (init.d / inittab / S99carmeter)
├── kernel/              # Linux 4.19 (野火 ebf fork + 本项目 DTS/patch)
│   └── arch/arm/boot/dts/imx6ull-carmeter-pro.dts
├── uboot/               # U-Boot (野火 ebf fork + 本项目 bootcmd 改动)
├── qt6/                 # Qt 6 交叉编译脚本 + 板端适配说明
├── release/             # 烧写镜像 (由 make release 生成, 不入库)
├── config.mk.example    # 本机构建配置模板 → 复制为 config.mk
└── Makefile             # 顶层一键构建
```

## 环境准备（构建主机）

Ubuntu 22.04+，需要：

```bash
# 交叉工具链 (GCC 12+ 用于 buildroot 基础系统外的 Qt6 编译)
sudo apt install gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf \
                 libc6-armhf-cross libc6-dev-armhf-cross
```

> 注意：buildroot 2019.02.6 自带 GCC 版本较老，与 GCC 12/15 存在兼容问题，
> 本仓库的 `buildroot/` 已包含全部兼容性补丁（host-gettext / e2fsprogs / fakeroot 等），
> 直接构建即可，无需额外处理。

## 构建

```bash
cp config.mk.example config.mk   # 按本机环境修改
make buildroot                   # 1) 基础系统 rootfs (数小时, 仅首次)
make qt6                         # 2) 交叉编译 Qt 6.7 → /opt/qt6-carmeter (4-6h, 仅首次)
make app                         # 3) 编译 carmeter
make release                     # 4) 重打包 rootfs + 同步 release/ + sha256
```

`make all` 按顺序执行全部步骤。每个步骤结果缓存在 `buildroot/output/`、
`~/qt6-cache/`、`/opt/qt6-carmeter`，重复构建增量进行。

## 烧写

release/ 产物用 NXP **mfgtools**（Windows 烧写工具）烧写到 eMMC：

1. 把 `release/*` 拷到 Windows
2. 双击 `Mfgtool2-imx6ull-SDCard.vbs`（或 eMMC 变体）
3. 板端串口 115200 观察启动 log
4. 启动后自动运行 carmeter，LCD 显示仪表盘

## 特性与板端适配说明

| 项 | 说明 |
|----|------|
| 启动速度 | random crng 0.1s（`trust_cpu` patch）、无网络等待，~3s 进仪表 |
| 字体 | wqy-zenhei 复制为 .ttf（Qt6 freetype 不扫描 .ttc） |
| 显示 | LinuxFB 双缓冲 pan（patch 见 `qt6/` 说明） |
| 音频 | 蜂鸣器 GPIO1_IO19 提示音（GpioManager） |
| 按键 | TTP223 触摸按键 GPIO5_IO01 切换设置页 |

## 已知限制

- 无 CAN 通信：数据源为 Mock，仅演示/开发用（`app/src/io/` 保留接口）
- 无 GPU：纯软件渲染，动画保持 30-60 FPS 但 CPU 占用较高
- 蓝牙/以太网已禁用（板端无网口需求）

## 许可证

**GPL-3.0** — 详见 [LICENSE](LICENSE)。

- 作者：**DuanMengJ**
- 本仓库**原创部分**（`app/`、`qt6/` 构建脚本、Makefile、文档）以 GPL-3.0 授权
- **上游组件**（`kernel/`、`buildroot/`、`uboot/`）保留各自上游协议（GPL-2.0 等），
  版权归原作者所有 — 见下方[上游致谢](#上游致谢)

### 上游致谢

本仓库包含以下上游项目的 fork 与修改，其版权归原作者所有：

- [野火 ebf_6ull_buildroot](https://gitee.com/Embedfire/ebf_6ull_buildroot)（buildroot 2019.02.6）
- [野火 ebf_linux_kernel_6ull](https://gitee.com/Embedfire/ebf_linux_kernel_6ull)（Linux 4.19）
- [野火 ebf_linux_uboot](https://gitee.com/Embedfire/ebf_linux_uboot)（U-Boot）
- [Qt 6.7](https://www.qt.io/)（LGPL 组件，本仓库以二进制形式使用）
- wqy-zenhei 文泉驿正黑字体（GPL/APL 双许可）
