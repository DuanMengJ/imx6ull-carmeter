#!/bin/sh
# M4-D D1: post-build.sh - buildroot 生成镜像前注入 Qt6 + carmeter + glibc 2.43
#
# buildroot 流程: target-finalize -> [本脚本] -> 生成 ext4/tar -> post-image.sh
# 参数: $1 = TARGET_DIR (output/target)
#
# D1 核心: 用本地 GCC 15.2 (glibc 2.43) 在 buildroot 外编 Qt6 + carmeter,
#   镜像生成前覆盖 rootfs 的 glibc 2.28 -> 2.43 (向后兼容 buildroot GCC 7.4 编的 busybox),
#   注入 Qt6 库/plugins/qml + carmeter 二进制 + libstdc++ (GCC 15) + 字体.
#
# 配套: defconfig 加 BR2_ROOTFS_POST_BUILD_SCRIPT, 移除 BR2_PACKAGE_CARMETER.

set -e

TARGET_DIR="$1"
QT6_PREFIX="${QT6_PREFIX:-/opt/qt6-carmeter}"
SYSROOT="${SYSROOT:-/usr/arm-linux-gnueabihf}"
CARMETER_STAGING="${CARMETER_STAGING:-$HOME/qt6-cache/carmeter-staging}"
BOARD_DIR="$(cd "$(dirname "$0")" && pwd)"   # buildroot/board/ebf/imx6ull-carmeter

echo "[post-build] D1 注入: glibc 2.43 + Qt6 + carmeter + libstdc++(GCC15)"

# ===== 1. 覆盖 glibc 2.28 -> 2.43 (完整覆盖, 删 2.28 残留) =====
# 关键: buildroot 2.28 的 libnss/libresolv/libcrypt 等与 2.43 的 libc.so.6 不兼容
# (混用导致 setlocale 异常 -> Qt locale "C" 非 UTF-8). 必须完整覆盖整个 glibc 库集.
echo "[post-build] 1/8 覆盖 glibc -> 2.43 (完整库集)"
# 删除所有 glibc 2.28 残留实体
rm -f "$TARGET_DIR/lib"/ld-2.28.so "$TARGET_DIR/lib"/libc-2.28.so \
      "$TARGET_DIR/lib"/libm-2.28.so "$TARGET_DIR/lib"/librt-2.28.so \
      "$TARGET_DIR/lib"/libpthread-2.28.so "$TARGET_DIR/lib"/libdl-2.28.so \
      "$TARGET_DIR/lib"/libutil-2.28.so "$TARGET_DIR/lib"/libanl-2.28.so \
      "$TARGET_DIR/lib"/libcrypt-2.28.so "$TARGET_DIR/lib"/libnss_dns-2.28.so \
      "$TARGET_DIR/lib"/libnss_files-2.28.so "$TARGET_DIR/lib"/libresolv-2.28.so 2>/dev/null || true
# 删除旧链接 (指向已删的 -2.28.so)
rm -f "$TARGET_DIR/lib"/ld-linux-armhf.so.3 "$TARGET_DIR/lib"/libc.so.6 \
      "$TARGET_DIR/lib"/libm.so.6 "$TARGET_DIR/lib"/libpthread.so.0 \
      "$TARGET_DIR/lib"/librt.so.1 "$TARGET_DIR/lib"/libdl.so.2 \
      "$TARGET_DIR/lib"/libnss_dns.so.2 "$TARGET_DIR/lib"/libnss_files.so.2 \
      "$TARGET_DIR/lib"/libresolv.so.2 "$TARGET_DIR/lib"/libanl.so.1 \
      "$TARGET_DIR/lib"/libutil.so.1 "$TARGET_DIR/lib"/libcrypt.so.1 2>/dev/null || true
# 复制 glibc 2.43 完整库集 (sysroot 里是实体文件, cp -aL 取消链接)
for lib in ld-linux-armhf.so.3 libc.so.6 libm.so.6 libpthread.so.0 librt.so.1 \
           libdl.so.2 libnss_files.so.2 libnss_dns.so.2 libresolv.so.2 \
           libanl.so.1 libBrokenLocale.so.1 libnsl.so.1; do
    [ -f "$SYSROOT/lib/$lib" ] && cp -aL "$SYSROOT/lib/$lib" "$TARGET_DIR/lib/"
done

# ===== 2. libstdc++ (GCC 15.2 的 6.0.35) 覆盖 GCC 7.4 的 6.0.24 =====
echo "[post-build] 2/8 覆盖 libstdc++ -> 6.0.35 (GCC 15)"
rm -f "$TARGET_DIR/usr/lib"/libstdc++.so* "$TARGET_DIR/usr/lib"/libstdc++*-gdb.py 2>/dev/null || true
cp -aL "$SYSROOT/lib/libstdc++.so.6.0.35" "$TARGET_DIR/usr/lib/"
ln -sf libstdc++.so.6.0.35 "$TARGET_DIR/usr/lib/libstdc++.so.6"
ln -sf libstdc++.so.6.0.35 "$TARGET_DIR/usr/lib/libstdc++.so"

# ===== 3. libgcc_s (GCC 15) =====
echo "[post-build] 3/8 覆盖 libgcc_s -> GCC 15"
rm -f "$TARGET_DIR/lib"/libgcc_s.so* 2>/dev/null || true
cp -aL "$SYSROOT/lib/libgcc_s.so.1" "$TARGET_DIR/lib/"

# 3.5 libgpiod (carmeter GpioManager 依赖, buzzer 控制 GPIO1_IO19)
cp -aL "$SYSROOT/lib/libgpiod.so.2"* "$TARGET_DIR/usr/lib/" 2>/dev/null || true

# ===== 4. Qt6 runtime 库 =====
echo "[post-build] 4/8 复制 Qt6 库"
cp -aL "$QT6_PREFIX/lib"/libQt6*.so* "$TARGET_DIR/usr/lib/" 2>/dev/null || true
cp -aL "$QT6_PREFIX/lib"/libicu*.so* "$TARGET_DIR/usr/lib/" 2>/dev/null || true
# Qt6 库的 cmake 配置/工具不进 rootfs (只要 runtime .so)

# ===== 5. Qt6 plugins + qml =====
echo "[post-build] 5/8 复制 Qt6 plugins + qml"
mkdir -p "$TARGET_DIR/usr/lib/qt6/plugins" "$TARGET_DIR/usr/lib/qt6/qml"
cp -ar "$QT6_PREFIX/plugins/"* "$TARGET_DIR/usr/lib/qt6/plugins/" 2>/dev/null || true
cp -ar "$QT6_PREFIX/qml/"* "$TARGET_DIR/usr/lib/qt6/qml/" 2>/dev/null || true
# 删 x86-64 污染 (Qt6 编译时 host build 残留 libqvkkhrdisplay.so 等, 非目标 ARM 架构, buildroot check 会报错)
find "$TARGET_DIR/usr/lib/qt6/plugins" -name '*.so' -exec sh -c 'file "$1" | grep -q "x86-64" && rm -f "$1"' _ {} \; 2>/dev/null || true

# 创建 /opt/qt6-carmeter 符号链接 (匹配 Qt 编译时 CMAKE_INSTALL_PREFIX=/opt/qt6-carmeter)
# Qt6 默认 PluginsPath/QmlImportsPath/LibrariesPath = /opt/qt6-carmeter/{plugins,qml,lib}
# 不创建的话 Qt 找不到 libqlinuxfb.so (no platform plugin 错误)
mkdir -p "$TARGET_DIR/opt/qt6-carmeter"
rm -f "$TARGET_DIR/opt/qt6-carmeter/plugins" "$TARGET_DIR/opt/qt6-carmeter/qml" "$TARGET_DIR/opt/qt6-carmeter/lib" 2>/dev/null || true
ln -sf /usr/lib/qt6/plugins "$TARGET_DIR/opt/qt6-carmeter/plugins" 2>/dev/null || true
ln -sf /usr/lib/qt6/qml "$TARGET_DIR/opt/qt6-carmeter/qml" 2>/dev/null || true
ln -sf /usr/lib "$TARGET_DIR/opt/qt6-carmeter/lib" 2>/dev/null || true

# ===== 6. carmeter 二进制 + 资源 =====
echo "[post-build] 6/8 复制 carmeter"
if [ -d "$CARMETER_STAGING" ]; then
    cp -aL "$CARMETER_STAGING/usr/bin/carmeter" "$TARGET_DIR/usr/bin/" 2>/dev/null || \
        echo "  WARN: carmeter 二进制未找到"
    # qt_add_qml_module install 的 QML 资源
    if [ -d "$CARMETER_STAGING/usr/share/carmeter" ]; then
        mkdir -p "$TARGET_DIR/usr/share/carmeter"
        cp -ar "$CARMETER_STAGING/usr/share/carmeter/"* "$TARGET_DIR/usr/share/carmeter/"
    fi
    # 若 install 到 lib/qt6/qml/CarMeter (qt_add_qml_module 默认)
    if [ -d "$CARMETER_STAGING/usr/lib/qt6/qml/CarMeter" ]; then
        mkdir -p "$TARGET_DIR/usr/lib/qt6/qml/CarMeter"
        cp -ar "$CARMETER_STAGING/usr/lib/qt6/qml/CarMeter/"* "$TARGET_DIR/usr/lib/qt6/qml/CarMeter/"
    fi
else
    echo "  WARN: $CARMETER_STAGING 不存在 - carmeter 未编译, 跳过"
fi

# ===== 7. 字体 wqy-zenhei (main.cpp QT_QPA_FONTDIR=/usr/share/fonts/wqy-zenhei) =====
echo "[post-build] 7/8 复制字体 wqy-zenhei"
mkdir -p "$TARGET_DIR/usr/share/fonts/wqy-zenhei"
FONT_FOUND=no
for f in "$BOARD_DIR/fonts/wqy-zenhei.ttc" \
         /usr/share/fonts/truetype/wqy/wqy-zenhei.ttc \
         /usr/share/fonts/wqy-zenhei/wqy-zenhei.ttc \
         /usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc \
         "$SYSROOT/usr/share/fonts/wqy-zenhei.ttc"; do
    if [ -f "$f" ]; then
        cp -aL "$f" "$TARGET_DIR/usr/share/fonts/wqy-zenhei/"
        # Qt6 freetype 后端 (fontconfig=OFF) 按扩展名扫描字体目录, 不识别 .ttc,
        # 只认 .ttf/.otf. 但 freetype 本身按文件内容能读 .ttc, 故额外复制一份
        # .ttf 扩展名 (同内容) 让 Qt populate 时扫描到 family. 否则字体数据库空
        # -> QML 文字全框框. (qemu-arm 验证: .ttc=0 family, .ttf=3 family)
        cp -aL "$f" "$TARGET_DIR/usr/share/fonts/wqy-zenhei/wqy-zenhei.ttf"
        echo "  字体来源: $f (+ wqy-zenhei.ttf 供 Qt6 freetype 扫描)"
        FONT_FOUND=yes
        break
    fi
done
[ "$FONT_FOUND" = no ] && echo "  WARN: wqy-zenhei 字体未找到, Qt 文字将无法渲染!"

# ===== 8. ld.so 配置 =====
# Qt6 库在 /usr/lib (ld.so 默认搜索路径), 不需要额外 ld.so.conf
# S99carmeter 的 LD_LIBRARY_PATH=/opt/qt6-carmeter/lib 指向不存在路径 (无害), 可后续清理
echo "[post-build] 8/8 ld.so: Qt6 在 /usr/lib (默认搜索, 无需额外配置)"

# ===== 9. 禁用 S40network (车Meter 不用以太网, can0 由 S99carmeter up) =====
rm -f "$TARGET_DIR/etc/init.d/S40network"
echo "[post-build] 禁用 S40network (以太网)"

echo ""
echo "[post-build] D1 注入完成. 验证:"
echo "  glibc:    $(ls $TARGET_DIR/lib/libc.so.6 2>/dev/null && strings $TARGET_DIR/lib/libc.so.6 2>/dev/null | grep -m1 'GNU C Library')"
echo "  libstdc++: $(ls $TARGET_DIR/usr/lib/libstdc++.so.6.0.* 2>/dev/null | tail -1)"
echo "  Qt6 库:   $(ls $TARGET_DIR/usr/lib/libQt6*.so 2>/dev/null | wc -l) 个 .so"
echo "  Qt6 qml:  $(ls $TARGET_DIR/usr/lib/qt6/qml/ 2>/dev/null | wc -l) 个目录"
echo "  carmeter: $(file $TARGET_DIR/usr/bin/carmeter 2>/dev/null | cut -d, -f1-2 || echo '缺失')"
echo "  字体:     $(ls $TARGET_DIR/usr/share/fonts/wqy-zenhei/ 2>/dev/null | head -1 || echo '缺失')"
