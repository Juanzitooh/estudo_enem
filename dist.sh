#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

VERSION=""
BASE_URL=""
OUT_DIR="app_flutter/releases"
LIMIT="0"
RUN_LINUX="1"
SKIP_FLUTTER="0"

usage() {
  cat <<'USAGE'
Uso:
  ./dist.sh [opcoes]

Opcoes:
  --version <v>       Versao de release (padrao: UTC atual YYYY.MM.DD.HHMMSS)
  --base-url <url>    URL base de publicacao (sem versao). Ex.: https://host/releases
  --out-dir <dir>     Diretorio de saida dos artefatos (padrao: app_flutter/releases)
  --limit <n>         Limite de questoes no bundle (0 = todas)
  --skip-flutter      Nao roda flutter pub/build (gera so conteudo)
  --no-run            Nao executa o app linux no final
  -h, --help          Mostra esta ajuda

Exemplo:
  ./dist.sh --version 2026.02.24.1 --base-url https://host/releases
USAGE
}

log() {
  printf '[dist] %s\n' "$*"
}

die() {
  printf '[dist][erro] %s\n' "$*" >&2
  exit 1
}

resolve_path() {
  local input="$1"
  if [[ "$input" = /* ]]; then
    printf '%s\n' "$input"
  else
    printf '%s/%s\n' "$REPO_ROOT" "$input"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || die "faltou valor para --version"
      VERSION="$2"
      shift 2
      ;;
    --base-url)
      [[ $# -ge 2 ]] || die "faltou valor para --base-url"
      BASE_URL="$2"
      shift 2
      ;;
    --out-dir)
      [[ $# -ge 2 ]] || die "faltou valor para --out-dir"
      OUT_DIR="$2"
      shift 2
      ;;
    --limit)
      [[ $# -ge 2 ]] || die "faltou valor para --limit"
      LIMIT="$2"
      shift 2
      ;;
    --skip-flutter)
      SKIP_FLUTTER="1"
      shift
      ;;
    --no-run)
      RUN_LINUX="0"
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

[[ "$LIMIT" =~ ^[0-9]+$ ]] || die "--limit deve ser inteiro >= 0"

if [[ -z "$VERSION" ]]; then
  VERSION="$(date -u +%Y.%m.%d.%H%M%S)"
fi

QUESTIONS_CSV="$REPO_ROOT/questoes/mapeamento_habilidades/questoes_mapeadas.csv"
MODULES_CSV="$REPO_ROOT/plano/indice_livros_6_volumes.csv"
ASSET_BUILDER="$REPO_ROOT/scripts/build_assets_release.py"
APP_DIR="$REPO_ROOT/app_flutter/enem_offline_client"
OUT_DIR_ABS="$(resolve_path "$OUT_DIR")"
RELEASE_DIR="$OUT_DIR_ABS/$VERSION"

[[ -f "$QUESTIONS_CSV" ]] || die "CSV de questoes nao encontrado: $QUESTIONS_CSV"
[[ -f "$MODULES_CSV" ]] || die "CSV de modulos nao encontrado: $MODULES_CSV"
[[ -f "$ASSET_BUILDER" ]] || die "script nao encontrado: $ASSET_BUILDER"
[[ -d "$APP_DIR" ]] || die "diretorio do app nao encontrado: $APP_DIR"

mkdir -p "$OUT_DIR_ABS"

CONTENT_BASE_URL=""
if [[ -n "$BASE_URL" ]]; then
  CONTENT_BASE_URL="${BASE_URL%/}/$VERSION"
fi

log "versao: $VERSION"
log "saida: $OUT_DIR_ABS"

BUILD_CONTENT_CMD=(
  python3 "$ASSET_BUILDER"
  --questions-csv "$QUESTIONS_CSV"
  --modules-csv "$MODULES_CSV"
  --out-dir "$OUT_DIR_ABS"
  --version "$VERSION"
)

if [[ "$LIMIT" -gt 0 ]]; then
  BUILD_CONTENT_CMD+=(--limit "$LIMIT")
fi

if [[ -n "$CONTENT_BASE_URL" ]]; then
  BUILD_CONTENT_CMD+=(--base-url "$CONTENT_BASE_URL")
fi

log "gerando pacote de conteudo (manifest + zip)..."
"${BUILD_CONTENT_CMD[@]}"

MANIFEST_PATH="$RELEASE_DIR/manifest.json"
[[ -f "$MANIFEST_PATH" ]] || die "manifest nao gerado: $MANIFEST_PATH"

LINUX_ARCHIVE=""
BUNDLE_DIR="$APP_DIR/build/linux/x64/release/bundle"

if [[ "$SKIP_FLUTTER" -eq 0 ]]; then
  command -v flutter >/dev/null 2>&1 || die "flutter nao encontrado no PATH"

  log "preparando build linux do app..."
  pushd "$APP_DIR" >/dev/null
  flutter config --enable-linux-desktop >/dev/null
  flutter pub get
  flutter build linux --release
  popd >/dev/null

  [[ -d "$BUNDLE_DIR" ]] || die "bundle linux nao encontrado: $BUNDLE_DIR"
  [[ -x "$BUNDLE_DIR/enem_offline_client" ]] || die "binario linux nao encontrado: $BUNDLE_DIR/enem_offline_client"

  LINUX_ARCHIVE="$RELEASE_DIR/enem_offline_client_linux_x64_${VERSION}.tar.gz"
  log "empacotando binario linux em: $LINUX_ARCHIVE"
  tar -C "$APP_DIR/build/linux/x64/release" -czf "$LINUX_ARCHIVE" bundle
  sha256sum "$LINUX_ARCHIVE" > "$LINUX_ARCHIVE.sha256"
else
  log "--skip-flutter ativo: build do app ignorado"
fi

SUMMARY_PATH="$RELEASE_DIR/dist_summary.txt"
{
  printf 'version=%s\n' "$VERSION"
  printf 'generated_at_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'manifest=%s\n' "$MANIFEST_PATH"
  if [[ -f "$LINUX_ARCHIVE" ]]; then
    printf 'linux_archive=%s\n' "$LINUX_ARCHIVE"
    printf 'linux_archive_sha256_file=%s\n' "$LINUX_ARCHIVE.sha256"
  else
    printf 'linux_archive=skipped\n'
  fi
} > "$SUMMARY_PATH"

log "resumo: $SUMMARY_PATH"
log "release pronto em: $RELEASE_DIR"

if [[ "$RUN_LINUX" -eq 1 && "$SKIP_FLUTTER" -eq 0 ]]; then
  log "executando app linux para teste manual... (feche a janela para encerrar o script)"
  (
    cd "$BUNDLE_DIR"
    ./enem_offline_client
  )
else
  log "execucao final no linux desativada (--no-run ou --skip-flutter)"
fi

log "finalizado"
