@echo off
chcp 65001 >nul
echo.
echo 🌸 启动AI对话框校园风项目 🌸
echo.
echo 正在启动后端服务...
start "AI后端服务" cmd /k "python app.py"
echo.
echo 等待后端服务启动...
timeout /t 3 /nobreak >nul
echo.
echo 正在启动前端服务...
start "AI前端服务" cmd /k "python -m http.server 8000"
echo.
echo 等待前端服务启动...
timeout /t 2 /nobreak >nul
echo.
echo ✨ 服务启动完成！✨
echo.
echo 📱 前端地址: http://localhost:8000
echo 🔧 后端地址: http://localhost:5000
echo.
echo 💝 Dear Master，请在浏览器中访问前端地址开始使用！
echo.
echo 按任意键打开浏览器...
pause >nul
start http://localhost:8000/AI对话框校园风修改-4126c8295c.html
exit