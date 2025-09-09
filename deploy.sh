#!/bin/bash

# AI应用生产环境部署脚本
# 使用方法: ./deploy.sh [domain] [email] 或 ./deploy.sh [start|stop|restart|logs|status]
# 示例: ./deploy.sh myai-app.com admin@myai-app.com

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]] && [[ "$1" != "start" ]] && [[ "$1" != "stop" ]] && [[ "$1" != "restart" ]] && [[ "$1" != "logs" ]] && [[ "$1" != "status" ]]; then
        log_error "完整部署需要root权限"
        log_info "请使用: sudo $0 $@"
        log_info "或使用管理命令: $0 [start|stop|restart|logs|status]"
        exit 1
    fi
}

# 检查系统要求
check_system() {
    log_info "检查系统要求..."
    
    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        log_error "不支持的操作系统"
        exit 1
    fi
    
    source /etc/os-release
    log_info "操作系统: $PRETTY_NAME"
    
    # 检查内存
    MEMORY=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [[ $MEMORY -lt 1024 ]]; then
        log_warning "内存不足1GB，可能影响性能"
    fi
    
    log_success "系统检查完成"
}

# 检查Docker和Docker Compose
check_dependencies() {
    log_info "检查依赖..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先安装Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose未安装，请先安装Docker Compose"
        exit 1
    fi
    
    log_success "依赖检查通过"
}

# 安装系统依赖
install_system_dependencies() {
    log_info "安装系统依赖..."
    
    # 更新包管理器
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y curl wget git nginx certbot python3-certbot-nginx ufw fail2ban
    elif command -v yum &> /dev/null; then
        yum update -y
        yum install -y curl wget git nginx certbot python3-certbot-nginx firewalld fail2ban
    else
        log_error "不支持的包管理器"
        exit 1
    fi
    
    log_success "系统依赖安装完成"
}

# 配置SSL证书
setup_ssl() {
    local domain=$1
    local email=$2
    
    log_info "为域名 $domain 申请SSL证书..."
    
    # 停止nginx以释放80端口
    systemctl stop nginx 2>/dev/null || true
    
    # 申请证书
    certbot certonly --standalone \
        --non-interactive \
        --agree-tos \
        --email "$email" \
        -d "$domain" \
        -d "www.$domain" \
        -d "api.$domain" \
        -d "admin.$domain"
    
    if [[ $? -eq 0 ]]; then
        log_success "SSL证书申请成功"
        
        # 设置自动续期
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
        
        # 创建证书软链接
        mkdir -p ./ssl
        ln -sf "/etc/letsencrypt/live/$domain/fullchain.pem" ./ssl/fullchain.pem
        ln -sf "/etc/letsencrypt/live/$domain/privkey.pem" ./ssl/privkey.pem
        ln -sf "/etc/letsencrypt/live/$domain/chain.pem" ./ssl/chain.pem
    else
        log_error "SSL证书申请失败"
        exit 1
    fi
}

# 创建必要的目录
setup_directories() {
    log_info "创建必要的目录..."
    mkdir -p logs/nginx
    mkdir -p ssl
    log_success "目录创建完成"
}

# 启动服务
start_services() {
    log_info "启动AI应用服务..."
    docker-compose up -d --build
    
    log_info "等待服务启动..."
    sleep 10
    
    # 检查服务状态
    if docker-compose ps | grep -q "Up"; then
        log_success "服务启动成功！"
        log_info "前端访问地址: http://localhost"
        log_info "后端API地址: http://localhost/api"
    else
        log_error "服务启动失败，请检查日志"
        docker-compose logs
        exit 1
    fi
}

# 停止服务
stop_services() {
    log_info "停止AI应用服务..."
    docker-compose down
    log_success "服务已停止"
}

# 重启服务
restart_services() {
    log_info "重启AI应用服务..."
    stop_services
    start_services
}

# 查看日志
view_logs() {
    log_info "查看服务日志..."
    docker-compose logs -f
}

# 查看服务状态
check_status() {
    log_info "服务状态:"
    docker-compose ps
    
    log_info "\n磁盘使用情况:"
    docker system df
    
    log_info "\n网络连接测试:"
    if curl -s http://localhost > /dev/null; then
        log_success "前端服务正常"
    else
        log_warning "前端服务异常"
    fi
    
    if curl -s http://localhost/api/health > /dev/null; then
        log_success "后端API服务正常"
    else
        log_warning "后端API服务异常"
    fi
}

# 清理资源
cleanup() {
    log_info "清理Docker资源..."
    docker-compose down -v
    docker system prune -f
    log_success "清理完成"
}

# 备份数据
backup() {
    log_info "备份应用数据..."
    BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # 备份日志
    cp -r logs "$BACKUP_DIR/"
    
    # 备份配置
    cp docker-compose.yml nginx.conf "$BACKUP_DIR/"
    
    log_success "备份完成: $BACKUP_DIR"
}

# 主函数
main() {
    case "$1" in
        start)
            check_dependencies
            setup_directories
            start_services
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        logs)
            view_logs
            ;;
        status)
            check_status
            ;;
        cleanup)
            cleanup
            ;;
        backup)
            backup
            ;;
        *)
            echo "使用方法: $0 {start|stop|restart|logs|status|cleanup|backup}"
            echo ""
            echo "命令说明:"
            echo "  start   - 启动所有服务"
            echo "  stop    - 停止所有服务"
            echo "  restart - 重启所有服务"
            echo "  logs    - 查看实时日志"
            echo "  status  - 查看服务状态"
            echo "  cleanup - 清理Docker资源"
            echo "  backup  - 备份应用数据"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"