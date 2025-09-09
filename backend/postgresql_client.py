from sqlalchemy import create_engine, text, MetaData, Table, Column, Integer, String, DateTime, JSON, Boolean
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.exc import SQLAlchemyError
from datetime import datetime
import logging
from config import POSTGRESQL_URI
import json
import os
import threading

logger = logging.getLogger(__name__)

Base = declarative_base()

class PostgreSQLClient:
    def __init__(self):
        self.engine = None
        self.Session = None
        self.use_local = False
        self.data_dir = 'data'
        self.lock = threading.Lock()
        
        # 尝试连接PostgreSQL，失败则使用本地存储
        if not self.connect():
            logger.warning("PostgreSQL连接失败，使用本地文件存储")
            self.use_local = True
            os.makedirs(self.data_dir, exist_ok=True)
    
    def connect(self):
        """连接到PostgreSQL"""
        try:
            # 配置连接参数
            engine_args = {
                'pool_pre_ping': True,
                'pool_recycle': 3600,
                'connect_args': {
                    'connect_timeout': 10
                }
            }
            
            self.engine = create_engine(POSTGRESQL_URI, **engine_args)
            self.Session = sessionmaker(bind=self.engine)
            
            # 测试连接
            with self.engine.connect() as conn:
                conn.execute(text("SELECT 1"))
            
            logger.info("成功连接到PostgreSQL数据库")
            self._create_tables()
            return True
        except Exception as e:
            logger.error(f"连接PostgreSQL失败: {e}")
            return False
    
    def _create_tables(self):
        """创建必要的表结构"""
        try:
            with self.engine.begin() as conn:
                # 创建通用数据表
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS app_data (
                        id SERIAL PRIMARY KEY,
                        collection_name VARCHAR(100) NOT NULL,
                        document_data JSONB NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                """))
                
                # 创建索引
                conn.execute(text("""
                    CREATE INDEX IF NOT EXISTS idx_collection_name 
                    ON app_data(collection_name)
                """))
                
                logger.info("数据库表结构创建完成")
        except Exception as e:
            logger.error(f"创建表结构失败: {e}")
    
    def _get_file_path(self, collection_name):
        """获取本地文件路径"""
        return os.path.join(self.data_dir, f'{collection_name}.json')
    
    def _load_local_data(self, collection_name):
        """加载本地数据"""
        file_path = self._get_file_path(collection_name)
        if os.path.exists(file_path):
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError):
                return []
        return []
    
    def _save_local_data(self, collection_name, data):
        """保存本地数据"""
        file_path = self._get_file_path(collection_name)
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2, default=str)
        except IOError as e:
            logger.error(f"保存本地数据失败: {e}")
    
    def insert(self, collection_name, document):
        """插入文档"""
        with self.lock:
            if self.use_local:
                data = self._load_local_data(collection_name)
                document['_id'] = len(data) + 1
                document['created_at'] = datetime.now().isoformat()
                data.append(document)
                self._save_local_data(collection_name, data)
                logger.info(f"本地插入文档到 {collection_name}: {document.get('_id')}")
                return document['_id']
            else:
                try:
                    session = self.Session()
                    document['created_at'] = datetime.now().isoformat()
                    
                    # 插入到PostgreSQL
                    result = session.execute(text("""
                        INSERT INTO app_data (collection_name, document_data, created_at)
                        VALUES (:collection, :data, CURRENT_TIMESTAMP)
                        RETURNING id
                    """), {
                        'collection': collection_name,
                        'data': json.dumps(document, default=str)
                    })
                    
                    doc_id = result.fetchone()[0]
                    session.commit()
                    session.close()
                    
                    logger.info(f"PostgreSQL插入文档到 {collection_name}: {doc_id}")
                    return doc_id
                except Exception as e:
                    logger.error(f"插入文档失败: {e}")
                    if 'session' in locals():
                        session.rollback()
                        session.close()
                    return None
    
    def find(self, collection_name, query=None, limit=None, sort=None):
        """查找文档"""
        if self.use_local:
            data = self._load_local_data(collection_name)
            
            # 简单的查询过滤
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
            
            # 排序
            if sort:
                for field, direction in reversed(sort):
                    data.sort(key=lambda x: x.get(field, ''), reverse=(direction == -1))
            
            # 限制结果数量
            if limit:
                data = data[:limit]
            
            return data
        else:
            try:
                session = self.Session()
                query_sql = "SELECT document_data FROM app_data WHERE collection_name = :collection"
                params = {'collection': collection_name}
                
                if limit:
                    query_sql += " LIMIT :limit"
                    params['limit'] = limit
                
                result = session.execute(text(query_sql), params)
                documents = []
                for row in result.fetchall():
                    doc_data = row[0]
                    if isinstance(doc_data, str):
                        documents.append(json.loads(doc_data))
                    else:
                        documents.append(doc_data)
                session.close()
                
                return documents
            except Exception as e:
                logger.error(f"查询文档失败: {e}")
                if 'session' in locals():
                    session.close()
                return []
    
    def count(self, collection_name, query=None):
        """统计文档数量"""
        if self.use_local:
            data = self._load_local_data(collection_name)
            if query:
                count = 0
                for doc in data:
                    match = True
                    for key, value in query.items():
                        if key not in doc or doc[key] != value:
                            match = False
                            break
                    if match:
                        count += 1
                return count
            return len(data)
        else:
            try:
                session = self.Session()
                result = session.execute(text("""
                    SELECT COUNT(*) FROM app_data WHERE collection_name = :collection
                """), {'collection': collection_name})
                count = result.fetchone()[0]
                session.close()
                return count
            except Exception as e:
                logger.error(f"统计文档失败: {e}")
                if 'session' in locals():
                    session.close()
                return 0
    
    def update_one(self, collection_name, filter_query, update_data):
        """更新单个文档"""
        with self.lock:
            if self.use_local:
                data = self._load_local_data(collection_name)
                for doc in data:
                    match = True
                    for key, value in filter_query.items():
                        if key not in doc or doc[key] != value:
                            match = False
                            break
                    if match:
                        if '$set' in update_data:
                            doc.update(update_data['$set'])
                        doc['updated_at'] = datetime.now().isoformat()
                        self._save_local_data(collection_name, data)
                        return True
                return False
            else:
                try:
                    session = self.Session()
                    # 简化的更新逻辑
                    update_fields = update_data.get('$set', {})
                    update_fields['updated_at'] = datetime.now().isoformat()
                    
                    result = session.execute(text("""
                        UPDATE app_data 
                        SET document_data = document_data || :update_data,
                            updated_at = CURRENT_TIMESTAMP
                        WHERE collection_name = :collection
                        AND document_data @> :filter_data
                    """), {
                        'collection': collection_name,
                        'update_data': json.dumps(update_fields),
                        'filter_data': json.dumps(filter_query)
                    })
                    
                    session.commit()
                    session.close()
                    return result.rowcount > 0
                except Exception as e:
                    logger.error(f"更新文档失败: {e}")
                    if 'session' in locals():
                        session.rollback()
                        session.close()
                    return False
    
    def delete_many(self, collection_name, query):
        """删除多个文档"""
        with self.lock:
            if self.use_local:
                data = self._load_local_data(collection_name)
                original_count = len(data)
                
                filtered_data = []
                for doc in data:
                    match = True
                    for key, value in query.items():
                        if key not in doc or doc[key] != value:
                            match = False
                            break
                    if not match:
                        filtered_data.append(doc)
                
                self._save_local_data(collection_name, filtered_data)
                return original_count - len(filtered_data)
            else:
                try:
                    session = self.Session()
                    result = session.execute(text("""
                        DELETE FROM app_data 
                        WHERE collection_name = :collection
                        AND document_data @> :query_data
                    """), {
                        'collection': collection_name,
                        'query_data': json.dumps(query)
                    })
                    
                    session.commit()
                    deleted_count = result.rowcount
                    session.close()
                    return deleted_count
                except Exception as e:
                    logger.error(f"删除文档失败: {e}")
                    if 'session' in locals():
                        session.rollback()
                        session.close()
                    return 0
    
    def close(self):
        """关闭数据库连接"""
        if self.engine:
            self.engine.dispose()
            logger.info("PostgreSQL连接已关闭")
    
    def get_current_mode(self):
        """获取当前存储模式"""
        return "local" if self.use_local else "postgresql"
    
    def get_status(self):
        """获取数据库连接状态"""
        if self.use_local:
            return True  # 本地文件存储总是可用的
        
        try:
            # 测试PostgreSQL连接
            with self.engine.connect() as conn:
                conn.execute(text("SELECT 1"))
            return True
        except Exception as e:
            logger.warning(f"PostgreSQL连接状态检查失败: {e}")
            return False
    
    def reconnect_postgresql(self):
        """重新连接PostgreSQL"""
        if self.connect():
            self.use_local = False
            logger.info("已切换到PostgreSQL模式")
            return True
        return False

# 创建全局数据库客户端实例
db = PostgreSQLClient()