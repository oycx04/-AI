# 域名和SSL证书配置指南

## 📋 域名配置准备

### 1. 域名选择建议
- **主域名**：选择简短易记的域名（如：myai-app.com）
- **子域名规划**：
  - `www.myai-app.com` - 主站
  - `api.myai-app.com` - API服务
  - `admin.myai-app.com` - 管理后台
  - `static.myai-app.com` - 静态资源

### 2. DNS配置
```
# A记录配置示例
www.myai-app.com     A    服务器IP地址
api.myai-app.com     A    服务器IP地址
admin.myai-app.com   A    服务器IP地址
static.myai-app.com  A    服务器IP地址

# CNAME记录（如果使用CDN）
www.myai-app.com     CNAME  your-cdn-domain.com
```

## 🔒 SSL证书配置

### 1. 免费SSL证书（推荐Let's Encrypt）

#### 安装Certbot
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install certbot python3-certbot-nginx

# CentOS/RHEL
sudo yum install certbot python3-certbot-nginx
```

#### 获取SSL证书
```bash
# 为单个域名申请证书
sudo certbot --nginx -d myai-app.com -d www.myai-app.com

# 为多个子域名申请证书
sudo certbot --nginx -d myai-app.com -d www.myai-app.com -d api.myai-app.com -d admin.myai-app.com
```

#### 自动续期配置
```bash
# 添加到crontab
sudo crontab -e

# 每天凌晨2点检查证书续期
0 2 * * * /usr/bin/certbot renew --quiet
```

### 2. 商业SSL证书配置

#### 生成CSR（证书签名请求）
```bash
# 生成私钥
openssl genrsa -out myai-app.com.key 2048

# 生成CSR
openssl req -new -key myai-app.com.key -out myai-app.com.csr
```

#### 证书安装
```bash
# 将证书文件放置到指定目录
sudo mkdir -p /etc/ssl/certs/myai-app/
sudo cp myai-app.com.crt /etc/ssl/certs/myai-app/
sudo cp myai-app.com.key /etc/ssl/private/myai-app/
sudo cp ca-bundle.crt /etc/ssl/certs/myai-app/
```

## 🌐 Nginx SSL配置

### 完整的Nginx配置文件
```nginx
# /etc/nginx/sites-available/myai-app.com
server {
    listen 80;
    server_name myai-app.com www.myai-app.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name myai-app.com www.myai-app.com;

    # SSL证书配置
    ssl_certificate /etc/letsencrypt/live/myai-app.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/myai-app.com/privkey.pem;
    
    # SSL安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # HSTS安全头
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    # 前端静态文件
    location / {
        root /var/www/myai-app/frontend;
        index index.html;
        try_files $uri $uri/ /index.html;
        
        # 缓存配置
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # API代理
    location /api/ {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # 超时配置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 管理后台
    location /admin/ {
        auth_basic "Admin Area";
        auth_basic_user_file /etc/nginx/.htpasswd;
        
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# API子域名配置
server {
    listen 443 ssl http2;
    server_name api.myai-app.com;

    ssl_certificate /etc/letsencrypt/live/myai-app.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/myai-app.com/privkey.pem;
    
    # CORS配置
    add_header Access-Control-Allow-Origin "https://myai-app.com" always;
    add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
    add_header Access-Control-Allow-Headers "Content-Type, Authorization" always;

    location / {
        if ($request_method = 'OPTIONS') {
            return 204;
        }
        
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 🔧 应用配置更新

### 1. 更新前端配置
```javascript
// frontend/js/config.js
const CONFIG = {
    // 生产环境API地址
    API_BASE_URL: 'https://api.myai-app.com',
    
    // 开发环境API地址
    // API_BASE_URL: 'http://localhost:5000',
    
    // 其他配置
    UPLOAD_MAX_SIZE: 10 * 1024 * 1024, // 10MB
    SUPPORTED_FORMATS: ['jpg', 'jpeg', 'png', 'gif']
};
```

### 2. 更新后端配置
```python
# backend/config.py
import os

class ProductionConfig:
    # 域名配置
    DOMAIN = 'myai-app.com'
    API_DOMAIN = 'api.myai-app.com'
    
    # HTTPS配置
    FORCE_HTTPS = True
    
    # CORS配置
    CORS_ORIGINS = [
        'https://myai-app.com',
        'https://www.myai-app.com'
    ]
    
    # 安全配置
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'your-secret-key-here'
    
    # 数据库配置
    MONGODB_URI = os.environ.get('MONGODB_URI') or 'mongodb://localhost:27017/myai_app'
```

### 3. 更新统计配置
```javascript
// frontend/analytics-config.js
const AnalyticsConfig = {
    googleAnalytics: {
        enabled: true,
        measurementId: 'G-YOUR-GA-ID', // 替换为真实的GA ID
        config: {
            cookie_domain: 'myai-app.com',
            anonymize_ip: true
        }
    },
    baiduAnalytics: {
        enabled: true,
        siteId: 'your-baidu-site-id' // 替换为真实的百度统计ID
    }
};
```

## 📝 部署检查清单

### 域名配置检查
- [ ] 域名已购买并完成实名认证
- [ ] DNS解析已配置并生效
- [ ] 子域名解析已配置
- [ ] 域名备案已完成（如需要）

### SSL证书检查
- [ ] SSL证书已申请并安装
- [ ] 证书包含所有需要的域名
- [ ] 自动续期已配置
- [ ] HTTPS重定向已配置
- [ ] SSL安全评级达到A+

### 安全配置检查
- [ ] 防火墙已配置
- [ ] 管理后台已设置密码保护
- [ ] 敏感文件已设置访问限制
- [ ] 安全头已配置
- [ ] 日志监控已启用

### 性能优化检查
- [ ] 静态资源缓存已配置
- [ ] Gzip压缩已启用
- [ ] CDN已配置（可选）
- [ ] 数据库连接池已优化
- [ ] 监控告警已配置

## 🚀 快速部署脚本

```bash
#!/bin/bash
# deploy-ssl.sh

# 设置变量
DOMAIN="myai-app.com"
EMAIL="your-email@example.com"

# 安装Certbot
sudo apt update
sudo apt install -y certbot python3-certbot-nginx

# 申请SSL证书
sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN -d api.$DOMAIN -d admin.$DOMAIN --email $EMAIL --agree-tos --non-interactive

# 配置自动续期
echo "0 2 * * * /usr/bin/certbot renew --quiet" | sudo crontab -

# 重启Nginx
sudo systemctl restart nginx

# 检查SSL配置
sudo nginx -t

echo "SSL配置完成！请访问 https://$DOMAIN 验证"
```

## 📞 技术支持

如果在配置过程中遇到问题，可以参考以下资源：
- Let's Encrypt官方文档：https://letsencrypt.org/docs/
- Nginx SSL配置指南：https://nginx.org/en/docs/http/configuring_https_servers.html
- SSL Labs测试工具：https://www.ssllabs.com/ssltest/

---

**注意**：请根据实际情况修改域名、IP地址和证书路径等配置信息。在生产环境部署前，建议先在测试环境验证所有配置。