#!/usr/bin/env bash
# 构建镜像并导出为 TGZ 到 ./dist/
set -euo pipefail
cd "$(dirname "$0")"

IMAGE="oracle2excel:1.0"
VERSION="1.0"
DIST_DIR="./dist"

# 目标平台: 默认 linux/amd64 (绝大多数 x86_64 服务器); arm64 服务器执行: ./build.sh linux/arm64
# 在 Apple Silicon 等 arm 开发机上给 x86 服务器构建时, 必须显式指定, 否则会构建出 arm 镜像导致
# 运行时 DPI-1047 (libclntsh.so 架构不匹配)
PLATFORM="${1:-linux/amd64}"

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
