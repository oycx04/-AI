// 统一导航栏管理
class NavbarManager {
    constructor() {
        // 构造函数中不立即初始化，等待页面加载完成
    }

    // 初始化导航栏
    init() {
        this.updateNavbar();
        this.bindEvents();
    }

    // 获取用户信息
    getUserInfo() {
        const userStr = localStorage.getItem('userInfo');
        return userStr ? JSON.parse(userStr) : null;
    }

    // 获取用户Token
    getUserToken() {
        return localStorage.getItem('userToken');
    }

    // 检查登录状态
    isLoggedIn() {
        const token = this.getUserToken();
        const user = this.getUserInfo();
        return !!(token && user);
    }

    // 更新导航栏状态
    updateNavbar() {
        const isLoggedIn = this.isLoggedIn();
        const userInfo = this.getUserInfo();
        
        // 获取导航栏元素
        const loginBtn = document.getElementById('loginBtn');
        const registerBtn = document.getElementById('registerBtn');
        const userMenu = document.getElementById('userMenu');
        const userAvatar = document.getElementById('userAvatar');
        const userName = document.getElementById('userName');
        
        console.log('更新导航栏状态:', { isLoggedIn, userInfo });
        
        if (isLoggedIn && userInfo) {
            // 已登录状态 - 隐藏登录注册按钮，显示用户菜单
            if (loginBtn) {
                loginBtn.style.display = 'none';
                console.log('隐藏登录按钮');
            }
            if (registerBtn) {
                registerBtn.style.display = 'none';
                console.log('隐藏注册按钮');
            }
            if (userMenu) {
                userMenu.style.display = 'block';
                console.log('显示用户菜单');
                if (userAvatar) {
                    userAvatar.textContent = userInfo.avatar_letter || userInfo.username.charAt(0).toUpperCase();
                }
                if (userName) {
                    userName.textContent = userInfo.username;
                }
            }
        } else {
            // 未登录状态 - 显示登录注册按钮，隐藏用户菜单
            if (loginBtn) {
                loginBtn.style.display = 'inline-block';
                console.log('显示登录按钮');
            }
            if (registerBtn) {
                registerBtn.style.display = 'inline-block';
                console.log('显示注册按钮');
            }
            if (userMenu) {
                userMenu.style.display = 'none';
                console.log('隐藏用户菜单');
            }
        }
    }

    // 绑定事件
    bindEvents() {
        // 登录按钮
        const loginBtn = document.getElementById('loginBtn');
        if (loginBtn) {
            loginBtn.addEventListener('click', () => {
                window.location.href = 'auth.html';
            });
        }

        // 注册按钮
        const registerBtn = document.getElementById('registerBtn');
        if (registerBtn) {
            registerBtn.addEventListener('click', () => {
                window.location.href = 'auth.html';
            });
        }

        // 个人中心按钮
        const profileBtn = document.getElementById('profileBtn');
        if (profileBtn) {
            profileBtn.addEventListener('click', () => {
                if (this.isLoggedIn()) {
                    window.location.href = 'profile.html';
                } else {
                    window.location.href = 'auth.html';
                }
            });
        }

        // 退出登录按钮
        const logoutBtn = document.getElementById('logoutBtn');
        if (logoutBtn) {
            logoutBtn.addEventListener('click', () => {
                this.logout();
            });
        }

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

    // 退出登录
    logout() {
        if (confirm('确定要退出登录吗？')) {
            localStorage.removeItem('userToken');
            localStorage.removeItem('userInfo');
            window.location.href = 'index.html';
        }
    }

    // 刷新导航栏状态（用于登录后调用）
    refresh() {
        this.updateNavbar();
    }
}

// 页面加载完成后初始化导航栏
document.addEventListener('DOMContentLoaded', () => {
    window.navbarManager = new NavbarManager();
    window.navbarManager.init();
});

// 如果页面已经加载完成，立即初始化
if (document.readyState === 'loading') {
    // 页面还在加载中，等待DOMContentLoaded事件
} else {
    // 页面已经加载完成，立即初始化
    window.navbarManager = new NavbarManager();
    window.navbarManager.init();
}

// 监听存储变化，自动更新导航栏
window.addEventListener('storage', (e) => {
    if (e.key === 'userToken' || e.key === 'userInfo') {
        if (window.navbarManager) {
            window.navbarManager.refresh();
        }
    }
});