#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PORT="8787"
VERSION=""
SKIP_SETUP="0"
SKIP_BUILD="0"
DEPLOY_ROOT="app_flutter/local_deploy"
TAG_ALIAS=""

usage() {
  cat <<'USAGE'
Uso:
  ./deploy.sh [opcoes]

Opcoes:
  --version <v>       Versao para gerar deploy local (padrao: local.YYYYMMDDHHMMSS)
  --port <n>          Porta do servidor local (padrao: 8787)
  --skip-setup        Nao roda setup de dependencias
  --skip-build        Nao roda dist.sh (usa deploy local ja existente)
  --deploy-root <dir> Pasta do deploy local (padrao: app_flutter/local_deploy)
  --tag-alias <nome>  Alias opcional para gerar manifest/tag no dist
  -h, --help          Mostra esta ajuda

Exemplos:
  ./deploy.sh
  ./deploy.sh --version local.20260227
  ./deploy.sh --skip-build --port 8788
USAGE
}

log() {
  printf '[deploy-linux] %s\n' "$*"
}

die() {
  printf '[deploy-linux][erro] %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || die "faltou valor para --version"
      VERSION="$2"
      shift 2
      ;;
    --port)
      [[ $# -ge 2 ]] || die "faltou valor para --port"
      PORT="$2"
      shift 2
      ;;
    --skip-setup)
      SKIP_SETUP="1"
      shift
      ;;
    --skip-build)
      SKIP_BUILD="1"
      shift
      ;;
    --deploy-root)
      [[ $# -ge 2 ]] || die "faltou valor para --deploy-root"
      DEPLOY_ROOT="$2"
      shift 2
      ;;
    --tag-alias)
      [[ $# -ge 2 ]] || die "faltou valor para --tag-alias"
      TAG_ALIAS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "opcao desconhecida: $1"
      ;;
  esac
done

[[ "$PORT" =~ ^[0-9]+$ ]] || die "--port deve ser numero inteiro"

if [[ -z "$VERSION" ]]; then
  VERSION="local.$(date +%Y%m%d%H%M%S)"
fi

if [[ "$SKIP_SETUP" -eq 0 ]]; then
  log "rodando setup de dependencias..."
  ./scripts/setup_flutter_linux.sh
else
  log "--skip-setup ativo"
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  log "gerando deploy local web via dist.sh..."
  DIST_CMD=(
    ./dist.sh
    --version "$VERSION"
    --linux-packages none
    --skip-linux-build
    --no-android-apk
    --web
    --deploy-local
    --deploy-root "$DEPLOY_ROOT"
    --no-install-linux
    --no-run
  )
  if [[ -n "$TAG_ALIAS" ]]; then
    DIST_CMD+=(--tag-alias "$TAG_ALIAS")
  fi
  "${DIST_CMD[@]}"
else
  log "--skip-build ativo"
fi

resolve_path() {
  local input="$1"
  if [[ "$input" = /* ]]; then
    printf '%s\n' "$input"
  else
    printf '%s/%s\n' "$SCRIPT_DIR" "$input"
  fi
}

DEPLOY_ROOT_ABS="$(resolve_path "$DEPLOY_ROOT")"
MANIFEST_PATH="$DEPLOY_ROOT_ABS/content/manifest.json"
[[ -f "$MANIFEST_PATH" ]] || die "manifest local nao encontrado em: $MANIFEST_PATH"

SERVER_LOG="$DEPLOY_ROOT_ABS/deploy_http_server.log"
SERVER_PID_FILE="$DEPLOY_ROOT_ABS/deploy_http_server.pid"
WEB_URL="http://127.0.0.1:${PORT}/"
MANIFEST_URL="http://127.0.0.1:${PORT}/content/manifest.json"
LOCAL_MANIFEST_HASH="$(sha256sum "$MANIFEST_PATH" | awk '{print $1}')"

is_port_listening() {
  local port="$1"
  python3 - "$port" <<'PY'
import socket
import sys

port = int(sys.argv[1])
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.settimeout(0.35)
try:
    result = sock.connect_ex(("127.0.0.1", port))
    sys.exit(0 if result == 0 else 1)
finally:
    sock.close()
PY
}

fetch_remote_manifest_hash() {
  local url="$1"
  python3 - "$url" <<'PY'
import hashlib
import sys
import urllib.request

url = sys.argv[1]
try:
    with urllib.request.urlopen(url, timeout=1.2) as response:
        payload = response.read()
except Exception:
    sys.exit(1)
print(hashlib.sha256(payload).hexdigest())
PY
}

find_next_free_port() {
  local start_port="$1"
  local candidate="$start_port"
  local tries=0
  while [[ "$tries" -lt 64 && "$candidate" -le 65535 ]]; do
    if ! is_port_listening "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
    candidate=$((candidate + 1))
    tries=$((tries + 1))
  done
  return 1
}

if [[ -f "$SERVER_PID_FILE" ]]; then
  OLD_PID="$(cat "$SERVER_PID_FILE" 2>/dev/null || true)"
  if [[ -n "$OLD_PID" ]] && ! kill -0 "$OLD_PID" >/dev/null 2>&1; then
    rm -f "$SERVER_PID_FILE"
  fi
fi

if is_port_listening "$PORT"; then
  log "porta $PORT ja esta em uso. validando reutilizacao..."
  REMOTE_MANIFEST_HASH="$(fetch_remote_manifest_hash "$MANIFEST_URL" || true)"
  if [[ -n "$REMOTE_MANIFEST_HASH" && "$REMOTE_MANIFEST_HASH" == "$LOCAL_MANIFEST_HASH" ]]; then
    log "servidor existente ja publica o mesmo deploy. reutilizando porta $PORT."
  else
    NEXT_PORT="$(find_next_free_port "$((PORT + 1))" || true)"
    [[ -n "$NEXT_PORT" ]] || die "porta $PORT ocupada e nao foi possivel achar porta livre."
    PORT="$NEXT_PORT"
    WEB_URL="http://127.0.0.1:${PORT}/"
    MANIFEST_URL="http://127.0.0.1:${PORT}/content/manifest.json"
    log "porta original ocupada por outro processo. usando porta $PORT."
  fi
fi

if ! is_port_listening "$PORT"; then
  log "subindo servidor local na porta $PORT..."
  (
    cd "$DEPLOY_ROOT_ABS"
    nohup python3 -m http.server "$PORT" >"$SERVER_LOG" 2>&1 &
    echo $! > "$SERVER_PID_FILE"
  )
  sleep 0.6
  if ! is_port_listening "$PORT"; then
    tail -n 40 "$SERVER_LOG" >&2 || true
    die "falha ao subir servidor HTTP na porta $PORT"
  fi
else
  log "servidor local ja ativo na porta $PORT."
fi

log "site local: $WEB_URL"
log "manifest local: $MANIFEST_URL"

if command -v xdg-open >/dev/null 2>&1; then
  log "abrindo navegador..."
  xdg-open "$WEB_URL" >/dev/null 2>&1 || true
else
  log "xdg-open indisponivel. abra manualmente: $WEB_URL"
fi

log "deploy local pronto."
