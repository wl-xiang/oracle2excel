#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从上游 Oracle 数据库导出 SQL 查询结果到 Excel 文件 (.xlsx)。

用法:
    python export_to_excel.py [配置文件路径]
    默认配置文件路径: /app/oracle_conn.json (Docker 内), 本地调试可传 ./oracle_conn.json

说明:
    - Oracle 11g 需要 Thick 模式 + service_name, 依赖镜像内的 Oracle Instant Client 19。
    - 配置与输出路径均通过 docker -v 挂载, 容器本身无状态。
"""

import json
import os
import re
import sys
import traceback
from datetime import datetime

import oracledb
from openpyxl import Workbook

# CLOB/BLOB (<=1GB) 直接按 str/bytes 取回, 减少逐行读取 LOB 的额外 round-trip
oracledb.defaults.fetch_lobs = False

# Excel 单 sheet 数据行数上限为 1048576, 预留 1 行表头
EXCEL_MAX_DATA_ROWS = 1048575

# xlsx 单元格不允许的控制字符 (保留 \t \n \r), 否则 openpyxl 抛 IllegalCharacterError
_XLSX_ILLEGAL_CHARS = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f]")

REQUIRED_KEYS = ("user", "password", "host", "port", "service_name", "sql", "output")


def log(msg):
    print(f"[{datetime.now():%Y-%m-%d %H:%M:%S}] {msg}", flush=True)


def load_config(path):
    """加载并校验 JSON 配置, 返回 dict。"""
    if not os.path.isfile(path):
        raise FileNotFoundError(f"配置文件不存在: {path}")
    with open(path, "r", encoding="utf-8") as f:
        cfg = json.load(f)
    missing = [k for k in REQUIRED_KEYS if not cfg.get(k)]
    if missing:
        raise ValueError(f"配置缺少必填字段: {', '.join(missing)}")
    cfg["port"] = int(cfg["port"])
    return cfg


def init_thick_mode():
    """启用 Thick 模式 (Oracle 11g 必需), 依赖镜像内的 Instant Client 19。"""
    lib_dir = os.environ.get("ORACLE_HOME") or None
    # init_oracle_client 仅在 Thick 模式初始化成功时返回, 失败会直接抛异常
    oracledb.init_oracle_client(lib_dir=lib_dir)
    log("Thick 模式初始化成功 (Instant Client: %s)" % (lib_dir or "默认路径"))


def convert_value(value):
    """将 Oracle 返回值转换为可写入 Excel 的 Python 类型。"""
    if value is None:
        return None
    # CLOB / BLOB / NCLOB / BFILE 等 LOB 对象: 读取后按内容类型转换
    if hasattr(value, "read"):
        value = value.read()
    if isinstance(value, bytes):
        return value.hex()
    if isinstance(value, str):
        # 清理 xlsx 不允许的控制字符
        return _XLSX_ILLEGAL_CHARS.sub("", value)
    if isinstance(value, datetime) and value.tzinfo is not None:
        # Excel 不支持带时区的时间 (TIMESTAMP WITH TIME ZONE), 保留原字面时间
        return value.replace(tzinfo=None)
    # int/float/str/date/timedelta 原样写入, openpyxl 均支持
    return value


def export(cfg):
    """连接数据库, 执行 SQL, 将结果写入 Excel。"""
    log(f"连接数据库 {cfg['host']}:{cfg['port']}/{cfg['service_name']} ...")
    with oracledb.connect(
        user=cfg["user"],
        password=cfg["password"],
        host=cfg["host"],
        port=cfg["port"],
        service_name=cfg["service_name"],
    ) as conn:
        log("数据库连接成功")
        with conn.cursor() as cursor:
            # Oracle 不接受 SQL 末尾的分号 (ORA-00911), 去掉以防配置里误带
            sql = cfg["sql"].strip().rstrip(";").rstrip()
            log(f"执行 SQL: {sql}")
            cursor.execute(sql)
            if cursor.description is None:
                raise ValueError("SQL 不是查询语句 (无结果集), 请检查配置中的 sql")

            columns = [d[0] for d in cursor.description]

            output = cfg["output"]
            out_dir = os.path.dirname(output)
            if out_dir:
                os.makedirs(out_dir, exist_ok=True)

            wb = Workbook(write_only=True)
            ws = wb.create_sheet("data")
            ws.append(columns)

            total = 0
            while True:
                rows = cursor.fetchmany(5000)
                if not rows:
                    break
                for row in rows:
                    total += 1
                    if total > EXCEL_MAX_DATA_ROWS:
                        raise RuntimeError(
                            f"结果集超过 Excel 单 sheet 上限 {EXCEL_MAX_DATA_ROWS + 1} 行, "
                            "请修改 SQL 缩小结果集"
                        )
                    ws.append([convert_value(v) for v in row])

            wb.save(output)
            log(f"导出完成: {total} 行 x {len(columns)} 列 -> {output}")


def main():
    cfg_path = sys.argv[1] if len(sys.argv) > 1 else "/app/oracle_conn.json"
    try:
        cfg = load_config(cfg_path)
        init_thick_mode()
        export(cfg)
    except Exception as e:
        log(f"导出失败: {e}")
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
