#!/bin/bash

# 阿里云服务器部署脚本
# 使用方法: chmod +x deploy-aliyun.sh && ./deploy-aliyun.sh

set -e

echo "🚀 开始部署AI应用到阿里云服务器..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker未安装，正在安装...${NC}"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
        echo -e "${GREEN}✅ Docker安装完成${NC}"
    else
        echo -e "${GREEN}✅ Docker已安装${NC}"
    fi
}

# 检查Docker Compose是否安装
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}❌ Docker Compose未安装，正在安装...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        echo -e "${GREEN}✅ Docker Compose安装完成${NC}"
    else
        echo -e "${GREEN}✅ Docker Compose已安装${NC}"
    fi
}

# 创建必要的目录
create_directories() {
    echo -e "${BLUE}📁 创建必要的目录...${NC}"
    mkdir -p logs/nginx
    mkdir -p ssl
    mkdir -p uploads
    mkdir -p backend/data
    echo -e "${GREEN}✅ 目录创建完成${NC}"
}

# 设置环境变量
setup_environment() {
    echo -e "${BLUE}⚙️ 设置环境变量...${NC}"
    if [ ! -f .env ]; then
        cp .env.production .env
        echo -e "${YELLOW}⚠️ 请编辑 .env 文件设置你的配置${NC}"
        echo -e "${YELLOW}   特别是 JWT_SECRET_KEY 和 DOMAIN${NC}"
    fi
    echo -e "${GREEN}✅ 环境变量设置完成${NC}"
}

# 配置防火墙
setup_firewall() {
    echo -e "${BLUE}🔥 配置防火墙...${NC}"
    if command -v ufw &> /dev/null; then
        sudo ufw allow 22
        sudo ufw allow 80
        sudo ufw allow 443
        sudo ufw --force enable
    elif command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-port=22/tcp
        sudo firewall-cmd --permanent --add-port=80/tcp
        sudo firewall-cmd --permanent --add-port=443/tcp
        sudo firewall-cmd --reload
    fi
    echo -e "${GREEN}✅ 防火墙配置完成${NC}"
}

# 构建和启动服务
deploy_services() {
    echo -e "${BLUE}🏗️ 构建和启动服务...${NC}"
    
    # 停止现有服务
    docker-compose -f docker-compose.prod.yml down 2>/dev/null || true
    
    # 清理旧镜像
    docker system prune -f
    
    # 构建和启动
    docker-compose -f docker-compose.prod.yml up -d --build
    
    echo -e "${GREEN}✅ 服务启动完成${NC}"
}

# 等待服务启动
wait_for_services() {
    echo -e "${BLUE}⏳ 等待服务启动...${NC}"
    sleep 10
    
    # 检查服务状态
    if docker-compose -f docker-compose.prod.yml ps | grep -q "Up"; then
        echo -e "${GREEN}✅ 服务运行正常${NC}"
    else
        echo -e "${RED}❌ 服务启动失败，查看日志:${NC}"
        docker-compose -f docker-compose.prod.yml logs
        exit 1
    fi
}

# 显示部署信息
show_deployment_info() {
    echo -e "\n${GREEN}🎉 部署完成！${NC}"
    echo -e "${BLUE}📊 服务状态:${NC}"
    docker-compose -f docker-compose.prod.yml ps
    
    echo -e "\n${BLUE}🌐 访问地址:${NC}"
    echo -e "  HTTP:  http://$(curl -s ifconfig.me)"
    echo -e "  HTTP:  http://15468597.top (需要DNS配置)"
    
    echo -e "\n${BLUE}📝 常用命令:${NC}"
    echo -e "  查看日志: docker-compose -f docker-compose.prod.yml logs -f"
    echo -e "  重启服务: docker-compose -f docker-compose.prod.yml restart"
    echo -e "  停止服务: docker-compose -f docker-compose.prod.yml down"
    
    echo -e "\n${YELLOW}⚠️ 下一步:${NC}"
    echo -e "  1. 配置域名DNS解析指向服务器IP"
    echo -e "  2. 安装SSL证书: sudo certbot --nginx -d 15468597.top"
    echo -e "  3. 设置自动续期: echo '0 12 * * * /usr/bin/certbot renew --quiet' | sudo crontab -"
}

# 主函数
main() {
    echo -e "${BLUE}🚀 AI应用阿里云部署脚本${NC}"
    echo -e "${BLUE}================================${NC}"
    
    check_docker
    check_docker_compose
    create_directories
    setup_environment
    setup_firewall
    deploy_services
    wait_for_services
    show_deployment_info
    
    echo -e "\n${GREEN}🎊 恭喜！部署成功完成！${NC}"
}

# 运行主函数
main "$@"