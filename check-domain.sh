#!/bin/bash

# 域名和SSL配置检查脚本
# 使用方法: ./check-domain.sh [domain]
# 示例: ./check-domain.sh myai-app.com

set -e

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
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# 检查域名解析
check_dns() {
    local domain=$1
    local subdomain=$2
    
    log_info "检查 $subdomain 的DNS解析..."
    
    # 获取IP地址
    local ip=$(dig +short $subdomain 2>/dev/null | tail -n1)
    
    if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_success "$subdomain 解析到: $ip"
        return 0
    else
        log_error "$subdomain DNS解析失败或无效"
        return 1
    fi
}

# 检查端口连通性
check_port() {
    local host=$1
    local port=$2
    local service=$3
    
    log_info "检查 $host:$port ($service) 连通性..."
    
    if timeout 5 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
        log_success "$host:$port ($service) 连通正常"
        return 0
    else
        log_error "$host:$port ($service) 连接失败"
        return 1
    fi
}

# 检查HTTP响应
check_http() {
    local url=$1
    local expected_code=${2:-200}
    
    log_info "检查 $url HTTP响应..."
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$url" 2>/dev/null || echo "000")
    
    if [[ "$response" == "$expected_code" ]]; then
        log_success "$url 响应正常 (HTTP $response)"
        return 0
    else
        log_error "$url 响应异常 (HTTP $response, 期望 $expected_code)"
        return 1
    fi
}

# 检查HTTPS和SSL证书
check_ssl() {
    local domain=$1
    
    log_info "检查 $domain SSL证书..."
    
    # 检查SSL证书有效性
    local ssl_info=$(echo | openssl s_client -servername $domain -connect $domain:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        local not_after=$(echo "$ssl_info" | grep "notAfter" | cut -d= -f2)
        local expiry_date=$(date -d "$not_after" +%s 2>/dev/null || echo "0")
        local current_date=$(date +%s)
        local days_left=$(( (expiry_date - current_date) / 86400 ))
        
        if [[ $days_left -gt 30 ]]; then
            log_success "$domain SSL证书有效，还有 $days_left 天到期"
        elif [[ $days_left -gt 0 ]]; then
            log_warning "$domain SSL证书即将到期，还有 $days_left 天"
        else
            log_error "$domain SSL证书已过期"
        fi
        
        # 检查证书链
        local chain_info=$(echo | openssl s_client -servername $domain -connect $domain:443 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null)
        if [[ -n "$chain_info" ]]; then
            log_success "SSL证书链完整"
        else
            log_warning "SSL证书链可能不完整"
        fi
        
        return 0
    else
        log_error "$domain SSL证书检查失败"
        return 1
    fi
}

# 检查SSL评级
check_ssl_rating() {
    local domain=$1
    
    log_info "检查 $domain SSL安全评级..."
    log_info "请访问 https://www.ssllabs.com/ssltest/analyze.html?d=$domain 查看详细评级"
    
    # 简单的SSL配置检查
    local ssl_protocols=$(echo | openssl s_client -servername $domain -connect $domain:443 2>/dev/null | grep "Protocol" | head -1)
    if [[ "$ssl_protocols" =~ "TLSv1.3" ]] || [[ "$ssl_protocols" =~ "TLSv1.2" ]]; then
        log_success "使用安全的TLS协议"
    else
        log_warning "可能使用了不安全的TLS协议"
    fi
}

# 检查网站性能
check_performance() {
    local url=$1
    
    log_info "检查 $url 性能..."
    
    local timing=$(curl -s -o /dev/null -w "连接时间: %{time_connect}s, 首字节时间: %{time_starttransfer}s, 总时间: %{time_total}s" "$url" 2>/dev/null || echo "性能检查失败")
    
    if [[ "$timing" != "性能检查失败" ]]; then
        log_success "$timing"
        
        # 检查响应时间
        local total_time=$(echo "$timing" | grep -o "总时间: [0-9.]*" | cut -d' ' -f2 | cut -d's' -f1)
        if (( $(echo "$total_time < 2.0" | bc -l) )); then
            log_success "响应时间良好 (< 2秒)"
        elif (( $(echo "$total_time < 5.0" | bc -l) )); then
            log_warning "响应时间一般 (2-5秒)"
        else
            log_error "响应时间较慢 (> 5秒)"
        fi
    else
        log_error "性能检查失败"
    fi
}

# 检查安全头
check_security_headers() {
    local url=$1
    
    log_info "检查 $url 安全头配置..."
    
    local headers=$(curl -s -I "$url" 2>/dev/null)
    
    # 检查重要的安全头
    local security_headers=(
        "Strict-Transport-Security"
        "X-Frame-Options"
        "X-Content-Type-Options"
        "X-XSS-Protection"
        "Content-Security-Policy"
    )
    
    local missing_headers=()
    
    for header in "${security_headers[@]}"; do
        if echo "$headers" | grep -qi "$header:"; then
            log_success "安全头 $header 已配置"
        else
            missing_headers+=("$header")
            log_warning "缺少安全头 $header"
        fi
    done
    
    if [[ ${#missing_headers[@]} -eq 0 ]]; then
        log_success "所有重要安全头都已配置"
    else
        log_warning "建议配置缺少的安全头以提高安全性"
    fi
}

# 检查重定向
check_redirects() {
    local domain=$1
    
    log_info "检查HTTP到HTTPS重定向..."
    
    local redirect_code=$(curl -s -o /dev/null -w "%{http_code}" --max-redirs 0 "http://$domain" 2>/dev/null || echo "000")
    
    if [[ "$redirect_code" == "301" ]] || [[ "$redirect_code" == "302" ]]; then
        log_success "HTTP正确重定向到HTTPS (HTTP $redirect_code)"
    else
        log_error "HTTP未重定向到HTTPS (HTTP $redirect_code)"
    fi
    
    # 检查www重定向
    local www_redirect=$(curl -s -o /dev/null -w "%{http_code}" --max-redirs 0 "https://www.$domain" 2>/dev/null || echo "000")
    
    if [[ "$www_redirect" == "301" ]] || [[ "$www_redirect" == "200" ]]; then
        log_success "www子域名配置正常"
    else
        log_warning "www子域名可能配置有问题"
    fi
}

# 检查API端点
check_api_endpoints() {
    local domain=$1
    
    log_info "检查API端点..."
    
    local api_endpoints=(
        "https://api.$domain/health"
        "https://$domain/api/health"
    )
    
    for endpoint in "${api_endpoints[@]}"; do
        local response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$endpoint" 2>/dev/null || echo "000")
        
        if [[ "$response" == "200" ]]; then
            log_success "API端点 $endpoint 正常"
            break
        else
            log_warning "API端点 $endpoint 响应异常 (HTTP $response)"
        fi
    done
}

# 生成检查报告
generate_report() {
    local domain=$1
    local report_file="domain-check-report-$(date +%Y%m%d_%H%M%S).txt"
    
    log_info "生成检查报告: $report_file"
    
    cat > "$report_file" << EOF
域名配置检查报告
==================

检查时间: $(date)
检查域名: $domain

检查项目:
- DNS解析
- 端口连通性
- HTTP/HTTPS响应
- SSL证书
- 安全头配置
- 重定向配置
- API端点
- 性能测试

详细结果请查看终端输出。

建议:
1. 确保所有子域名都正确解析到服务器IP
2. 配置完整的安全头以提高安全性
3. 定期检查SSL证书到期时间
4. 监控网站性能和可用性
5. 设置自动化监控和告警

检查工具: $0
EOF
    
    log_success "报告已保存到: $report_file"
}

# 主检查函数
run_checks() {
    local domain=$1
    
    log_info "开始检查域名: $domain"
    echo
    
    # 检查必要工具
    local required_tools=("dig" "curl" "openssl" "bc")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "缺少必要工具: $tool"
            log_info "请安装: sudo apt-get install dnsutils curl openssl bc"
            exit 1
        fi
    done
    
    # DNS解析检查
    echo "=== DNS解析检查 ==="
    check_dns "$domain" "$domain"
    check_dns "$domain" "www.$domain"
    check_dns "$domain" "api.$domain"
    check_dns "$domain" "admin.$domain"
    echo
    
    # 端口连通性检查
    echo "=== 端口连通性检查 ==="
    check_port "$domain" 80 "HTTP"
    check_port "$domain" 443 "HTTPS"
    echo
    
    # HTTP响应检查
    echo "=== HTTP响应检查 ==="
    check_http "https://$domain" 200
    check_http "https://www.$domain" 200
    check_http "https://admin.$domain" 200
    echo
    
    # SSL证书检查
    echo "=== SSL证书检查 ==="
    check_ssl "$domain"
    check_ssl_rating "$domain"
    echo
    
    # 重定向检查
    echo "=== 重定向检查 ==="
    check_redirects "$domain"
    echo
    
    # 安全头检查
    echo "=== 安全头检查 ==="
    check_security_headers "https://$domain"
    echo
    
    # API端点检查
    echo "=== API端点检查 ==="
    check_api_endpoints "$domain"
    echo
    
    # 性能检查
    echo "=== 性能检查 ==="
    check_performance "https://$domain"
    echo
    
    # 生成报告
    generate_report "$domain"
    
    log_success "域名检查完成！"
}

# 显示使用帮助
show_help() {
    echo "域名和SSL配置检查工具"
    echo
    echo "使用方法:"
    echo "  $0 <domain>          检查指定域名"
    echo "  $0 -h, --help       显示帮助信息"
    echo
    echo "示例:"
    echo "  $0 myai-app.com"
    echo
    echo "检查项目:"
    echo "  - DNS解析状态"
    echo "  - 端口连通性 (80, 443)"
    echo "  - HTTP/HTTPS响应"
    echo "  - SSL证书有效性和到期时间"
    echo "  - 安全头配置"
    echo "  - 重定向配置"
    echo "  - API端点可用性"
    echo "  - 网站性能"
    echo
}

# 主函数
main() {
    local domain=$1
    
    # 检查参数
    if [[ -z "$domain" ]] || [[ "$domain" == "-h" ]] || [[ "$domain" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    # 验证域名格式
    if [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        log_error "无效的域名格式: $domain"
        exit 1
    fi
    
    # 运行检查
    run_checks "$domain"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi