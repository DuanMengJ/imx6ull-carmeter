# imx6ull-carmeter 顶层构建 Makefile
#
# 用法:
#   cp config.mk.example config.mk   # 可选: 按本机环境定制
#   make qt6       # 交叉编译 Qt 6.7 (首次 4-6h, 增量秒级)
#   make app       # 编译 carmeter (依赖 qt6)
#   make buildroot # 构建基础 rootfs (首次数小时, 自动注入 Qt6 + carmeter)
#   make kernel    # zImage + dtb
#   make uboot     # u-boot-mmc.imx
#   make release   # 汇总全部产物到 release/ + sha256sum
#   make all       # 按依赖顺序执行以上全部
#   make clean     # 清理 release/
#
# 所有路径都可用 config.mk 或环境变量覆盖 (见 config.mk.example)。

# ---------- 本机配置 ----------
-include config.mk

# ---------- 默认值 ----------
QT6_PREFIX       ?= /opt/qt6-carmeter
QT_HOST          ?= /opt/qt6-carmeter-host
QT_SRC           ?= $(HOME)/qt6-cache/qt-everywhere-src-6.7.3
CARMETER_STAGING ?= $(HOME)/qt6-cache/carmeter-staging
CROSS_COMPILE    ?= arm-linux-gnueabihf-
SYSROOT          ?= /usr/arm-linux-gnueabihf
KERNEL_DIR       ?= kernel
UBOOT_DIR        ?= uboot
BUILDROOT_DIR    ?= buildroot
APP_DIR          ?= app
RELEASE_DIR      ?= release
JOBS             ?= $(shell nproc)

# 导出给子构建 (buildroot post-build.sh 读取这些环境变量注入 rootfs)
export QT6_PREFIX QT_HOST CARMETER_STAGING SYSROOT JOBS

# ---------- 目标 ----------
.PHONY: all qt6 qt6-check app app-check buildroot kernel uboot release clean help

all: qt6 app buildroot kernel uboot release
	@echo ""
	@echo "=== 全部构建完成. 烧写 release/ 到 eMMC 即可 ==="

help:
	@echo "imx6ull-carmeter 构建目标:"
	@echo "  make qt6       交叉编译 Qt 6.7 -> $(QT6_PREFIX)"
	@echo "  make app       编译 carmeter -> $(CARMETER_STAGING)"
	@echo "  make buildroot 构建 rootfs (注入 Qt6 + carmeter)"
	@echo "  make kernel    编译 zImage + imx6ull-carmeter-pro.dtb"
	@echo "  make uboot     编译 u-boot-mmc.imx"
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

# ---------- buildroot (rootfs) ----------
buildroot: qt6-check app-check
	$(MAKE) -C "$(BUILDROOT_DIR)" imx6ull_carmeter_defconfig
	$(MAKE) -C "$(BUILDROOT_DIR)" -j"$(JOBS)"

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
	@cp -L "$(BUILDROOT_DIR)/output/images/rootfs.ext4" "$(RELEASE_DIR)/rootfs.ext4"
	@cp    "$(BUILDROOT_DIR)/output/images/rootfs.tar"   "$(RELEASE_DIR)/rootfs.tar"
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
	@echo "已清理 $(RELEASE_DIR)/ (构建产物保存在 buildroot/output/, /opt/qt6-carmeter, $(CARMETER_STAGING))"
