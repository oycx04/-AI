# AI应用 - 智能计算器与工具集

一个集成了多种AI功能的Web应用，包括智能计算器、文本处理工具等，并集成了主流广告联盟以支持项目运营。

## 🚀 功能特性

- **智能计算器**: 支持基础数学运算、科学计算、单位转换等
- **文本处理**: 文本分析、格式转换、编码解码等工具
- **响应式设计**: 完美适配桌面端和移动端
- **广告集成**: 集成百度联盟、360联盟、搜狗联盟等主流广告平台
- **用户体验优化**: 广告屏蔽检测、友好提示等

## 📋 系统要求

- Docker 20.10+
- Docker Compose 1.29+
- 2GB+ 可用内存
- 10GB+ 可用磁盘空间

## 🛠️ 快速部署

### 1. 克隆项目
```bash
git clone <repository-url>
cd ai-app
```

### 2. 配置环境变量
```bash
# 复制环境变量模板
cp .env.production .env

# 编辑配置文件，填入你的广告联盟ID等信息
nano .env
```

### 3. 启动服务
```bash
# 给部署脚本执行权限
chmod +x deploy.sh

# 启动所有服务
./deploy.sh start
```

### 4. 访问应用
- 前端页面: http://localhost
- 后端API: http://localhost/api

## 📖 部署脚本使用

```bash
# 启动服务
./deploy.sh start

# 停止服务
./deploy.sh stop

# 重启服务
./deploy.sh restart

# 查看日志
./deploy.sh logs

# 查看状态
./deploy.sh status

# 清理资源
./deploy.sh cleanup

# 备份数据
./deploy.sh backup
```

## 🔧 生产环境配置

### SSL证书配置
1. 将SSL证书文件放置到 `ssl/` 目录
2. 修改 `nginx.conf` 中的HTTPS配置
3. 取消注释HTTPS服务器配置块

### 域名配置
1. 在 `.env` 文件中设置 `DOMAIN_NAME`
2. 修改 `nginx.conf` 中的 `server_name`
3. 配置DNS解析指向服务器IP

### 广告联盟配置
1. 注册各大广告联盟账号
2. 获取广告位ID和密钥
3. 在 `.env` 文件中填入相应配置
4. 取消 `index.html` 中广告代码的注释

## 📊 监控和维护

### 日志查看
```bash
# 应用日志
tail -f logs/app.log

# Nginx访问日志
tail -f logs/nginx/access.log

# Nginx错误日志
tail -f logs/nginx/error.log
```

### 性能监控
```bash
# 查看容器资源使用
docker stats

# 查看磁盘使用
df -h

# 查看内存使用
free -h
```

## 🔒 安全建议

1. **更改默认密钥**: 修改 `.env` 中的 `SECRET_KEY`
2. **启用HTTPS**: 配置SSL证书，强制HTTPS访问
3. **防火墙配置**: 只开放必要端口（80, 443）
4. **定期更新**: 保持Docker镜像和依赖包更新
5. **访问控制**: 配置适当的访问限制和速率限制

## 🐛 故障排除

### 常见问题

**Q: 服务启动失败**
```bash
# 查看详细日志
docker-compose logs

# 检查端口占用
netstat -tlnp | grep :80
```

**Q: 广告不显示**
1. 检查广告联盟配置是否正确
2. 确认域名已在广告联盟后台添加
3. 检查广告屏蔽插件是否影响

**Q: 性能问题**
1. 检查服务器资源使用情况
2. 优化Nginx配置
3. 启用缓存和压缩

## 📞 技术支持

如遇到问题，请：
1. 查看日志文件
2. 检查配置文件
3. 参考故障排除指南

## 📄 许可证

本项目采用 MIT 许可证

---

**注意**: 请确保在生产环境中正确配置所有安全设置和环境变量。

## 📁 项目结构

```
ai应用（1）/
├── 🎯 主要文件
│   ├── AI对话框校园风修改-4126c8295c.html    # 主界面文件
│   ├── app.py                                # 后端Flask应用
│   ├── config.py                             # 配置文件
│   └── start.bat                             # 一键启动脚本
│
├── 🎨 其他界面文件
│   ├── index.html                            # 备用主页
│   ├── 简易AI前端修改设计-493d540767.html      # 简化版界面
│   └── learning-path-generator.html          # 学习路径生成器
│
├── 🖼️ 资源文件
│   ├── cute-dog.png                         # 可爱小狗头像
│   ├── cute-robot.png                       # 机器人头像
│   └── generated_images/                     # 生成图片目录
│
└── 📚 文档
    └── README.md                             # 项目说明文档
```

## 🚀 快速启动

### 方法一：一键启动（推荐）
双击 `start.bat` 文件即可同时启动前端和后端服务。

### 方法二：手动启动
1. 启动后端服务：
   ```bash
   python app.py
   ```

2. 启动前端服务：
   ```bash
   python -m http.server 8000
   ```

3. 在浏览器中访问：`http://localhost:8000`

## ✨ 主要功能

- 🤖 **AI对话**：智能对话助手，支持多种AI模型
- ⏰ **学习计时器**：番茄钟功能，支持开始/暂停/重置
- 📝 **学习目标**：可自定义学习目标设置
- 🎨 **可爱界面**：校园风格设计，温馨可爱
- 📊 **数学公式**：支持MathJax数学公式渲染
- 💾 **数据持久化**：本地存储用户设置和对话历史
- 🖼️ **图像生成**：集成Qwen-Image API，支持AI图像生成

## 🛠️ 技术栈

- **前端**：HTML5, CSS3, JavaScript, Tailwind CSS
- **后端**：Python Flask
- **AI集成**：支持多种AI API（包括Qwen-Image）
- **数学渲染**：MathJax
- **图标**：Font Awesome

## ⚙️ 配置说明

### API密钥配置
1. 打开 `config.py` 文件
2. 将 `API_KEY = "your-api-key-here"` 中的值替换为您的真实API密钥
3. 获取API密钥：访问 [阿里云DashScope控制台](https://dashscope.console.aliyun.com/)

## 📋 使用说明

1. **对话功能**：在输入框中输入问题，点击发送或按Enter键
2. **学习计时器**：
   - 点击"开始学习"启动计时
   - 计时过程中可点击"暂停"暂停计时
   - 点击"重置"清零计时器
3. **学习目标**：在设置中可自定义学习目标
4. **快速功能**：使用快速按钮快速插入常用问题
5. **图像生成**：通过API接口生成AI图像

## 📡 API接口

### 生成图像
- **URL**: `POST /generate`
- **参数**:
  ```json
  {
    "prompt": "一只可爱的小猫",
    "aspect_ratio": "1:1",
    "num_inference_steps": 20,
    "guidance_scale": 7.5
  }
  ```

## 🎯 项目特色

- 🌸 **可爱设计**：粉色系校园风格，界面温馨可爱
- 🐕 **萌宠头像**：使用可爱小狗作为AI助手头像
- ⚡ **响应式设计**：适配不同屏幕尺寸
- 🔧 **易于扩展**：模块化设计，便于功能扩展
- 🚀 **一键启动**：简化部署流程

---

💝 **Dear Master，希望这个可爱的AI助手能陪伴你愉快的学习时光！** 🌟