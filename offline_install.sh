#!/bin/bash

# ==========================================================
# Gost Panel 純手工離線客戶端安裝腳本
# 適用於：無法存取外網 (HTTP/HTTPS) 的內部伺服器
# ==========================================================

INSTALL_DIR="/etc/gost"

# 檢查權限
if [[ $(id -u) -ne 0 ]]; then
    echo "❌ 錯誤：請使用 root 權限執行此腳本 (sudo ./offline_install.sh)"
    exit 1
fi

# 顯示幫助
usage() {
    echo "用法: ./offline_install.sh [目錄/本機gost檔案] -a [伺服器地址] -s [金鑰]"
    echo ""
    echo "範例: ./offline_install.sh ./gost-amd64 -a qqhk.itgeek.cyou:6365 -s 7ee6bd785fde49998e05b16d8a5aeec5"
    echo ""
    echo "注意: 執行前請務必將下載好的 gost 二進位檔案一併放到這台伺服器上！"
}

if [[ $# -lt 5 ]]; then
    usage
    exit 1
fi

# 解析參數
GOST_LOCAL_FILE="$1"
shift

while getopts "a:s:" opt; do
  case $opt in
    a) SERVER_ADDR="$OPTARG" ;;
    s) SECRET="$OPTARG" ;;
    *) usage; exit 1 ;;
  esac
done

# 檢查檔案是否存在
if [[ ! -f "$GOST_LOCAL_FILE" ]]; then
    echo "❌ 錯誤：找不到指定的 gost 本機二進位檔案 '$GOST_LOCAL_FILE'！"
    echo "請先從您的電腦下載 gost 二進位檔並傳到這台伺服器上。"
    exit 1
fi

echo "🚀 開始離線安裝 GOST..."

mkdir -p "$INSTALL_DIR"

# 停止并禁用已有服务
if systemctl list-units --full -all | grep -Fq "gost.service"; then
  echo "🔍 檢測到已存在的 gost 服務"
  systemctl stop gost 2>/dev/null && echo "🛑 停止服務"
  systemctl disable gost 2>/dev/null && echo "🚫 禁用自啟"
fi

# 删除旧文件
[[ -f "$INSTALL_DIR/gost" ]] && echo "🧹 刪除舊文件 gost" && rm -f "$INSTALL_DIR/gost"

echo "📦 正在從本地檔案安裝 $GOST_LOCAL_FILE ..."
cp "$GOST_LOCAL_FILE" "$INSTALL_DIR/gost"
chmod +x "$INSTALL_DIR/gost"
echo "✅ 本地安裝完成"

# 打印版本
echo "🔎 gost 版本：$($INSTALL_DIR/gost -V)"

# 寫入 config.json
CONFIG_FILE="$INSTALL_DIR/config.json"
echo "📄 創建新配置: config.json"
cat > "$CONFIG_FILE" <<EOF
{
  "addr": "$SERVER_ADDR",
  "secret": "$SECRET"
}
EOF

# 写入 gost.json
GOST_CONFIG="$INSTALL_DIR/gost.json"
if [[ -f "$GOST_CONFIG" ]]; then
  echo "⏭️ 跳過設定檔案: gost.json (已經存在)"
else
  echo "📄 創建新功能配置: gost.json"
  cat > "$GOST_CONFIG" <<EOF
{}
EOF
fi

# 加強權限
chmod 600 "$INSTALL_DIR"/*.json

# 建立 systemd 服務
SERVICE_FILE="/etc/systemd/system/gost.service"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Gost Proxy Service
After=network.target

[Service]
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/gost
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 啟動服務
systemctl daemon-reload
systemctl enable gost
systemctl start gost

# 檢查狀態
echo "🔄 檢查服務狀態..."
if systemctl is-active --quiet gost; then
  echo "✅ 離線安裝完成，gost服務已啟動並設定為開機啟動。"
  echo "📁 配置目錄: $INSTALL_DIR"
  echo "🔧 服務狀態: $(systemctl is-active gost)"
else
  echo "❌ gost服務啟動失敗，請執行以下命令查看日誌："
  echo "journalctl -u gost -f"
fi
