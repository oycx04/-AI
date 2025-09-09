# 统一数据库客户端
# PostgreSQL数据库连接管理

import json
import os
from datetime import datetime
import threading
import logging
from config import DATABASE_TYPE

logger = logging.getLogger(__name__)

class SimpleDatabase:
    def __init__(self, data_dir='data'):
        self.data_dir = data_dir
        self.lock = threading.Lock()
        os.makedirs(data_dir, exist_ok=True)
    
    def _get_file_path(self, collection):
        return os.path.join(self.data_dir, f'{collection}.json')
    
    def _load_data(self, collection):
        file_path = self._get_file_path(collection)
        if os.path.exists(file_path):
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError):
                return []
        return []
    
    def _save_data(self, collection, data):
        file_path = self._get_file_path(collection)
        with self.lock:
            try:
                with open(file_path, 'w', encoding='utf-8') as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)
                return True
            except IOError:
                return False
    
    def insert(self, collection, document):
        """插入文档"""
        data = self._load_data(collection)
        document['_id'] = len(data) + 1
        document['created_at'] = datetime.now().isoformat()
        data.append(document)
        return self._save_data(collection, data)
    
    def find(self, collection, query=None, limit=None):
        """查找文档"""
        data = self._load_data(collection)
        
        if query:
            filtered_data = []
            for doc in data:
                match = True
                for key, value in query.items():
                    if key not in doc or doc[key] != value:
                        match = False
                        break
                if match:
                    filtered_data.append(doc)
            data = filtered_data
        
        if limit:
            data = data[-limit:]  # 返回最新的记录
        
        return data
    
    def count(self, collection, query=None):
        """统计文档数量"""
        return len(self.find(collection, query))
    
    def aggregate(self, collection, pipeline):
        """简单的聚合操作"""
        data = self._load_data(collection)
        
        # 简单实现一些基本的聚合操作
        for stage in pipeline:
            if '$match' in stage:
                # 过滤数据
                match_query = stage['$match']
                filtered_data = []
                for doc in data:
                    match = True
                    for key, value in match_query.items():
                        if key not in doc or doc[key] != value:
                            match = False
                            break
                    if match:
                        filtered_data.append(doc)
                data = filtered_data
            
            elif '$group' in stage:
                # 分组操作
                group_stage = stage['$group']
                group_key = group_stage.get('_id')
                
                if group_key:
                    groups = {}
                    for doc in data:
                        key_value = doc.get(group_key.replace('$', ''), 'unknown')
                        if key_value not in groups:
                            groups[key_value] = []
                        groups[key_value].append(doc)
                    
                    # 计算聚合结果
                    result = []
                    for key, docs in groups.items():
                        group_result = {'_id': key}
                        for field, operation in group_stage.items():
                            if field != '_id':
                                if operation == {'$sum': 1}:
                                    group_result[field] = len(docs)
                                elif isinstance(operation, dict) and '$sum' in operation:
                                    sum_field = operation['$sum'].replace('$', '')
                                    group_result[field] = sum([doc.get(sum_field, 0) for doc in docs])
                        result.append(group_result)
                    data = result
        
        return data
    
    def delete_many(self, collection, query):
        """删除多个文档"""
        data = self._load_data(collection)
        original_count = len(data)
        
        filtered_data = []
        for doc in data:
            match = True
            for key, value in query.items():
                if key in doc and doc[key] == value:
                    match = False
                    break
            if match:
                filtered_data.append(doc)
        
        self._save_data(collection, filtered_data)
        return original_count - len(filtered_data)

# 全局数据库实例
# 根据配置选择数据库客户端
if DATABASE_TYPE.lower() == 'postgresql':
    try:
        from postgresql_client import db
        logger.info("使用PostgreSQL数据库客户端")
    except ImportError as e:
        logger.error(f"导入PostgreSQL客户端失败: {e}")
        # 回退到简单数据库
        db = SimpleDatabase()
        logger.info("回退到简单文件数据库客户端")
else:
    # 默认使用简单数据库
    db = SimpleDatabase()
    logger.info("使用简单文件数据库客户端")

# 导出数据库客户端实例
__all__ = ['db']