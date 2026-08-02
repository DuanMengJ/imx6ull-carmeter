# qt6/ — Qt 6 交叉编译配置

## 为什么在 buildroot 外编译 Qt6?

buildroot 2019.02.6 自带 GCC 7.4,而 Qt 6.7 要求 GCC ≥ 11 / Clang ≥ 12。
本项目用 **系统 arm-linux-gnueabihf 工具链 (GCC 15)** 在 buildroot 外编译 Qt6,
绕过 buildroot 老编译器,构建 rootfs 时用 `post-build.sh` 把 Qt6 运行时注入镜像。

ABI 一致性要求: **carmeter 必须与 Qt6 用同一个编译器编译** (都是 GCC 15.2),
否则链接进 GCC 7.4 的 libstdc++ ABI 不兼容 (原 carmeter.mk 方案的坑, D1 已修复)。

## 文件

| 文件 | 用途 |
|------|------|
| `build-qt6.sh` | Qt6 编译: qtbase + qtshadertools + qtdeclarative, install 到 `$QT6_PREFIX` |
| `build-carmeter.sh` | carmeter 交叉编译, DESTDIR 到 `$CARMETER_STAGING` |
| `qt6-toolchain.cmake` | Qt6 编译用 toolchain (sysroot = `/usr/arm-linux-gnueabihf`) |
| `carmeter-toolchain.cmake` | carmeter 用 toolchain (额外含 `/opt/qt6-carmeter` 的 cmake config) |

## 构建

```bash
./qt6/build-qt6.sh        # 首次 4-6 小时 (4 核), 产物 /opt/qt6-carmeter
./qt6/build-carmeter.sh   # 产物 ~/qt6-cache/carmeter-staging/
```

两个脚本的所有路径都可用环境变量覆盖 (见脚本头部), 顶层 `make qt6` / `make app`
由 `config.mk` 提供这些变量。

## 关键配置说明

| 项 | 说明 |
|----|------|
| `-DINPUT_linuxfb=yes` | LinuxFB 平台插件 (无 GPU, 软件渲染) |
| `-DINPUT_fontconfig=no` | 关 fontconfig → Qt 用 freetype 直接扫字体目录 (见 post-build.sh 的 .ttf 处理) |
| `-DINPUT_optimize_size=yes -DINPUT_strip=yes` | 体积优化 (rootfs 128MB) |
| `-DQT_BUILD_SUBMODULES="qtbase;qtshadertools;qtdeclarative"` | 只编 carmeter 依赖的 3 个模块 |
| `-DINPUT_reduce_exports=yes` | 减小 .so 导出符号, 省空间 |

## 板端适配 (本仓库内的对应改动)

- **carmeter 字体路径**: `app/src/main.cpp` 设置 `QT_QPA_FONTDIR=/usr/share/fonts/wqy-zenhei`
  (Qt6 freetype 后端按扩展名扫描, 只认 .ttf/.otf — post-build.sh 里把 .ttc 复制成 .ttf)
- **LinuxFB 双缓冲**: 曾用 FBIOPAN_DISPLAY 给 qlinuxfbscreen 加双缓冲 pan (消除撕裂),
  当前版本已回退为上游单 buffer。如有撕裂问题可按此思路重新加回。
- **随机数初始化加速**: Qt 启动依赖 getrandom, i.MX6ULL 的 CRNG 初始化慢 (116s) —
  见 `kernel/drivers/char/random.c` 的 `trust_cpu` 修改。
- **ppoll/futex 兼容**: Qt 6.7 在 kernel 4.19 上用新 syscall 会 ENOSYS —
  `buildroot/board/ebf/imx6ull-carmeter/post-build.sh` 用 glibc 2.43 覆盖 2.28,
  旧 kernel 用老 futex 路径 (见 glibc 的 futex_waitv 兼容处理)。
