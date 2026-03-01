#!/bin/bash
set -euo pipefail

# ============================================================
#  Gost Panel 一鍵啟動腳本（免編譯版）
#  適用場景：直接拉取預編譯好的 Docker 鏡像，無需在伺服器上自行編譯
#
#  選項 A：前後端雙容器模式（推薦新手使用）
#         拉取 backend + frontend 兩個容器，全由 Docker 管理
#
#  選項 B：後端容器 + 前端靜態檔案模式（適合已有 Nginx 的使用者）
#         只拉取 backend 容器，前端靜態檔案放到宿主機 Nginx
# ============================================================

export LANG=en_US.UTF-8
export LC_ALL=C

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局變數
INSTALL_DIR="/opt/gost-panel"
DOCKER_CMD=""
GITHUB_REPO="kofttlcc/gost-panel"
COMPOSE_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/docker-compose-v4.yml"
ENV_EXAMPLE_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/.env.example"
NGINX_CONF_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/vite-frontend/nginx.conf"
FRONTEND_DIST_URL="https://github.com/${GITHUB_REPO}/releases/download/latest/frontend-dist.tar.gz"

# ============ 工具函數 ============

print_banner() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║       Gost Panel 一鍵啟動（免編譯版）       ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
  echo ""
}

log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
  echo -e "${BLUE}[STEP]${NC} $1"
}

generate_random() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 12
  else
    head -c 30 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | cut -c 1-24
  fi
}

generate_jwt_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    head -c 80 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | cut -c 1-64
  fi
}

# ============ 環境檢測 ============

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log_error "請使用 root 權限運行此腳本（sudo bash quick_start.sh）"
    exit 1
  fi
}

check_docker() {
  if command -v docker-compose &>/dev/null; then
    DOCKER_CMD="docker-compose"
  elif command -v docker &>/dev/null; then
    if docker compose version &>/dev/null 2>&1; then
      DOCKER_CMD="docker compose"
    else
      log_error "偵測到 Docker，但不支援 'docker compose' 指令。請安裝 docker-compose 或更新 Docker。"
      exit 1
    fi
  else
    log_error "未偵測到 Docker。請先安裝 Docker："
    echo "  curl -fsSL https://get.docker.com | bash"
    exit 1
  fi
  log_info "偵測到 Docker 指令：${DOCKER_CMD}"
}

check_mysql() {
  echo ""
  log_warn "本面板不包含內建 MySQL，您需要提前準備好一個 MySQL 數據庫。"
  echo ""
  echo -e "  如果 MySQL 在同一台伺服器上（非 Docker 內）："
  echo -e "    DB_HOST 應填寫 ${CYAN}172.17.0.1${NC}"
  echo ""
  echo -e "  如果 MySQL 在另一台伺服器上："
  echo -e "    DB_HOST 應填寫 ${CYAN}該伺服器的 IP 位址${NC}"
  echo ""
}

# ============ .env 配置生成 ============

setup_env() {
  local env_file="${INSTALL_DIR}/.env"

  if [ -f "$env_file" ]; then
    log_info "偵測到已有 .env 檔案，是否要重新配置？[y/N]"
    read -r answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
      log_info "保留現有 .env 配置"
      return
    fi
  fi

  echo ""
  log_step "配置數據庫連線參數"
  echo ""

  echo -e -n "${CYAN}請輸入 MySQL 主機位址${NC} [預設: 172.17.0.1]: "
  read -r db_host
  db_host=${db_host:-172.17.0.1}

  echo -e -n "${CYAN}請輸入數據庫名稱${NC} [預設: gost_panel]: "
  read -r db_name
  db_name=${db_name:-gost_panel}

  echo -e -n "${CYAN}請輸入數據庫使用者名稱${NC} [預設: gost_user]: "
  read -r db_user
  db_user=${db_user:-gost_user}

  local default_db_pass
  default_db_pass=$(generate_random)
  echo -e -n "${CYAN}請輸入數據庫密碼${NC} [預設: 自動生成]: "
  read -r db_pass
  db_pass=${db_pass:-$default_db_pass}

  echo -e -n "${CYAN}請輸入後端埠號${NC} [預設: 6365]: "
  read -r backend_port
  backend_port=${backend_port:-6365}

  echo -e -n "${CYAN}請輸入前端埠號${NC} [預設: 6366]: "
  read -r frontend_port
  frontend_port=${frontend_port:-6366}

  local jwt_secret
  jwt_secret=$(generate_jwt_secret)

  cat >"$env_file" <<EOF
# Gost Panel 環境變數配置
# 由 quick_start.sh 自動生成於 $(date '+%Y-%m-%d %H:%M:%S')

# 數據庫連線設定
DB_HOST=${db_host}
DB_PORT=3306
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_pass}

# 系統安全密鑰
JWT_SECRET=${jwt_secret}

# 面板埠號
FRONTEND_PORT=${frontend_port}
BACKEND_PORT=${backend_port}
EOF

  log_info ".env 配置已生成"
  echo ""
  echo -e "  ${YELLOW}重要：請確保 MySQL 中已建立對應的數據庫和使用者：${NC}"
  echo ""
  echo -e "  ${CYAN}CREATE DATABASE IF NOT EXISTS \`${db_name}\` DEFAULT CHARACTER SET utf8mb4;${NC}"
  echo -e "  ${CYAN}CREATE USER IF NOT EXISTS '${db_user}'@'%' IDENTIFIED BY '${db_pass}';${NC}"
  echo -e "  ${CYAN}GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'%';${NC}"
  echo -e "  ${CYAN}FLUSH PRIVILEGES;${NC}"
  echo ""
}

# ============ 選項 A：雙容器模式 ============

deploy_dual_container() {
  log_step "模式 A：前後端雙容器部署"
  echo ""

  # 建立安裝目錄
  mkdir -p "$INSTALL_DIR"
  cd "$INSTALL_DIR"

  # 下載 docker-compose 檔案
  log_info "下載 docker-compose-v4.yml ..."
  curl -fsSL "$COMPOSE_URL" -o docker-compose.yml

  # 配置 .env
  check_mysql
  setup_env

  # 拉取鏡像
  log_info "拉取 Docker 鏡像..."
  $DOCKER_CMD -f docker-compose.yml pull

  # 啟動服務
  log_info "啟動服務..."
  $DOCKER_CMD -f docker-compose.yml up -d

  echo ""
  log_info "✅ 雙容器模式部署完成！"
  echo ""

  # 讀取埠號
  local frontend_port backend_port
  frontend_port=$(grep '^FRONTEND_PORT=' .env 2>/dev/null | cut -d= -f2)
  backend_port=$(grep '^BACKEND_PORT=' .env 2>/dev/null | cut -d= -f2)
  frontend_port=${frontend_port:-6366}
  backend_port=${backend_port:-6365}

  echo -e "  ${GREEN}前端面板：${NC}  http://<伺服器IP>:${frontend_port}"
  echo -e "  ${GREEN}後端 API：${NC}  http://<伺服器IP>:${backend_port}"
  echo ""
  echo -e "  ${YELLOW}預設管理員帳號：${NC}  admin_user"
  echo -e "  ${YELLOW}預設管理員密碼：${NC}  admin_user"
  echo ""
  echo -e "  ${RED}⚠ 請務必登入後立即修改預設密碼！${NC}"
  echo ""
}

# ============ 選項 B：後端容器 + 前端靜態檔案 ============

deploy_backend_only() {
  log_step "模式 B：後端容器 + 前端靜態檔案部署"
  echo ""

  # 建立安裝目錄
  mkdir -p "$INSTALL_DIR"
  cd "$INSTALL_DIR"

  # 下載 docker-compose 檔案（僅取 backend 部分）
  log_info "生成 docker-compose.yml（僅後端容器）..."
  cat >docker-compose.yml <<'COMPOSE_EOF'
services:
  backend:
    image: koftt/springboot-backend:latest
    container_name: springboot-backend
    restart: unless-stopped
    environment:
      DB_HOST: ${DB_HOST:-172.17.0.1}
      DB_NAME: ${DB_NAME}
      DB_USER: ${DB_USER}
      DB_PASSWORD: ${DB_PASSWORD}
      JWT_SECRET: ${JWT_SECRET}
      LOG_DIR: /app/logs
    ports:
      - "${BACKEND_PORT:-6365}:6365"
    volumes:
      - backend_logs:/app/logs
    healthcheck:
      test: ["CMD", "sh", "-c", "wget --no-verbose --tries=1 --spider http://localhost:6365/flow/test || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 90s

volumes:
  backend_logs:
    name: backend_logs
    driver: local
COMPOSE_EOF

  # 配置 .env
  check_mysql
  setup_env

  # 拉取後端鏡像
  log_info "拉取後端 Docker 鏡像..."
  $DOCKER_CMD -f docker-compose.yml pull

  # 啟動後端
  log_info "啟動後端服務..."
  $DOCKER_CMD -f docker-compose.yml up -d

  # 部署前端靜態檔案
  deploy_frontend_static

  echo ""
  log_info "✅ 後端容器 + 前端靜態檔案模式部署完成！"
  echo ""

  local backend_port frontend_port
  backend_port=$(grep '^BACKEND_PORT=' .env 2>/dev/null | cut -d= -f2)
  frontend_port=$(grep '^FRONTEND_PORT=' .env 2>/dev/null | cut -d= -f2)
  backend_port=${backend_port:-6365}
  frontend_port=${frontend_port:-6366}

  echo -e "  ${GREEN}前端面板：${NC}  http://<伺服器IP>:${frontend_port}"
  echo -e "  ${GREEN}後端 API：${NC}  http://<伺服器IP>:${backend_port}"
  echo ""
  echo -e "  ${YELLOW}預設管理員帳號：${NC}  admin_user"
  echo -e "  ${YELLOW}預設管理員密碼：${NC}  admin_user"
  echo ""
  echo -e "  ${RED}⚠ 請務必登入後立即修改預設密碼！${NC}"
  echo ""
}

deploy_frontend_static() {
  local backend_port
  backend_port=$(grep '^BACKEND_PORT=' "${INSTALL_DIR}/.env" 2>/dev/null | cut -d= -f2)
  backend_port=${backend_port:-6365}
  local frontend_port
  frontend_port=$(grep '^FRONTEND_PORT=' "${INSTALL_DIR}/.env" 2>/dev/null | cut -d= -f2)
  frontend_port=${frontend_port:-6366}

  echo ""
  log_step "配置前端靜態檔案目錄"
  echo ""
  echo -e "  請輸入您的 Nginx 網站根目錄（前端靜態檔案將部署到此處）"
  echo -e "  常見路徑範例："
  echo -e "    寶塔面板：${CYAN}/www/wwwroot/你的網站目錄${NC}"
  echo -e "    預設路徑：${CYAN}/var/www/gost-panel${NC}"
  echo ""
  read -rp "$(echo -e ${CYAN}'請輸入前端檔案目錄'${NC}' [預設: /var/www/gost-panel]: ')" web_root
  web_root=${web_root:-/var/www/gost-panel}

  # 移除尾部斜線
  web_root=${web_root%/}

  log_info "前端靜態檔案將部署到：${web_root}"

  # 建立目錄並部署
  mkdir -p "$web_root"

  # 先嘗試從 Release 下載
  if curl -fsSL "$FRONTEND_DIST_URL" -o /tmp/frontend-dist.tar.gz 2>/dev/null; then
    log_info "從 GitHub Release 下載前端靜態包..."
    tar -xzf /tmp/frontend-dist.tar.gz -C "$web_root" --strip-components=1 2>/dev/null || \
    tar -xzf /tmp/frontend-dist.tar.gz -C "$web_root" 2>/dev/null
    rm -f /tmp/frontend-dist.tar.gz
  else
    log_warn "無法從 Release 下載前端靜態包，嘗試從容器內複製..."
    # 從前端鏡像中提取 dist 檔案
    docker pull koftt/vite-frontend:latest
    local tmp_container
    tmp_container=$(docker create koftt/vite-frontend:latest)
    docker cp "${tmp_container}:/usr/share/nginx/html/." "$web_root/"
    docker rm "$tmp_container" >/dev/null
    log_info "已從前端鏡像中提取靜態檔案"
  fi

  # 生成 Nginx 反代配置檔案（不自動寫入系統 Nginx 目錄，避免與面板衝突）
  generate_nginx_conf_file "$backend_port" "$frontend_port" "$web_root"

  # 偵測伺服器環境並輸出對應操作指引
  print_setup_guide "$backend_port" "$frontend_port" "$web_root"
}

# 生成 Nginx 配置檔案到安裝目錄（僅生成，不自動載入）
generate_nginx_conf_file() {
  local backend_port=$1
  local frontend_port=$2
  local web_root=$3
  local conf_file="${INSTALL_DIR}/nginx-gost-panel.conf"

  cat >"$conf_file" <<EOF
# ============================================
# Gost Panel Nginx / OpenResty 反向代理配置
# 由 quick_start.sh 自動生成
# 請將此配置複製到您的 Nginx/OpenResty 配置中
# ============================================

    # 靜態資源快取
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Vue Router history 模式支持
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # API 反向代理到後端容器
    location ^~ /api/v1/ {
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_pass http://127.0.0.1:${backend_port}/api/v1/;
    }

    # 流量上報反向代理
    location /flow/upload {
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_pass http://127.0.0.1:${backend_port}/flow/upload;
    }

    location /flow/config {
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_pass http://127.0.0.1:${backend_port}/flow/config;
    }

    # WebSocket 反向代理
    location /system-info {
        proxy_pass http://127.0.0.1:${backend_port}/system-info;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
EOF

  log_info "Nginx 配置已生成到：${conf_file}"
}

# 偵測環境並輸出對應操作指引
print_setup_guide() {
  local backend_port=$1
  local frontend_port=$2
  local web_root=$3
  local conf_file="${INSTALL_DIR}/nginx-gost-panel.conf"

  echo ""
  echo -e "${YELLOW}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${YELLOW}║           Nginx / OpenResty 反向代理配置指引            ║${NC}"
  echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  前端靜態檔案位於：${CYAN}${web_root}${NC}"
  echo -e "  完整配置檔案位於：${CYAN}${conf_file}${NC}"
  echo ""

  # 偵測伺服器管理面板類型
  if [ -d "/opt/1panel" ]; then
    # ===== 1Panel =====
    echo -e "  ${GREEN}▸ 偵測到 1Panel 面板${NC}"
    echo ""
    echo -e "  請按以下步驟在 1Panel 中配置："
    echo ""
    echo -e "  ${CYAN}1.${NC} 進入 1Panel → 網站 → 建立網站"
    echo -e "  ${CYAN}2.${NC} 選擇「靜態網站」，網站根目錄填寫：${CYAN}${web_root}${NC}"
    echo -e "  ${CYAN}3.${NC} 監聽埠號填寫：${CYAN}${frontend_port}${NC}"
    echo -e "  ${CYAN}4.${NC} 建立完成後，進入該網站的「配置」頁面"
    echo -e "  ${CYAN}5.${NC} 將以下反向代理規則加入到配置中（location 區塊內）："
    echo ""
    echo -e "  ${CYAN}# ── API 反向代理（加入到 server 區塊內）──${NC}"
    echo -e "  ${CYAN}location ^~ /api/v1/ {${NC}"
    echo -e "  ${CYAN}    proxy_set_header Host \$host;${NC}"
    echo -e "  ${CYAN}    proxy_set_header X-Real-IP \$remote_addr;${NC}"
    echo -e "  ${CYAN}    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;${NC}"
    echo -e "  ${CYAN}    proxy_set_header X-Forwarded-Proto \$scheme;${NC}"
    echo -e "  ${CYAN}    proxy_pass http://127.0.0.1:${backend_port}/api/v1/;${NC}"
    echo -e "  ${CYAN}}${NC}"
    echo ""
    echo -e "  ${CYAN}location /flow/upload {${NC}"
    echo -e "  ${CYAN}    proxy_set_header Host \$host;${NC}"
    echo -e "  ${CYAN}    proxy_set_header X-Real-IP \$remote_addr;${NC}"
    echo -e "  ${CYAN}    proxy_pass http://127.0.0.1:${backend_port}/flow/upload;${NC}"
    echo -e "  ${CYAN}}${NC}"
    echo ""
    echo -e "  ${CYAN}location /flow/config {${NC}"
    echo -e "  ${CYAN}    proxy_set_header Host \$host;${NC}"
    echo -e "  ${CYAN}    proxy_set_header X-Real-IP \$remote_addr;${NC}"
    echo -e "  ${CYAN}    proxy_pass http://127.0.0.1:${backend_port}/flow/config;${NC}"
    echo -e "  ${CYAN}}${NC}"
    echo ""
    echo -e "  ${CYAN}location /system-info {${NC}"
    echo -e "  ${CYAN}    proxy_pass http://127.0.0.1:${backend_port}/system-info;${NC}"
    echo -e "  ${CYAN}    proxy_http_version 1.1;${NC}"
    echo -e "  ${CYAN}    proxy_set_header Upgrade \$http_upgrade;${NC}"
    echo -e "  ${CYAN}    proxy_set_header Connection \"upgrade\";${NC}"
    echo -e "  ${CYAN}}${NC}"
    echo ""

  elif [ -d "/www/server/panel" ]; then
    # ===== 寶塔面板 =====
    echo -e "  ${GREEN}▸ 偵測到寶塔面板${NC}"
    echo ""
    echo -e "  請按以下步驟在寶塔面板中配置："
    echo ""
    echo -e "  ${CYAN}1.${NC} 進入寶塔面板 → 網站 → 新增網站"
    echo -e "  ${CYAN}2.${NC} 網站根目錄設為：${CYAN}${web_root}${NC}"
    echo -e "  ${CYAN}3.${NC} 新增完成後，點擊網站名稱 → 「配置文件」"
    echo -e "  ${CYAN}4.${NC} 找到原有的 ${YELLOW}location / { ... }${NC} 區塊並**刪除或註解掉**"
    echo -e "  ${CYAN}5.${NC} 在檔案末尾（最後一個 ${YELLOW}}${NC} 的上面一行）"
    echo -e "      將 ${CYAN}${conf_file}${NC} 的內容複製貼上"
    echo -e "  ${CYAN}6.${NC} 點擊儲存，即可生效！"
    echo ""

  else
    # ===== 通用環境 =====
    echo -e "  ${GREEN}▸ 通用 Nginx / OpenResty 配置${NC}"
    echo ""
    echo -e "  目前生成的配置檔 ${CYAN}${conf_file}${NC} 僅包含 ${YELLOW}location${NC} 反代規則。"
    echo -e "  請將其內容手動整合到您的 Nginx 虛擬主機 (vhost) 配置中："
    echo ""
    echo -e "  ${CYAN}1.${NC} 尋找您的站點配置檔（通常在 /etc/nginx/conf.d/ 或 /etc/nginx/sites-enabled/）"
    echo -e "  ${CYAN}2.${NC} 打開配置檔，找到您的 ${YELLOW}server { ... }${NC} 區塊"
    echo -e "  ${CYAN}3.${NC} 將 ${CYAN}${conf_file}${NC} 的內容複製並貼到 server 區塊的結尾處"
    echo -e "  ${CYAN}4.${NC} 確保沒有重複的 ${YELLOW}location /${NC} 區塊，若有則替換掉"
    echo -e "  ${CYAN}5.${NC} 執行指令測試並重載：${CYAN}nginx -t && nginx -s reload${NC}"
    echo ""
    echo ""
  fi

  echo -e "  ${YELLOW}提示：${NC}完整配置已儲存到 ${CYAN}${conf_file}${NC}"
  echo -e "  ${YELLOW}      ${NC}您可以隨時用 ${CYAN}cat ${conf_file}${NC} 查看"
  echo ""
}

# ============ 主選單 ============

show_menu() {
  print_banner
  echo -e "  請選擇部署模式："
  echo ""
  echo -e "  ${GREEN}A${NC}) 雙容器模式（推薦新手）"
  echo -e "     拉取前端 + 後端兩個 Docker 容器"
  echo -e "     適合：全新伺服器，不需要自建 Nginx"
  echo ""
  echo -e "  ${GREEN}B${NC}) 後端容器 + 前端靜態檔案模式"
  echo -e "     只拉取後端容器，前端使用宿主機 Nginx"
  echo -e "     適合：已有 Nginx/OpenResty/寶塔面板的伺服器"
  echo ""
  echo -e "  ${GREEN}Q${NC}) 退出"
  echo ""
}

main() {
  check_root
  check_docker

  show_menu
  read -rp "$(echo -e '  請輸入選項 [A/B/Q]: ')" choice

  case "$choice" in
    [Aa])
      deploy_dual_container
      ;;
    [Bb])
      deploy_backend_only
      ;;
    [Qq])
      log_info "已退出"
      exit 0
      ;;
    *)
      log_error "無效選項：$choice"
      exit 1
      ;;
  esac
}

main "$@"
