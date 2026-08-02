################################################################################
#
# gawk
#
################################################################################

GAWK_VERSION = 4.2.1
GAWK_SOURCE = gawk-$(GAWK_VERSION).tar.xz
GAWK_SITE = $(BR2_GNU_MIRROR)/gawk
GAWK_DEPENDENCIES = host-gawk
GAWK_LICENSE = GPL-3.0+
GAWK_LICENSE_FILES = COPYING

# gawk 4.2.1 + gcc 15 兼容:
# - implicit function declaration (strtod 在 node.c) 视为 error
# - 大量老 C 语法警告
# 强制用 gnu11 + 禁兼容警告, 让 GCC 15 不要因为老代码报错
HOST_GAWK_CONF_ENV += CFLAGS="$(HOST_CFLAGS) -std=gnu11 -Wno-error=incompatible-pointer-types -Wno-error=implicit-function-declaration -Wno-error=int-conversion"

# 编译完后用系统 gawk 5.3.2 替代 (glibc 2.40 兼容)
define HOST_GAWK_INSTALL_HOST_CMDS
	ln -sf /usr/bin/gawk $(HOST_DIR)/bin/gawk
	ln -sf /usr/bin/gawk-5.3.2 $(HOST_DIR)/bin/gawk-5.3.2
endef
HOST_GAWK_POST_INSTALL_HOOKS += HOST_GAWK_INSTALL_HOST_CMDS

ifeq ($(BR2_PACKAGE_LIBSIGSEGV),y)
GAWK_DEPENDENCIES += libsigsegv
endif

# --with-mpfr requires an argument so just let
# configure find it automatically
ifeq ($(BR2_PACKAGE_MPFR),y)
GAWK_DEPENDENCIES += mpfr
else
GAWK_CONF_OPTS += --without-mpfr
endif

# --with-readline requires an argument so just let
# configure find it automatically
ifeq ($(BR2_PACKAGE_READLINE),y)
GAWK_DEPENDENCIES += readline
else
GAWK_CONF_OPTS += --without-readline
endif

HOST_GAWK_CONF_OPTS = --without-readline --without-mpfr

define GAWK_CREATE_SYMLINK
	ln -sf gawk $(TARGET_DIR)/usr/bin/awk
endef

GAWK_POST_INSTALL_TARGET_HOOKS += GAWK_CREATE_SYMLINK

$(eval $(autotools-package))
$(eval $(host-autotools-package))
