# gost-panel 轉發面板

本專案基於 [go-gost/gost](https://github.com/go-gost/gost) 和 [go-gost/x](https://github.com/go-gost/x) 兩個開源庫，實現了轉發面板。

---

## 特性

- 支持按 **隧道帳號級別** 管理流量轉發數量，可用於使用者/隧道配額控制
- 支持 **TCP** 和 **UDP** 協議的轉發
- 支持兩種轉發模式：**端口轉發** 與 **隧道轉發**
- 可針對 **指定使用者的指定隧道進行限速** 設定
- 支持配置 **單向或雙向流量計費方式**，靈活適配不同計費模型
- 提供多種轉發策略配置，適用於各類網路場景

---

## 系統架構概述

面板由以下元件組成，根據您的環境可靈活搭配：

| 元件 | 說明 | 是否必須 |
|------|------|----------|
| **Backend** (Spring Boot) | 後端 API 服務，預設監聽 `6365` 埠 | ✅ 必須 |
| **Frontend** (Vite/React) | 前端管理介面，預設監聽 `6366` 埠 | ✅ 必須 (靜態檔案或容器) |
| **MySQL** | 資料庫，存放使用者、節點、轉發規則等資料 | ✅ 必須 (可使用既有的) |
| **Nginx** | 反向代理 & 靜態檔案伺服器 | ❌ 選用 (可使用既有的) |

> 💡 **核心理念**：新版面板 **不內建 MySQL 和 Nginx**，減少容器數量與潛在衝突。您可以直接使用伺服器上既有的 MySQL 與 Nginx/OpenResty，也可以透過面板內建容器一站式快速啟動服務。

---

## 部署流程

### ⚠️ 部署前必讀：資料庫準備

因安全考量，面板不再內建 MySQL 容器，後端將直接連線至伺服器上現有的 MySQL。

**在部署前，請完成以下操作：**

1. 通過您的管理面板（如 aaPanel / 1Panel / 寶塔等）或命令行在伺服器上建立一個全新的 MySQL Database，並建立擁有完整權限的「帳號」與「密碼」。
2. 從本專案取得 [`gost.sql`](gost.sql) 並匯入到該資料庫：
   ```bash
   # 方法一：命令行匯入
   mysql -u 使用者名 -p 資料庫名 < gost.sql

   # 方法二：透過 phpMyAdmin 或面板自帶的匯入功能
   ```

> 📌 如果您的伺服器上已有 MySQL（透過 aaPanel 等安裝），您 **不需要額外安裝** 任何資料庫，直接利用既有的即可。

---

### 方式一：一鍵免編譯部署（推薦）

直接拉取預編譯好的 Docker 鏡像，無需在伺服器上編譯。提供兩種模式可選：

```bash
curl -fsSL https://raw.githubusercontent.com/kofttlcc/gost-panel/main/quick_start.sh -o quick_start.sh && sudo bash quick_start.sh
```

#### 模式 A：雙容器模式（推薦新手）

拉取 Backend + Frontend 兩個 Docker 容器，全由 Docker 管理，無需自備 Nginx。

- 適合：全新伺服器、不想配置 Nginx 的使用者
- 啟動後直接訪問 `http://伺服器IP:6366`

#### 模式 B：後端容器 + 前端靜態檔案（適合已有 Nginx/OpenResty）

只拉取後端 Docker 容器，前端靜態檔案由腳本自動提取到您指定的目錄，由您的宿主機 Nginx / OpenResty 進行託管。

- 適合：已有 **1Panel + OpenResty**、**寶塔面板**、或原生 Nginx 的伺服器
- 腳本會自動偵測伺服器環境（1Panel / 寶塔 / 通用），並輸出對應的 Nginx 配置指引
- **不會自動寫入任何 Nginx 配置目錄**，避免與現有網站衝突
- 完整的反代配置檔會生成到 `/opt/gost-panel/nginx-gost-panel.conf`，供您手動複製使用

> 💡 **兩種模式的共通特性：**
> - 互動式配置 `.env`（MySQL 連線、埠號、JWT 密鑰自動生成）
> - 自動輸出建庫 SQL 語句方便複製執行
> - 預設管理員帳號 `admin_user` / 密碼 `admin_user`，首次登入後請立即修改

---

### 方式一（舊版）：一鍵腳本部署

> ⚠️ 此腳本為舊版，建議使用上方的 `quick_start.sh` 替代。

```bash
curl -sSL https://github.com/kofttlcc/gost-panel/releases/download/latest/panel_install.sh -o panel_install.sh && bash panel_install.sh
```

---

### 方式二：原始碼自編譯部署（推薦進階用戶）

此方式會在您的伺服器上從原始碼編譯 Docker 映像，適合需要自訂修改或不信任第三方預編譯映像的情境。

#### 1. 克隆專案

```bash
git clone https://github.com/kofttlcc/gost-panel.git
cd gost-panel
```

#### 2. 設定環境變數

```bash
cp .env.example .env
nano .env   # 或使用 vim 等編輯器
```

`.env` 檔案範例如下：

```env
# 資料庫連線（填入您在 MySQL 手動建好的資訊）
DB_HOST=172.17.0.1     # Docker 預設橋接 IP，指向宿主機上的 MySQL
DB_PORT=3306
DB_NAME=your_database_name
DB_USER=your_database_user
DB_PASSWORD=your_database_password

# 安全密鑰（務必改成隨機亂碼）
JWT_SECRET=your_random_jwt_secret_string

# 面板埠號
FRONTEND_PORT=6366
BACKEND_PORT=6365
```

> 💡 **`DB_HOST` 填寫說明：**
> - MySQL 裝在**同一台伺服器** → 填 `172.17.0.1`（Docker 預設橋接網路透過此 IP 訪問宿主機）
> - MySQL 裝在**遠端伺服器** → 填遠端伺服器的公網 IP 或內網 IP
> - 千萬 **不要填 `localhost` 或 `127.0.0.1`**，因為容器內的 `127.0.0.1` 指的是容器自身，無法訪問到宿主機

#### 3. 編譯與啟動

根據您伺服器上是否已有 Nginx / OpenResty，選擇以下其中一種方式：

---

##### 場景 A：伺服器上 **沒有** Nginx（全新機器）

使用 `--profile nginx` 參數，同時啟動 Backend 容器與一個自帶的 Nginx 前端容器：

```bash
docker compose -f docker-compose-build.yml --profile nginx up --build -d
```

部署完成後，透過 `http://伺服器IP:6366` 即可訪問面板。

---

##### 場景 B：伺服器上 **已有** Nginx / OpenResty（如 1Panel、aaPanel、寶塔）

此場景下**僅啟動 Backend 容器**，前端交由您既有的 Nginx 處理：

**步驟 1 — 啟動後端**

```bash
docker compose -f docker-compose-build.yml up --build -d
```

> 此命令不帶 `--profile nginx`，因此**只會啟動 Backend**，不會啟動 Nginx 容器，避免端口衝突。

**步驟 2 — 編譯前端靜態檔案**

執行提供的腳本，將前端編譯成純靜態檔案（輸出至 `./vite-frontend/dist`）：

```bash
chmod +x build_frontend_static.sh
./build_frontend_static.sh
```

將 `dist` 資料夾的內容複製到您 Nginx 網站的根目錄（如 `/www/wwwroot/你的目錄`）。

**步驟 3 — 設定 Nginx 反向代理**

在您的 Nginx / OpenResty 網站配置中，加入以下反代規則（假設後端埠號為 `6365`）：

```nginx
server {
    listen 80;
    server_name 您的網域或IP;

    root /您的前端靜態檔案路徑;
    index index.html;

    # 前端路由（SPA 需要此設定）
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 後端 API 反向代理
    location ^~ /api/v1/ {
        proxy_pass http://127.0.0.1:6365/api/v1/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 流量上報反向代理
    location /flow/upload {
        proxy_pass http://127.0.0.1:6365/flow/upload;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /flow/config {
        proxy_pass http://127.0.0.1:6365/flow/config;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # WebSocket 反向代理
    location /system-info {
        proxy_pass http://127.0.0.1:6365/system-info;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

> 💡 **不同面板的操作指引：**
> - **1Panel + OpenResty**：進入 1Panel → 網站 → 建立靜態網站 → 設定根目錄 → 在配置中加入反代
> - **寶塔面板 / aaPanel**：網站 → 新增網站 → 修改配置文件 → 貼上反代規則
> - **原生 Nginx**：將配置寫入 `/etc/nginx/conf.d/gost-panel.conf` 後 `nginx -s reload`

---

### 默認管理員帳號

| 項目 | 值 |
|------|-----|
| 帳號 | `admin_user` |
| 密碼 | `admin_user` |

> ⚠️ **請於首次登入後立即修改預設密碼！**

---

## 常見問題

### Q：我的伺服器上已有 MySQL，需要額外安裝嗎？

**不需要。** 面板不內建 MySQL 容器。您只需在既有的 MySQL 中建立資料庫並匯入 `gost.sql`，然後在 `.env` 中填入對應連線資訊即可。

### Q：我的伺服器上已有 Nginx / OpenResty（1Panel、aaPanel、寶塔），會衝突嗎？

**不會。** 不管使用哪種部署方式：
- **一鍵免編譯（`quick_start.sh`）模式 B**：腳本不會自動寫入任何 Nginx 配置，僅生成配置檔到 `/opt/gost-panel/nginx-gost-panel.conf` 供您手動複製
- **原始碼自編譯**：不帶 `--profile nginx` 參數即不會啟動 Nginx 容器

兩種方式都不會修改您現有的 Nginx / OpenResty 配置，完全兼容 1Panel、aaPanel、寶塔等面板。

### Q：`DB_HOST` 應該填什麼？

- **MySQL 在同一台伺服器上** → 填 `172.17.0.1`（Docker 橋接網路 IP）
- **MySQL 在遠端主機** → 填該主機的 IP 位址
- ❌ 不要填 `localhost` 或 `127.0.0.1`（容器內的環回地址指向容器本身）

### Q：如何更新面板？

使用一鍵腳本安裝的使用者，重新執行腳本並選擇「更新面板」選項即可。原始碼編譯的使用者，請先拉取最新代碼後重新 build：

```bash
cd gost-panel
git pull
docker compose -f docker-compose-build.yml --profile nginx up --build -d
```

---

## 免責聲明

本專案僅供個人學習與研究使用，基於開源專案進行二次開發。

使用本專案所帶來的任何風險均由使用者自行承擔，包括但不限於：

- 配置不當或使用錯誤導致的服務異常或不可用；
- 使用本專案引發的網路攻擊、封禁、濫用等行為；
- 伺服器因使用本專案被入侵、滲透、濫用導致的資料洩露、資源消耗或損失；
- 因違反當地法律法規所產生的任何法律責任。

本專案為開源的流量轉發工具，僅限合法、合規用途。
使用者必須確保其使用行為符合所在國家或地區的法律法規。

**作者不對因使用本專案導致的任何法律責任、經濟損失或其他後果承擔責任。**
**禁止將本專案用於任何違法或未經授權的行為，包括但不限於網路攻擊、資料竊取、非法訪問等。**

如不同意上述條款，請立即停止使用本專案。

作者對因使用本專案所造成的任何直接或間接損失概不負責，亦不提供任何形式的擔保、承諾或技術支援。

請務必在合法、合規、安全的前提下使用本專案。
