#!/usr/bin/env bash
# 构建镜像并导出为 TGZ 到 ./dist/
set -euo pipefail
cd "$(dirname "$0")"

IMAGE="oracle2excel:1.0"
VERSION="1.0"
DIST_DIR="./dist"

mkdir -p "$DIST_DIR"

echo "==> 构建镜像 $IMAGE ..."
docker build -t "$IMAGE" .

echo "==> 导出镜像到 $DIST_DIR/oracle2excel_${VERSION}.tar.gz ..."
docker save "$IMAGE" | gzip > "$DIST_DIR/oracle2excel_${VERSION}.tar.gz"

echo "==> 完成:"
ls -lh "$DIST_DIR"

echo ""
echo "目标机器加载方式:"
echo "  docker load < oracle2excel_${VERSION}.tar.gz"
echo "  然后将 oracle_conn.json / run.sh / output/ 放在同目录, 执行 ./run.sh"
