from flask import Blueprint, request, jsonify, session
from werkzeug.security import generate_password_hash, check_password_hash
import psycopg2
from psycopg2.extras import RealDictCursor
import os
from datetime import datetime, timedelta
import jwt
import re

auth_bp = Blueprint('auth', __name__)

# 数据库连接配置
def get_db_connection():
    try:
        from config import POSTGRESQL_URI
        conn = psycopg2.connect(POSTGRESQL_URI)
        return conn
    except Exception as e:
        print(f"数据库连接失败: {e}")
        return None

# 初始化用户表
def init_user_table():
    conn = get_db_connection()
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    username VARCHAR(50) UNIQUE NOT NULL,
                    email VARCHAR(100) UNIQUE NOT NULL,
                    password_hash VARCHAR(255) NOT NULL,
                    avatar_letter VARCHAR(1) NOT NULL,
                    school VARCHAR(200),
                    study_time INTEGER DEFAULT 0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    last_login TIMESTAMP,
                    is_active BOOLEAN DEFAULT TRUE
                )
            """)
            
            # 检查并添加school字段（如果不存在）
            cursor.execute("""
                DO $$ 
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                                  WHERE table_name='users' AND column_name='school') THEN
                        ALTER TABLE users ADD COLUMN school VARCHAR(200);
                    END IF;
                END $$;
            """)
            
            # 创建学习时长记录表
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS study_sessions (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER REFERENCES users(id),
                    start_time TIMESTAMP NOT NULL,
                    end_time TIMESTAMP,
                    duration INTEGER DEFAULT 0,
                    session_type VARCHAR(50) DEFAULT 'study',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            conn.commit()
            cursor.close()
            conn.close()
            print("用户表初始化成功")
        except Exception as e:
            print(f"初始化用户表失败: {e}")
            conn.rollback()
            conn.close()

# 验证邮箱格式
def is_valid_email(email):
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None

# 验证用户名格式
def is_valid_username(username):
    # 用户名只能包含字母、数字和下划线，长度3-20
    pattern = r'^[a-zA-Z0-9_]{3,20}$'
    return re.match(pattern, username) is not None

# 生成JWT token
def generate_token(user_id, username):
    payload = {
        'user_id': user_id,
        'username': username,
        'exp': datetime.utcnow() + timedelta(days=7)  # 7天过期
    }
    return jwt.encode(payload, os.getenv('JWT_SECRET', 'your-secret-key'), algorithm='HS256')

# 验证JWT token
def verify_token(token):
    try:
        payload = jwt.decode(token, os.getenv('JWT_SECRET', 'your-secret-key'), algorithms=['HS256'])
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

# 用户注册
@auth_bp.route('/register', methods=['POST'])
def register():
    try:
        data = request.get_json()
        username = data.get('username', '').strip()
        email = data.get('email', '').strip().lower()
        password = data.get('password', '')
        school = data.get('school', '').strip()
        
        # 验证输入
        if not username or not email or not password or not school:
            return jsonify({
                'status': 'error',
                'message': '用户名、邮箱、密码和学校不能为空'
            }), 400
        
        if not is_valid_username(username):
            return jsonify({
                'status': 'error',
                'message': '用户名格式不正确（3-20位字母、数字或下划线）'
            }), 400
        
        if not is_valid_email(email):
            return jsonify({
                'status': 'error',
                'message': '邮箱格式不正确'
            }), 400
        
        if len(password) < 6:
            return jsonify({
                'status': 'error',
                'message': '密码长度至少6位'
            }), 400
        
        conn = get_db_connection()
        if not conn:
            return jsonify({
                'status': 'error',
                'message': '数据库连接失败'
            }), 500
        
        cursor = conn.cursor()
        
        # 检查用户名和邮箱是否已存在
        cursor.execute("SELECT id FROM users WHERE username = %s OR email = %s", (username, email))
        if cursor.fetchone():
            cursor.close()
            conn.close()
            return jsonify({
                'status': 'error',
                'message': '用户名或邮箱已存在'
            }), 400
        
        # 生成密码哈希和头像字母
        password_hash = generate_password_hash(password)
        avatar_letter = username[0].upper()
        
        # 插入新用户
        cursor.execute("""
            INSERT INTO users (username, email, password_hash, avatar_letter, school)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING id
        """, (username, email, password_hash, avatar_letter, school))
        
        user_id = cursor.fetchone()[0]
        conn.commit()
        cursor.close()
        conn.close()
        
        # 生成token
        token = generate_token(user_id, username)
        
        return jsonify({
            'status': 'success',
            'message': '注册成功',
            'data': {
                'user_id': user_id,
                'username': username,
                'email': email,
                'avatar_letter': avatar_letter,
                'school': school,
                'token': token
            }
        }), 201
        
    except Exception as e:
        print(f"注册失败: {e}")
        return jsonify({
            'status': 'error',
            'message': '注册失败，请稍后重试'
        }), 500

# 用户登录
@auth_bp.route('/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        username_or_email = data.get('username', '').strip()
        password = data.get('password', '')
        
        if not username_or_email or not password:
            return jsonify({
                'status': 'error',
                'message': '用户名/邮箱和密码不能为空'
            }), 400
        
        conn = get_db_connection()
        if not conn:
            return jsonify({
                'status': 'error',
                'message': '数据库连接失败'
            }), 500
        
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # 查找用户（支持用户名或邮箱登录）
        cursor.execute("""
            SELECT id, username, email, password_hash, avatar_letter, school, study_time, is_active
            FROM users 
            WHERE (username = %s OR email = %s) AND is_active = TRUE
        """, (username_or_email, username_or_email.lower()))
        
        user = cursor.fetchone()
        
        if not user or not check_password_hash(user['password_hash'], password):
            cursor.close()
            conn.close()
            return jsonify({
                'status': 'error',
                'message': '用户名/邮箱或密码错误'
            }), 401
        
        # 更新最后登录时间
        cursor.execute(
            "UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = %s",
            (user['id'],)
        )
        conn.commit()
        cursor.close()
        conn.close()
        
        # 生成token
        token = generate_token(user['id'], user['username'])
        
        return jsonify({
            'status': 'success',
            'message': '登录成功',
            'data': {
                'user_id': user['id'],
                'username': user['username'],
                'email': user['email'],
                'avatar_letter': user['avatar_letter'],
                'school': user['school'],
                'study_time': user['study_time'],
                'token': token
            }
        }), 200
        
    except Exception as e:
        print(f"登录失败: {e}")
        return jsonify({
            'status': 'error',
            'message': '登录失败，请稍后重试'
        }), 500

# 获取用户资料
@auth_bp.route('/profile', methods=['GET'])
def get_profile():
    """获取用户资料"""
    try:
        # 验证token
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({
                'status': 'error',
                'message': '未提供认证token'
            }), 401
        
        token = auth_header.split(' ')[1]
        payload = verify_token(token)
        
        if not payload:
            return jsonify({
                'status': 'error',
                'message': 'token无效或已过期'
            }), 401
        
        conn = get_db_connection()
        if not conn:
            return jsonify({
                'status': 'error',
                'message': '数据库连接失败'
            }), 500
        
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # 获取用户基本信息和学习统计
        cursor.execute("""
            SELECT u.username, u.email, u.created_at,
                   COALESCE(SUM(ss.duration), 0) as total_study_time,
                   COUNT(DISTINCT DATE(ss.created_at)) as study_days
            FROM users u
            LEFT JOIN study_sessions ss ON u.id = ss.user_id
            WHERE u.id = %s
            GROUP BY u.id, u.username, u.email, u.created_at
        """, (payload['user_id'],))
        
        user_data = cursor.fetchone()
        
        # 获取用户排名
        cursor.execute("""
            SELECT rank FROM (
                SELECT u.id, 
                       ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(ss.duration), 0) DESC) as rank
                FROM users u
                LEFT JOIN study_sessions ss ON u.id = ss.user_id
                GROUP BY u.id
            ) ranked_users
            WHERE id = %s
        """, (payload['user_id'],))
        
        rank_data = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if user_data:
            profile = {
                'username': user_data['username'],
                'email': user_data['email'],
                'created_at': user_data['created_at'].isoformat() if user_data['created_at'] else None,
                'total_study_time': int(user_data['total_study_time']),
                'study_days': int(user_data['study_days']),
                'current_rank': int(rank_data['rank']) if rank_data else None
            }
            
            return jsonify({
                'status': 'success',
                'data': profile
            }), 200
        else:
            return jsonify({
                'status': 'error',
                'message': '用户不存在'
            }), 404
            
    except Exception as e:
        print(f"获取用户资料失败: {e}")
        return jsonify({
            'status': 'error',
            'message': '获取用户资料失败'
        }), 500

# 更新学习时长
@auth_bp.route('/study-time', methods=['POST'])
def update_study_time():
    try:
        # 验证token
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({
                'status': 'error',
                'message': '未提供认证token'
            }), 401
        
        token = auth_header.split(' ')[1]
        payload = verify_token(token)
        
        if not payload:
            return jsonify({
                'status': 'error',
                'message': 'token无效或已过期'
            }), 401
        
        data = request.get_json()
        duration = data.get('duration', 0)  # 学习时长（秒）
        session_type = data.get('session_type', 'study')
        
        if duration <= 0:
            return jsonify({
                'status': 'error',
                'message': '学习时长必须大于0'
            }), 400
        
        conn = get_db_connection()
        if not conn:
            return jsonify({
                'status': 'error',
                'message': '数据库连接失败'
            }), 500
        
        cursor = conn.cursor()
        
        # 更新用户总学习时长
        cursor.execute(
            "UPDATE users SET study_time = study_time + %s WHERE id = %s",
            (duration, payload['user_id'])
        )
        
        # 记录学习会话
        cursor.execute("""
            INSERT INTO study_sessions (user_id, start_time, end_time, duration, session_type)
            VALUES (%s, %s, %s, %s, %s)
        """, (
            payload['user_id'],
            datetime.utcnow() - timedelta(seconds=duration),
            datetime.utcnow(),
            duration,
            session_type
        ))
        
        # 获取更新后的总学习时长
        cursor.execute("SELECT study_time FROM users WHERE id = %s", (payload['user_id'],))
        total_study_time = cursor.fetchone()[0]
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({
            'status': 'success',
            'message': '学习时长更新成功',
            'data': {
                'duration_added': duration,
                'total_study_time': total_study_time
            }
        }), 200
        
    except Exception as e:
        print(f"更新学习时长失败: {e}")
        return jsonify({
            'status': 'error',
            'message': '更新学习时长失败'
        }), 500

# 获取卷王排名
@auth_bp.route('/leaderboard', methods=['GET'])
def get_leaderboard():
    try:
        limit = request.args.get('limit', 10, type=int)
        if limit > 100:
            limit = 100
        
        # 从PostgreSQL数据库获取用户数据
        conn = get_db_connection()
        if not conn:
            return jsonify({
                'status': 'error',
                'message': '数据库连接失败'
            }), 500
        
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # 查询活跃用户，按学习时长排序
        cursor.execute("""
            SELECT username, avatar_letter, school, study_time
            FROM users 
            WHERE is_active = TRUE 
            ORDER BY study_time DESC 
            LIMIT %s
        """, (limit,))
        
        users = cursor.fetchall()
        cursor.close()
        conn.close()
        
        if not users:
            return jsonify({
                'status': 'success',
                'data': []
            }), 200
        
        # 格式化数据
        formatted_data = []
        for i, user in enumerate(users, 1):
            formatted_data.append({
                'rank': i,
                'username': user['username'] or '未知用户',
                'avatar_letter': user['avatar_letter'] or (user['username'][0].upper() if user['username'] else 'U'),
                'school': user['school'] or '未知学校',
                'study_time': user['study_time'] or 0,
                'study_hours': round((user['study_time'] or 0) / 3600, 1)  # 转换为小时
            })
        
        return jsonify({
            'status': 'success',
            'data': formatted_data
        }), 200
        
    except Exception as e:
        print(f"获取排行榜失败: {e}")
        return jsonify({
            'status': 'error',
            'message': '获取排行榜失败'
        }), 500

# 更新用户资料
@auth_bp.route('/profile', methods=['PUT'])
def update_profile():
    try:
        # 验证token
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({
                'status': 'error',
                'message': '未提供认证token'
            }), 401
        
        token = auth_header.split(' ')[1]
        payload = verify_token(token)
        
        if not payload:
            return jsonify({
                'status': 'error',
                'message': 'token无效或已过期'
            }), 401
        
        data = request.get_json()
        username = data.get('username', '').strip()
        email = data.get('email', '').strip().lower()
        
        if not username or not email:
            return jsonify({
                'status': 'error',
                'message': '用户名和邮箱不能为空'
            }), 400
        
        if not is_valid_username(username):
            return jsonify({
                'status': 'error',
                'message': '用户名格式不正确（3-20位字母、数字或下划线）'
            }), 400
        
        if not is_valid_email(email):
            return jsonify({
                'status': 'error',
                'message': '邮箱格式不正确'
            }), 400
        
        conn = get_db_connection()
        if not conn:
            return jsonify({
                'status': 'error',
                'message': '数据库连接失败'
            }), 500
        
        cursor = conn.cursor()
        
        # 检查用户名和邮箱是否已被其他用户使用
        cursor.execute("""
            SELECT id FROM users 
            WHERE (username = %s OR email = %s) AND id != %s
        """, (username, email, payload['user_id']))
        
        existing_user = cursor.fetchone()
        if existing_user:
            cursor.close()
            conn.close()
            return jsonify({
                'status': 'error',
                'message': '用户名或邮箱已被使用'
            }), 400
        
        # 更新用户信息
        cursor.execute("""
            UPDATE users 
            SET username = %s, email = %s, avatar_letter = %s
            WHERE id = %s
        """, (username, email, username[0].upper(), payload['user_id']))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({
            'status': 'success',
            'message': '资料更新成功'
        }), 200
        
    except Exception as e:
        print(f"更新用户资料失败: {e}")
        return jsonify({
            'status': 'error',
            'message': '更新用户资料失败'
        }), 500

# 获取学习记录
@auth_bp.route('/study-records', methods=['GET'])
def get_study_records():
    try:
        # 验证token
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({
                'status': 'error',
                'message': '未提供认证token'
            }), 401
        
        token = auth_header.split(' ')[1]
        payload = verify_token(token)
        
        if not payload:
            return jsonify({
                'status': 'error',
                'message': 'token无效或已过期'
            }), 401
        
        limit = request.args.get('limit', 10, type=int)
        if limit > 100:
            limit = 100
        
        conn = get_db_connection()
        if not conn:
            return jsonify({
                'status': 'error',
                'message': '数据库连接失败'
            }), 500
        
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # 获取学习记录
        cursor.execute("""
            SELECT DATE(created_at) as study_date, 
                   SUM(duration) as total_duration,
                   COUNT(*) as session_count
            FROM study_sessions 
            WHERE user_id = %s
            GROUP BY DATE(created_at)
            ORDER BY study_date DESC
            LIMIT %s
        """, (payload['user_id'], limit))
        
        records = cursor.fetchall()
        cursor.close()
        conn.close()
        
        # 格式化数据
        study_records = []
        for record in records:
            study_records.append({
                'study_date': record['study_date'].isoformat() if record['study_date'] else None,
                'total_duration': record['total_duration'],
                'session_count': record['session_count'],
                'study_hours': round(record['total_duration'] / 3600, 1)
            })
        
        return jsonify({
            'status': 'success',
            'data': study_records
        }), 200
        
    except Exception as e:
        print(f"获取学习记录失败: {e}")
        return jsonify({
            'status': 'error',
            'message': '获取学习记录失败'
        }), 500

# 获取统计数据
@auth_bp.route('/statistics', methods=['GET'])
def get_statistics():
    try:
        import json
        import os
        
        # 直接读取统计文件（因为它是对象格式，不是数组）
        stats_file = os.path.join('data', 'statistics.json')
        if os.path.exists(stats_file):
            with open(stats_file, 'r', encoding='utf-8') as f:
                stats_data = json.load(f)
        else:
            # 如果没有统计数据，返回默认值
            stats_data = {
                'total_users': 0,
                'total_study_time': 0,
                'total_sessions': 0,
                'active_users_today': 0,
                'popular_subjects': [],
                'daily_stats': [],
                'school_rankings': [],
                'last_updated': datetime.now().isoformat()
            }
        
        return jsonify({
            'status': 'success',
            'data': stats_data
        }), 200
        
    except Exception as e:
        print(f"获取统计数据失败: {e}")
        return jsonify({
            'status': 'error',
            'message': '获取统计数据失败'
        }), 500

# 初始化数据库表
init_user_table()