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

# fakeroot 1.20.2 + glibc 2.30+ 兼容问题:
# 1) _BSD_SOURCE 移除 (改 _DEFAULT_SOURCE)
# 2) GCC 15 把 implicit declaration 视为 error (强制 setgroups_size_arg=size_t)
# 3) _STAT_VER_GLIBC2_3_4 宏移除 (configure 检测不到就不 AC_DEFINE(_STAT_VER),
#    libfakeroot.c 14 处 _STAT_VER 引用全部 undeclared:
#    chown/lchown/fchown/fchownat/llistxattr/flistxattr/lremovexattr/fremovexattr
#    + fts_read/fts_children (fts 的同时还有 incompatible pointer type 问题))
# 4) <fts.h> 中 FTSENT.fts_statp 类型从 struct stat64 * 改为 struct stat * (LFS 合一)
# 解决方案:
#   a) sed 把 libfakeroot.c 所有 _STAT_VER token 替换为字面量 0 (fakeroot wrap 的
#      next___xstat64 等在新 glibc 上不接 version 参数, 0 是合法 fallback)
#   b) sed 把 fts_read/fts_children 里的 SEND_GET_STAT64(r->fts_statp, _STAT_VER)
#      改成强制 cast 的 send_get_stat64((struct stat64 *)r->fts_statp), GCC 15 对
#      强制 cast 不报 incompatible-pointer-type error
define HOST_FAKEROOT_FIX_GLIBC240_HOOK
	$(SED) 's|#define _BSD_SOURCE|#define _DEFAULT_SOURCE|g' $(@D)/configure
	$(SED) 's|^setgroups_size_arg=unknown$$|setgroups_size_arg=unknown; if true; then setgroups_size_arg=size_t; fi|' $(@D)/configure
	$(SED) 's|_STAT_VER|0|g' $(@D)/libfakeroot.c
	$(SED) 's|SEND_GET_STAT64(r->fts_statp, 0);|send_get_stat64((struct stat64 *)r->fts_statp);|g' $(@D)/libfakeroot.c
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
