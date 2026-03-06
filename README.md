# gost-panel 轉發面板

本專案基於 [go-gost/gost](https://github.com/go-gost/gost) 和 [go-gost/x](https://github.com/go-gost/x) 兩個開源庫，實現了轉發面板。

---

## ✨ 最新特性 (Phase 8)

- **輕量化架構**：全新推出 SQLite 輕量版（Lite），後端記憶體佔用極低 (~150MB)，無需外掛 MySQL，適合小雞部署。
- **PWA 輕應用支援**：前端面板支援 PWA，可直接「加到主畫面」成為桌面/手機端獨立 App，體驗流暢。
- **延遲監控儀表板**：內建 TCP/ICMP 節點延遲定時測試與可視化折線圖（1H/4H/24H/1W 維度切換）。
- **配額與限速管理**：支持按 **隧道帳號級別** 管理流量轉發數量；支持 **指定使用者的指定隧道進行限速**。
- **強大轉發能力**：支持 **TCP** 和 **UDP** 轉發，提供 **端口轉發** 與 **隧道轉發** 兩種模式。
- **靈活計費**：支持配置單向或雙向流量計費方式。

---

## 🏗 系統架構概述

面板由以下元件組成，根據您的環境可靈活搭配：

| 元件 | 說明 | 狀態 |
|------|------|----------|
| **Backend** (Spring Boot) | 後端 API 服務，分為 Lite (SQLite) 與 Standard (MySQL) | ✅ 必須 |
| **Frontend** (Vite/React) | 前端流暢管理介面，完全支援 PWA | ✅ 必須 |
| **資料庫** | 推薦使用內建 SQLite（免配置）；或沿用現有 MySQL | ✅ 必須 |
| **Nginx** | 反向代理 & 靜態檔案伺服器 | ❌ 選用 |

> 💡 **核心推薦**：極力推薦使用 **SQLite 輕量版 (Lite)**。它剝離了對外部 MySQL 的依賴，開箱即用，資源消耗極小。

---

## 🚀 全新安裝指南 (推薦：SQLite 輕量版)

如果您是新用戶或希望部署在小記憶體 VPS 上，請使用 Lite 輕量版本。只需 Docker 環境即可一鍵部署。

### 步驟 1：建立目錄與設定檔

```bash
mkdir -p /opt/gost-panel/data
cd /opt/gost-panel

# 生成隨機 JWT 密鑰
JWT_SECRET=$(openssl rand -hex 32)
echo "JWT_SECRET=${JWT_SECRET}" > .env
```

### 步驟 2：下載 Compose 設定並啟動

```bash
# 下載 SQLite 專用 docker-compose 配置
wget https://raw.githubusercontent.com/kofttlcc/gost-panel/main/docker-compose-lite.yml

# 啟動容器
docker compose -f docker-compose-lite.yml up -d
```

### 步驟 3：訪問面板

- 面板位址：`http://伺服器IP:80`
- API 位址：`http://伺服器IP:6365`（前端會自動連線）
- 預設帳號：`admin_user`
- 預設密碼：`admin_user`

> ⚠️ **安全警告：請於首次登入後，立刻前往設定修改預設密碼！**

---

## 🔄 舊版本升級指南 (MySQL 遷移至 SQLite)

如果您之前使用 `quick_start.sh` 或手動部署了 MySQL 版本的 Gost-Panel，強烈建議您升級到 SQLite 輕量版，以獲得更低的資源佔用與最新的 PWA / 延遲監控功能。

### 💡 情境 A：升級現有的 Lite 版 (包含 SQLite 資料庫升級 + Nginx 前端)
若您**已經**在使用輕量版 (`docker-compose-lite.yml`)，且前端是直接用 Nginx 代理 `./frontend` 靜態目錄：
1. **下載平滑升級腳本並執行**：
   此腳本會拉取最新的 docker 映像檔、自動補齊延遲測試所需的新資料表，並更新前端目錄。
   ```bash
   wget -qO upgrade_lite.sh https://raw.githubusercontent.com/kofttlcc/gost-panel/main/upgrade_lite.sh && chmod +x upgrade_lite.sh
   ./upgrade_lite.sh
   ```
2. **重整快取**：
   更新完成後，請於瀏覽器按下 `Ctrl + F5` 或 `Cmd + Shift + R` 以便載入最新的 PWA 前端頁面。

---

### 💡 情境 B：從舊版 MySQL 遷移至 SQLite 輕量版
我們提供了自動化遷移腳本，可將舊版 MySQL 資料完整轉移至 SQLite。

### 步驟 1：下載遷移腳本

```bash
mkdir -p /opt/gost-panel/data
cd /opt/gost-panel
wget https://raw.githubusercontent.com/kofttlcc/gost-panel/main/springboot-backend-lite/migrate_mysql_to_sqlite.sh
```

### 步驟 2：編輯遷移腳本填寫密碼

打開腳本並填寫您目前的 MySQL 連線資訊：
```bash
nano migrate_mysql_to_sqlite.sh
```
找到檔案上方的配置區，填入真實資訊：
```bash
MYSQL_CONTAINER="您的MySQL容器名稱" # (若用外部MySQL，腳本需稍作修改)
MYSQL_USER="root"
MYSQL_PASS="您的MySQL密碼"
MYSQL_DB="舊版資料庫名稱"
```

### 步驟 3：執行遷移

```bash
# 注意：這需要先安裝 sqlite3 (apt-get update && apt-get install -y sqlite3)
bash migrate_mysql_to_sqlite.sh /opt/gost-panel/data/gost.db
```
*腳本會自動將表結構與數據從 MySQL 匯出並匯入到指定的 `/opt/gost-panel/data/gost.db` 中。*

### 步驟 4：切換為 Lite 容器啟動

停止並刪除舊的容器（舊版 backend / frontend）：
```bash
docker compose down
```

下載 Lite 版本的 Docker Compose 檔案並啟動：
```bash
wget https://raw.githubusercontent.com/kofttlcc/gost-panel/main/docker-compose-lite.yml
# 確保 .env 檔案中的 JWT_SECRET 存在且正確（可延用舊的）
docker compose -f docker-compose-lite.yml up -d
```

---

## 🏢 舊版安裝保留 (MySQL 版本)

如果您的伺服器上已經有現成的 MySQL 與 Nginx (如寶塔/1Panel)，且仍堅持使用 MySQL 作為儲存，可以使用一鍵啟動腳本部署標準版。

```bash
# 包含雙容器模式 與 後端容器+前端靜態檔案模式
curl -fsSL https://raw.githubusercontent.com/kofttlcc/gost-panel/main/quick_start.sh -o quick_start.sh && sudo bash quick_start.sh
```

> **MySQL 部署注意**：部署前請確定已經在 MySQL 中新建了對應的 DataBase 並匯入了 `gost.sql` 初始化檔案。

---

## 🛠 Nginx 反向代理 (可選)

如果您希望設定網域並啟用 HTTPS，或者隱藏預設的 80/6365 埠，可以透過 Nginx 反向代理。

反向代理的核心配置如下：

```nginx
    # 主頁面 (前端靜態檔或容器轉發)
    location / {
        proxy_pass http://127.0.0.1:80; # 如果 frontend 是容器，指向 80
        proxy_set_header Host $host;
    }

    # API 請求反代至後端
    location ^~ /api/v1/ {
        proxy_pass http://127.0.0.1:6365/api/v1/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 節點流量/延遲配置下發/上報
    location /flow/ {
        proxy_pass http://127.0.0.1:6365/flow/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # WebSocket 系統資訊監控
    location /system-info {
        proxy_pass http://127.0.0.1:6365/system-info;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
```

---

## ⚠️ 免責聲明

本專案僅供個人學習與研究使用，基於開源專案進行二次開發。

使用本專案所帶來的任何風險均由使用者自行承擔，包括但不限於：
- 配置不當或使用錯誤導致的服務異常或不可用；
- 使用本專案引發的網路攻擊、封禁、濫用等行為；
- 伺服器因使用本專案被入侵、滲透、濫用導致的資料洩露、資源消耗或損失；
- 因違反當地法律法規所產生的任何法律責任。

本專案為開源的流量轉發工具，僅限合法、合規用途。使用者必須確保其使用行為符合所在國家或地區的法律法規。**作者不對因使用本專案導致的任何法律責任、經濟損失或其他後果承擔責任。禁止將本專案用於任何違法或未經授權的行為。** 如不同意上述條款，請立即停止使用本專案。
