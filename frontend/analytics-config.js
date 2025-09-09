// 网站统计配置文件
// 请根据实际情况修改以下配置

const AnalyticsConfig = {
    // Google Analytics 配置
    googleAnalytics: {
        enabled: true,
        measurementId: 'G-XXXXXXXXXX', // 请替换为实际的 Google Analytics 测量 ID
        config: {
            // 自定义配置选项
            send_page_view: true,
            anonymize_ip: true,
            cookie_expires: 63072000, // 2年
            custom_map: {
                'custom_parameter_1': 'dimension1'
            }
        }
    },
    
    // 百度统计配置
    baiduAnalytics: {
        enabled: true,
        siteId: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', // 请替换为实际的百度统计站点ID
        config: {
            // 百度统计自定义配置
            autoPageview: true,
            trackSinglePage: true
        }
    },
    
    // 事件追踪配置
    eventTracking: {
        enabled: true,
        // 自动追踪的事件类型
        autoTrack: {
            clicks: true,
            scrolls: true,
            formSubmits: true,
            downloads: true,
            outboundLinks: true
        },
        // 自定义事件配置
        customEvents: {
            'button_click': {
                category: 'engagement',
                action: 'click',
                label: 'button'
            },
            'form_submit': {
                category: 'engagement',
                action: 'submit',
                label: 'form'
            },
            'page_scroll': {
                category: 'engagement',
                action: 'scroll',
                label: 'page'
            }
        }
    },
    
    // 用户行为追踪配置
    tracking: {
        // 是否追踪点击事件
        trackClicks: true,
        
        // 是否追踪滚动深度
        trackScrollDepth: true,
        
        // 滚动深度追踪间隔（百分比）
        scrollDepthInterval: 25,
        
        // 是否追踪页面停留时间
        trackPageTiming: true,
        
        // 最小追踪时间（秒）
        minTrackingTime: 5,
        
        // 是否追踪表单交互
        trackFormInteractions: true,
        
        // 是否追踪下载链接
        trackDownloads: true,
        
        // 是否追踪外部链接
        trackExternalLinks: true
    },
    
    // 用户行为分析配置
    behaviorAnalytics: {
        enabled: true,
        // 热力图配置
        heatmap: {
            enabled: false,
            sampleRate: 0.1 // 10% 采样率
        },
        // 用户录屏配置
        sessionRecording: {
            enabled: false,
            sampleRate: 0.05 // 5% 采样率
        },
        // 用户路径分析
        userJourney: {
            enabled: true,
            maxEvents: 100
        }
    },
    
    // 隐私设置
    privacy: {
        // 是否启用IP匿名化
        anonymizeIP: true,
        
        // 是否遵守Do Not Track
        respectDNT: true,
        
        // Cookie同意检查
        requireCookieConsent: false
    },
    
    // 调试模式
    debug: {
        enabled: false, // 生产环境请设置为 false
        console: true,
        verbose: false
    }
};

// 初始化统计服务
function initAnalytics() {
    if (typeof window === 'undefined') return;
    
    // 初始化 Google Analytics
    if (AnalyticsConfig.googleAnalytics.enabled && AnalyticsConfig.googleAnalytics.measurementId !== 'G-XXXXXXXXXX') {
        // 更新 gtag 脚本的 ID
        const gaScript = document.querySelector('script[src*="googletagmanager.com/gtag/js"]');
        if (gaScript) {
            gaScript.src = `https://www.googletagmanager.com/gtag/js?id=${AnalyticsConfig.googleAnalytics.measurementId}`;
        }
        
        // 配置 Google Analytics
        if (typeof gtag !== 'undefined') {
            gtag('config', AnalyticsConfig.googleAnalytics.measurementId, AnalyticsConfig.googleAnalytics.config);
            
            if (AnalyticsConfig.debug.enabled && AnalyticsConfig.debug.console) {
                console.log('Google Analytics initialized:', AnalyticsConfig.googleAnalytics.measurementId);
            }
        }
    }
    
    // 初始化百度统计
    if (AnalyticsConfig.baiduAnalytics.enabled && AnalyticsConfig.baiduAnalytics.siteId !== 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx') {
        (function() {
            var hm = document.createElement("script");
            hm.src = `https://hm.baidu.com/hm.js?${AnalyticsConfig.baiduAnalytics.siteId}`;
            var s = document.getElementsByTagName("script")[0]; 
            s.parentNode.insertBefore(hm, s);
            
            if (AnalyticsConfig.debug.enabled && AnalyticsConfig.debug.console) {
                console.log('百度统计 initialized:', AnalyticsConfig.baiduAnalytics.siteId);
            }
        })();
    }
    
    // 初始化事件追踪
    if (AnalyticsConfig.eventTracking.enabled) {
        initEventTracking();
    }
    
    // 初始化用户行为分析
    if (AnalyticsConfig.behaviorAnalytics.enabled) {
        initBehaviorAnalytics();
    }
}

// 初始化事件追踪
function initEventTracking() {
    const config = AnalyticsConfig.eventTracking;
    
    // 自动追踪点击事件
    if (config.autoTrack.clicks) {
        document.addEventListener('click', function(e) {
            const element = e.target;
            const tagName = element.tagName.toLowerCase();
            const className = element.className;
            const id = element.id;
            
            // 追踪按钮点击
            if (tagName === 'button' || element.type === 'button' || element.role === 'button') {
                trackEvent('button_click', {
                    element_id: id,
                    element_class: className,
                    button_text: element.textContent?.trim().substring(0, 50)
                });
            }
            
            // 追踪链接点击
            if (tagName === 'a') {
                const href = element.href;
                const isOutbound = href && !href.includes(window.location.hostname);
                
                trackEvent('link_click', {
                    link_url: href,
                    link_text: element.textContent?.trim().substring(0, 50),
                    is_outbound: isOutbound
                });
            }
        });
    }
    
    // 自动追踪表单提交
    if (config.autoTrack.formSubmits) {
        document.addEventListener('submit', function(e) {
            const form = e.target;
            trackEvent('form_submit', {
                form_id: form.id,
                form_class: form.className,
                form_action: form.action
            });
        });
    }
    
    // 自动追踪滚动事件
    if (config.autoTrack.scrolls) {
        let scrollTimeout;
        let scrollDepth = 0;
        
        window.addEventListener('scroll', function() {
            clearTimeout(scrollTimeout);
            scrollTimeout = setTimeout(function() {
                const currentDepth = Math.round((window.scrollY / (document.body.scrollHeight - window.innerHeight)) * 100);
                
                // 每25%记录一次滚动深度
                if (currentDepth > scrollDepth && currentDepth % 25 === 0) {
                    scrollDepth = currentDepth;
                    trackEvent('page_scroll', {
                        scroll_depth: currentDepth,
                        page_url: window.location.href
                    });
                }
            }, 250);
        });
    }
}

// 初始化用户行为分析
function initBehaviorAnalytics() {
    const config = AnalyticsConfig.behaviorAnalytics;
    
    // 用户路径追踪
    if (config.userJourney.enabled) {
        const userJourney = JSON.parse(localStorage.getItem('userJourney') || '[]');
        
        // 记录页面访问
        const pageVisit = {
            url: window.location.href,
            title: document.title,
            timestamp: new Date().toISOString(),
            referrer: document.referrer
        };
        
        userJourney.push(pageVisit);
        
        // 限制记录数量
        if (userJourney.length > config.userJourney.maxEvents) {
            userJourney.shift();
        }
        
        localStorage.setItem('userJourney', JSON.stringify(userJourney));
        
        // 发送用户路径数据
        trackBehavior('page_visit', pageVisit);
    }
}

// 追踪自定义事件
function trackEvent(eventName, eventData = {}) {
    const config = AnalyticsConfig.eventTracking.customEvents[eventName] || {};
    
    // Google Analytics 事件追踪
    if (AnalyticsConfig.googleAnalytics.enabled && typeof gtag !== 'undefined') {
        gtag('event', config.action || eventName, {
            event_category: config.category || 'general',
            event_label: config.label || eventName,
            custom_parameter_1: eventData.element_id || eventData.form_id || '',
            ...eventData
        });
    }
    
    // 百度统计事件追踪
    if (AnalyticsConfig.baiduAnalytics.enabled && typeof _hmt !== 'undefined') {
        _hmt.push(['_trackEvent', config.category || 'general', config.action || eventName, config.label || eventName]);
    }
    
    // 发送到后端API
    if (typeof fetch !== 'undefined') {
        fetch('http://localhost:5000/api/analytics/track', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                event_type: eventName,
                event_category: config.category || 'general',
                event_action: config.action || eventName,
                event_label: config.label || eventName,
                page_url: window.location.href,
                timestamp: new Date().toISOString(),
                user_agent: navigator.userAgent,
                ...eventData
            })
        }).catch(error => {
            if (AnalyticsConfig.debug.enabled) {
                console.error('Failed to track event:', error);
            }
        });
    }
    
    if (AnalyticsConfig.debug.enabled && AnalyticsConfig.debug.console) {
        console.log('Event tracked:', eventName, eventData);
    }
}

// 追踪用户行为
function trackBehavior(behaviorType, behaviorData = {}) {
    const data = {
        behavior_type: behaviorType,
        page_url: window.location.href,
        timestamp: new Date().toISOString(),
        user_agent: navigator.userAgent,
        session_id: getSessionId(),
        ...behaviorData
    };
    
    // 对于页面卸载事件，使用sendBeacon
    if (behaviorType === 'page_unload' && navigator.sendBeacon) {
        try {
            // 创建Blob以确保正确的Content-Type
            const blob = new Blob([JSON.stringify(data)], {
                type: 'application/json'
            });
            navigator.sendBeacon('http://localhost:5000/api/analytics/behavior', blob);
        } catch (error) {
            // 静默处理sendBeacon错误
            if (AnalyticsConfig.debug.enabled) {
                console.warn('SendBeacon failed:', error);
            }
        }
        return; // 页面卸载时不使用fetch
    }
    
    // 普通情况使用fetch
    if (typeof fetch !== 'undefined') {
        fetch('http://localhost:5000/api/analytics/behavior', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(data)
        }).catch(error => {
            // 只在非页面卸载时记录错误
            if (AnalyticsConfig.debug.enabled && behaviorType !== 'page_unload') {
                console.error('Failed to track behavior:', error);
            }
        });
    }
    
    if (AnalyticsConfig.debug.enabled && AnalyticsConfig.debug.console) {
        console.log('Behavior tracked:', behaviorType, behaviorData);
    }
}

// 获取会话ID
function getSessionId() {
    let sessionId = sessionStorage.getItem('analytics_session_id');
    if (!sessionId) {
        sessionId = 'session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
        sessionStorage.setItem('analytics_session_id', sessionId);
    }
    return sessionId;
}

// 页面卸载时发送剩余数据
window.addEventListener('beforeunload', function() {
    // 发送页面停留时间
    const stayTime = Date.now() - (window.pageLoadTime || Date.now());
    
    // 直接使用sendBeacon，避免ERR_ABORTED错误
    if (navigator.sendBeacon) {
        const data = {
            behavior_type: 'page_unload',
            page_url: window.location.href,
            timestamp: new Date().toISOString(),
            user_agent: navigator.userAgent,
            session_id: getSessionId(),
            stay_time: stayTime
        };
        
        try {
            const blob = new Blob([JSON.stringify(data)], {
                type: 'application/json'
            });
            navigator.sendBeacon('http://localhost:5000/api/analytics/behavior', blob);
        } catch (error) {
            // 静默处理错误，不显示在控制台
        }
    }
});

// 使用visibilitychange事件作为备选方案
document.addEventListener('visibilitychange', function() {
    if (document.visibilityState === 'hidden') {
        const stayTime = Date.now() - (window.pageLoadTime || Date.now());
        
        if (navigator.sendBeacon) {
            const data = {
                behavior_type: 'page_hidden',
                page_url: window.location.href,
                timestamp: new Date().toISOString(),
                user_agent: navigator.userAgent,
                session_id: getSessionId(),
                stay_time: stayTime
            };
            
            try {
                const blob = new Blob([JSON.stringify(data)], {
                    type: 'application/json'
                });
                navigator.sendBeacon('http://localhost:5000/api/analytics/behavior', blob);
            } catch (error) {
                // 静默处理错误
            }
        }
    }
});

// 记录页面加载时间
window.pageLoadTime = Date.now();

// 导出配置和函数供全局使用
if (typeof window !== 'undefined') {
    window.AnalyticsConfig = AnalyticsConfig;
    window.initAnalytics = initAnalytics;
    window.trackEvent = trackEvent;
    window.trackBehavior = trackBehavior;
}

// 导出配置（如果在模块环境中）
if (typeof module !== 'undefined' && module.exports) {
    module.exports = AnalyticsConfig;
}

// 自动初始化（如果页面已加载完成）
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initAnalytics);
} else {
    initAnalytics();
}