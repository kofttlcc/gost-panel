#!/bin/bash
# ============================================================
# MySQL → SQLite 資料遷移腳本
# 用途：將 MySQL 中的面板資料（節點、隧道、轉發等）遷移至 SQLite
# 用法：bash migrate_mysql_to_sqlite.sh
# ============================================================

# ========== 配置區（請根據實際環境修改）==========
MYSQL_HOST="${DB_HOST:-172.17.0.1}"
MYSQL_USER="${DB_USER:-root}"
MYSQL_PASS="${DB_PASSWORD:-}"
MYSQL_DB="${DB_NAME:-gost}"
SQLITE_DB="${1:-/tmp/gost.db}"
# ================================================

TABLES="node tunnel forward user user_tunnel speed_limit statistics_flow vite_config"

# 檢查必要工具
command -v mysqldump >/dev/null 2>&1 || { echo "錯誤: 需要安裝 mysqldump"; echo "  apt-get install -y default-mysql-client"; exit 1; }
command -v sqlite3 >/dev/null 2>&1 || { echo "錯誤: 需要安裝 sqlite3"; echo "  apt-get install -y sqlite3"; exit 1; }

# 如果已存在舊的 SQLite 檔案，備份它
if [ -f "$SQLITE_DB" ]; then
    BACKUP="${SQLITE_DB}.bak.$(date +%s)"
    echo "⚠ 已存在 SQLite 資料庫，備份至: $BACKUP"
    cp "$SQLITE_DB" "$BACKUP"
    rm -f "$SQLITE_DB"
fi

echo "=========================================="
echo "  MySQL → SQLite 資料遷移工具"
echo "=========================================="
echo "MySQL: ${MYSQL_USER}@${MYSQL_HOST}/${MYSQL_DB}"
echo "SQLite: ${SQLITE_DB}"
echo ""

# ========== 步驟 1: 建立 SQLite 表結構 ==========
echo "=== 步驟 1/3: 建立 SQLite 表結構 ==="

sqlite3 "$SQLITE_DB" << 'SCHEMA_EOF'
CREATE TABLE IF NOT EXISTS "forward" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "user_id" INTEGER NOT NULL,
  "user_name" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "tunnel_id" INTEGER NOT NULL,
  "in_port" INTEGER NOT NULL,
  "out_port" INTEGER DEFAULT NULL,
  "remote_addr" TEXT NOT NULL,
  "strategy" TEXT NOT NULL DEFAULT 'fifo',
  "interface_name" TEXT DEFAULT NULL,
  "in_flow" INTEGER NOT NULL DEFAULT 0,
  "out_flow" INTEGER NOT NULL DEFAULT 0,
  "created_time" INTEGER NOT NULL,
  "updated_time" INTEGER NOT NULL,
  "status" INTEGER NOT NULL,
  "inx" INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS "node" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "name" TEXT NOT NULL,
  "secret" TEXT NOT NULL,
  "ip" TEXT,
  "server_ip" TEXT NOT NULL,
  "port_sta" INTEGER NOT NULL,
  "port_end" INTEGER NOT NULL,
  "version" TEXT DEFAULT NULL,
  "http" INTEGER NOT NULL DEFAULT 0,
  "tls" INTEGER NOT NULL DEFAULT 0,
  "socks" INTEGER NOT NULL DEFAULT 0,
  "created_time" INTEGER NOT NULL,
  "updated_time" INTEGER DEFAULT NULL,
  "status" INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS "speed_limit" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "name" TEXT NOT NULL,
  "speed" INTEGER NOT NULL,
  "tunnel_id" INTEGER NOT NULL,
  "tunnel_name" TEXT NOT NULL,
  "created_time" INTEGER NOT NULL,
  "updated_time" INTEGER DEFAULT NULL,
  "status" INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS "statistics_flow" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "user_id" INTEGER NOT NULL,
  "flow" INTEGER NOT NULL,
  "total_flow" INTEGER NOT NULL,
  "time" TEXT NOT NULL,
  "created_time" INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS "tunnel" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "name" TEXT NOT NULL,
  "traffic_ratio" REAL NOT NULL DEFAULT 1.0,
  "in_node_id" INTEGER NOT NULL,
  "in_ip" TEXT NOT NULL,
  "out_node_id" INTEGER NOT NULL,
  "out_ip" TEXT NOT NULL,
  "type" INTEGER NOT NULL,
  "protocol" TEXT NOT NULL DEFAULT 'tls',
  "flow" INTEGER NOT NULL,
  "tcp_listen_addr" TEXT NOT NULL DEFAULT '[::]',
  "udp_listen_addr" TEXT NOT NULL DEFAULT '[::]',
  "interface_name" TEXT DEFAULT NULL,
  "created_time" INTEGER NOT NULL,
  "updated_time" INTEGER NOT NULL,
  "status" INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS "user" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "user" TEXT NOT NULL,
  "pwd" TEXT NOT NULL,
  "role_id" INTEGER NOT NULL,
  "exp_time" INTEGER NOT NULL,
  "flow" INTEGER NOT NULL,
  "in_flow" INTEGER NOT NULL DEFAULT 0,
  "out_flow" INTEGER NOT NULL DEFAULT 0,
  "flow_reset_time" INTEGER NOT NULL,
  "num" INTEGER NOT NULL,
  "created_time" INTEGER NOT NULL,
  "updated_time" INTEGER DEFAULT NULL,
  "status" INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS "user_tunnel" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "user_id" INTEGER NOT NULL,
  "tunnel_id" INTEGER NOT NULL,
  "speed_id" INTEGER DEFAULT NULL,
  "num" INTEGER NOT NULL,
  "flow" INTEGER NOT NULL,
  "in_flow" INTEGER NOT NULL DEFAULT 0,
  "out_flow" INTEGER NOT NULL DEFAULT 0,
  "flow_reset_time" INTEGER NOT NULL,
  "exp_time" INTEGER NOT NULL,
  "status" INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS "vite_config" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "name" TEXT NOT NULL UNIQUE,
  "value" TEXT NOT NULL,
  "time" INTEGER NOT NULL
);
SCHEMA_EOF

echo "  ✓ 表結構建立完成"
echo ""

# ========== 步驟 2: 從 MySQL 匯出並匯入 SQLite ==========
echo "=== 步驟 2/3: 遷移資料 ==="

FAIL=0
for TABLE in $TABLES; do
    printf "  遷移 %-20s ... " "$TABLE"

    # 從 MySQL 匯出為相容格式
    DUMP=$(mysqldump -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" \
        --no-create-info --compact --compatible=ansi \
        --skip-extended-insert --complete-insert \
        "$MYSQL_DB" "$TABLE" 2>/dev/null)

    if [ $? -ne 0 ]; then
        echo "✗ 匯出失敗"
        FAIL=1
        continue
    fi

    # 清理 MySQL 專屬語法並匯入 SQLite
    echo "$DUMP" | \
        sed 's/`/"/g' | \
        sed '/^\/\*/d' | \
        sed '/^--/d' | \
        sed '/^SET /d' | \
        sed '/^LOCK /d' | \
        sed '/^UNLOCK /d' | \
        sed '/^$/d' | \
        sqlite3 "$SQLITE_DB" 2>/dev/null

    COUNT=$(sqlite3 "$SQLITE_DB" "SELECT COUNT(*) FROM \"$TABLE\";")
    echo "✓ $COUNT 條記錄"
done

echo ""

# ========== 步驟 3: 驗證 ==========
echo "=== 步驟 3/3: 驗證結果 ==="
echo ""
echo "  表名                    記錄數"
echo "  ─────────────────────  ──────"
for TABLE in $TABLES; do
    COUNT=$(sqlite3 "$SQLITE_DB" "SELECT COUNT(*) FROM \"$TABLE\";")
    printf "  %-22s  %s\n" "$TABLE" "$COUNT"
done

DB_SIZE=$(du -h "$SQLITE_DB" | cut -f1)
echo ""
echo "  SQLite 檔案大小: $DB_SIZE"
echo ""

if [ $FAIL -eq 0 ]; then
    echo "=========================================="
    echo "  ✓ 遷移成功！"
    echo "=========================================="
    echo ""
    echo "下一步 - 將資料庫複製到 lite 容器："
    echo ""
    echo "  # 複製到容器"
    echo "  docker cp $SQLITE_DB springboot-backend-lite:/app/data/gost.db"
    echo "  docker restart springboot-backend-lite"
    echo ""
    echo "  # 或者直接複製到 Docker volume 目錄"
    echo "  docker volume inspect backend_lite_data --format '{{.Mountpoint}}'"
    echo "  # 然後 cp $SQLITE_DB <volume_mountpoint>/gost.db"
else
    echo "=========================================="
    echo "  ⚠ 部分表遷移失敗，請檢查 MySQL 連接資訊"
    echo "=========================================="
fi
