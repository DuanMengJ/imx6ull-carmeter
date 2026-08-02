# carmeter 专用 toolchain - 基于 qt6-carmeter-toolchain.cmake, 改 FIND_ROOT_PATH + MODE
#
# 与 Qt6 编译 toolchain 的差异:
#   - CMAKE_FIND_ROOT_PATH 额外包含 /opt/qt6-carmeter (让 find_package 能找 Qt6 模块)
#   - CMAKE_FIND_ROOT_PATH_MODE_* = BOTH (允许跳出 sysroot 找 /opt/qt6-carmeter 的 Qt6 config)
# 原因: Qt6Core 依赖 Qt6ZlibPrivate 等 private 模块, 它们的 cmake config 在
#   /opt/qt6-carmeter/lib/cmake/Qt6ZlibPrivate/. MODE=ONLY 时 find 只搜 sysroot
#   (/usr/arm-linux-gnueabihf), 找不到 -> Qt6Core NOT FOUND.

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(CMAKE_C_COMPILER /usr/bin/arm-linux-gnueabihf-gcc)
set(CMAKE_CXX_COMPILER /usr/bin/arm-linux-gnueabihf-g++)

# find root: sysroot (glibc/libstdc++) + Qt6 安装目录 (cmake config + .so)
set(CMAKE_FIND_ROOT_PATH /usr/arm-linux-gnueabihf /opt/qt6-carmeter)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)

set(CMAKE_BUILD_TYPE Release CACHE STRING "build type")
# 关 PIE: 减体积 + 启动快 (carmeter 不需 ASLR, 嵌入式固定地址)
set(CMAKE_C_FLAGS "-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -O3 -fno-pie" CACHE STRING "CFLAGS")
set(CMAKE_CXX_FLAGS "-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -O3 -fno-pie" CACHE STRING "CXXFLAGS")
set(CMAKE_EXE_LINKER_FLAGS "-no-pie" CACHE STRING "LDFLAGS")
set(CMAKE_SHARED_LINKER_FLAGS "" CACHE STRING "LDFLAGS")
set(CMAKE_INSTALL_SO_NO_EXE 0)

set(ENV{PKG_CONFIG_LIBDIR} "/usr/lib/arm-linux-gnueabihf/pkgconfig:/usr/arm-linux-gnueabihf/lib/pkgconfig:/usr/share/pkgconfig")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "")
