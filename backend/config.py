# API配置文件
# 请在这里设置您的API密钥

# 阿里云DashScope API配置
# 获取API密钥：https://dashscope.console.aliyun.com/
API_KEY = "your-api-key-here"

# API基础URL（通常不需要修改）
API_BASE_URL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text2image/image-synthesis"

# PostgreSQL数据库配置
POSTGRESQL_URI = "postgresql://neondb_owner:npg_dTRX2E5ZJMCV@ep-steep-thunder-a12o3gri-pooler.ap-southeast-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"
DATABASE_TYPE = "postgresql"

# 服务器配置
FLASK_HOST = "0.0.0.0"
FLASK_PORT = 5000
FLASK_DEBUG = True

# 使用说明：
# 1. 访问 https://dashscope.console.aliyun.com/
# 2. 注册/登录阿里云账号
# 3. 开通DashScope服务
# 4. 获取API密钥
# 5. 将上面的 "your-api-key-here" 替换为您的真实API密钥
# 6. 保存文件并重启服务器

# 注意：请不要将包含真实API密钥的文件提交到版本控制系统中！