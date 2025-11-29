import os
import json
import sys  # 用于检测打包环境

class Config:
    # 基础配置
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key'
    
    # 获取项目根目录 (basedir)
    if getattr(sys, 'frozen', False):
        # 打包后：使用可执行文件 (.exe) 所在的真实目录
        basedir = os.path.dirname(sys.executable)
    else:
        # 开发环境：使用 config.py 所在的目录
        basedir = os.path.abspath(os.path.dirname(__file__))
    
    # ---------------------------------------------------------
    # 0. 定义默认配置模板db_config.json
    # ---------------------------------------------------------
    DEFAULT_DB_CONFIG = {
        "db_mode": "sqlite",
        "sqlite_path": "app.db",
        "psql_config": {
            "host": "postgresql-xxxxx",
            "port": "5432",
            "user": "komari_db",
            "password": "xxxxxxx",
            "database": "komari_db"
        }
    }

    # ---------------------------------------------------------
    # 数据库配置逻辑 (优先级: 环境变量 > db_config.json > 默认值)
    # ---------------------------------------------------------
    
    _db_config = {}
    _config_path = os.path.join(basedir, 'db_config.json')
    _should_write_default = False

    # 1. 检查文件状态并尝试读取
    if not os.path.exists(_config_path):
        print(f"[Config] {_config_path} 不存在，准备创建默认配置...")
        _should_write_default = True
    elif os.path.getsize(_config_path) == 0:
        print(f"[Config] {_config_path} 为空文件(Docker touch?)，准备写入默认配置...")
        _should_write_default = True
    else:
        # 文件存在且不为空，尝试解析 JSON
        try:
            with open(_config_path, 'r', encoding='utf-8') as f:
                content = f.read().strip()
                if not content:
                    _should_write_default = True
                else:
                    _db_config = json.loads(content)
        except json.JSONDecodeError as e:
            print(f"[Config] JSON 解析失败 ({e})，准备覆盖为默认配置...")
            _should_write_default = True
        except Exception as e:
            print(f"[Config] 读取配置文件失败: {e}")
            # 如果读取出错，至少使用内存中的默认值防止报错
            _db_config = DEFAULT_DB_CONFIG

    # 2. 如果需要，写入默认配置到文件
    if _should_write_default:
        try:
            with open(_config_path, 'w', encoding='utf-8') as f:
                json.dump(DEFAULT_DB_CONFIG, f, indent=4)
            print(f"[Config] ✅ 已成功将默认参数写入 {_config_path}")
            _db_config = DEFAULT_DB_CONFIG
        except Exception as e:
            print(f"[Config] ❌ 写入默认配置文件失败 (可能是权限问题): {e}")
            # 写入失败也没关系，内存中使用默认值继续运行
            _db_config = DEFAULT_DB_CONFIG

    # 3. 确定数据库模式 (环境变量优先)
    # 环境变量: KOMARI_DB_MODE (sqlite, psql)
    _db_mode = os.environ.get('KOMARI_DB_MODE') or _db_config.get('db_mode', 'sqlite')
    
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    
    if _db_mode == 'psql':
        # PostgreSQL 配置
        # 优先读取环境变量，否则读取 json 配置，最后默认值
        _pg_conf = _db_config.get('psql_config', {})
        
        _pg_host = os.environ.get('PG_HOST') or _pg_conf.get('host', 'localhost')
        _pg_port = os.environ.get('PG_PORT') or _pg_conf.get('port', '5432')
        _pg_user = os.environ.get('PG_USER') or _pg_conf.get('user', 'komari_user')
        _pg_pass = os.environ.get('PG_PASSWORD') or _pg_conf.get('password', 'komari_password')
        _pg_db   = os.environ.get('PG_DB') or _pg_conf.get('database', 'komari_db')
        
        SQLALCHEMY_DATABASE_URI = f"postgresql://{_pg_user}:{_pg_pass}@{_pg_host}:{_pg_port}/{_pg_db}"
        print(f">>> Database Mode: PostgreSQL ({_pg_host}:{_pg_port}/{_pg_db})")
        
    else:
        # SQLite 配置 (默认)
        _sqlite_path = os.environ.get('SQLITE_PATH') or _db_config.get('sqlite_path', 'app.db')
        # 确保是绝对路径
        if not os.path.isabs(_sqlite_path):
            _sqlite_path = os.path.join(basedir, _sqlite_path)
            
        SQLALCHEMY_DATABASE_URI = 'sqlite:///' + _sqlite_path
        print(f">>> Database Mode: SQLite ({_sqlite_path})")