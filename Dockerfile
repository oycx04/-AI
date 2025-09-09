# 使用官方Python运行时作为父镜像
FROM python:3.9-slim

# 设置工作目录
WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# 复制requirements文件
COPY backend/requirements.txt .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制后端代码
COPY backend/ ./backend/

# 复制前端代码
COPY frontend/ ./frontend/

# 暴露端口
EXPOSE 5000 8000

# 创建启动脚本
RUN echo '#!/bin/bash\n\
echo "启动卷王AI平台..."\n\
echo "启动后端服务..."\n\
cd /app/backend && python app.py &\n\
BACKEND_PID=$!\n\
echo "后端服务已启动 (PID: $BACKEND_PID)"\n\
echo "启动前端服务..."\n\
cd /app/frontend && python -m http.server 8000 &\n\
FRONTEND_PID=$!\n\
echo "前端服务已启动 (PID: $FRONTEND_PID)"\n\
echo "卷王AI平台启动完成！"\n\
echo "前端访问地址: http://localhost:8000"\n\
echo "后端API地址: http://localhost:5000"\n\
wait' > /app/start.sh && chmod +x /app/start.sh

# 启动应用
CMD ["/app/start.sh"]