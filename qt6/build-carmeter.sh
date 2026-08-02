#!/bin/bash
# build-carmeter.sh — carmeter 交叉编译 (本地 GCC 15.2, 与 Qt6 同编译器保 ABI)
#
# 依赖: /opt/qt6-carmeter (qt6/build-qt6.sh 的产物) + arm-linux-gnueabihf 工具链
# 产物: $CARMETER_STAGING (DESTDIR install), buildroot post-build.sh 从该目录
#   把 carmeter + QML 资源注入 rootfs.
#
# 用法: ./qt6/build-carmeter.sh   (config.mk 里 CARMETER_STAGING 等环境变量覆盖默认值)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/app"
BUILD="${CARMETER_BUILD:-$HOME/qt6-cache/carmeter-build}"
STAGING="${CARMETER_STAGING:-$HOME/qt6-cache/carmeter-staging}"
TOOLCHAIN="$ROOT/qt6/carmeter-toolchain.cmake"
QT6="${QT6_PREFIX:-/opt/qt6-carmeter}"
QT_HOST="${QT_HOST:-/opt/qt6-carmeter-host}"
JOBS="${JOBS:-4}"

# 前置检查: Qt6 target 必须已 install
[ -f "$QT6/lib/libQt6Core.so.6" ] || { echo "ERR: $QT6/lib/libQt6Core.so.6 不存在, 先跑 qt6/build-qt6.sh"; exit 1; }
[ -f "$QT6/lib/cmake/Qt6/Qt6Config.cmake" ] || { echo "ERR: Qt6 cmake config 不存在 ($QT6/lib/cmake/Qt6/Qt6Config.cmake)"; exit 1; }

rm -rf "$BUILD" "$STAGING"
mkdir -p "$BUILD"

echo "=== carmeter cross-compile (GCC 15.2) ==="
echo "APP:       $APP"
echo "BUILD:     $BUILD"
echo "STAGING:   $STAGING"
echo "QT6:       $QT6"
echo "QT_HOST:   $QT_HOST"
echo "CXX:       $(arm-linux-gnueabihf-g++ -dumpversion)"
echo "JOBS:      $JOBS"
echo ""

cmake -S "$APP" -B "$BUILD" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_PREFIX_PATH="$QT6" \
    -DQt6_DIR="$QT6/lib/cmake/Qt6" \
    -DQt6Core_DIR="$QT6/lib/cmake/Qt6Core" \
    -DQt6Gui_DIR="$QT6/lib/cmake/Qt6Gui" \
    -DQt6Qml_DIR="$QT6/lib/cmake/Qt6Qml" \
    -DQt6Quick_DIR="$QT6/lib/cmake/Qt6Quick" \
    -DQt6QuickControls2_DIR="$QT6/lib/cmake/Qt6QuickControls2" \
    -DQT_HOST_PATH="$QT_HOST" \
    -DBUILD_TESTING=OFF \
    -DBUILD_FOR_EMBEDDED=ON \
    -DQT_NO_PACKAGE_VERSION_CHECK=ON \
    -DQT_NO_CXX17_FILESYSTEM=ON \
    -DQT_NO_FIND_HOST_TOOLS_PATH_MANIPULATION=ON \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=BOTH

echo "=== cmake configure exit: $? ==="
ninja -C "$BUILD" -j"$JOBS"
echo "=== ninja build exit: $? ==="

DESTDIR="$STAGING" ninja -C "$BUILD" install
echo "=== install exit: $? ==="
echo ""
echo "carmeter 二进制:"
file "$STAGING/usr/bin/carmeter" 2>/dev/null || ls -l "$STAGING/usr/bin/" 2>/dev/null
