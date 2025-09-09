from flask import Blueprint, request, jsonify, render_template
from datetime import datetime, timedelta
import json
import os
from collections import defaultdict
from database import db
import logging

analytics_bp = Blueprint('analytics', __name__)
logger = logging.getLogger(__name__)

# 数据存储路径
DATA_DIR = os.path.join(os.path.dirname(__file__), '..', 'data')
ANALYTICS_FILE = os.path.join(DATA_DIR, 'analytics.json')
USER_BEHAVIOR_FILE = os.path.join(DATA_DIR, 'user_behavior.json')

# 确保数据目录存在
os.makedirs(DATA_DIR, exist_ok=True)

def load_analytics_data():
    """加载统计数据（兼容旧格式）"""
    try:
        events = db.find('events')
        behaviors = db.find('behaviors')
        return {'events': events, 'behaviors': behaviors}
    except Exception as e:
        print(f"加载统计数据失败: {e}")
        return {'events': [], 'behaviors': []}

def save_analytics_data(data):
    """保存统计数据（已废弃，使用数据库直接操作）"""
    # 这个函数保留用于兼容性，实际使用db.insert
    return True

def load_data(file_path):
    """加载数据文件"""
    if os.path.exists(file_path):
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except:
            return []
    return []

def save_data(file_path, data):
    """保存数据到文件"""
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

@analytics_bp.route('/track', methods=['POST'])
def track_event():
    """接收前端发送的统计事件"""
    try:
        data = request.get_json()
        
        # 添加时间戳和IP
        event_data = {
            'timestamp': datetime.now().isoformat(),
            'ip': request.remote_addr,
            'user_agent': request.headers.get('User-Agent', ''),
            'event_type': data.get('event_type'),
            'event_category': data.get('event_category'),
            'event_action': data.get('event_action'),
            'event_label': data.get('event_label'),
            'event_value': data.get('event_value'),
            'page_url': data.get('page_url'),
            'page_title': data.get('page_title'),
            'referrer': data.get('referrer'),
            'session_id': data.get('session_id')
        }
        
        # 保存到数据库
        if db.insert('events', event_data):
            return jsonify({'status': 'success'})
        else:
            return jsonify({'status': 'error', 'message': '保存事件失败'}), 500
        
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 400

@analytics_bp.route('/behavior', methods=['POST'])
def track_behavior():
    """接收用户行为数据"""
    try:
        # 处理不同的Content-Type
        if request.is_json:
            data = request.get_json()
        else:
            # 处理sendBeacon发送的Blob数据
            content_type = request.headers.get('Content-Type', '')
            if 'application/json' in content_type or request.get_data():
                try:
                    data = json.loads(request.get_data(as_text=True))
                except json.JSONDecodeError:
                    # 如果JSON解析失败，尝试作为表单数据处理
                    data = request.form.to_dict()
            else:
                data = request.form.to_dict()
        
        behavior_data = {
            'timestamp': datetime.now().isoformat(),
            'ip': request.remote_addr,
            'session_id': data.get('session_id'),
            'behavior_type': data.get('behavior_type'),  # click, scroll, timing, etc.
            'element': data.get('element'),
            'value': data.get('value'),
            'page_url': data.get('page_url'),
            'viewport_width': data.get('viewport_width'),
            'viewport_height': data.get('viewport_height'),
            'user_agent': data.get('user_agent'),
            'stay_time': data.get('stay_time')
        }
        
        # 保存到数据库
        if db.insert('behaviors', behavior_data):
            return jsonify({'status': 'success'})
        else:
            return jsonify({'status': 'error', 'message': '保存行为数据失败'}), 500
        
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 400

@analytics_bp.route('/dashboard')
def get_dashboard_data():
    """获取仪表板数据"""
    try:
        # 从数据库加载数据
        events = db.find('events')
        behaviors = db.find('behaviors')
        
        # 计算统计数据
        now = datetime.now()
        today = now.date()
        yesterday = today - timedelta(days=1)
        week_ago = today - timedelta(days=7)
        
        # 今日数据
        today_events = [e for e in events if datetime.fromisoformat(e['timestamp']).date() == today]
        yesterday_events = [e for e in events if datetime.fromisoformat(e['timestamp']).date() == yesterday]
        week_events = [e for e in events if datetime.fromisoformat(e['timestamp']).date() >= week_ago]
        
        # 页面浏览量统计
        page_views = defaultdict(int)
        for event in events:
            if event.get('event_type') == 'page_view':
                page_views[event.get('page_url', 'unknown')] += 1
        
        # 事件类型统计
        event_types = defaultdict(int)
        for event in events:
            event_types[event.get('event_type', 'unknown')] += 1
        
        # 用户行为统计
        behavior_stats = defaultdict(int)
        for behavior in behaviors:
            behavior_stats[behavior.get('behavior_type', 'unknown')] += 1
        
        # 热门功能统计
        feature_usage = defaultdict(int)
        for event in events:
            if event.get('event_type') == 'feature_click':
                feature_usage[event.get('event_label', 'unknown')] += 1
        
        dashboard_data = {
            'summary': {
                'total_events': len(events),
                'today_events': len(today_events),
                'yesterday_events': len(yesterday_events),
                'week_events': len(week_events),
                'total_behaviors': len(behaviors)
            },
            'page_views': dict(sorted(page_views.items(), key=lambda x: x[1], reverse=True)[:10]),
            'event_types': dict(event_types),
            'behavior_stats': dict(behavior_stats),
            'feature_usage': dict(sorted(feature_usage.items(), key=lambda x: x[1], reverse=True)[:10]),
            'recent_events': events[-20:] if events else [],
            'recent_behaviors': behaviors[-20:] if behaviors else []
        }
        
        return jsonify(dashboard_data)
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@analytics_bp.route('/export')
def export_data():
    """导出统计数据"""
    try:
        export_type = request.args.get('type', 'all')
        format_type = request.args.get('format', 'json')
        
        # 从数据库加载数据
        if export_type == 'events':
            data = db.find('events')
        elif export_type == 'behaviors':
            data = db.find('behaviors')
        else:
            data = {
                'events': db.find('events'),
                'behaviors': db.find('behaviors')
            }
        
        if format_type == 'csv':
            # 简单的CSV导出
            import csv
            import io
            
            output = io.StringIO()
            if export_type == 'events' and data:
                writer = csv.DictWriter(output, fieldnames=data[0].keys())
                writer.writeheader()
                writer.writerows(data)
            elif export_type == 'behaviors' and data:
                writer = csv.DictWriter(output, fieldnames=data[0].keys())
                writer.writeheader()
                writer.writerows(data)
            
            from flask import Response
            response = Response(
                output.getvalue(),
                mimetype='text/csv',
                headers={'Content-Disposition': f'attachment; filename=analytics_{export_type}_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv'}
            )
            return response
        else:
            # JSON导出
            return jsonify({
                'data': data,
                'exported_at': datetime.now().isoformat(),
                'total_records': len(data) if isinstance(data, list) else sum(len(v) for v in data.values() if isinstance(v, list))
            })
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@analytics_bp.route('/admin/analytics')
def admin_dashboard():
    """管理员统计仪表板页面"""
    return render_template('admin_analytics.html')

@analytics_bp.route('/database/status', methods=['GET'])
def get_database_status():
    """获取当前数据库连接状态"""
    try:
        return jsonify({
            'status': 'success',
            'current_mode': 'postgresql',
            'is_postgresql': True,
            'is_local': False
        })
    except Exception as e:
        logger.error(f"获取数据库状态失败: {e}")
        return jsonify({'error': str(e)}), 500

@analytics_bp.route('/database/postgresql/status', methods=['GET'])
def get_postgresql_status():
    """获取PostgreSQL数据库连接状态"""
    try:
        from postgresql_client import db as pg_db
        current_mode = pg_db.get_current_mode()
        is_connected = current_mode == 'postgresql'
        
        return jsonify({
            'status': 'success',
            'connected': is_connected,
            'current_mode': current_mode,
            'database_type': 'postgresql'
        })
    except Exception as e:
        logger.error(f"获取PostgreSQL状态失败: {e}")
        return jsonify({
            'status': 'error',
            'connected': False,
            'error': str(e)
        }), 500

@analytics_bp.route('/database/postgresql/reconnect', methods=['POST'])
def reconnect_postgresql():
    """重新连接PostgreSQL数据库"""
    try:
        from postgresql_client import db as pg_db
        success = pg_db.reconnect_postgresql()
        
        if success:
            return jsonify({
                'status': 'success',
                'message': 'PostgreSQL重新连接成功',
                'current_mode': pg_db.get_current_mode()
            })
        else:
            return jsonify({
                'status': 'error',
                'message': 'PostgreSQL重新连接失败，请检查配置和网络连接',
                'current_mode': pg_db.get_current_mode()
            }), 400
    except Exception as e:
        logger.error(f"重新连接PostgreSQL失败: {e}")
        return jsonify({
            'status': 'error',
            'error': str(e)
        }), 500

@analytics_bp.route('/database/postgresql/test', methods=['POST'])
def test_postgresql_connection():
    """测试PostgreSQL数据库连接"""
    try:
        from postgresql_client import db as pg_db
        
        # 测试基本连接
        if pg_db.get_current_mode() == 'postgresql':
            # 尝试执行一个简单的查询来测试连接
            test_result = pg_db.find('test_connection', limit=1)
            return jsonify({
                'status': 'success',
                'message': 'PostgreSQL连接测试成功',
                'connected': True,
                'test_query_result': len(test_result) if test_result else 0
            })
        else:
            return jsonify({
                'status': 'warning',
                'message': '当前使用本地存储模式，PostgreSQL未连接',
                'connected': False
            })
    except Exception as e:
        logger.error(f"测试PostgreSQL连接失败: {e}")
        return jsonify({
            'status': 'error',
            'message': f'PostgreSQL连接测试失败: {str(e)}',
            'connected': False
        }), 500