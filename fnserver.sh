#!/bin/bash

#====================================================
# 脚本名称：Eric 的媒体服务器一键部署脚本 (优化版)
# 适用环境：飞牛 NAS (FnOS) 或 标准 Debian/Ubuntu
#====================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${GREEN}=========================================${NC}"
echo "  飞牛媒体服务一键部署脚本"
echo "  YouTube 頻道：https://www.youtube.com/@Eric-f2v"
echo -e "${GREEN}=========================================${NC}"

# 1. 基础路径配置
BASE_DIR="/mnt/sata1-1/mvtv"
DOCKER_DIR="$BASE_DIR/docker"
MEDIA_DIR="$BASE_DIR/media"

# 确保以 root 执行
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}错误：请使用 root 权限执行此脚本 (sudo ./fnserver.sh)${NC}"
  exit 1
fi

echo "--- 正在建立所需的目录结构 ---"
mkdir -p "$DOCKER_DIR"/{jellyseerr,sonarr,radarr,bazarr}/config
mkdir -p "$MEDIA_DIR"/{downloads,movie,tv}
echo "✅ 目录建立完成！"

# 2. 设置权限（使用 root 权限）
echo -e "\n--- 权限设置 ---"
PUID=0
PGID=0
TZ="Asia/Shanghai"
echo "✅ 权限设置完成！使用 root 权限 (PUID=0, PGID=0)"

# 3. 部署函数
deploy_app() {
  local app_name=$1
  local compose_content=$2
  local app_path="$DOCKER_DIR/$app_name"

  echo -e "\n🛠️  正在部署: $app_name"
  echo "$compose_content" > "$app_path/docker-compose.yml"
  
  cd "$app_path"
  docker compose up -d
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ $app_name 启动成功！${NC}"
  else
    echo -e "${RED}❌ $app_name 启动失败，请检查 docker-compose.yml${NC}"
  fi
  cd - > /dev/null
}

# 4. 删除函数
delete_app() {
  local app_name=$1
  local app_path="$DOCKER_DIR/$app_name"

  echo -e "\n🗑️  正在删除: $app_name"
  
  if [ -d "$app_path" ]; then
    cd "$app_path"
    docker compose down -v 2>/dev/null || docker compose down
    cd - > /dev/null
    echo -e "${GREEN}✅ $app_name 删除完成！${NC}"
  else
    echo -e "${YELLOW}⚠️  $app_name 配置目录不存在，跳过${NC}"
  fi
}

# 5. 批量删除所有应用
delete_all() {
  echo -e "\n${RED}！！！ 警告：即将删除所有部署的应用 ！！！${NC}"
  echo -e "${RED}！！！ 这将删除所有容器、数据卷和配置文件 ！！！${NC}"
  read -p "确认删除？(y/N): " confirm
  confirm=${confirm:-N}
  
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "取消删除操作"
    exit 0
  fi
  
  echo -e "\n${RED}--- 开始删除所有应用 ---${NC}"
  delete_app "jellyseerr"
  delete_app "sonarr"
  delete_app "radarr"
  delete_app "bazarr"
  
  echo -e "\n${GREEN}--- 🗑️  所有应用已删除 ---${NC}"
  echo "如需清理持久化数据，请手动删除 $DOCKER_DIR 和 $MEDIA_DIR 目录"
}

# --- 各应用配置开始 ---

# Jellyseerr
jellyseerr_compose="version: '3.5'
services:
  jellyseerr:
    image: fallenbagel/jellyseerr:latest
    container_name: jellyseerr
    ports:
      - 5055:5055
    environment:
      - TZ=$TZ
      - LOG_LEVEL=debug
    volumes:
      - $DOCKER_DIR/jellyseerr/config:/app/config
    restart: unless-stopped"

# Sonarr
sonarr_compose="version: '3.5'
services:
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    ports:
      - 8989:8989
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TZ
    volumes:
      - $DOCKER_DIR/sonarr/config:/config
      - $MEDIA_DIR:/media
    restart: unless-stopped"

# Radarr
radarr_compose="version: '3.5'
services:
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    ports:
      - 7878:7878
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TZ
    volumes:
      - $DOCKER_DIR/radarr/config:/config
      - $MEDIA_DIR:/media
    restart: unless-stopped"

# Bazarr
bazarr_compose="version: '3.5'
services:
  bazarr:
    image: lscr.io/linuxserver/bazarr:latest
    container_name: bazarr
    ports:
      - 6767:6767
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TZ
    volumes:
      - $DOCKER_DIR/bazarr/config:/config
      - $MEDIA_DIR:/media
    restart: unless-stopped"

# --- 执行部署序列 ---
deploy_app "jellyseerr" "$jellyseerr_compose"
deploy_app "sonarr" "$sonarr_compose"
deploy_app "radarr" "$radarr_compose"
deploy_app "bazarr" "$bazarr_compose"

echo -e "\n${GREEN}--- 🎉 所有应用程序部署完成！ ---${NC}"
echo "请通过 NAS IP 加以下端口访问："
echo "  - Jellyseerr:  5055"
echo "  - Sonarr:      8989"
echo "  - Radarr:      7878"
echo "  - Bazarr:      6767"
echo -e "\n${GREEN}温馨提示：在 Sonarr/Radarr 设置媒体库时，请统一使用 /media 路径以实现硬链接。${NC}"

# --- 交互式菜单 ---
echo -e "\n${GREEN}=========================================${NC}"
echo "  请选择操作："
echo "  1. 部署所有应用"
echo "  2. 删除所有应用"
echo "  3. 仅部署指定应用"
echo "  4. 仅删除指定应用"
echo "  0. 退出"
echo -e "${GREEN}=========================================${NC}"
read -p "请输入选项 (0-4): " choice

case $choice in
  1)
    echo -e "\n${GREEN}--- 开始部署所有应用 ---${NC}"
    deploy_app "jellyseerr" "$jellyseerr_compose"
    deploy_app "sonarr" "$sonarr_compose"
    deploy_app "radarr" "$radarr_compose"
    deploy_app "bazarr" "$bazarr_compose"
    echo -e "\n${GREEN}--- 🎉 所有应用部署完成 ---${NC}"
    ;;
  2)
    delete_all
    ;;
  3)
    echo -e "\n${GREEN}--- 单独部署 ---${NC}"
    read -p "输入要部署的应用名称（多个用空格分隔）: " apps
    for app in $apps; do
      case $app in
        jellyseerr) deploy_app "jellyseerr" "$jellyseerr_compose" ;;
        sonarr) deploy_app "sonarr" "$sonarr_compose" ;;
        radarr) deploy_app "radarr" "$radarr_compose" ;;
        bazarr) deploy_app "bazarr" "$bazarr_compose" ;;
        *) echo -e "${RED}未知应用: $app${NC}" ;;
      esac
    done
    ;;
  4)
    echo -e "\n${GREEN}--- 单独删除 ---${NC}"
    read -p "输入要删除的应用名称（多个用空格分隔）: " apps
    for app in $apps; do
      delete_app "$app"
    done
    ;;
  0)
    echo "退出脚本"
    exit 0
    ;;
  *)
    echo -e "${RED}无效选项${NC}"
    exit 1
    ;;
esac
