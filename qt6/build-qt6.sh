#!/bin/bash
# build-qt6.sh — Qt 6.7.3 ARM 交叉编译 (本地 GCC 15.2 + glibc 2.43, buildroot 外)
#
# 背景: buildroot 2019.02.6 自带 GCC 7.4 太老, 编不了 Qt6.
#   本项目用系统 arm-linux-gnueabihf 工具链 (GCC 12+) 在 buildroot 外编译 Qt6,
#   编译产物 install 到 $QT6_PREFIX (默认 /opt/qt6-carmeter).
#   构建 rootfs 时 post-build.sh 把 Qt6 库注入 rootfs, 并用 glibc 2.43 覆盖
#   buildroot 的 glibc 2.28 (carmeter 与 Qt6 的 ABI 要求).
#
# 前置依赖:
#   - Qt 源码: ~/qt6-cache/qt-everywhere-src-6.7.3 (qt-everywhere-src-6.7.3.tar.xz 解包)
#     → 用环境变量 QT_SRC 指定其他路径
#   - 交叉工具链: gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf (apt 安装)
#   - ninja + cmake (≥3.21)
#
# 产物: $QT6_PREFIX (target 库) + $QT_HOST (host 工具, 生成 qmlcache 等)
# 只编 qtbase + qtshadertools + qtdeclarative (carmeter 实际依赖).
# 耗时: 首次 4-6 小时 (4 核), 增量秒级.
#
# 用法: ./qt6/build-qt6.sh   (config.mk 里 QT6_PREFIX 等环境变量会覆盖默认值)

set -euo pipefail

QT_SRC="${QT_SRC:-$HOME/qt6-cache/qt-everywhere-src-6.7.3}"
QT_BUILD="${QT_BUILD:-$HOME/qt6-cache/qt6-target-build}"
QT_INSTALL="${QT6_PREFIX:-/opt/qt6-carmeter}"
QT_HOST="${QT_HOST:-/opt/qt6-carmeter-host}"
TOOLCHAIN="$(cd "$(dirname "$0")" && pwd)/qt6-toolchain.cmake"
JOBS="${JOBS:-4}"

# 前置检查
[ -d "$QT_SRC" ] || { echo "ERR: Qt6 源码不存在: $QT_SRC"; echo "     先下载并解包 qt-everywhere-src-6.7.3.tar.xz 到该目录"; exit 1; }
[ -f "$QT_SRC/CMakeLists.txt" ] || { echo "ERR: $QT_SRC 不是 Qt 源码树 (缺 CMakeLists.txt)"; exit 1; }
command -v arm-linux-gnueabihf-g++ >/dev/null || { echo "ERR: 缺 arm-linux-gnueabihf 交叉工具链, 先 apt install g++-arm-linux-gnueabihf"; exit 1; }
command -v ninja >/dev/null || { echo "ERR: 缺 ninja, 先 apt install ninja-build"; exit 1; }

rm -rf "$QT_BUILD"
mkdir -p "$QT_BUILD"

echo "=== Qt 6.7.3 ARM cross-compile ==="
echo "SRC:       $QT_SRC"
echo "BUILD:     $QT_BUILD"
echo "PREFIX:    $QT_INSTALL"
echo "HOST_PATH: $QT_HOST"
echo "TOOLCHAIN: $TOOLCHAIN"
echo "CXX:       $(arm-linux-gnueabihf-g++ -dumpversion)"
echo "JOBS:      $JOBS"
echo ""

cmake -S "$QT_SRC" -B "$QT_BUILD" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$QT_INSTALL" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DQT_HOST_PATH="$QT_HOST" \
    -DQT_BUILD_EXAMPLES=OFF \
    -DQT_BUILD_TESTS=OFF \
    -DQT_BUILD_SUBMODULES="qtbase;qtshadertools;qtdeclarative" \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
    -DINPUT_accessibility=no \
    -DINPUT_testlib=no \
    -DINPUT_opengl=no \
    -DINPUT_opengles2=no \
    -DINPUT_opengles3=no \
    -DINPUT_egl=no \
    -DINPUT_eglfs=no \
    -DINPUT_linuxfb=yes \
    -DINPUT_dbus=no \
    -DINPUT_gstreamer=no \
    -DINPUT_pulseaudio=no \
    -DINPUT_alsa=no \
    -DINPUT_glib=no \
    -DINPUT_harfbuzz=no \
    -DINPUT_fontconfig=no \
    -DINPUT_reduce_exports=yes \
    -DINPUT_pch=no \
    -DINPUT_use_gold_linker=no \
    -DINPUT_sql_sqlite=no \
    -DINPUT_sql_psql=no \
    -DINPUT_sql_mysql=no \
    -DINPUT_sql_odbc=no \
    -DINPUT_libpng=qt \
    -DINPUT_libjpeg=qt \
    -DINPUT_optimize_size=yes \
    -DINPUT_strip=yes \
    -DQT_SKIP_SVGTOQML=ON

echo ""
echo "=== cmake configure exit: $? ==="
ninja -C "$QT_BUILD" -j"$JOBS"
echo "=== ninja build exit: $? ==="
ninja -C "$QT_BUILD" install
echo "=== install exit: $? ==="
echo ""
echo "Qt6 已安装到 $QT_INSTALL:"
ls "$QT_INSTALL/lib/libQt6Core.so.6" 2>/dev/null && echo "OK: libQt6Core.so.6"
