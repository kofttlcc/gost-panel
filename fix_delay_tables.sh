#!/bin/bash
# 延遲監控表自動檢測與建立腳本
# 用法: bash fix_delay_tables.sh [SQLite DB 路径]
# 預設路徑: /opt/gost-panel/data/gost.db

DB_PATH="${1:-/opt/gost-panel/data/gost.db}"

echo "=============================="
echo "延遲監控表檢測腳本"
echo "=============================="
echo "📁 資料庫路徑: $DB_PATH"

# 檢查 sqlite3 是否可用
if ! command -v sqlite3 &> /dev/null; then
    echo "❌ sqlite3 未安裝，嘗試在 Docker 容器內執行..."
    CONTAINER=$(docker ps --format '{{.Names}}' | grep -i backend | head -1)
    if [ -z "$CONTAINER" ]; then
        echo "❌ 找不到後端容器，請手動安裝 sqlite3 或指定容器名稱"
        exit 1
    fi
    echo "📦 使用容器: $CONTAINER"
    EXEC_CMD="docker exec $CONTAINER sqlite3 /app/data/gost.db"
else
    if [ ! -f "$DB_PATH" ]; then
        echo "❌ 資料庫檔案不存在: $DB_PATH"
        echo "請指定正確路徑: bash fix_delay_tables.sh /your/path/gost.db"
        exit 1
    fi
    EXEC_CMD="sqlite3 $DB_PATH"
fi

echo ""
echo "🔍 檢查現有表..."
TABLES=$($EXEC_CMD ".tables" 2>&1)
echo "   現有表: $TABLES"
echo ""

# === 檢查 delay_test_source 表 ===
if echo "$TABLES" | grep -q "delay_test_source"; then
    echo "✅ delay_test_source 表已存在"
    COLS=$($EXEC_CMD "PRAGMA table_info(delay_test_source);" 2>&1)
    echo "   欄位: $(echo "$COLS" | awk -F'|' '{printf $2" "}')"
else
    echo "⚠️  delay_test_source 表不存在，正在建立..."
    $EXEC_CMD "CREATE TABLE IF NOT EXISTS \"delay_test_source\" (
      \"id\" INTEGER PRIMARY KEY AUTOINCREMENT,
      \"node_id\" INTEGER DEFAULT 0,
      \"name\" TEXT NOT NULL,
      \"host\" TEXT NOT NULL,
      \"protocol\" TEXT NOT NULL DEFAULT 'TCPING',
      \"port\" INTEGER NOT NULL DEFAULT 443,
      \"created_time\" INTEGER DEFAULT NULL,
      \"updated_time\" INTEGER DEFAULT NULL
    );"
    if [ $? -eq 0 ]; then
        echo "✅ delay_test_source 表建立成功"
    else
        echo "❌ delay_test_source 表建立失敗"
    fi
fi

echo ""

# === 檢查 node_delay_log 表 ===
if echo "$TABLES" | grep -q "node_delay_log"; then
    echo "✅ node_delay_log 表已存在"
    COLS=$($EXEC_CMD "PRAGMA table_info(node_delay_log);" 2>&1)
    echo "   欄位: $(echo "$COLS" | awk -F'|' '{printf $2" "}')"
    
    # 檢查是否有 latency 欄位
    if ! echo "$COLS" | grep -q "latency"; then
        echo "⚠️  缺少 latency 欄位！正在刪除舊表並重建..."
        $EXEC_CMD "DROP TABLE IF EXISTS node_delay_log;"
        $EXEC_CMD "CREATE TABLE \"node_delay_log\" (
          \"id\" INTEGER PRIMARY KEY AUTOINCREMENT,
          \"node_id\" INTEGER NOT NULL,
          \"source_id\" INTEGER NOT NULL,
          \"latency\" REAL NOT NULL DEFAULT 0,
          \"success\" INTEGER NOT NULL DEFAULT 0,
          \"error_msg\" TEXT DEFAULT NULL,
          \"created_time\" INTEGER NOT NULL
        );"
        echo "✅ node_delay_log 表已重建（含 latency 欄位）"
    fi
else
    echo "⚠️  node_delay_log 表不存在，正在建立..."
    $EXEC_CMD "CREATE TABLE IF NOT EXISTS \"node_delay_log\" (
      \"id\" INTEGER PRIMARY KEY AUTOINCREMENT,
      \"node_id\" INTEGER NOT NULL,
      \"source_id\" INTEGER NOT NULL,
      \"latency\" REAL NOT NULL DEFAULT 0,
      \"success\" INTEGER NOT NULL DEFAULT 0,
      \"error_msg\" TEXT DEFAULT NULL,
      \"created_time\" INTEGER NOT NULL
    );"
    if [ $? -eq 0 ]; then
        echo "✅ node_delay_log 表建立成功"
    else
        echo "❌ node_delay_log 表建立失敗"
    fi
fi

# === 建立索引 ===
echo ""
echo "🔧 建立索引..."
$EXEC_CMD "CREATE INDEX IF NOT EXISTS \"idx_delay_log_node_time\" ON \"node_delay_log\" (\"node_id\", \"created_time\");" 2>/dev/null
$EXEC_CMD "CREATE INDEX IF NOT EXISTS \"idx_delay_log_source\" ON \"node_delay_log\" (\"source_id\");" 2>/dev/null
echo "✅ 索引已建立"

# === 驗證 ===
echo ""
echo "=============================="
echo "📊 最終驗證"
echo "=============================="
echo "delay_test_source 記錄數: $($EXEC_CMD "SELECT COUNT(*) FROM delay_test_source;" 2>&1)"
echo "node_delay_log 記錄數:   $($EXEC_CMD "SELECT COUNT(*) FROM node_delay_log;" 2>&1)"
echo ""
echo "✅ 完成！如果後端容器正在運行，無需重啟，下次查詢即生效。"
