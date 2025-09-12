# 阿里云服务器部署脚本 (PowerShell版本)
# 使用方法: .\deploy-aliyun.ps1

Write-Host "🚀 开始准备AI应用部署到阿里云服务器..." -ForegroundColor Green

# 检查必要工具
function Test-Requirements {
    Write-Host "📋 检查部署要求..." -ForegroundColor Blue
    
    # 检查Git
    if (!(Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "❌ Git未安装，请先安装Git" -ForegroundColor Red
        exit 1
    }
    
    # 检查SSH客户端
    if (!(Get-Command ssh -ErrorAction SilentlyContinue)) {
        Write-Host "❌ SSH客户端未找到，请确保已安装OpenSSH" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ 基本工具检查完成" -ForegroundColor Green
}

# 创建部署包
function New-DeploymentPackage {
    Write-Host "📦 创建部署包..." -ForegroundColor Blue
    
    # 清理临时文件
    if (Test-Path "ai-app-deploy.zip") {
        Remove-Item "ai-app-deploy.zip" -Force
    }
    
    # 创建排除列表
    $excludeItems = @(
        ".git",
        "node_modules",
        "__pycache__",
        "*.pyc",
        ".env.local",
        "logs",
        "uploads",
        "ssl",
        "ai-app-deploy.zip"
    )
    
    # 获取所有文件
    $files = Get-ChildItem -Recurse | Where-Object {
        $item = $_
        $shouldExclude = $false
        foreach ($exclude in $excludeItems) {
            if ($item.FullName -like "*$exclude*") {
                $shouldExclude = $true
                break
            }
        }
        (-not $shouldExclude) -and (-not $item.PSIsContainer)
    }
    
    # 创建ZIP包
    Compress-Archive -Path $files.FullName -DestinationPath "ai-app-deploy.zip" -Force
    
    Write-Host "✅ 部署包创建完成: ai-app-deploy.zip" -ForegroundColor Green
}

# 显示部署说明
function Show-DeploymentInstructions {
    Write-Host "\n📖 阿里云服务器部署说明" -ForegroundColor Yellow
    Write-Host "================================" -ForegroundColor Yellow
    
    Write-Host "\n1️⃣ 上传文件到服务器:" -ForegroundColor Cyan
    Write-Host "   scp ai-app-deploy.zip root@你的服务器IP:/root/" -ForegroundColor White
    
    Write-Host "\n2️⃣ 连接到服务器:" -ForegroundColor Cyan
    Write-Host "   ssh root@你的服务器IP" -ForegroundColor White
    
    Write-Host "\n3️⃣ 在服务器上执行:" -ForegroundColor Cyan
    Write-Host "   cd /root" -ForegroundColor White
    Write-Host "   unzip -o ai-app-deploy.zip -d ai-app" -ForegroundColor White
    Write-Host "   cd ai-app" -ForegroundColor White
    Write-Host "   chmod +x deploy-aliyun.sh" -ForegroundColor White
    Write-Host "   ./deploy-aliyun.sh" -ForegroundColor White
    
    Write-Host "\n4️⃣ 配置域名DNS:" -ForegroundColor Cyan
    Write-Host "   在阿里云DNS控制台添加A记录:" -ForegroundColor White
    Write-Host "   记录类型: A" -ForegroundColor White
    Write-Host "   主机记录: @" -ForegroundColor White
    Write-Host "   记录值: 你的服务器IP" -ForegroundColor White
    Write-Host "   TTL: 600" -ForegroundColor White
    
    Write-Host "\n5️⃣ 配置SSL证书 (在服务器上):" -ForegroundColor Cyan
    Write-Host "   sudo apt install certbot python3-certbot-nginx -y" -ForegroundColor White
    Write-Host "   sudo certbot --nginx -d 15468597.top" -ForegroundColor White
    
    Write-Host "\n🎯 部署完成后访问地址:" -ForegroundColor Green
    Write-Host "   HTTP:  http://15468597.top" -ForegroundColor White
    Write-Host "   HTTPS: https://15468597.top" -ForegroundColor White
}

# 显示服务器要求
function Show-ServerRequirements {
    Write-Host "\n🖥️ 阿里云服务器要求" -ForegroundColor Yellow
    Write-Host "================================" -ForegroundColor Yellow
    
    Write-Host "\n💻 硬件配置:" -ForegroundColor Cyan
    Write-Host "   CPU: 1核心以上" -ForegroundColor White
    Write-Host "   内存: 2GB以上" -ForegroundColor White
    Write-Host "   存储: 20GB以上" -ForegroundColor White
    
    Write-Host "\n🐧 操作系统:" -ForegroundColor Cyan
    Write-Host "   Ubuntu 20.04+ (推荐)" -ForegroundColor White
    Write-Host "   CentOS 7+" -ForegroundColor White
    Write-Host "   Debian 10+" -ForegroundColor White
    
    Write-Host "\n🔌 网络配置:" -ForegroundColor Cyan
    Write-Host "   开放端口: 22 (SSH), 80 (HTTP), 443 (HTTPS)" -ForegroundColor White
    Write-Host "   公网IP地址" -ForegroundColor White
    Write-Host "   域名解析配置" -ForegroundColor White
}

# 显示故障排除
function Show-Troubleshooting {
    Write-Host "\n🔧 常见问题解决" -ForegroundColor Yellow
    Write-Host "================================" -ForegroundColor Yellow
    
    Write-Host "\n❓ 连接被拒绝:" -ForegroundColor Cyan
    Write-Host "   检查服务器IP是否正确" -ForegroundColor White
    Write-Host "   检查SSH端口(22)是否开放" -ForegroundColor White
    Write-Host "   检查防火墙设置" -ForegroundColor White
    
    Write-Host "\n❓ 域名无法访问:" -ForegroundColor Cyan
    Write-Host "   检查DNS解析是否生效 (可能需要等待10-30分钟)" -ForegroundColor White
    Write-Host "   使用 nslookup 15468597.top 检查解析" -ForegroundColor White
    Write-Host "   确认服务器防火墙开放80/443端口" -ForegroundColor White
    
    Write-Host "\n❓ 服务启动失败:" -ForegroundColor Cyan
    Write-Host "   查看日志: docker-compose -f docker-compose.prod.yml logs" -ForegroundColor White
    Write-Host "   检查端口占用: sudo netstat -tlnp | grep :80" -ForegroundColor White
    Write-Host "   重启服务: docker-compose -f docker-compose.prod.yml restart" -ForegroundColor White
}

# 主函数
function Main {
    Clear-Host
    Write-Host "🌟 AI应用阿里云部署助手" -ForegroundColor Magenta
    Write-Host "========================" -ForegroundColor Magenta
    
    Test-Requirements
    New-DeploymentPackage
    Show-ServerRequirements
    Show-DeploymentInstructions
    Show-Troubleshooting
    
    Write-Host "\n🎊 准备工作完成！" -ForegroundColor Green
    Write-Host "现在可以按照上述说明在阿里云服务器上部署了！" -ForegroundColor Green
    
    # 询问是否打开部署指南
    $openGuide = Read-Host "\n是否打开详细部署指南？(y/n)"
    if ($openGuide -eq 'y' -or $openGuide -eq 'Y') {
        if (Test-Path "阿里云部署指南.md") {
            Invoke-Item "阿里云部署指南.md"
        }
    }
}

# 运行主函数
Main