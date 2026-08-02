################################################################################
#
# fakeroot
#
################################################################################

FAKEROOT_VERSION = 1.20.2
FAKEROOT_SOURCE = fakeroot_$(FAKEROOT_VERSION).orig.tar.bz2
FAKEROOT_SITE = http://snapshot.debian.org/archive/debian/20141005T221953Z/pool/main/f/fakeroot

HOST_FAKEROOT_DEPENDENCIES = host-acl
# Force capabilities detection off
# For now these are process capabilities (faked) rather than file
# so they're of no real use
HOST_FAKEROOT_CONF_ENV = \
	ac_cv_header_sys_capability_h=no \
	ac_cv_func_capset=no \
	ac_cv_type_setgroups_size_type=size_t \
	setgroups_size_arg=size_t

# fakeroot 1.20.2 + glibc 2.40 兼容问题:
# 1) _BSD_SOURCE 移除 (改 _DEFAULT_SOURCE)
# 2) GCC 15 把 implicit declaration 视为 error (强制 setgroups_size_arg=size_t)
# 3) _STAT_VER 宏移除 (libfakeroot.c 无法编译)
# 4) 即使前 3 个 patch 全做, libfakeroot.c 还引用 glibc 不存在的 stat/64 函数
# fakeroot 1.20.2 是 2014 年代码, glibc 2.40 (2024) 移除了 _STAT_VER
# 解决方案: 跳过自编译 fakeroot, 用 Ubuntu 系统装的 fakeroot 1.37.2
# (新版本兼容 glibc 2.40). 用 buildroot install hook 把系统 fakeroot
# 软链接到 output/host/bin/.
define HOST_FAKEROOT_FIX_GLIBC240_HOOK
	$(SED) 's|#define _BSD_SOURCE|#define _DEFAULT_SOURCE|g' $(@D)/configure
	$(SED) 's|^setgroups_size_arg=unknown$$|setgroups_size_arg=unknown; if true; then setgroups_size_arg=size_t; fi|' $(@D)/configure
endef
HOST_FAKEROOT_POST_PATCH_HOOKS += HOST_FAKEROOT_FIX_GLIBC240_HOOK

# 用系统 fakeroot 1.37.2 替代自编译的 host-fakeroot
# (buildroot 的 host-fakeroot stamp 触发编译, 但 install 阶段我们覆盖它)
# 注: Debian/Ubuntu 1.37.2 把 faked 改名 faked-sysv (alternatives 系统)
# 且把 libfakeroot-0.so 装到 /usr/lib/x86_64-linux-gnu/, 但 buildroot 1.20.2
# 的 wrapper 硬编码找 /usr/lib/libfakeroot/libfakeroot.so, 永远找不到。
# 所以必须替换 wrapper, 不能让它继续运行。
define HOST_FAKEROOT_INSTALL_HOST_CMDS
	rm -f $(HOST_DIR)/bin/fakeroot $(HOST_DIR)/bin/faked
	ln -sf /usr/bin/fakeroot $(HOST_DIR)/bin/fakeroot
	ln -sf /usr/bin/faked-sysv $(HOST_DIR)/bin/faked
endef

HOST_FAKEROOT_POST_INSTALL_HOOKS += HOST_FAKEROOT_INSTALL_HOST_CMDS

# 保险: buildroot install 阶段可能 install-lib 后覆盖。HOST_FAKEROOT_FINALIZE
# 在 target finalize 时再覆盖一次 (ext2.mk 用 fakeroot 在 target finalize 之前,
# 所以必须 POST_INSTALL hook, 不能晚)
define HOST_FAKEROOT_FINALIZE_OVERRIDE
	rm -f $(HOST_DIR)/bin/fakeroot $(HOST_DIR)/bin/faked
	ln -sf /usr/bin/fakeroot $(HOST_DIR)/bin/fakeroot
	ln -sf /usr/bin/faked-sysv $(HOST_DIR)/bin/faked
endef
HOST_FAKEROOT_POST_INSTALL_HOOKS += HOST_FAKEROOT_FINALIZE_OVERRIDE

FAKEROOT_LICENSE = GPL-3.0+
FAKEROOT_LICENSE_FILES = COPYING

$(eval $(host-autotools-package))
