#!/usr/bin/env bash
# 运行导出服务: docker run --rm, 配置文件与输出目录均从当前目录挂载进容器
set -euo pipefail
cd "$(dirname "$0")"

IMAGE="oracle2excel:1.0"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "[错误] 镜像 $IMAGE 不存在, 请先执行: ./build.sh"
    exit 1
fi

if [ ! -f ./oracle_conn.json ]; then
    echo "[错误] 当前目录缺少配置文件 oracle_conn.json (可参考 oracle_conn.json 修改)"
    exit 1
fi

mkdir -p ./output

exec docker run --rm \
    -v "$(pwd)/oracle_conn.json:/app/oracle_conn.json:ro" \
    -v "$(pwd)/output:/app/output" \
    "$IMAGE"
