################################################################################
#
# gmp
#
################################################################################

GMP_VERSION = 6.1.2
GMP_SITE = $(BR2_GNU_MIRROR)/gmp
GMP_SOURCE = gmp-$(GMP_VERSION).tar.xz
GMP_INSTALL_STAGING = YES
GMP_LICENSE = LGPL-3.0+ or GPL-2.0+
GMP_LICENSE_FILES = COPYING.LESSERv3 COPYINGv2
GMP_DEPENDENCIES = host-m4
HOST_GMP_DEPENDENCIES = host-m4

# gmp 6.1.2 + gcc 15 兼容:
# 1) configure 测试 long long reliability 用 K&R 函数声明 `void g()`,
#    gcc 15 -std=c23 等同 `void g(void)` 不接受参数, 报"too many arguments"
# 2) K&R 声明 `void f()` 调用 `f(arg)` 也会报 incompatible
# 强制 -std=gnu11 让 K&R 函数声明保留 variadic 语义
HOST_GMP_CONF_ENV += CFLAGS="$(HOST_CFLAGS) -std=gnu11"

# GMP doesn't support assembly for coldfire or mips r6 ISA yet
# Disable for ARM v7m since it has different asm constraints
ifeq ($(BR2_m68k_cf)$(BR2_MIPS_CPU_MIPS32R6)$(BR2_MIPS_CPU_MIPS64R6)$(BR2_ARM_CPU_ARMV7M),y)
GMP_CONF_OPTS += --disable-assembly
endif

$(eval $(autotools-package))
$(eval $(host-autotools-package))
