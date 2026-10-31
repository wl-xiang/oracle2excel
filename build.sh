#!/usr/bin/env bash
# 构建镜像并导出为 TGZ 到 ./dist/
set -euo pipefail
cd "$(dirname "$0")"

IMAGE="oracle2excel:1.0"
VERSION="1.0"
DIST_DIR="./dist"

# 目标平台: 本工程构建机与部署机均为 arm64, 默认 linux/arm64
# 如需给 x86_64 服务器构建, 执行: ./build.sh linux/amd64
# 若不指定 --platform, arm 机器上会构建出 arm 镜像; 而错误架构的 Instant Client 会导致
# 运行时 DPI-1047 (libclntsh.so 架构不匹配, 报 No such file or directory)
PLATFORM="${1:-linux/arm64}"

mkdir -p "$DIST_DIR"

echo "==> 构建镜像 $IMAGE (platform: $PLATFORM) ..."
docker build --platform "$PLATFORM" -t "$IMAGE" .

echo "==> 导出镜像到 $DIST_DIR/oracle2excel_${VERSION}.tar.gz ..."
docker save "$IMAGE" | gzip > "$DIST_DIR/oracle2excel_${VERSION}.tar.gz"

echo "==> 完成:"
ls -lh "$DIST_DIR"

echo ""
echo "目标机器加载方式:"
echo "  docker load < oracle2excel_${VERSION}.tar.gz"
echo "  然后将 oracle_conn.json / run.sh / output/ 放在同目录, 执行 ./run.sh"
