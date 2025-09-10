# Vercel Python函数入口点
import sys
import os

# 添加项目根目录到Python路径
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# 设置环境变量，使用简单数据库
os.environ['DATABASE_TYPE'] = 'simple'

try:
    from backend.app import app
    # Vercel需要的应用实例
    application = app
except Exception as e:
    # 如果导入失败，创建一个简单的Flask应用
    from flask import Flask, jsonify
    app = Flask(__name__)
    
    @app.route('/health')
    def health():
        return jsonify({"status": "ok", "message": "Vercel deployment active"})
    
    @app.route('/')
    def home():
        return jsonify({"message": "AI应用后端服务", "status": "running"})
    
    application = app

# 为了兼容性，也导出app
app = application

if __name__ == '__main__':
    app.run()