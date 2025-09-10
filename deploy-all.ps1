# AI应用全平台部署脚本
# 作者：AI助手
# 用途：自动化部署到GitHub、Docker Hub和配置域名

Write-Host "🚀 开始AI应用全平台部署..." -ForegroundColor Green

# 1. 检查Git状态并推送到GitHub
Write-Host "📦 步骤1: 推送代码到GitHub..." -ForegroundColor Yellow
try {
    git add .
    git commit -m "自动部署更新 - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    git push origin main
    Write-Host "✅ GitHub推送成功" -ForegroundColor Green
} catch {
    Write-Host "❌ GitHub推送失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. 构建并推送Docker镜像
Write-Host "🐳 步骤2: 构建Docker镜像..." -ForegroundColor Yellow
try {
    docker build -f Dockerfile.hub -t oycx04/ai-app:latest .
    Write-Host "✅ Docker镜像构建成功" -ForegroundColor Green
    
    Write-Host "📤 推送到Docker Hub..." -ForegroundColor Yellow
    docker push oycx04/ai-app:latest
    Write-Host "✅ Docker Hub推送成功" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker操作失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. 显示部署信息
Write-Host "📋 部署信息:" -ForegroundColor Cyan
Write-Host "  GitHub仓库: https://github.com/oycx04/-AI.git" -ForegroundColor White
Write-Host "  Docker镜像: oycx04/ai-app:latest" -ForegroundColor White
Write-Host "  目标域名: https://15468597.top" -ForegroundColor White

# 4. 显示下一步操作
Write-Host "📝 下一步操作:" -ForegroundColor Cyan
Write-Host "  1. 在Vercel中导入GitHub仓库" -ForegroundColor White
Write-Host "  2. 配置环境变量 (DATABASE_URL, JWT_SECRET_KEY, REDIS_URL)" -ForegroundColor White
Write-Host "  3. 在域名管理面板配置DNS解析到Vercel" -ForegroundColor White
Write-Host "  4. 或者在VPS上运行: docker run -d -p 80:80 oycx04/ai-app:latest" -ForegroundColor White

Write-Host "🎉 部署脚本执行完成！" -ForegroundColor Green