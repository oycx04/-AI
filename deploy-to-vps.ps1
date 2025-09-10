# AI应用部署到VPS脚本 - 15468597.top
# 使用方法: .\deploy-to-vps.ps1 -VpsIP "your-vps-ip" -SshUser "root"

param(
    [Parameter(Mandatory=$true)]
    [string]$VpsIP,
    
    [Parameter(Mandatory=$false)]
    [string]$SshUser = "root",
    
    [Parameter(Mandatory=$false)]
    [string]$Domain = "15468597.top",
    
    [Parameter(Mandatory=$false)]
    [string]$AppName = "ai-app"
)

Write-Host "🚀 开始部署AI应用到VPS: $VpsIP" -ForegroundColor Green
Write-Host "📋 域名: $Domain" -ForegroundColor Cyan
Write-Host "👤 SSH用户: $SshUser" -ForegroundColor Cyan

# 检查必要工具
if (-not (Get-Command scp -ErrorAction SilentlyContinue)) {
    Write-Host "❌ 未找到scp命令，请安装OpenSSH客户端" -ForegroundColor Red
    Write-Host "可以通过Windows功能或Git Bash安装" -ForegroundColor Yellow
    exit 1
}

if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Host "❌ 未找到ssh命令，请安装OpenSSH客户端" -ForegroundColor Red
    exit 1
}

try {
    # 1. 上传项目文件到VPS
    Write-Host "📤 上传项目文件到VPS..." -ForegroundColor Yellow
    
    # 创建远程目录
    ssh "$SshUser@$VpsIP" "mkdir -p /opt/$AppName"
    
    # 上传文件（排除不必要的文件）
    $excludeFiles = @(
        "*.git*",
        "node_modules",
        "__pycache__",
        "*.pyc",
        "logs",
        "*.log"
    )
    
    # 使用rsync或scp上传（这里使用scp）
    scp -r . "$SshUser@$VpsIP:/opt/$AppName/"
    
    Write-Host "✅ 文件上传完成" -ForegroundColor Green
    
    # 2. 在VPS上执行部署命令
    Write-Host "🔧 在VPS上执行部署..." -ForegroundColor Yellow
    
    $deployScript = @'
set -e

echo "🔄 更新系统..."
apt update && apt upgrade -y

echo "📦 安装必要软件..."
apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx

echo "🐳 启动Docker服务..."
systemctl start docker
systemctl enable docker

echo "📁 进入项目目录..."
cd /opt/ai-app

echo "🛑 停止现有容器..."
docker-compose down || true

echo "🔨 构建Docker镜像..."
docker-compose build

echo "🚀 启动服务..."
docker-compose up -d

echo "⏳ 等待服务启动..."
sleep 30

echo "📊 检查服务状态..."
docker-compose ps

echo "🌐 配置Nginx..."
cp nginx.conf /etc/nginx/sites-available/ai-app
ln -sf /etc/nginx/sites-available/ai-app /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

echo "🔍 测试Nginx配置..."
nginx -t

echo "🔄 重启Nginx..."
systemctl restart nginx
systemctl enable nginx

echo "✅ 基础部署完成！"
echo "📝 接下来需要手动配置SSL证书:"
echo "   sudo certbot --nginx -d 15468597.top -d www.15468597.top"
echo "🌐 请确保域名DNS已指向此服务器IP"
'@
    
    # 执行部署脚本
    $deployScript | ssh "$SshUser@$VpsIP" 'bash -s'
    
    Write-Host "🎉 部署脚本执行完成！" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 后续步骤:" -ForegroundColor Cyan
    Write-Host "1. 确保域名 $Domain 的DNS A记录指向 $VpsIP" -ForegroundColor White
    Write-Host "2. SSH到VPS执行SSL证书配置:" -ForegroundColor White
    Write-Host "   ssh $SshUser@$VpsIP" -ForegroundColor Gray
    Write-Host "   sudo certbot --nginx -d $Domain -d www.$Domain" -ForegroundColor Gray
    Write-Host "3. 访问 https://$Domain 测试部署结果" -ForegroundColor White
    Write-Host ""
    Write-Host "🔍 检查服务状态:" -ForegroundColor Cyan
    Write-Host "   ssh $SshUser@$VpsIP 'docker-compose -f /opt/$AppName/docker-compose.yml ps'" -ForegroundColor Gray
    Write-Host "   ssh $SshUser@$VpsIP 'systemctl status nginx'" -ForegroundColor Gray
    
} catch {
    Write-Host "❌ 部署过程中出现错误: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🌟 部署完成！请按照上述步骤完成SSL配置。" -ForegroundColor Green