# imx6ull-carmeter 顶层构建 Makefile
#
# D1 方案: buildroot 不 fresh build, 而是复用 CarMeter_Qt 7月31日成功的
# buildroot/output/target/ 作为基础 rootfs, 再跑本项目 post-build.sh 注入
# 外部编译的 Qt6 + carmeter + glibc 2.43 + libstdc++. 完全避开 buildroot 2019.02.6
# 在 GCC 15 + make 4.4 下的兼容问题 (host-fakeroot/glibc stdio-common 等卡死).
#
# 用法:
#   cp config.mk.example config.mk   # 可选: 按本机环境定制
#   make qt6       # 交叉编译 Qt 6.7 (首次 4-6h, 增量秒级)
#   make app       # 编译 carmeter (依赖 qt6)
#   make kernel    # zImage + dtb
#   make uboot     # u-boot-mmc.imx
#   make buildroot # D1 注入: rsync CarMeter_Qt target + post-build.sh 注入
#   make release   # 汇总全部产物到 release/ + sha256sum
#   make all       # 按依赖顺序执行以上全部
#   make clean     # 清理 release/
#
# 所有路径都可用 config.mk 或环境变量覆盖 (见 config.mk.example)。

# ---------- 本机配置 ----------
-include config.mk

# ---------- 默认值 ----------
QT6_PREFIX          ?= /opt/qt6-carmeter
QT_HOST             ?= /opt/qt6-carmeter-host
QT_SRC              ?= $(HOME)/qt6-cache/qt-everywhere-src-6.7.3
CARMETER_STAGING    ?= $(HOME)/qt6-cache/carmeter-staging
CROSS_COMPILE       ?= arm-linux-gnueabihf-
SYSROOT             ?= /usr/arm-linux-gnueabihf
KERNEL_DIR          ?= kernel
UBOOT_DIR           ?= uboot
BUILDROOT_DIR       ?= buildroot
APP_DIR             ?= app
RELEASE_DIR         ?= release
JOBS                ?= $(shell nproc)
# D1 方案: 复用兄弟项目 CarMeter_Qt 的 buildroot output 作为基础 rootfs
CARMETER_QT_DIR     ?= ../CarMeter_Qt
CARMETER_QT_BUILDOUTPUT ?= $(CARMETER_QT_DIR)/buildroot/output
BOARD_DIR           ?= $(BUILDROOT_DIR)/board/ebf/imx6ull-carmeter
BUILDROOT_TARGET    ?= $(BUILDROOT_DIR)/output/target
BUILDROOT_IMAGES    ?= $(BUILDROOT_DIR)/output/images
ROOTFS_SIZE         ?= 256M

# 导出给子构建 (buildroot post-build.sh 读取这些环境变量注入 rootfs)
export QT6_PREFIX QT_HOST CARMETER_STAGING SYSROOT JOBS

# ---------- 目标 ----------
.PHONY: all qt6 qt6-check app app-check buildroot kernel uboot release clean help

all: qt6 app buildroot kernel uboot release
	@echo ""
	@echo "=== 全部构建完成. 烧写 release/ 到 eMMC 即可 ==="

help:
	@echo "imx6ull-carmeter 构建目标 (D1 方案):"
	@echo "  make qt6       交叉编译 Qt 6.7 -> $(QT6_PREFIX)"
	@echo "  make app       编译 carmeter -> $(CARMETER_STAGING)"
	@echo "  make kernel    编译 zImage + imx6ull-carmeter-pro.dtb"
	@echo "  make uboot     编译 u-boot-mmc.imx"
	@echo "  make buildroot D1 注入: rsync CarMeter_Qt target + post-build.sh"
	@echo "  make release   汇总 release/ + sha256sum.txt"
	@echo "  make all       以上全部"
	@echo "  make clean     清理 release/"

# ---------- Qt6 ----------
qt6:
	./qt6/build-qt6.sh

qt6-check:
	@test -f "$(QT6_PREFIX)/lib/libQt6Core.so.6" || { \
		echo "ERR: Qt6 未安装 ($(QT6_PREFIX)/lib/libQt6Core.so.6 缺失), 先跑 make qt6"; \
		exit 1; }

# ---------- carmeter ----------
app: qt6-check
	./qt6/build-carmeter.sh

app-check:
	@test -f "$(CARMETER_STAGING)/usr/bin/carmeter" || { \
		echo "ERR: carmeter 未编译 ($(CARMETER_STAGING)/usr/bin/carmeter 缺失), 先跑 make app"; \
		exit 1; }

# ---------- buildroot (D1 注入) ----------
# 复用 CarMeter_Qt 7月31日成功 build 的 buildroot/output/target/ 作为基础 rootfs
# (busybox + glibc 2.28 + 基础配置), 然后跑本项目 post-build.sh 注入:
#   1. 覆盖 glibc 2.28 -> 2.43 (向后兼容 busybox)
#   2. 覆盖 libstdc++ 6.0.24 -> 6.0.35 (GCC 15)
#   3. 覆盖 libgcc_s -> GCC 15
#   4. 复制 Qt6 库 (从 $(QT6_PREFIX))
#   5. 复制 Qt6 plugins + qml
#   6. 复制 carmeter 二进制 (从 $(CARMETER_STAGING))
#   7. 复制字体 wqy-zenhei
#   8. ld.so 配置
# 产物: $(BUILDROOT_IMAGES)/{rootfs.ext4, rootfs.tar}
buildroot: qt6-check app-check
	@echo "=== D1 buildroot: 复用 CarMeter_Qt target + post-build.sh 注入 ==="
	@test -d "$(CARMETER_QT_BUILDOUTPUT)/target" || { \
		echo "ERR: CarMeter_Qt buildroot output 不存在: $(CARMETER_QT_BUILDOUTPUT)/target"; \
		echo "     需要先在 CarMeter_Qt 项目跑 make (老 GCC/make 环境能编通)"; \
		echo "     或者 cp -a 老 release/rootfs.tar 解包到 $(CARMETER_QT_BUILDOUTPUT)/target/"; \
		exit 1; }
	@echo "[D1] 1/4 rsync CarMeter_Qt target -> $(BUILDROOT_TARGET)"
	@mkdir -p "$(BUILDROOT_TARGET)"
	@rsync -a --delete "$(CARMETER_QT_BUILDOUTPUT)/target/" "$(BUILDROOT_TARGET)/"
	@echo "[D1] 2/4 post-build.sh 注入 (glibc 2.43 + Qt6 + carmeter + libstdc++)"
	@bash "$(BOARD_DIR)/post-build.sh" "$(BUILDROOT_TARGET)"
	@echo "[D1] 3/4 mkfs.ext4 打包 -> $(BUILDROOT_IMAGES)/rootfs.ext4 ($(ROOTFS_SIZE))"
	@mkdir -p "$(BUILDROOT_IMAGES)"
	@mkfs.ext4 -F -L rootfs -b 4096 -d "$(BUILDROOT_TARGET)" "$(BUILDROOT_IMAGES)/rootfs.ext4" "$(ROOTFS_SIZE)"
	@echo "[D1] 4/4 tar 打包 -> $(BUILDROOT_IMAGES)/rootfs.tar"
	@cd "$(BUILDROOT_TARGET)" && tar -cf - . > "../images/rootfs.tar"
	@echo ""
	@ls -lh "$(BUILDROOT_IMAGES)/"
	@echo "buildroot D1 注入产物: $(BUILDROOT_IMAGES)/rootfs.ext4 + rootfs.tar"

# ---------- kernel ----------
kernel:
	@test -f "$(KERNEL_DIR)/.config" || { \
		echo "ERR: $(KERNEL_DIR)/.config 缺失 (仓库自带构建配置), 请检查 kernel 目录完整"; \
		exit 1; }
	$(MAKE) -C "$(KERNEL_DIR)" ARCH=arm CROSS_COMPILE="$(CROSS_COMPILE)" -j"$(JOBS)" zImage dtbs

# ---------- uboot ----------
uboot:
	$(MAKE) -C "$(UBOOT_DIR)" ARCH=arm CROSS_COMPILE="$(CROSS_COMPILE)" mx6ull_fire_mmc_defconfig
	$(MAKE) -C "$(UBOOT_DIR)" ARCH=arm CROSS_COMPILE="$(CROSS_COMPILE)" -j"$(JOBS)"

# ---------- release (汇总烧写镜像) ----------
release: buildroot kernel uboot
	@mkdir -p "$(RELEASE_DIR)"
	@cp -L "$(BUILDROOT_IMAGES)/rootfs.ext4" "$(RELEASE_DIR)/rootfs.ext4"
	@cp    "$(BUILDROOT_IMAGES)/rootfs.tar"   "$(RELEASE_DIR)/rootfs.tar"
	@cp    "$(KERNEL_DIR)/arch/arm/boot/zImage"          "$(RELEASE_DIR)/zImage"
	@cp    "$(KERNEL_DIR)/arch/arm/boot/dts/imx6ull-carmeter-pro.dtb" "$(RELEASE_DIR)/imx6ull-carmeter-pro.dtb"
	@cp    "$(UBOOT_DIR)/u-boot.imx"                     "$(RELEASE_DIR)/u-boot-mmc.imx"
	@rm -f "$(RELEASE_DIR)/imx6ull-mmc-npi.dtb"
	@cd "$(RELEASE_DIR)" && sha256sum u-boot-mmc.imx zImage imx6ull-carmeter-pro.dtb rootfs.ext4 rootfs.tar > sha256sum.txt
	@echo ""
	@echo "=== release/ 就绪 ==="
	@ls -lh "$(RELEASE_DIR)"

# ---------- 清理 ----------
clean:
	@rm -rf "$(RELEASE_DIR)"
	@echo "已清理 $(RELEASE_DIR)/ (构建产物保存在 $(BUILDROOT_TARGET), /opt/qt6-carmeter, $(CARMETER_STAGING))"
