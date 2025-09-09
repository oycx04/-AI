// 统一导航栏组件
class UnifiedNavbar {
    constructor() {
        this.currentPage = this.getCurrentPage();
        this.isLoggedIn = this.checkLoginStatus();
        this.userInfo = this.getUserInfo();
    }

    getCurrentPage() {
        const path = window.location.pathname;
        const filename = path.split('/').pop() || 'index.html';
        return filename.replace('.html', '');
    }

    checkLoginStatus() {
        // 兼容不同页面的认证方式
        const token = localStorage.getItem('userToken') || localStorage.getItem('token');
        const userInfo = localStorage.getItem('userInfo') || localStorage.getItem('user');
        
        if (token && userInfo) {
            try {
                this.user = JSON.parse(userInfo);
                return true;
            } catch (e) {
                console.error('解析用户信息失败:', e);
                this.user = null;
                return false;
            }
        } else {
            this.user = null;
            return false;
        }
    }

    getUserInfo() {
        // 兼容不同页面的用户信息存储方式
        const userInfo = localStorage.getItem('userInfo') || localStorage.getItem('user');
        if (userInfo) {
            try {
                return JSON.parse(userInfo);
            } catch (e) {
                console.error('解析用户信息失败:', e);
                return null;
            }
        }
        return null;
    }

    generateNavbarHTML() {
        const navItems = [
            { id: 'index', href: 'index.html', icon: 'fas fa-comments', text: '卷王AI' },
            { id: 'simple-ai', href: 'simple-ai.html', icon: 'fas fa-palette', text: 'AI画师助手' },
            { id: 'learning-path-generator', href: 'learning-path-generator.html', icon: 'fas fa-route', text: '学习路径生成器' },
            { id: 'leaderboard', href: 'leaderboard.html', icon: 'fas fa-trophy', text: '卷王排名' }
        ];

        const navItemsHTML = navItems.map(item => {
            const activeClass = this.currentPage === item.id ? 'active bg-white bg-opacity-20' : '';
            return `
                <button onclick="window.location.href='${item.href}'" class="nav-btn ${activeClass} px-6 py-3 rounded-xl font-semibold transition-all duration-300 text-white hover:bg-white hover:bg-opacity-20">
                    <i class="${item.icon} mr-2"></i>${item.text}
                </button>
            `;
        }).join('');

        const userSection = this.isLoggedIn ? this.generateLoggedInUserSection() : this.generateLoggedOutUserSection();

        return `
            <nav class="fixed top-0 left-0 right-0 z-50 bg-gradient-to-r from-blue-600 via-purple-600 to-pink-600 shadow-lg">
                <div class="container mx-auto px-6 py-4">
                    <div class="flex items-center justify-between">
                        <div class="flex items-center space-x-3">
                            <div class="w-10 h-10 rounded-full bg-white flex items-center justify-center text-blue-600">
                                <i class="fas fa-graduation-cap text-xl"></i>
                            </div>
                            <div>
                                <h1 class="text-xl font-bold text-white">AI助手平台</h1>
                                <p class="text-sm text-white opacity-80">智能学习与创作助手</p>
                            </div>
                        </div>
                        
                        <!-- 页面切换导航 -->
                        <div class="flex items-center space-x-4">
                            ${navItemsHTML}
                            
                            <!-- 分隔线 -->
                            <div class="w-px h-8 bg-white bg-opacity-30 mx-2"></div>
                            
                            <!-- 用户功能 -->
                            ${userSection}
                        </div>
                    </div>
                </div>
            </nav>
        `;
    }

    generateLoggedInUserSection() {
        const userName = this.userInfo?.username || this.userInfo?.name || '用户';
        const userInitial = userName.charAt(0).toUpperCase();
        
        return `
            <div id="userMenu" class="relative">
                <button id="userMenuToggle" class="flex items-center space-x-2 px-4 py-2 rounded-lg font-medium transition-all duration-300 bg-white bg-opacity-20 hover:bg-opacity-30 text-white">
                    <div id="userAvatar" class="w-8 h-8 rounded-full bg-blue-500 flex items-center justify-center text-white font-bold text-sm">${userInitial}</div>
                    <span id="userName">${userName}</span>
                    <i class="fas fa-chevron-down text-sm"></i>
                </button>
                <div id="userDropdown" class="absolute right-0 mt-2 w-48 bg-white rounded-lg shadow-lg py-2 hidden">
                    <button onclick="window.location.href='profile.html'" class="w-full text-left px-4 py-2 text-gray-700 hover:bg-gray-100 transition-colors">
                        <i class="fas fa-user mr-2"></i>个人中心
                    </button>
                    <button onclick="logout()" class="w-full text-left px-4 py-2 text-gray-700 hover:bg-gray-100 transition-colors">
                        <i class="fas fa-sign-out-alt mr-2"></i>退出登录
                    </button>
                </div>
            </div>
        `;
    }

    generateLoggedOutUserSection() {
        return `
            <button onclick="window.location.href='auth.html'" class="px-4 py-2 rounded-lg font-medium transition-all duration-300 bg-blue-500 hover:bg-blue-600 text-white">
                <i class="fas fa-sign-in-alt mr-2"></i>登录
            </button>
            <button onclick="window.location.href='auth.html'" class="px-4 py-2 rounded-lg font-medium transition-all duration-300 bg-green-500 hover:bg-green-600 text-white">
                <i class="fas fa-user-plus mr-2"></i>注册
            </button>
        `;
    }

    render() {
        const navbarHTML = this.generateNavbarHTML();
        
        // 如果页面已有导航栏，先移除
        const existingNav = document.querySelector('nav');
        if (existingNav) {
            existingNav.remove();
        }
        
        // 插入新的导航栏到body开头
        document.body.insertAdjacentHTML('afterbegin', navbarHTML);
        
        // 绑定事件
        this.bindEvents();
    }

    bindEvents() {
        // 用户菜单切换
        const userMenuToggle = document.getElementById('userMenuToggle');
        const userDropdown = document.getElementById('userDropdown');
        
        if (userMenuToggle && userDropdown) {
            userMenuToggle.addEventListener('click', (e) => {
                e.stopPropagation();
                userDropdown.classList.toggle('hidden');
            });
            
            // 点击其他地方关闭菜单
            document.addEventListener('click', () => {
                userDropdown.classList.add('hidden');
            });
        }
    }

    // 更新登录状态
    updateLoginStatus() {
        this.isLoggedIn = this.checkLoginStatus();
        this.userInfo = this.getUserInfo();
        this.render();
    }
}

// 全局退出登录函数
function logout() {
    // 清除所有可能的认证信息
    localStorage.removeItem('userToken');
    localStorage.removeItem('token');
    localStorage.removeItem('userInfo');
    localStorage.removeItem('user');
    
    // 更新导航栏
    if (window.unifiedNavbar) {
        window.unifiedNavbar.updateLoginStatus();
    }
    
    // 跳转到首页
    window.location.href = 'index.html';
}

// 确保logout函数在全局作用域可用
window.logout = logout;

// 初始化导航栏
function initUnifiedNavbar() {
    window.unifiedNavbar = new UnifiedNavbar();
    window.unifiedNavbar.render();
}

// 页面加载完成后初始化
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initUnifiedNavbar);
} else {
    initUnifiedNavbar();
}