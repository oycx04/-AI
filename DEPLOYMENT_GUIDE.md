# AI应用部署指南

## 概述
本指南详细说明如何将AI应用部署到多个平台：GitHub、Vercel、Docker Hub，并配置自定义域名。

## 1. GitHub部署

### 状态：✅ 已完成
- 代码已推送到：https://github.com/oycx04/-AI.git
- 包含所有最新更新和配置文件

## 2. Vercel部署

### 配置文件
- `vercel.json` - Vercel部署配置
- `backend/requirements-vercel.txt` - Python依赖

### 部署步骤
1. 访问 [Vercel Dashboard](https://vercel.com/dashboard)
2. 点击 "New Project"
3. 导入GitHub仓库：`oycx04/-AI`
4. 配置环境变量：
   - `DATABASE_URL`: PostgreSQL数据库连接字符串
   - `JWT_SECRET_KEY`: JWT密钥
   - `REDIS_URL`: Redis连接字符串
5. 部署完成后获得Vercel URL

### 环境变量设置
```bash
# 在Vercel Dashboard中设置
DATABASE_URL=postgresql://username:password@host:port/database
JWT_SECRET_KEY=your-secret-key-here
REDIS_URL=redis://username:password@host:port
```

## 3. Docker Hub部署

### 配置文件
- `Dockerfile.hub` - Docker Hub专用Dockerfile

### 部署步骤
1. 构建镜像：`docker build -f Dockerfile.hub -t oycx04/ai-app:latest .`
2. 推送到Docker Hub：`docker push oycx04/ai-app:latest`
3. 在服务器上拉取并运行：
   ```bash
   docker pull oycx04/ai-app:latest
   docker run -d -p 80:80 -p 5000:5000 \
     -e DATABASE_URL="your-db-url" \
     -e JWT_SECRET_KEY="your-jwt-key" \
     -e REDIS_URL="your-redis-url" \
     oycx04/ai-app:latest
   ```

## 4. 域名配置 (15468597.top)

### DNS设置
1. 登录域名管理面板
2. 添加以下DNS记录：

#### 如果使用Vercel：
```
类型: CNAME
名称: @
值: cname.vercel-dns.com

类型: CNAME  
名称: www
值: cname.vercel-dns.com
```

#### 如果使用VPS/云服务器：
```
类型: A
名称: @
值: [服务器IP地址]

类型: A
名称: www  
值: [服务器IP地址]
```

### SSL证书
- Vercel：自动提供SSL证书
- 自建服务器：使用Let's Encrypt或购买SSL证书

## 5. 部署验证

### 检查项目
- [ ] 前端页面正常加载
- [ ] API接口响应正常
- [ ] 数据库连接成功
- [ ] Redis缓存工作正常
- [ ] 用户认证功能正常
- [ ] 域名解析正确
- [ ] SSL证书有效

### 测试URL
- 主页：https://15468597.top
- API健康检查：https://15468597.top/api/health
- 管理页面：https://15468597.top/admin/oycx2004.html

## 6. 监控和维护

### 日志监控
- Vercel：在Dashboard中查看Function Logs
- Docker：使用 `docker logs container-name`

### 性能监控
- 使用Vercel Analytics
- 配置Uptime监控服务

### 备份策略
- 数据库定期备份
- 代码版本控制（GitHub）
- 配置文件备份

## 故障排除

### 常见问题
1. **部署失败**：检查环境变量配置
2. **数据库连接失败**：验证DATABASE_URL格式
3. **域名不解析**：检查DNS设置和传播时间
4. **SSL证书问题**：等待证书自动颁发或手动配置

### 联系支持
- Vercel Support: https://vercel.com/support
- Docker Hub Support: https://hub.docker.com/support

---

**部署完成后，您的AI应用将在以下地址可用：**
- 🌐 主域名：https://15468597.top
- 🚀 Vercel：[部署后获得]
- 🐳 Docker Hub：https://hub.docker.com/r/oycx04/ai-app