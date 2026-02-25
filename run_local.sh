#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PORT="8787"
VERSION=""
SKIP_SETUP="0"
SKIP_BUILD="0"

usage() {
  cat <<'USAGE'
Uso:
  ./run_local.sh [opcoes]

Opcoes:
  --version <v>   Versao a usar no dist (padrao: local.YYYYMMDDHHMMSS)
  --port <n>      Porta do servidor local (padrao: 8787)
  --skip-setup    Nao roda setup do Flutter/dependencias
  --skip-build    Nao roda dist.sh (serve versao ja existente)
  -h, --help      Mostra esta ajuda

Exemplos:
  ./run_local.sh
  ./run_local.sh --version local.0.1
  ./run_local.sh --version local.0.1 --port 9999 --skip-setup
USAGE
}

die() {
  printf '[run-local][erro] %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[run-local] %s\n' "$*"
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
  log "rodando setup automatico de Flutter/dependencias..."
  ./scripts/setup_flutter_linux.sh
else
  log "--skip-setup ativo"
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  log "gerando release local com dist.sh..."
  ./dist.sh --version "$VERSION" --no-run
else
  log "--skip-build ativo"
fi

RELEASE_DIR="$SCRIPT_DIR/app_flutter/releases/$VERSION"
[[ -f "$RELEASE_DIR/manifest.json" ]] || die "manifest nao encontrado em $RELEASE_DIR"

log "manifest local: http://127.0.0.1:${PORT}/manifest.json"
log "subindo servidor local (Ctrl+C para encerrar)..."
cd "$RELEASE_DIR"
python3 -m http.server "$PORT"
