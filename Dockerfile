# syntax=docker/dockerfile:1
# 基于 python:3.11-slim (Debian 12 bookworm, 该版本库中存在 libaio1 包)
FROM python:3.11-slim

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
# 官方公开直链, 无需登录/许可证确认
ENV ORACLE_BASE=/opt/oracle \
    INSTANTCLIENT_DIR=/opt/oracle/instantclient_19_19
RUN mkdir -p /opt/oracle && \
    wget -q --timeout=60 \
        "https://download.oracle.com/otn_software/linux/instantclient/1919000/instantclient-basic-linux.x64-19.19.0.0.0dbru.zip" \
        -O /tmp/instantclient.zip && \
    unzip -q /tmp/instantclient.zip -d /opt/oracle && \
    rm -f /tmp/instantclient.zip && \
    ls /opt/oracle/instantclient_19_19/libclntsh.so.19.1

# Instant Client 相关环境变量
ENV ORACLE_HOME=/opt/oracle/instantclient_19_19 \
    LD_LIBRARY_PATH=/opt/oracle/instantclient_19_19 \
    TNS_ADMIN=/app \
    PATH=/opt/oracle/instantclient_19_19:$PATH

WORKDIR /app

COPY export_to_excel.py .

# 配置文件 oracle_conn.json 与输出目录 ./output 均在运行时通过 -v 挂载, 不打入镜像
CMD ["python", "export_to_excel.py", "/app/oracle_conn.json"]
