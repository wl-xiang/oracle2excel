# syntax=docker/dockerfile:1
# 显式固定到 Debian 12 bookworm: libaio1 仅存在于 bookworm,
# 默认的 python:3.11-slim 已切到 trixie, 其中该包已更名为 libaio1t64, 安装会报 exit 100
FROM python:3.11-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    LANG=C.UTF-8

# Oracle Instant Client 19 运行所需的系统库 (libaio 等) 及在线下载/解压工具
RUN apt-get update && apt-get install -y --no-install-recommends \
        libaio1 \
        libnsl2 \
        wget \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# Python 依赖 (在线安装)
RUN pip install --no-cache-dir \
        oracledb==2.5.1 \
        openpyxl==3.1.5

# 在线下载 Oracle Instant Client 19 Basic (19c 兼容 Oracle 11.2, Thick 模式必需)
# 官方公开直链, 无需登录/许可证确认; x64/arm64 均有 19.19 版本, 解压目录名一致
# TARGETARCH 由 BuildKit 根据 --platform 自动注入; 未启用 BuildKit 时回退到构建机 uname
ARG TARGETARCH
ENV ORACLE_BASE=/opt/oracle \
    INSTANTCLIENT_DIR=/opt/oracle/instantclient_19_19
RUN mkdir -p /opt/oracle && \
    ARCH="${TARGETARCH:-$(uname -m | sed -e 's/^x86_64$/amd64/' -e 's/^aarch64$/arm64/')}" && \
    case "$ARCH" in \
        amd64) IC_URL="https://download.oracle.com/otn_software/linux/instantclient/1919000/instantclient-basic-linux.x64-19.19.0.0.0dbru.zip" ;; \
        arm64) IC_URL="https://download.oracle.com/otn_software/linux/instantclient/1919000/instantclient-basic-linux.arm64-19.19.0.0.0dbru.zip" ;; \
        *) echo "[错误] 不支持的目标架构: $ARCH" >&2; exit 1 ;; \
    esac && \
    wget -q --timeout=60 "$IC_URL" -O /tmp/instantclient.zip && \
    unzip -q /tmp/instantclient.zip -d /opt/oracle && \
    rm -f /tmp/instantclient.zip && \
    ls /opt/oracle/instantclient_19_19/libclntsh.so.19.1 && \
    # 校验下载的 .so 的 ELF 机器类型与目标架构一致 (62=x86-64, 183=aarch64), 防止架构错配静默通过构建
    python -c "import sys; d=open('/opt/oracle/instantclient_19_19/libclntsh.so.19.1','rb').read(20); exp={'amd64':62,'arm64':183}[sys.argv[1]]; assert int.from_bytes(d[18:20],'little')==exp, 'Instant Client ELF 架构与目标平台不一致'" "$ARCH"

# Instant Client 相关环境变量
ENV ORACLE_HOME=/opt/oracle/instantclient_19_19 \
    LD_LIBRARY_PATH=/opt/oracle/instantclient_19_19 \
    TNS_ADMIN=/app \
    PATH=/opt/oracle/instantclient_19_19:$PATH

WORKDIR /app

COPY export_to_excel.py .

# 配置文件 oracle_conn.json 与输出目录 ./output 均在运行时通过 -v 挂载, 不打入镜像
CMD ["python", "export_to_excel.py", "/app/oracle_conn.json"]
