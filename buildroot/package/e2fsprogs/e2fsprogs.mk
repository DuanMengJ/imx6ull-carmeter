################################################################################
#
# e2fsprogs
#
################################################################################

E2FSPROGS_VERSION = 1.45.4
E2FSPROGS_SOURCE = e2fsprogs-$(E2FSPROGS_VERSION).tar.xz
E2FSPROGS_SITE = $(BR2_KERNEL_MIRROR)/linux/kernel/people/tytso/e2fsprogs/v$(E2FSPROGS_VERSION)
E2FSPROGS_LICENSE = GPL-2.0, MIT-like with advertising clause (libss and libet)
E2FSPROGS_LICENSE_FILES = NOTICE lib/ss/mit-sipb-copyright.h lib/et/internal.h
E2FSPROGS_INSTALL_STAGING = YES

# Use libblkid and libuuid from util-linux for host and target packages.
# This prevents overriding them with e2fsprogs' ones, which may cause
# problems for other packages.
E2FSPROGS_DEPENDENCIES = host-pkgconf util-linux
HOST_E2FSPROGS_DEPENDENCIES = host-pkgconf host-util-linux

# e4defrag doesn't build on older systems like RHEL5.x, and we don't
# need it on the host anyway.
# Disable fuse2fs as well to avoid carrying over deps, and it's unused
HOST_E2FSPROGS_CONF_OPTS = \
	--disable-defrag \
	--disable-e2initrd-helper \
	--disable-fuse2fs \
	--disable-libblkid \
	--disable-libuuid \
	--disable-testio-debug \
	--enable-symlink-install \
	--enable-elf-shlibs \
	--with-crond-dir=no

# Set the binary directories to "/bin" and "/sbin", as busybox does,
# so that we do not end up with two versions of e2fs tools.
E2FSPROGS_CONF_OPTS = \
	--bindir=/bin \
	--sbindir=/sbin \
	$(if $(BR2_STATIC_LIBS),--disable-elf-shlibs,--enable-elf-shlibs) \
	$(if $(BR2_PACKAGE_E2FSPROGS_DEBUGFS),--enable-debugfs,--disable-debugfs) \
	$(if $(BR2_PACKAGE_E2FSPROGS_E2IMAGE),--enable-imager,--disable-imager) \
	$(if $(BR2_PACKAGE_E2FSPROGS_E4DEFRAG),--enable-defrag,--disable-defrag) \
	$(if $(BR2_PACKAGE_E2FSPROGS_FSCK),--enable-fsck,--disable-fsck) \
	$(if $(BR2_PACKAGE_E2FSPROGS_RESIZE2FS),--enable-resizer,--disable-resizer) \
	--disable-uuidd \
	--disable-libblkid \
	--disable-libuuid \
	--disable-e2initrd-helper \
	--disable-testio-debug \
	--disable-rpath \
	--enable-symlink-install

ifeq ($(BR2_PACKAGE_E2FSPROGS_FUSE2FS),y)
E2FSPROGS_CONF_OPTS += --enable-fuse2fs
E2FSPROGS_DEPENDENCIES += libfuse
else
E2FSPROGS_CONF_OPTS += --disable-fuse2fs
endif

ifeq ($(BR2_nios2),y)
E2FSPROGS_CONF_ENV += ac_cv_func_fallocate=no
endif

E2FSPROGS_CONF_ENV += ac_cv_path_LDCONFIG=true

HOST_E2FSPROGS_CONF_ENV += ac_cv_path_LDCONFIG=true

# gcc 15 默认拒绝 `typedef int bool` (e2fsprogs 1.45.4 tdb.c 的问题)
# 但 -std=c17 模式不报错. 注入 -std=c17 到 MCONFIG.in 所有 CFLAGS 变量
# 同时 e2fsprogs 1.45.4:
# 1) 子目录 Makefile 用相对路径 `config/install-sh` 跑 `make install`,
#    子目录里找不到 install-sh. 用 $(top_builddir) 绝对化路径
# 2) MCONFIG 模板的 MKDIR_P 用 install-sh -c -d + 多个目录参数,
#    install-sh 脚本只支持 2 个参数 (src, dst), 多参数时 dst 被覆盖.
#    改成直接用 mkdir -p 处理多目录.
define HOST_E2FSPROGS_FIX_CSTD_HOOK
	$(SED) 's|^CFLAGS = @CFLAGS@$$|CFLAGS = @CFLAGS@ -std=c17|' $(@D)/MCONFIG.in
	$(SED) 's|^CFLAGS_SHLIB = @CFLAGS_SHLIB@$$|CFLAGS_SHLIB = @CFLAGS_SHLIB@ -std=c17|' $(@D)/MCONFIG.in
	$(SED) 's|^CFLAGS_STLIB = @CFLAGS_STLIB@$$|CFLAGS_STLIB = @CFLAGS_STLIB@ -std=c17|' $(@D)/MCONFIG.in
	$(SED) 's|^BUILD_CFLAGS = @BUILD_CFLAGS@$$|BUILD_CFLAGS = @BUILD_CFLAGS@ -std=c17|' $(@D)/MCONFIG.in
	$(SED) 's|^MKDIR_P = @MKDIR_P@$$|MKDIR_P = mkdir -p|' $(@D)/MCONFIG.in
endef
HOST_E2FSPROGS_PRE_CONFIGURE_HOOKS += HOST_E2FSPROGS_FIX_CSTD_HOOK

E2FSPROGS_INSTALL_STAGING_OPTS = \
	DESTDIR=$(STAGING_DIR) \
	install-libs

# Package does not build in parallel due to improper make rules
define HOST_E2FSPROGS_INSTALL_CMDS
	$(HOST_MAKE_ENV) $(MAKE1) -C $(@D) install install-libs
endef

$(eval $(autotools-package))
$(eval $(host-autotools-package))
