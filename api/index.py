# Vercel Python函数入口点
import sys
import os

# 添加项目根目录到Python路径
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.app import app

# Vercel需要的应用实例
application = app

# 为了兼容性，也导出app
app = app

if __name__ == '__main__':
    app.run()