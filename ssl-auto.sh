#!/bin/bash

# SSL证书自动申请和续期脚本
# 支持Let's Encrypt免费证书
# 使用方法: ./ssl-auto.sh [command] [domain]

set -e

# 配置变量
CERTBOT_EMAIL="admin@example.com"  # 请修改为您的邮箱
WEBROOT_PATH="/var/www/html"       # 网站根目录
NGINX_CONFIG_PATH="/etc/nginx"     # Nginx配置目录
SSL_CERT_PATH="/etc/letsencrypt"   # SSL证书存储路径
BACKUP_PATH="/backup/ssl"          # 证书备份路径

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo $0 $@"
        exit 1
    fi
}

# 检查系统依赖
check_dependencies() {
    log_step "检查系统依赖..."
    
    local deps=("certbot" "nginx" "curl" "openssl")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warning "缺少依赖: ${missing_deps[*]}"
        log_info "正在安装依赖..."
        
        # 检测系统类型并安装依赖
        if command -v apt-get &> /dev/null; then
            apt-get update
            apt-get install -y certbot python3-certbot-nginx nginx curl openssl
        elif command -v yum &> /dev/null; then
            yum install -y certbot python3-certbot-nginx nginx curl openssl
        elif command -v dnf &> /dev/null; then
            dnf install -y certbot python3-certbot-nginx nginx curl openssl
        else
            log_error "不支持的系统，请手动安装: ${missing_deps[*]}"
            exit 1
        fi
        
        log_success "依赖安装完成"
    else
        log_success "所有依赖已安装"
    fi
}

# 验证域名
validate_domain() {
    local domain=$1
    
    if [[ -z "$domain" ]]; then
        log_error "域名不能为空"
        return 1
    fi
    
    # 验证域名格式
    if [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        log_error "无效的域名格式: $domain"
        return 1
    fi
    
    # 检查域名解析
    log_info "检查域名 $domain 的DNS解析..."
    local ip=$(dig +short "$domain" 2>/dev/null | tail -n1)
    
    if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_success "域名 $domain 解析到: $ip"
        return 0
    else
        log_error "域名 $domain DNS解析失败"
        return 1
    fi
}

# 检查端口80是否可用
check_port_80() {
    log_info "检查端口80可用性..."
    
    if netstat -tlnp | grep -q ":80 "; then
        local process=$(netstat -tlnp | grep ":80 " | awk '{print $7}' | head -1)
        log_warning "端口80被占用: $process"
        
        # 如果是nginx占用，尝试停止
        if [[ "$process" =~ nginx ]]; then
            log_info "停止nginx服务以释放端口80..."
            systemctl stop nginx
            sleep 2
            
            if ! netstat -tlnp | grep -q ":80 "; then
                log_success "端口80已释放"
                return 0
            else
                log_error "无法释放端口80"
                return 1
            fi
        else
            log_error "端口80被其他进程占用，请手动处理"
            return 1
        fi
    else
        log_success "端口80可用"
        return 0
    fi
}

# 创建webroot目录
setup_webroot() {
    local domain=$1
    local webroot="$WEBROOT_PATH/$domain"
    
    log_info "设置webroot目录: $webroot"
    
    mkdir -p "$webroot/.well-known/acme-challenge"
    chown -R www-data:www-data "$webroot" 2>/dev/null || chown -R nginx:nginx "$webroot" 2>/dev/null || true
    chmod -R 755 "$webroot"
    
    # 创建临时nginx配置
    local temp_config="/etc/nginx/sites-available/temp-$domain"
    
    cat > "$temp_config" << EOF
server {
    listen 80;
    server_name $domain www.$domain;
    
    location /.well-known/acme-challenge/ {
        root $webroot;
        try_files \$uri =404;
    }
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}
EOF
    
    # 启用配置
    if [[ -d "/etc/nginx/sites-enabled" ]]; then
        ln -sf "$temp_config" "/etc/nginx/sites-enabled/temp-$domain"
    fi
    
    # 测试nginx配置
    if nginx -t; then
        systemctl reload nginx
        log_success "临时nginx配置已生效"
    else
        log_error "nginx配置测试失败"
        return 1
    fi
}

# 申请SSL证书
obtain_certificate() {
    local domain=$1
    local email=${2:-$CERTBOT_EMAIL}
    
    log_step "为域名 $domain 申请SSL证书..."
    
    # 构建域名列表
    local domain_args="-d $domain -d www.$domain"
    
    # 检查是否需要添加其他子域名
    local subdomains=("api" "admin" "cdn")
    for subdomain in "${subdomains[@]}"; do
        local full_domain="$subdomain.$domain"
        if dig +short "$full_domain" &>/dev/null; then
            domain_args="$domain_args -d $full_domain"
            log_info "添加子域名: $full_domain"
        fi
    done
    
    # 申请证书
    log_info "执行certbot命令..."
    
    if certbot certonly \
        --webroot \
        --webroot-path="$WEBROOT_PATH/$domain" \
        --email="$email" \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        $domain_args; then
        
        log_success "SSL证书申请成功！"
        
        # 显示证书信息
        local cert_path="/etc/letsencrypt/live/$domain"
        if [[ -f "$cert_path/fullchain.pem" ]]; then
            log_info "证书路径: $cert_path"
            
            # 显示证书有效期
            local expiry=$(openssl x509 -in "$cert_path/fullchain.pem" -noout -enddate | cut -d= -f2)
            log_info "证书到期时间: $expiry"
        fi
        
        return 0
    else
        log_error "SSL证书申请失败"
        return 1
    fi
}

# 配置nginx SSL
configure_nginx_ssl() {
    local domain=$1
    local cert_path="/etc/letsencrypt/live/$domain"
    
    log_step "配置nginx SSL..."
    
    # 检查证书文件
    if [[ ! -f "$cert_path/fullchain.pem" ]] || [[ ! -f "$cert_path/privkey.pem" ]]; then
        log_error "证书文件不存在: $cert_path"
        return 1
    fi
    
    # 创建SSL配置
    local ssl_config="/etc/nginx/sites-available/$domain-ssl"
    
    cat > "$ssl_config" << EOF
# SSL配置 for $domain
# 生成时间: $(date)

server {
    listen 80;
    server_name $domain www.$domain;
    
    # HTTP到HTTPS重定向
    location / {
        return 301 https://\$server_name\$request_uri;
    }
    
    # Let's Encrypt验证
    location /.well-known/acme-challenge/ {
        root $WEBROOT_PATH/$domain;
        try_files \$uri =404;
    }
}

server {
    listen 443 ssl http2;
    server_name $domain www.$domain;
    
    # SSL证书配置
    ssl_certificate $cert_path/fullchain.pem;
    ssl_certificate_key $cert_path/privkey.pem;
    
    # SSL安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # 安全头
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # 网站根目录
    root $WEBROOT_PATH/$domain;
    index index.html index.htm index.php;
    
    # 通用location配置
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # API代理（如果需要）
    location /api/ {
        proxy_pass http://localhost:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # 静态资源缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|txt)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # 安全配置
    location ~ /\. {
        deny all;
    }
}
EOF
    
    # 移除临时配置
    rm -f "/etc/nginx/sites-enabled/temp-$domain"
    rm -f "/etc/nginx/sites-available/temp-$domain"
    
    # 启用SSL配置
    if [[ -d "/etc/nginx/sites-enabled" ]]; then
        ln -sf "$ssl_config" "/etc/nginx/sites-enabled/$domain-ssl"
    fi
    
    # 测试nginx配置
    if nginx -t; then
        systemctl reload nginx
        log_success "nginx SSL配置已生效"
        return 0
    else
        log_error "nginx配置测试失败"
        return 1
    fi
}

# 设置自动续期
setup_auto_renewal() {
    log_step "设置SSL证书自动续期..."
    
    # 创建续期脚本
    local renewal_script="/usr/local/bin/ssl-renewal.sh"
    
    cat > "$renewal_script" << 'EOF'
#!/bin/bash

# SSL证书自动续期脚本
# 由ssl-auto.sh自动生成

set -e

# 日志文件
LOG_FILE="/var/log/ssl-renewal.log"

# 记录日志
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "开始SSL证书续期检查..."

# 续期证书
if /usr/bin/certbot renew --quiet --no-self-upgrade; then
    log "证书续期检查完成"
    
    # 重载nginx
    if systemctl reload nginx; then
        log "nginx重载成功"
    else
        log "nginx重载失败"
    fi
else
    log "证书续期失败"
    exit 1
fi

log "SSL证书续期任务完成"
EOF
    
    chmod +x "$renewal_script"
    
    # 添加crontab任务
    local cron_job="0 2 * * 0 $renewal_script"
    
    # 检查是否已存在
    if ! crontab -l 2>/dev/null | grep -q "$renewal_script"; then
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        log_success "自动续期任务已添加到crontab"
    else
        log_info "自动续期任务已存在"
    fi
    
    # 创建日志轮转配置
    cat > "/etc/logrotate.d/ssl-renewal" << EOF
/var/log/ssl-renewal.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF
    
    log_success "SSL证书自动续期配置完成"
    log_info "续期脚本: $renewal_script"
    log_info "日志文件: /var/log/ssl-renewal.log"
    log_info "执行时间: 每周日凌晨2点"
}

# 备份证书
backup_certificates() {
    local domain=$1
    
    log_step "备份SSL证书..."
    
    local backup_dir="$BACKUP_PATH/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    if [[ -d "/etc/letsencrypt/live/$domain" ]]; then
        cp -r "/etc/letsencrypt/live/$domain" "$backup_dir/"
        cp -r "/etc/letsencrypt/archive/$domain" "$backup_dir/" 2>/dev/null || true
        cp "/etc/letsencrypt/renewal/$domain.conf" "$backup_dir/" 2>/dev/null || true
        
        # 创建备份信息文件
        cat > "$backup_dir/backup-info.txt" << EOF
证书备份信息
============

备份时间: $(date)
域名: $domain
证书路径: /etc/letsencrypt/live/$domain

文件列表:
$(ls -la "$backup_dir/")

证书信息:
$(openssl x509 -in "/etc/letsencrypt/live/$domain/fullchain.pem" -noout -text | head -20)
EOF
        
        log_success "证书备份完成: $backup_dir"
        
        # 清理旧备份（保留最近10个）
        if [[ -d "$BACKUP_PATH" ]]; then
            local old_backups=$(ls -1t "$BACKUP_PATH" | tail -n +11)
            if [[ -n "$old_backups" ]]; then
                echo "$old_backups" | while read -r old_backup; do
                    rm -rf "$BACKUP_PATH/$old_backup"
                    log_info "删除旧备份: $old_backup"
                done
            fi
        fi
    else
        log_warning "证书目录不存在，跳过备份"
    fi
}

# 测试SSL配置
test_ssl_config() {
    local domain=$1
    
    log_step "测试SSL配置..."
    
    # 测试HTTPS连接
    if curl -s --connect-timeout 10 "https://$domain" > /dev/null; then
        log_success "HTTPS连接测试成功"
    else
        log_error "HTTPS连接测试失败"
        return 1
    fi
    
    # 测试SSL证书
    local ssl_info=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        local not_after=$(echo "$ssl_info" | grep "notAfter" | cut -d= -f2)
        log_success "SSL证书有效，到期时间: $not_after"
    else
        log_error "SSL证书验证失败"
        return 1
    fi
    
    # 测试HTTP重定向
    local redirect_code=$(curl -s -o /dev/null -w "%{http_code}" --max-redirs 0 "http://$domain" 2>/dev/null || echo "000")
    
    if [[ "$redirect_code" == "301" ]] || [[ "$redirect_code" == "302" ]]; then
        log_success "HTTP到HTTPS重定向正常"
    else
        log_warning "HTTP重定向可能有问题 (HTTP $redirect_code)"
    fi
    
    log_success "SSL配置测试完成"
}

# 显示证书信息
show_certificate_info() {
    local domain=$1
    local cert_path="/etc/letsencrypt/live/$domain"
    
    if [[ ! -f "$cert_path/fullchain.pem" ]]; then
        log_error "证书不存在: $domain"
        return 1
    fi
    
    echo "=== SSL证书信息 ==="
    echo "域名: $domain"
    echo "证书路径: $cert_path"
    echo
    
    # 证书详细信息
    openssl x509 -in "$cert_path/fullchain.pem" -noout -text | grep -A 2 "Subject:"
    openssl x509 -in "$cert_path/fullchain.pem" -noout -text | grep -A 2 "Issuer:"
    openssl x509 -in "$cert_path/fullchain.pem" -noout -dates
    
    echo
    echo "=== 证书文件 ==="
    ls -la "$cert_path/"
    
    echo
    echo "=== 续期配置 ==="
    if [[ -f "/etc/letsencrypt/renewal/$domain.conf" ]]; then
        cat "/etc/letsencrypt/renewal/$domain.conf"
    else
        echo "续期配置文件不存在"
    fi
}

# 列出所有证书
list_certificates() {
    log_info "列出所有SSL证书..."
    
    if [[ -d "/etc/letsencrypt/live" ]]; then
        echo "=== 已安装的SSL证书 ==="
        
        for cert_dir in /etc/letsencrypt/live/*/; do
            if [[ -d "$cert_dir" ]]; then
                local domain=$(basename "$cert_dir")
                
                if [[ "$domain" != "README" ]]; then
                    echo
                    echo "域名: $domain"
                    
                    if [[ -f "$cert_dir/fullchain.pem" ]]; then
                        local expiry=$(openssl x509 -in "$cert_dir/fullchain.pem" -noout -enddate | cut -d= -f2)
                        local expiry_timestamp=$(date -d "$expiry" +%s 2>/dev/null || echo "0")
                        local current_timestamp=$(date +%s)
                        local days_left=$(( (expiry_timestamp - current_timestamp) / 86400 ))
                        
                        echo "  到期时间: $expiry"
                        
                        if [[ $days_left -gt 30 ]]; then
                            echo -e "  状态: ${GREEN}正常${NC} (还有 $days_left 天)"
                        elif [[ $days_left -gt 0 ]]; then
                            echo -e "  状态: ${YELLOW}即将到期${NC} (还有 $days_left 天)"
                        else
                            echo -e "  状态: ${RED}已过期${NC}"
                        fi
                        
                        # 显示包含的域名
                        local san_domains=$(openssl x509 -in "$cert_dir/fullchain.pem" -noout -text | grep -A 1 "Subject Alternative Name" | tail -1 | sed 's/DNS://g' | tr ',' '\n' | sed 's/^ *//' | tr '\n' ' ')
                        if [[ -n "$san_domains" ]]; then
                            echo "  包含域名: $san_domains"
                        fi
                    else
                        echo -e "  状态: ${RED}证书文件缺失${NC}"
                    fi
                fi
            fi
        done
        
        echo
    else
        log_warning "未找到SSL证书目录"
    fi
}

# 续期证书
renew_certificate() {
    local domain=$1
    
    log_step "续期SSL证书: $domain"
    
    if [[ -n "$domain" ]]; then
        # 续期指定域名
        if certbot renew --cert-name "$domain" --force-renewal; then
            log_success "证书续期成功: $domain"
            
            # 重载nginx
            if systemctl reload nginx; then
                log_success "nginx重载成功"
            else
                log_warning "nginx重载失败"
            fi
        else
            log_error "证书续期失败: $domain"
            return 1
        fi
    else
        # 续期所有证书
        if certbot renew; then
            log_success "所有证书续期检查完成"
            
            # 重载nginx
            if systemctl reload nginx; then
                log_success "nginx重载成功"
            else
                log_warning "nginx重载失败"
            fi
        else
            log_error "证书续期失败"
            return 1
        fi
    fi
}

# 删除证书
revoke_certificate() {
    local domain=$1
    
    if [[ -z "$domain" ]]; then
        log_error "请指定要删除的域名"
        return 1
    fi
    
    log_warning "即将删除域名 $domain 的SSL证书"
    read -p "确认删除？(y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_step "删除SSL证书: $domain"
        
        # 备份证书
        backup_certificates "$domain"
        
        # 撤销证书
        if certbot revoke --cert-path "/etc/letsencrypt/live/$domain/fullchain.pem"; then
            log_success "证书撤销成功"
        else
            log_warning "证书撤销失败，继续删除本地文件"
        fi
        
        # 删除证书文件
        certbot delete --cert-name "$domain"
        
        # 删除nginx配置
        rm -f "/etc/nginx/sites-enabled/$domain-ssl"
        rm -f "/etc/nginx/sites-available/$domain-ssl"
        
        # 重载nginx
        if nginx -t && systemctl reload nginx; then
            log_success "nginx配置已更新"
        else
            log_warning "nginx配置更新失败"
        fi
        
        log_success "SSL证书删除完成: $domain"
    else
        log_info "取消删除操作"
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
SSL证书自动管理工具
==================

使用方法:
  $0 install <domain> [email]     申请并安装SSL证书
  $0 renew [domain]               续期SSL证书（不指定域名则续期所有）
  $0 list                         列出所有SSL证书
  $0 info <domain>                显示证书详细信息
  $0 test <domain>                测试SSL配置
  $0 backup <domain>              备份SSL证书
  $0 revoke <domain>              撤销并删除SSL证书
  $0 setup-auto                   设置自动续期
  $0 -h, --help                  显示帮助信息

示例:
  $0 install myai-app.com admin@myai-app.com
  $0 renew myai-app.com
  $0 list
  $0 info myai-app.com
  $0 test myai-app.com

功能特性:
  ✓ 自动申请Let's Encrypt免费SSL证书
  ✓ 自动配置nginx SSL
  ✓ 支持多域名和子域名
  ✓ 自动续期和监控
  ✓ 证书备份和恢复
  ✓ 安全配置优化
  ✓ 详细的日志记录

配置文件:
  证书路径: /etc/letsencrypt/live/
  nginx配置: /etc/nginx/sites-available/
  备份路径: /backup/ssl/
  日志文件: /var/log/ssl-renewal.log

注意事项:
  1. 需要root权限运行
  2. 确保域名正确解析到服务器
  3. 端口80和443需要开放
  4. 建议定期备份证书文件

EOF
}

# 主函数
main() {
    local command=$1
    local domain=$2
    local email=$3
    
    case "$command" in
        "install")
            if [[ -z "$domain" ]]; then
                log_error "请指定域名"
                show_help
                exit 1
            fi
            
            check_root
            check_dependencies
            validate_domain "$domain" || exit 1
            check_port_80 || exit 1
            setup_webroot "$domain" || exit 1
            obtain_certificate "$domain" "$email" || exit 1
            configure_nginx_ssl "$domain" || exit 1
            setup_auto_renewal
            backup_certificates "$domain"
            test_ssl_config "$domain" || exit 1
            
            log_success "SSL证书安装完成！"
            log_info "请访问 https://$domain 验证配置"
            ;;
            
        "renew")
            check_root
            renew_certificate "$domain"
            ;;
            
        "list")
            list_certificates
            ;;
            
        "info")
            if [[ -z "$domain" ]]; then
                log_error "请指定域名"
                exit 1
            fi
            show_certificate_info "$domain"
            ;;
            
        "test")
            if [[ -z "$domain" ]]; then
                log_error "请指定域名"
                exit 1
            fi
            test_ssl_config "$domain"
            ;;
            
        "backup")
            if [[ -z "$domain" ]]; then
                log_error "请指定域名"
                exit 1
            fi
            check_root
            backup_certificates "$domain"
            ;;
            
        "revoke")
            if [[ -z "$domain" ]]; then
                log_error "请指定域名"
                exit 1
            fi
            check_root
            revoke_certificate "$domain"
            ;;
            
        "setup-auto")
            check_root
            setup_auto_renewal
            ;;
            
        "-h"|"--help"|"")
            show_help
            ;;
            
        *)
            log_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi