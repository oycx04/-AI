#!/bin/bash

# 生产环境监控脚本
# 监控系统资源、服务状态、网站可用性等
# 使用方法: ./monitor.sh [options]

set -e

# 配置变量
MONITOR_CONFIG="/etc/ai-app/monitor.conf"
LOG_DIR="/var/log/ai-app"
ALERT_EMAIL="admin@example.com"
WEBHOOK_URL=""  # Slack/钉钉等webhook地址
CHECK_INTERVAL=60  # 检查间隔（秒）
MAX_LOG_SIZE="100M"  # 日志文件最大大小

# 阈值配置
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90
LOAD_THRESHOLD=5.0
RESPONSE_TIME_THRESHOLD=5000  # 毫秒

# 服务列表
SERVICES=("nginx" "redis" "docker")

# 监控的URL列表
MONITOR_URLS=(
    "https://localhost"
    "https://localhost/api/health"
    "https://localhost/admin"
)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
    echo -e "${BLUE}$msg${NC}"
    echo "$msg" >> "$LOG_DIR/monitor.log"
}

log_success() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
    echo -e "${GREEN}$msg${NC}"
    echo "$msg" >> "$LOG_DIR/monitor.log"
}

log_warning() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1"
    echo -e "${YELLOW}$msg${NC}"
    echo "$msg" >> "$LOG_DIR/monitor.log"
    send_alert "WARNING" "$1"
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo -e "${RED}$msg${NC}"
    echo "$msg" >> "$LOG_DIR/monitor.log"
    send_alert "ERROR" "$1"
}

log_critical() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [CRITICAL] $1"
    echo -e "${RED}${msg}${NC}"
    echo "$msg" >> "$LOG_DIR/monitor.log"
    send_alert "CRITICAL" "$1"
}

# 初始化监控环境
init_monitor() {
    log_info "初始化监控环境..."
    
    # 创建日志目录
    mkdir -p "$LOG_DIR"
    
    # 创建配置目录
    mkdir -p "$(dirname "$MONITOR_CONFIG")"
    
    # 创建默认配置文件
    if [[ ! -f "$MONITOR_CONFIG" ]]; then
        cat > "$MONITOR_CONFIG" << EOF
# AI应用监控配置文件
# 生成时间: $(date)

# 邮件配置
ALERT_EMAIL="$ALERT_EMAIL"
SMTP_SERVER="localhost"
SMTP_PORT="25"

# Webhook配置
WEBHOOK_URL="$WEBHOOK_URL"

# 监控阈值
CPU_THRESHOLD=$CPU_THRESHOLD
MEMORY_THRESHOLD=$MEMORY_THRESHOLD
DISK_THRESHOLD=$DISK_THRESHOLD
LOAD_THRESHOLD=$LOAD_THRESHOLD
RESPONSE_TIME_THRESHOLD=$RESPONSE_TIME_THRESHOLD

# 检查间隔（秒）
CHECK_INTERVAL=$CHECK_INTERVAL

# 监控的服务
SERVICES="${SERVICES[*]}"

# 监控的URL
MONITOR_URLS="${MONITOR_URLS[*]}"
EOF
        log_success "配置文件已创建: $MONITOR_CONFIG"
    fi
    
    # 加载配置
    if [[ -f "$MONITOR_CONFIG" ]]; then
        source "$MONITOR_CONFIG"
        log_info "配置文件已加载"
    fi
    
    log_success "监控环境初始化完成"
}

# 发送告警
send_alert() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 邮件告警
    if [[ -n "$ALERT_EMAIL" ]] && command -v mail &> /dev/null; then
        local subject="[AI应用监控] $level 告警"
        local body="时间: $timestamp\n级别: $level\n消息: $message\n\n服务器: $(hostname)\nIP: $(hostname -I | awk '{print $1}')"
        
        echo -e "$body" | mail -s "$subject" "$ALERT_EMAIL" 2>/dev/null || true
    fi
    
    # Webhook告警
    if [[ -n "$WEBHOOK_URL" ]]; then
        local payload=$(cat << EOF
{
    "msgtype": "text",
    "text": {
        "content": "🚨 AI应用监控告警\n\n级别: $level\n时间: $timestamp\n消息: $message\n服务器: $(hostname)"
    }
}
EOF
        )
        
        curl -s -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "$payload" &> /dev/null || true
    fi
}

# 检查系统资源
check_system_resources() {
    log_info "检查系统资源..."
    
    # CPU使用率
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d',' -f1)
    cpu_usage=${cpu_usage%.*}  # 去掉小数部分
    
    if [[ $cpu_usage -gt $CPU_THRESHOLD ]]; then
        log_warning "CPU使用率过高: ${cpu_usage}% (阈值: ${CPU_THRESHOLD}%)"
    else
        log_success "CPU使用率正常: ${cpu_usage}%"
    fi
    
    # 内存使用率
    local memory_info=$(free | grep Mem)
    local total_mem=$(echo $memory_info | awk '{print $2}')
    local used_mem=$(echo $memory_info | awk '{print $3}')
    local memory_usage=$((used_mem * 100 / total_mem))
    
    if [[ $memory_usage -gt $MEMORY_THRESHOLD ]]; then
        log_warning "内存使用率过高: ${memory_usage}% (阈值: ${MEMORY_THRESHOLD}%)"
    else
        log_success "内存使用率正常: ${memory_usage}%"
    fi
    
    # 磁盘使用率
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | cut -d'%' -f1)
    
    if [[ $disk_usage -gt $DISK_THRESHOLD ]]; then
        log_warning "磁盘使用率过高: ${disk_usage}% (阈值: ${DISK_THRESHOLD}%)"
    else
        log_success "磁盘使用率正常: ${disk_usage}%"
    fi
    
    # 系统负载
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | cut -d',' -f1)
    
    if (( $(echo "$load_avg > $LOAD_THRESHOLD" | bc -l) )); then
        log_warning "系统负载过高: $load_avg (阈值: $LOAD_THRESHOLD)"
    else
        log_success "系统负载正常: $load_avg"
    fi
    
    # 网络连接数
    local connections=$(netstat -an | grep ESTABLISHED | wc -l)
    log_info "当前网络连接数: $connections"
    
    # 进程数
    local processes=$(ps aux | wc -l)
    log_info "当前进程数: $processes"
}

# 检查服务状态
check_services() {
    log_info "检查服务状态..."
    
    for service in ${SERVICES[@]}; do
        if systemctl is-active --quiet "$service"; then
            log_success "服务 $service 运行正常"
            
            # 检查服务资源使用
            local pid=$(systemctl show --property MainPID --value "$service")
            if [[ "$pid" != "0" ]] && [[ -n "$pid" ]]; then
                local cpu_usage=$(ps -p "$pid" -o %cpu --no-headers 2>/dev/null | awk '{print $1}' || echo "0")
                local mem_usage=$(ps -p "$pid" -o %mem --no-headers 2>/dev/null | awk '{print $1}' || echo "0")
                log_info "服务 $service 资源使用 - CPU: ${cpu_usage}%, 内存: ${mem_usage}%"
            fi
        else
            log_error "服务 $service 未运行"
            
            # 尝试重启服务
            log_info "尝试重启服务 $service..."
            if systemctl restart "$service"; then
                log_success "服务 $service 重启成功"
            else
                log_critical "服务 $service 重启失败"
            fi
        fi
    done
}

# 检查Docker容器
check_docker_containers() {
    if ! command -v docker &> /dev/null; then
        return 0
    fi
    
    log_info "检查Docker容器状态..."
    
    # 获取所有容器
    local containers=$(docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | tail -n +2)
    
    if [[ -z "$containers" ]]; then
        log_info "未发现Docker容器"
        return 0
    fi
    
    while IFS=$'\t' read -r name status image; do
        if [[ "$status" =~ ^Up ]]; then
            log_success "容器 $name 运行正常 ($image)"
            
            # 检查容器资源使用
            local stats=$(docker stats --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}" "$name" 2>/dev/null | tail -n +2)
            if [[ -n "$stats" ]]; then
                log_info "容器 $name 资源使用: $stats"
            fi
        else
            log_error "容器 $name 状态异常: $status"
            
            # 尝试重启容器
            log_info "尝试重启容器 $name..."
            if docker restart "$name" &> /dev/null; then
                log_success "容器 $name 重启成功"
            else
                log_critical "容器 $name 重启失败"
            fi
        fi
    done <<< "$containers"
}

# 检查网站可用性
check_website_availability() {
    log_info "检查网站可用性..."
    
    for url in ${MONITOR_URLS[@]}; do
        log_info "检查URL: $url"
        
        # 测试HTTP响应
        local start_time=$(date +%s%3N)
        local response=$(curl -s -o /dev/null -w "%{http_code}:%{time_total}" --connect-timeout 10 --max-time 30 "$url" 2>/dev/null || echo "000:0")
        local end_time=$(date +%s%3N)
        
        local http_code=$(echo "$response" | cut -d':' -f1)
        local response_time=$(echo "$response" | cut -d':' -f2)
        local response_time_ms=$(echo "$response_time * 1000" | bc -l | cut -d'.' -f1)
        
        if [[ "$http_code" == "200" ]]; then
            if [[ $response_time_ms -gt $RESPONSE_TIME_THRESHOLD ]]; then
                log_warning "$url 响应时间过长: ${response_time_ms}ms (阈值: ${RESPONSE_TIME_THRESHOLD}ms)"
            else
                log_success "$url 访问正常 (${response_time_ms}ms)"
            fi
        elif [[ "$http_code" == "000" ]]; then
            log_error "$url 连接失败"
        else
            log_error "$url 响应异常: HTTP $http_code"
        fi
        
        # 检查SSL证书（HTTPS）
        if [[ "$url" =~ ^https:// ]]; then
            local domain=$(echo "$url" | sed 's|https://||' | cut -d'/' -f1)
            check_ssl_certificate "$domain"
        fi
    done
}

# 检查SSL证书
check_ssl_certificate() {
    local domain=$1
    
    log_info "检查SSL证书: $domain"
    
    local ssl_info=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        local not_after=$(echo "$ssl_info" | grep "notAfter" | cut -d= -f2)
        local expiry_date=$(date -d "$not_after" +%s 2>/dev/null || echo "0")
        local current_date=$(date +%s)
        local days_left=$(( (expiry_date - current_date) / 86400 ))
        
        if [[ $days_left -lt 7 ]]; then
            log_critical "$domain SSL证书即将到期: $days_left 天"
        elif [[ $days_left -lt 30 ]]; then
            log_warning "$domain SSL证书即将到期: $days_left 天"
        else
            log_success "$domain SSL证书有效: $days_left 天后到期"
        fi
    else
        log_error "$domain SSL证书检查失败"
    fi
}

# 检查数据库连接
check_database_connections() {
    log_info "检查数据库连接..."
    
    # MongoDB已移除，现在使用PostgreSQL
    log_info "数据库已切换到PostgreSQL"
    
    # Redis
    if command -v redis-cli &> /dev/null; then
        if redis-cli ping &> /dev/null; then
            log_success "Redis连接正常"
            
            # 检查Redis信息
            local redis_info=$(redis-cli info memory 2>/dev/null | grep used_memory_human | cut -d':' -f2 | tr -d '\r')
            if [[ -n "$redis_info" ]]; then
                log_info "Redis内存使用: $redis_info"
            fi
        else
            log_error "Redis连接失败"
        fi
    fi
}

# 检查日志文件
check_log_files() {
    log_info "检查日志文件..."
    
    local log_files=(
        "/var/log/nginx/error.log"
        "/var/log/ai-app/app.log"
        "$LOG_DIR/monitor.log"
    )
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            local file_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo "0")
            local file_size_mb=$((file_size / 1024 / 1024))
            
            log_info "日志文件 $log_file: ${file_size_mb}MB"
            
            # 检查是否有错误日志
            local error_count=$(grep -c "ERROR\|CRITICAL\|FATAL" "$log_file" 2>/dev/null || echo "0")
            if [[ $error_count -gt 0 ]]; then
                log_warning "$log_file 包含 $error_count 个错误日志"
            fi
            
            # 检查日志文件大小
            if [[ $file_size_mb -gt 100 ]]; then
                log_warning "日志文件 $log_file 过大: ${file_size_mb}MB"
            fi
        fi
    done
}

# 生成监控报告
generate_report() {
    local report_file="$LOG_DIR/monitor-report-$(date +%Y%m%d_%H%M%S).html"
    
    log_info "生成监控报告: $report_file"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AI应用监控报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { text-align: center; color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }
        .section { margin: 20px 0; }
        .section h3 { color: #007bff; border-left: 4px solid #007bff; padding-left: 10px; }
        .status-ok { color: #28a745; }
        .status-warning { color: #ffc107; }
        .status-error { color: #dc3545; }
        .metric { display: inline-block; margin: 10px; padding: 10px; background: #f8f9fa; border-radius: 4px; min-width: 150px; }
        .metric-label { font-weight: bold; }
        .metric-value { font-size: 1.2em; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f8f9fa; }
        .footer { text-align: center; color: #666; font-size: 0.9em; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🖥️ AI应用监控报告</h1>
            <p>生成时间: $(date '+%Y-%m-%d %H:%M:%S')</p>
            <p>服务器: $(hostname) ($(hostname -I | awk '{print $1}'))</p>
        </div>
        
        <div class="section">
            <h3>📊 系统资源</h3>
            <div class="metric">
                <div class="metric-label">CPU使用率</div>
                <div class="metric-value">$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)</div>
            </div>
            <div class="metric">
                <div class="metric-label">内存使用率</div>
                <div class="metric-value">$(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')</div>
            </div>
            <div class="metric">
                <div class="metric-label">磁盘使用率</div>
                <div class="metric-value">$(df / | tail -1 | awk '{print $5}')</div>
            </div>
            <div class="metric">
                <div class="metric-label">系统负载</div>
                <div class="metric-value">$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | cut -d',' -f1)</div>
            </div>
        </div>
        
        <div class="section">
            <h3>🔧 服务状态</h3>
            <table>
                <tr><th>服务名称</th><th>状态</th><th>运行时间</th></tr>
EOF
    
    # 添加服务状态
    for service in ${SERVICES[@]}; do
        local status="❌ 停止"
        local uptime="-"
        
        if systemctl is-active --quiet "$service"; then
            status="✅ 运行中"
            uptime=$(systemctl show --property ActiveEnterTimestamp --value "$service" | xargs -I {} date -d "{}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "未知")
        fi
        
        echo "                <tr><td>$service</td><td>$status</td><td>$uptime</td></tr>" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF
            </table>
        </div>
        
        <div class="section">
            <h3>🌐 网站可用性</h3>
            <table>
                <tr><th>URL</th><th>状态</th><th>响应时间</th></tr>
EOF
    
    # 添加网站状态
    for url in ${MONITOR_URLS[@]}; do
        local response=$(curl -s -o /dev/null -w "%{http_code}:%{time_total}" --connect-timeout 10 --max-time 30 "$url" 2>/dev/null || echo "000:0")
        local http_code=$(echo "$response" | cut -d':' -f1)
        local response_time=$(echo "$response" | cut -d':' -f2)
        local response_time_ms=$(echo "$response_time * 1000" | bc -l | cut -d'.' -f1)
        
        local status="❌ 异常"
        if [[ "$http_code" == "200" ]]; then
            status="✅ 正常"
        fi
        
        echo "                <tr><td>$url</td><td>$status (HTTP $http_code)</td><td>${response_time_ms}ms</td></tr>" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF
            </table>
        </div>
        
        <div class="section">
            <h3>💾 存储信息</h3>
            <table>
                <tr><th>挂载点</th><th>文件系统</th><th>大小</th><th>已用</th><th>可用</th><th>使用率</th></tr>
EOF
    
    # 添加磁盘信息
    df -h | grep -E '^/dev/' | while read filesystem size used avail percent mount; do
        echo "                <tr><td>$mount</td><td>$filesystem</td><td>$size</td><td>$used</td><td>$avail</td><td>$percent</td></tr>" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF
            </table>
        </div>
        
        <div class="footer">
            <p>📝 详细日志请查看: $LOG_DIR/monitor.log</p>
            <p>🔄 下次检查时间: $(date -d "+$CHECK_INTERVAL seconds" '+%Y-%m-%d %H:%M:%S')</p>
        </div>
    </div>
</body>
</html>
EOF
    
    log_success "监控报告已生成: $report_file"
}

# 清理日志文件
cleanup_logs() {
    log_info "清理日志文件..."
    
    # 压缩旧日志
    find "$LOG_DIR" -name "*.log" -size +"$MAX_LOG_SIZE" -exec gzip {} \;
    
    # 删除30天前的日志
    find "$LOG_DIR" -name "*.gz" -mtime +30 -delete
    find "$LOG_DIR" -name "monitor-report-*.html" -mtime +7 -delete
    
    log_success "日志清理完成"
}

# 运行单次检查
run_single_check() {
    log_info "开始监控检查..."
    
    check_system_resources
    check_services
    check_docker_containers
    check_website_availability
    check_database_connections
    check_log_files
    
    log_success "监控检查完成"
}

# 运行持续监控
run_continuous_monitor() {
    log_info "启动持续监控模式 (间隔: ${CHECK_INTERVAL}秒)"
    
    while true; do
        run_single_check
        
        # 每小时生成一次报告
        local current_minute=$(date +%M)
        if [[ "$current_minute" == "00" ]]; then
            generate_report
            cleanup_logs
        fi
        
        log_info "等待 $CHECK_INTERVAL 秒后进行下次检查..."
        sleep "$CHECK_INTERVAL"
    done
}

# 安装监控服务
install_monitor_service() {
    log_info "安装监控服务..."
    
    local service_file="/etc/systemd/system/ai-app-monitor.service"
    
    cat > "$service_file" << EOF
[Unit]
Description=AI应用监控服务
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$(dirname "$0")
ExecStart=$0 daemon
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable ai-app-monitor
    
    log_success "监控服务已安装"
    log_info "启动服务: systemctl start ai-app-monitor"
    log_info "查看状态: systemctl status ai-app-monitor"
    log_info "查看日志: journalctl -u ai-app-monitor -f"
}

# 显示帮助信息
show_help() {
    cat << EOF
AI应用监控工具
==============

使用方法:
  $0 check                    运行单次监控检查
  $0 daemon                   运行持续监控（守护进程模式）
  $0 report                   生成监控报告
  $0 install                  安装为系统服务
  $0 config                   显示配置信息
  $0 logs                     显示监控日志
  $0 cleanup                  清理日志文件
  $0 -h, --help              显示帮助信息

监控项目:
  ✓ 系统资源 (CPU、内存、磁盘、负载)
  ✓ 服务状态 (nginx、mongodb、redis等)
  ✓ Docker容器状态
  ✓ 网站可用性和响应时间
  ✓ SSL证书有效期
  ✓ 数据库连接状态
  ✓ 日志文件分析

告警方式:
  ✓ 邮件通知
  ✓ Webhook通知 (Slack、钉钉等)
  ✓ 日志记录

配置文件: $MONITOR_CONFIG
日志目录: $LOG_DIR

示例:
  $0 check                    # 运行一次检查
  $0 daemon                   # 持续监控
  $0 install                  # 安装服务

EOF
}

# 显示配置信息
show_config() {
    echo "=== 监控配置信息 ==="
    echo "配置文件: $MONITOR_CONFIG"
    echo "日志目录: $LOG_DIR"
    echo "告警邮箱: $ALERT_EMAIL"
    echo "检查间隔: $CHECK_INTERVAL 秒"
    echo "CPU阈值: $CPU_THRESHOLD%"
    echo "内存阈值: $MEMORY_THRESHOLD%"
    echo "磁盘阈值: $DISK_THRESHOLD%"
    echo "负载阈值: $LOAD_THRESHOLD"
    echo "响应时间阈值: $RESPONSE_TIME_THRESHOLD ms"
    echo
    echo "监控服务: ${SERVICES[*]}"
    echo "监控URL: ${MONITOR_URLS[*]}"
    echo
}

# 显示日志
show_logs() {
    local log_file="$LOG_DIR/monitor.log"
    
    if [[ -f "$log_file" ]]; then
        echo "=== 最近的监控日志 ==="
        tail -50 "$log_file"
    else
        echo "监控日志文件不存在: $log_file"
    fi
}

# 主函数
main() {
    local command=${1:-"check"}
    
    # 初始化
    init_monitor
    
    case "$command" in
        "check")
            run_single_check
            ;;
            
        "daemon")
            run_continuous_monitor
            ;;
            
        "report")
            generate_report
            ;;
            
        "install")
            if [[ $EUID -ne 0 ]]; then
                log_error "安装服务需要root权限"
                exit 1
            fi
            install_monitor_service
            ;;
            
        "config")
            show_config
            ;;
            
        "logs")
            show_logs
            ;;
            
        "cleanup")
            cleanup_logs
            ;;
            
        "-h"|"--help")
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