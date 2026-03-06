#!/bin/bash

# Gost-Panel Lite 版本升級與資料表補齊腳本

echo "========================================================="
echo "  Gost-Panel Lite 版平滑升級工具 (SQLite 後端 + Nginx 前端)"
echo "========================================================="
echo ""

# 檢查是否在 gost-panel 目錄或具有 docker-compose-lite.yml
if [ ! -f "docker-compose-lite.yml" ] && [ ! -f "docker-compose-v4.yml" ]; then
    echo "錯誤：當前目錄下找不到 docker-compose-lite.yml 或 docker-compose-v4.yml。"
    echo "請切換至 gost-panel 安裝目錄後執行此腳本。"
    exit 1
fi

echo ">> 步驟 1：更新最新 Lite 版後端 Docker 映像檔..."
# 根據常見命名拉取最新版 Lite 後端映像檔
docker pull kofttlcc/gost-panel:latest-lite

echo ">> 步驟 2：停止運行中的容器..."
if [ -f "docker-compose-lite.yml" ]; then
    docker-compose -f docker-compose-lite.yml down
else
    # 兼容混合 v4 的配置
    docker-compose -f docker-compose-v4.yml down
fi

echo ">> 步驟 3：自動補齊 SQLite 缺少的延遲測試資料庫表結構..."
# 檢查 SQLite 資料庫檔案是否存在
DB_FILE="./data/gost.db"
if [ ! -f "$DB_FILE" ]; then
    # 嘗試尋找默認掛載路徑
    DB_FILE="$(pwd)/data/gost.db"
fi

if [ -f "$DB_FILE" ]; then
    echo "找到 SQLite 資料庫文件: $DB_FILE"
    echo "正在注入 delay_test_source 與 node_delay_log 表結構..."
    
    # 注入新的建表 SQL 語句
    sqlite3 "$DB_FILE" <<SQL_EOF
CREATE TABLE IF NOT EXISTS delay_test_source (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(255) NOT NULL,
    host VARCHAR(255) NOT NULL,
    protocol VARCHAR(50) NOT NULL,
    port INTEGER,
    node_id VARCHAR(50),
    created_time INTEGER NOT NULL,
    updated_time INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS node_delay_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    node_id VARCHAR(50) NOT NULL,
    source_id INTEGER NOT NULL,
    delay_ms INTEGER,
    status VARCHAR(50) NOT NULL,
    created_time INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_delay_test_source_name ON delay_test_source(name);
CREATE INDEX IF NOT EXISTS idx_node_delay_log_node_id ON node_delay_log(node_id);
CREATE INDEX IF NOT EXISTS idx_node_delay_log_source_id ON node_delay_log(source_id);
CREATE INDEX IF NOT EXISTS idx_node_delay_log_created_time ON node_delay_log(created_time);
SQL_EOF
    
    if [ $? -eq 0 ]; then
        echo "資料表創建/更新成功！"
    else
        echo "警告：資料表更新可能出現問題，請手動確認 SQLite $DB_FILE。"
    fi
else
    echo "警告：未找到 SQLite 資料庫文件 ($DB_FILE)，請確認您的資料庫掛載路徑。"
fi

echo ">> 步驟 4：重新啟動 Lite 後端容器..."
if [ -f "docker-compose-lite.yml" ]; then
    docker-compose -f docker-compose-lite.yml up -d
else
    # 在 quick_start 中預設使用 v4 啟動 backend-springboot-lite
    docker-compose -f docker-compose-v4.yml up -d backend-springboot-lite
fi

echo ">> 步驟 5：更新前端靜態檔案面板..."
echo "正在下載最新的前端靜態檔..."
wget -qO frontend.tar.gz https://github.com/kofttlcc/gost-panel/releases/latest/download/frontend.tar.gz
if [ $? -eq 0 ]; then
    # 備份舊版前端
    if [ -d "./frontend" ]; then
        echo "備份舊版前端到 frontend_backup_$(date +%Y%m%d%H%M%S)..."
        mv ./frontend ./frontend_backup_$(date +%Y%m%d%H%M%S)
    fi
    # 解壓縮新版前端
    mkdir -p ./frontend
    tar -xzf frontend.tar.gz -C ./frontend
    # 移除壓縮檔
    rm frontend.tar.gz
    echo "前端更新完成！"
else
    echo "錯誤：前端靜態檔下載失敗，請手動從 GitHub Release 頁面下載 frontend.tar.gz 覆蓋至 frontend 目錄。"
fi

echo ""
echo "========================================================="
echo "  升級完成！"
echo "  1. 後端 Lite 版 Docker 容器已經使用最新版本重新啟動。"
echo "  2. SQLite 資料庫的「延遲測試」新資料表結構已經自動補齊。"
echo "  3. 前端靜態資源已下載並解壓至 ./frontend 目錄。"
echo "  4. 由於您使用 Nginx 進行反代，Nginx 將會自動讀取最新的 html/js 檔案。"
echo "  "
echo "  若前端出現異常，請嘗試在瀏覽器清除快取或強制刷新 (Ctrl+F5/Cmd+Shift+R)。"
echo "========================================================="
