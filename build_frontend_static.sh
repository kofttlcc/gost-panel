#!/bin/bash

# Ensure we're in the correct directory (gost-panel root)
cd "$(dirname "$0")"

# 檢查 Docker 是否安裝
if ! command -v docker &> /dev/null; then
    echo "錯誤: 系統未安裝 Docker。請先安裝 Docker。"
    exit 1
fi

echo "開始利用 Docker BuildKit 編譯前端靜態資源..."

# 編譯前端源碼為一個臨時的 Docker 鏡像 (只跑到 builder 階段)
IMAGE_NAME="temp-flux-vite-builder"
docker build -f vite-frontend/Dockerfile --target builder -t $IMAGE_NAME ./vite-frontend

if [ $? -eq 0 ]; then
    echo "編譯成功，正在將靜態資源複製到本地目錄..."
    # 建立一個臨時容器，並不啟動它
    CONTAINER_ID=$(docker create $IMAGE_NAME)
    
    # 將 /app/dist 目錄複製出到宿主機
    rm -rf ./vite-frontend/dist
    docker cp $CONTAINER_ID:/app/dist ./vite-frontend/
    
    # 刪除臨時容器與鏡像
    docker rm -v $CONTAINER_ID > /dev/null
    docker rmi $IMAGE_NAME > /dev/null
    
    echo "======================================"
    echo "🎉 抽取完成！"
    echo "靜態文件已輸出到: $(pwd)/vite-frontend/dist"
    echo "======================================"
    echo ""
    echo "您可以將 OpenResty/Nginx 的 root 指向上述目錄，並將 /api 代理給 localhost:6365。"
else
    echo "❌ 鏡像編譯失敗，請檢查上述錯誤訊息。"
    exit 1
fi
