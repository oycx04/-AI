# AI应用部署指南 - 15468597.top

## 📋 部署概览

本指南将帮助您将AI应用部署到域名 `15468597.top`，包含完整的VPS部署、DNS配置和SSL证书设置。

## 🎯 部署架构

- **前端**: 静态文件服务 (Nginx)
- **后端**: Python Flask API
- **数据库**: PostgreSQL (Neon云服务)
- **反向代理**: Nginx
- **SSL证书**: Let's Encrypt (免费)
- **容器化**: Docker + Docker Compose

## 📝 准备工作

### 1. VPS要求
- **操作系统**: Ubuntu 20.04+ / Debian 11+
- **内存**: 最少2GB RAM
- **存储**: 最少20GB磁盘空间
- **网络**: 公网IP地址

### 2. 域名配置
需要在域名服务商处配置DNS记录：

```
类型    名称              值
A      15468597.top      [您的VPS IP地址]
A      www.15468597.top  [您的VPS IP地址]
```

## 🚀 部署步骤

### 步骤1: DNS解析配置

1. 登录您的域名服务商管理面板
2. 找到DNS管理或域名解析设置
3. 添加以下记录：
   - **A记录**: `15468597.top` → `您的VPS IP`
   - **A记录**: `www.15468597.top` → `您的VPS IP`
4. 等待DNS传播（通常5-30分钟）

**验证DNS解析**:
```bash
nslookup 15468597.top
ping 15468597.top
```

### 步骤2: VPS部署

#### 方法A: 使用PowerShell脚本（推荐）

```powershell
# 在项目根目录执行
.\deploy-to-vps.ps1 -VpsIP "您的VPS IP" -SshUser "root"
```

#### 方法B: 手动部署

1. **上传项目文件**:
```bash
scp -r . root@您的VPS_IP:/opt/ai-app/
```

2. **SSH连接到VPS**:
```bash
ssh root@您的VPS_IP
```

3. **安装依赖**:
```bash
apt update && apt upgrade -y
apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx
systemctl start docker
systemctl enable docker
```

4. **部署应用**:
```bash
cd /opt/ai-app
docker-compose down || true
docker-compose build
docker-compose up -d
```

5. **配置Nginx**:
```bash
cp nginx.conf /etc/nginx/sites-available/ai-app
ln -sf /etc/nginx/sites-available/ai-app /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx
systemctl enable nginx
```

### 步骤3: SSL证书配置

1. **安装SSL证书**:
```bash
sudo certbot --nginx -d 15468597.top -d www.15468597.top
```

2. **设置自动续期**:
```bash
sudo crontab -e
# 添加以下行
0 12 * * * /usr/bin/certbot renew --quiet
```

### 步骤4: 验证部署

1. **检查服务状态**:
```bash
docker-compose ps
systemctl status nginx
```

2. **测试访问**:
- HTTP: `http://15468597.top` (应该重定向到HTTPS)
- HTTPS: `https://15468597.top`
- API: `https://15468597.top/api/health`

## 🔧 配置文件说明

### Docker Compose配置
- **ai-app服务**: 运行Python后端
- **nginx服务**: 反向代理和静态文件服务
- **网络**: 内部通信网络
- **卷挂载**: 日志持久化

### Nginx配置特点
- **HTTPS重定向**: HTTP自动跳转HTTPS
- **安全头**: HSTS、X-Frame-Options等
- **静态文件缓存**: 1年缓存期
- **API代理**: `/api/`路径代理到后端
- **CORS支持**: 跨域请求支持

## 🛠️ 常用维护命令

### 查看日志
```bash
# 应用日志
docker-compose logs -f ai-app

# Nginx日志
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

### 重启服务
```bash
# 重启应用
docker-compose restart

# 重启Nginx
sudo systemctl restart nginx
```

### 更新部署
```bash
cd /opt/ai-app
git pull origin main
docker-compose build
docker-compose up -d
```

## 🔍 故障排除

### 常见问题

1. **域名无法访问**
   - 检查DNS解析是否生效
   - 确认VPS防火墙开放80/443端口
   - 验证Nginx配置语法

2. **SSL证书申请失败**
   - 确保域名已正确解析到VPS
   - 检查80端口是否被占用
   - 暂时停止Nginx再申请证书

3. **API无法访问**
   - 检查后端容器是否正常运行
   - 验证数据库连接配置
   - 查看应用日志排查错误

### 调试命令
```bash
# 检查端口占用
netstat -tlnp | grep :80
netstat -tlnp | grep :443

# 测试Nginx配置
nginx -t

# 检查SSL证书
openssl s_client -connect 15468597.top:443

# 检查Docker容器
docker ps
docker logs ai-app_ai-app_1
```

## 📊 监控和性能

### 系统监控
```bash
# 系统资源
htop
df -h
free -h

# Docker资源使用
docker stats
```

### 性能优化建议
1. 启用Nginx Gzip压缩
2. 配置静态文件缓存
3. 使用CDN加速静态资源
4. 定期清理Docker镜像和容器
5. 监控数据库性能

## 🔐 安全建议

1. **服务器安全**:
   - 禁用root SSH登录
   - 使用SSH密钥认证
   - 配置防火墙规则
   - 定期更新系统

2. **应用安全**:
   - 定期更新依赖包
   - 配置HTTPS安全头
   - 限制API访问频率
   - 备份重要数据

## 📞 技术支持

如果在部署过程中遇到问题，请检查：
1. 系统日志: `/var/log/syslog`
2. Nginx日志: `/var/log/nginx/`
3. 应用日志: `docker-compose logs`
4. SSL证书状态: `certbot certificates`

---

**部署完成后，您的AI应用将在 `https://15468597.top` 正常运行！** 🎉