# AI应用部署指南

## 快速部署

### 1. 本地开发环境

```bash
# 启动后端服务
cd backend
python app.py

# 启动前端服务（新终端）
cd frontend
python -m http.server 8000
```

访问：
- 前端：http://localhost:8000
- 后端API：http://localhost:5000
- 管理面板：http://localhost:8000/admin-analytics.html

### 2. Docker部署

```bash
# 构建并启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

### 3. 生产环境部署（带Nginx）

```bash
# 启动完整的生产环境
docker-compose --profile production up -d
```

## 数据库配置

### MongoDB连接

1. 编辑 `backend/config.py`
2. 更新 `MONGODB_URI` 为你的MongoDB连接字符串
3. 如果连接失败，系统会自动使用本地文件存储

### 当前配置的MongoDB

```
mongodb+srv://1184053958_db_user:pumG4uidb95xZhzf@cluster0.wapqtqm.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0
```

**注意：** 如果认证失败，请检查：
- 用户名和密码是否正确
- 数据库用户权限是否足够
- 网络连接是否正常

## SSL证书获取

### 方法1：Let's Encrypt（免费）

```bash
# 使用提供的SSL自动化脚本
./ssl-auto.sh your-domain.com
```

### 方法2：手动申请

1. **免费证书提供商：**
   - Let's Encrypt（推荐）
   - ZeroSSL
   - SSL For Free

2. **付费证书提供商：**
   - 阿里云SSL证书
   - 腾讯云SSL证书
   - DigiCert
   - Comodo

3. **申请步骤：**
   ```bash
   # 安装certbot
   sudo apt-get install certbot
   
   # 申请证书
   sudo certbot certonly --standalone -d your-domain.com
   
   # 证书文件位置
   # /etc/letsencrypt/live/your-domain.com/fullchain.pem
   # /etc/letsencrypt/live/your-domain.com/privkey.pem
   ```

## 域名获取

### 国内域名注册商
- **阿里云（万网）**：https://wanwang.aliyun.com/
- **腾讯云**：https://dnspod.cloud.tencent.com/
- **华为云**：https://www.huaweicloud.com/product/domain.html
- **百度云**：https://cloud.baidu.com/product/bcd.html

### 国外域名注册商
- **Namecheap**：https://www.namecheap.com/
- **GoDaddy**：https://www.godaddy.com/
- **Cloudflare**：https://www.cloudflare.com/

### 域名配置步骤

1. **购买域名**
2. **配置DNS解析**
   ```
   A记录：@ -> 你的服务器IP
   A记录：www -> 你的服务器IP
   ```
3. **等待DNS生效**（通常5-30分钟）
4. **验证解析**
   ```bash
   nslookup your-domain.com
   ```

## 服务器要求

### 最低配置
- CPU：1核
- 内存：1GB
- 存储：10GB
- 带宽：1Mbps

### 推荐配置
- CPU：2核
- 内存：2GB
- 存储：20GB SSD
- 带宽：5Mbps

### 云服务器推荐
- **阿里云ECS**
- **腾讯云CVM**
- **华为云ECS**
- **AWS EC2**
- **DigitalOcean**

## 监控和维护

### 使用监控脚本

```bash
# 安装监控服务
./monitor.sh install

# 启动监控
./monitor.sh start

# 查看状态
./monitor.sh status
```

### 日志查看

```bash
# Docker日志
docker-compose logs -f ai-app

# 应用日志
tail -f logs/app.log

# Nginx日志
tail -f logs/nginx/access.log
```

## 故障排除

### 常见问题

1. **API连接失败**
   - 检查后端服务是否启动
   - 检查端口是否被占用
   - 检查防火墙设置

2. **MongoDB连接失败**
   - 检查连接字符串
   - 检查网络连接
   - 系统会自动切换到本地存储

3. **SSL证书问题**
   - 检查证书文件路径
   - 检查证书是否过期
   - 使用 `./check-domain.sh` 检查

### 联系支持

如果遇到问题，请提供：
- 错误日志
- 系统环境信息
- 部署配置

## 安全建议

1. **定期更新**
   - 更新系统包
   - 更新Docker镜像
   - 更新SSL证书

2. **访问控制**
   - 配置防火墙
   - 限制管理面板访问
   - 使用强密码

3. **备份策略**
   - 定期备份数据
   - 备份配置文件
   - 测试恢复流程