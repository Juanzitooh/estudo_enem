#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PORT="8787"
VERSION=""
SKIP_SETUP="0"
SKIP_BUILD="0"
LINUX_PACKAGES="none"

usage() {
  cat <<'USAGE'
Uso:
  ./dev_linux.sh [opcoes]

Opcoes:
  --version <v>       Versao a usar no dist (padrao: local.YYYYMMDDHHMMSS)
  --port <n>          Porta do servidor local de manifest (padrao: 8787)
  --skip-setup        Nao roda setup do Flutter/dependencias
  --skip-build        Nao roda dist.sh (usa release existente)
  --linux-packages <m>
                      Pacotes Linux no dist: all, deb, appimage, none (padrao: none)
  -h, --help          Mostra esta ajuda

Exemplos:
  ./dev_linux.sh
  ./dev_linux.sh --version local.0.1
  ./dev_linux.sh --version local.0.1 --skip-setup --skip-build
USAGE
}

log() {
  printf '[dev-linux] %s\n' "$*"
}

die() {
  printf '[dev-linux][erro] %s\n' "$*" >&2
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
    --linux-packages)
      [[ $# -ge 2 ]] || die "faltou valor para --linux-packages"
      LINUX_PACKAGES="$2"
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
case "$LINUX_PACKAGES" in
  all|deb|appimage|none) ;;
  *) die "--linux-packages invalido: $LINUX_PACKAGES (use all, deb, appimage, none)" ;;
esac

if [[ -z "$VERSION" ]]; then
  VERSION="local.$(date +%Y%m%d%H%M%S)"
fi

if [[ "$SKIP_SETUP" -eq 0 ]]; then
  log "rodando setup automatico de Flutter/dependencias..."
  ./scripts/setup_flutter_linux.sh
else
  log "--skip-setup ativo"
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  log "gerando release local com dist.sh..."
  ./dist.sh --version "$VERSION" --no-run --linux-packages "$LINUX_PACKAGES"
else
  log "--skip-build ativo"
fi

RELEASE_DIR="$SCRIPT_DIR/app_flutter/releases/$VERSION"
[[ -f "$RELEASE_DIR/manifest.json" ]] || die "manifest nao encontrado em $RELEASE_DIR"

APP_BIN="$SCRIPT_DIR/app_flutter/enem_offline_client/build/linux/x64/release/bundle/enem_offline_client"
[[ -x "$APP_BIN" ]] || die "binario do app nao encontrado: $APP_BIN"

SERVER_LOG="$RELEASE_DIR/dev_http_server.log"
MANIFEST_URL="http://127.0.0.1:${PORT}/manifest.json"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

log "subindo servidor local em background..."
(
  cd "$RELEASE_DIR"
  python3 -m http.server "$PORT" >"$SERVER_LOG" 2>&1
) &
SERVER_PID=$!

sleep 0.6
if ! kill -0 "$SERVER_PID" >/dev/null 2>&1; then
  tail -n 40 "$SERVER_LOG" >&2 || true
  die "falha ao subir servidor HTTP na porta $PORT"
fi

log "manifest para update: $MANIFEST_URL"
log "dica: no app, cole a URL e clique em 'Atualizar por manifest'"
log "abrindo app Linux..."

XCURSOR_THEME="${XCURSOR_THEME:-Adwaita}" \
XCURSOR_SIZE="${XCURSOR_SIZE:-24}" \
"$APP_BIN"
