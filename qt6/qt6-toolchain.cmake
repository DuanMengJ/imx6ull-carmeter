# CarMeter Qt6 交叉编译 toolchain — D1 方案: 本地 GCC 15.2 + glibc 2.43 sysroot
#
# 关键: 不设 CMAKE_SYSROOT.
# /usr/arm-linux-gnueabihf/lib/libc.so 是 GNU ld script, 内含绝对路径
#   GROUP ( /usr/arm-linux-gnueabihf/lib/libc.so.6 ... ld-linux-armhf.so.3 )
# 若设 CMAKE_SYSROOT=/usr/arm-linux-gnueabihf, gcc --sysroot=... 会把这些绝对路径
# 当作 sysroot 内的相对路径, 映射为 $SYSROOT/usr/arm-linux-gnueabihf/lib/... (不存在),
# 链接报 "cannot find libc.so.6 inside sysroot".
# 不设 sysroot 时, GCC 用默认 multiarch 搜索路径, 实测能找到 libc/libstdc++/crt 全部.
# (验证: arm-linux-gnueabihf-g++ -std=c++17 test.cpp -o test -> ARM ELF, for GNU/Linux 3.2.0)

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(CMAKE_C_COMPILER /usr/bin/arm-linux-gnueabihf-gcc)
set(CMAKE_CXX_COMPILER /usr/bin/arm-linux-gnueabihf-g++)

# cmake find_* 只在目标 sysroot 目录找库/头, 不污染主机
set(CMAKE_FIND_ROOT_PATH /usr/arm-linux-gnueabihf)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

set(CMAKE_BUILD_TYPE Release CACHE STRING "build type")
set(CMAKE_C_FLAGS "-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -O3" CACHE STRING "CFLAGS")
set(CMAKE_CXX_FLAGS "-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -O3" CACHE STRING "CXXFLAGS")
set(CMAKE_EXE_LINKER_FLAGS "" CACHE STRING "LDFLAGS")
set(CMAKE_SHARED_LINKER_FLAGS "" CACHE STRING "LDFLAGS")
set(CMAKE_INSTALL_SO_NO_EXE 0)

# pkg-config 不误用主机库 (留空 SYSROOT_DIR, 靠绝对路径)
set(ENV{PKG_CONFIG_LIBDIR} "/usr/arm-linux-gnueabihf/lib/pkgconfig:/usr/share/pkgconfig")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "")
