#!/bin/bash

# AI应用部署到VPS脚本 - 15468597.top
# 使用方法: ./deploy-to-vps.sh [VPS_IP] [SSH_USER]

set -e

VPS_IP=${1:-"your-vps-ip"}
SSH_USER=${2:-"root"}
DOMAIN="15468597.top"
APP_NAME="ai-app"

echo "🚀 开始部署AI应用到VPS: $VPS_IP"
echo "📋 域名: $DOMAIN"
echo "👤 SSH用户: $SSH_USER"

# 检查参数
if [ "$VPS_IP" = "your-vps-ip" ]; then
    echo "❌ 请提供VPS IP地址"
    echo "使用方法: ./deploy-to-vps.sh [VPS_IP] [SSH_USER]"
    exit 1
fi

# 1. 上传项目文件到VPS
echo "📤 上传项目文件到VPS..."
scp -r . $SSH_USER@$VPS_IP:/opt/$APP_NAME/

# 2. 在VPS上执行部署命令
echo "🔧 在VPS上执行部署..."
ssh $SSH_USER@$VPS_IP << 'EOF'
set -e

# 更新系统
apt update && apt upgrade -y

# 安装必要软件
apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx

# 启动Docker服务
systemctl start docker
systemctl enable docker

# 进入项目目录
cd /opt/ai-app

# 构建并启动容器
docker-compose down || true
docker-compose build
docker-compose up -d

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 30

# 检查服务状态
docker-compose ps

# 配置Nginx
cp nginx.conf /etc/nginx/sites-available/ai-app
ln -sf /etc/nginx/sites-available/ai-app /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# 测试Nginx配置
nginx -t

# 重启Nginx
systemctl restart nginx
systemctl enable nginx

echo "✅ 基础部署完成！"
echo "📝 接下来需要手动配置SSL证书:"
echo "   sudo certbot --nginx -d 15468597.top -d www.15468597.top"
echo "🌐 请确保域名DNS已指向此服务器IP"

EOF

echo "🎉 部署脚本执行完成！"
echo ""
echo "📋 后续步骤:"
echo "1. 确保域名 $DOMAIN 的DNS A记录指向 $VPS_IP"
echo "2. SSH到VPS执行SSL证书配置:"
echo "   ssh $SSH_USER@$VPS_IP"
echo "   sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN"
echo "3. 访问 https://$DOMAIN 测试部署结果"
echo ""
echo "🔍 检查服务状态:"
echo "   ssh $SSH_USER@$VPS_IP 'docker-compose -f /opt/$APP_NAME/docker-compose.yml ps'"
echo "   ssh $SSH_USER@$VPS_IP 'systemctl status nginx'"