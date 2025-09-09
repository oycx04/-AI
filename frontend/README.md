# 前端项目结构说明

## 目录结构

```
frontend/
├── index.html              # 主应用首页（卷王AI）
├── learning-path-generator.html  # 学习路径生成器
├── simple-ai.html          # AI画师助手
├── backup-index.html       # 导航页面备份
├── analytics-config.js     # 统计配置文件
├── admin/                  # 管理员平台（独立）
│   ├── index.html         # 管理员仪表板
│   └── analytics-config.js # 管理员平台统计配置
├── assets/                 # 静态资源
├── css/                    # 样式文件
└── js/                     # JavaScript文件
```

## 访问方式

### 开发环境
- **主应用**: http://localhost:8000/
- **管理员平台**: http://localhost:8000/admin/
- **后端API**: http://localhost:5000/api/

### 生产环境（通过Nginx代理）
- **主应用**: http://your-domain.com/
- **管理员平台**: http://your-domain.com/admin/
- **后端API**: http://your-domain.com/api/

## 部署说明

1. **Docker部署**:
   ```bash
   docker-compose up -d
   ```

2. **访问验证**:
   - 主应用首页会直接显示卷王AI界面
   - 管理员平台通过 `/admin/` 路径独立访问
   - 所有API接口通过 `/api/` 路径访问

## 功能特性

### 主应用 (index.html)
- 卷王AI
- 广告联盟集成
- 用户行为统计
- 响应式设计

### 管理员平台 (admin/index.html)
- 网站统计仪表板
- 数据库状态监控
- 存储模式切换
- 数据导出功能
- 实时事件监控

## 注意事项

1. 管理员平台已完全独立，不会影响主应用的访问
2. 两个平台共享后端API，但有独立的前端入口
3. 统计配置文件在两个目录中都有副本，可以独立配置
4. Nginx配置已更新，支持管理员平台的独立路由