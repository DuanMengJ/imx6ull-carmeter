#!/bin/sh
# post-image.sh - buildroot 生成 ext4 后调用
# D1: Qt6+carmeter+glibc2.43 已由 post-build.sh 在镜像生成前注入, 本脚本不再复制 Qt6 (无效).
# 保留骨架供未来扩展 (如 mfgtools 专用镜像后处理).
set -e

echo "post-image: D1 rootfs 已由 post-build.sh 注入 (Qt6+carmeter+glibc2.43), 本脚本无操作"
