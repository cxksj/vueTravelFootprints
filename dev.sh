#!/usr/bin/env bash
# 旅迹分支验收服务一键启停：后端 5200 + 前端 5174（独立于主检出的 5100/5173）
# 用法：./dev.sh start | stop | restart | status | log backend|frontend
set -euo pipefail
cd "$(dirname "$0")"

BACKEND_PORT=5200
FRONTEND_PORT=5174
LOG_DIR=/tmp/dcyy-dev

pids_on() { lsof -nP -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null || true; }

check() {
  local pids
  pids=$(pids_on "$2")
  if [[ -n "$pids" ]]; then
    echo "$1  http://localhost:$2  运行中 (pid $pids)"
  else
    echo "$1  端口 $2  未运行"
  fi
}

start() {
  if [[ -z "$(pids_on $BACKEND_PORT)" ]]; then
    mkdir -p "$LOG_DIR"
    (cd backend-go && PORT=$BACKEND_PORT nohup go run . >"$LOG_DIR/backend.log" 2>&1 &)
    echo "后端启动中（日志 $LOG_DIR/backend.log）"
  else
    echo "后端 $BACKEND_PORT 已在运行，跳过"
  fi
  if [[ -z "$(pids_on $FRONTEND_PORT)" ]]; then
    mkdir -p "$LOG_DIR"
    VITE_API_BASE_URL=http://localhost:$BACKEND_PORT nohup npm run dev -- --port $FRONTEND_PORT >"$LOG_DIR/frontend.log" 2>&1 &
    echo "前端启动中（日志 $LOG_DIR/frontend.log）"
  else
    echo "前端 $FRONTEND_PORT 已在运行，跳过"
  fi
  echo "等待服务就绪..."
  for _ in $(seq 1 20); do
    if [[ -n "$(pids_on $BACKEND_PORT)" && -n "$(pids_on $FRONTEND_PORT)" ]]; then break; fi
    sleep 1
  done
  status
}

stop() {
  local stopped=0
  for port in $FRONTEND_PORT $BACKEND_PORT; do
    local pids
    pids=$(pids_on $port)
    if [[ -n "$pids" ]]; then
      kill $pids 2>/dev/null || true
      echo "已停止端口 $port (pid $pids)"
      stopped=1
    fi
  done
  if [[ $stopped -eq 0 ]]; then echo "服务未在运行"; fi
}

status() {
  check "前端" "$FRONTEND_PORT"
  check "后端" "$BACKEND_PORT"
}

log() {
  case "${1:-}" in
    backend) tail -f "$LOG_DIR/backend.log" ;;
    frontend) tail -f "$LOG_DIR/frontend.log" ;;
    *) echo "用法：./dev.sh log backend|frontend" && exit 1 ;;
  esac
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  restart) stop; sleep 1; start ;;
  status) status ;;
  log) log "${2:-}" ;;
  *)
    echo "用法：./dev.sh start | stop | restart | status | log backend|frontend"
    exit 1
    ;;
esac
