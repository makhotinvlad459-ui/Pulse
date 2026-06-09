# backend/gunicorn.conf.py
import multiprocessing

bind = "0.0.0.0:8000"
workers = 2  # или multiprocessing.cpu_count() * 2 + 1
worker_class = "uvicorn.workers.UvicornWorker"
timeout = 120
keepalive = 5
graceful_timeout = 30

# Для production
accesslog = "-"
errorlog = "-"
loglevel = "info"

# Для WebSocket
ws_max_msg_size = 10 * 1024 * 1024  # 10MB