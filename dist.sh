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
BOOTSTRAP_FLUTTER="1"
FLUTTER_DIR="${HOME}/tools/flutter"
LINUX_PACKAGES="all"
INSTALL_LINUX="0"
INSTALL_TYPE="deb"
ROOT_EXPORT="0"
MANIFEST_URL=""
DB_DIR=""

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
  --no-bootstrap-flutter
                      Nao tenta instalar/configurar Flutter automaticamente
  --flutter-dir <dir> Diretorio alvo do Flutter no bootstrap (padrao: ~/tools/flutter)
  --linux-packages <m>
                      Pacotes Linux: all, deb, appimage, none (padrao: all)
  --manifest-url <u>  Override da URL padrao no app (ENEM_MANIFEST_URL)
  --db-dir <dir>      Override do diretorio padrao do banco no app (ENEM_DB_DIR)
  --root-export       Copia artefatos Linux tambem para a raiz do repositorio
  --install-linux     Instala app no Linux ao final do dist
  --install-type <t>  Tipo de instalacao: deb, appimage ou bundle (padrao: deb)
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
    --no-bootstrap-flutter)
      BOOTSTRAP_FLUTTER="0"
      shift
      ;;
    --flutter-dir)
      [[ $# -ge 2 ]] || die "faltou valor para --flutter-dir"
      FLUTTER_DIR="$2"
      shift 2
      ;;
    --linux-packages)
      [[ $# -ge 2 ]] || die "faltou valor para --linux-packages"
      LINUX_PACKAGES="$2"
      shift 2
      ;;
    --manifest-url)
      [[ $# -ge 2 ]] || die "faltou valor para --manifest-url"
      MANIFEST_URL="$2"
      shift 2
      ;;
    --db-dir)
      [[ $# -ge 2 ]] || die "faltou valor para --db-dir"
      DB_DIR="$2"
      shift 2
      ;;
    --root-export)
      ROOT_EXPORT="1"
      shift
      ;;
    --install-linux)
      INSTALL_LINUX="1"
      shift
      ;;
    --install-type)
      [[ $# -ge 2 ]] || die "faltou valor para --install-type"
      INSTALL_TYPE="$2"
      shift 2
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
case "$LINUX_PACKAGES" in
  all|deb|appimage|none) ;;
  *) die "--linux-packages invalido: $LINUX_PACKAGES (use all, deb, appimage, none)" ;;
esac
case "$INSTALL_TYPE" in
  deb|appimage|bundle) ;;
  *) die "--install-type invalido: $INSTALL_TYPE (use deb, appimage, bundle)" ;;
esac

if [[ -z "$VERSION" ]]; then
  VERSION="$(date -u +%Y.%m.%d.%H%M%S)"
fi

QUESTIONS_CSV="$REPO_ROOT/questoes/mapeamento_habilidades/questoes_mapeadas.csv"
MODULES_CSV="$REPO_ROOT/plano/indice_livros_6_volumes.csv"
ASSET_BUILDER="$REPO_ROOT/scripts/build_assets_release.py"
APP_DIR="$REPO_ROOT/app_flutter/enem_offline_client"
OUT_DIR_ABS="$(resolve_path "$OUT_DIR")"
RELEASE_DIR="$OUT_DIR_ABS/$VERSION"
FLUTTER_SETUP_SCRIPT="$REPO_ROOT/scripts/setup_flutter_linux.sh"
LINUX_PACKAGE_SCRIPT="$REPO_ROOT/scripts/package_linux_artifacts.sh"
LINUX_INSTALL_SCRIPT="$REPO_ROOT/install_linux.sh"

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
if [[ -n "$MANIFEST_URL" ]]; then
  log "override manifest-url: $MANIFEST_URL"
fi
if [[ -n "$DB_DIR" ]]; then
  log "override db-dir: $DB_DIR"
fi

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
ROOT_LINUX_ARCHIVE=""
ROOT_LINUX_BUNDLE_DIR=""
LINUX_DEB=""
ROOT_LINUX_DEB=""
LINUX_APPIMAGE=""
ROOT_LINUX_APPIMAGE=""

if [[ "$SKIP_FLUTTER" -eq 0 ]]; then
  if ! command -v flutter >/dev/null 2>&1; then
    if [[ -x "$FLUTTER_DIR/bin/flutter" ]]; then
      log "flutter encontrado em $FLUTTER_DIR/bin/flutter. ajustando PATH..."
      export PATH="$FLUTTER_DIR/bin:$PATH"
    elif [[ "$BOOTSTRAP_FLUTTER" -eq 1 ]]; then
      [[ -x "$FLUTTER_SETUP_SCRIPT" ]] || die "script de setup do Flutter nao encontrado/executavel: $FLUTTER_SETUP_SCRIPT"
      log "flutter nao encontrado. executando bootstrap automatico..."
      "$FLUTTER_SETUP_SCRIPT" --method auto --flutter-dir "$FLUTTER_DIR"
      export PATH="$FLUTTER_DIR/bin:$PATH"
    fi
  fi

  command -v flutter >/dev/null 2>&1 || die "flutter nao encontrado no PATH (use scripts/setup_flutter_linux.sh ou ajuste --flutter-dir)"

  MISSING_LINUX_TOOLS=()
  for tool in clang++ cmake ninja; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      MISSING_LINUX_TOOLS+=("$tool")
    fi
  done
  if [[ ! -x "/usr/lib/llvm-18/bin/ld.lld" && ! -x "/usr/lib/llvm-18/bin/ld" ]]; then
    if ! command -v ld.lld >/dev/null 2>&1; then
      MISSING_LINUX_TOOLS+=("ld.lld")
    fi
  fi

  if [[ "${#MISSING_LINUX_TOOLS[@]}" -gt 0 && "$BOOTSTRAP_FLUTTER" -eq 1 ]]; then
    [[ -x "$FLUTTER_SETUP_SCRIPT" ]] || die "script de setup do Flutter nao encontrado/executavel: $FLUTTER_SETUP_SCRIPT"
    log "dependencias Linux ausentes (${MISSING_LINUX_TOOLS[*]}). tentando bootstrap..."
    "$FLUTTER_SETUP_SCRIPT" --method auto --flutter-dir "$FLUTTER_DIR"
    export PATH="$FLUTTER_DIR/bin:$PATH"

    MISSING_LINUX_TOOLS=()
    for tool in clang++ cmake ninja; do
      if ! command -v "$tool" >/dev/null 2>&1; then
        MISSING_LINUX_TOOLS+=("$tool")
      fi
    done
    if [[ ! -x "/usr/lib/llvm-18/bin/ld.lld" && ! -x "/usr/lib/llvm-18/bin/ld" ]]; then
      if ! command -v ld.lld >/dev/null 2>&1; then
        MISSING_LINUX_TOOLS+=("ld.lld")
      fi
    fi
  fi

  if [[ "${#MISSING_LINUX_TOOLS[@]}" -gt 0 ]]; then
    die "dependencias Linux ausentes (${MISSING_LINUX_TOOLS[*]}). Rode scripts/setup_flutter_linux.sh (sem --skip-deps) ou sudo apt install -y lld clang cmake ninja-build."
  fi

  log "preparando build linux do app..."
  pushd "$APP_DIR" >/dev/null
  flutter config --enable-linux-desktop >/dev/null
  if [[ ! -f "$APP_DIR/linux/CMakeLists.txt" ]]; then
    log "projeto sem plataforma Linux. executando flutter create --platforms=linux ..."
    flutter create --platforms=linux .
  fi
  flutter pub get
  FLUTTER_BUILD_CMD=(flutter build linux --release)
  if [[ -n "$MANIFEST_URL" ]]; then
    FLUTTER_BUILD_CMD+=(--dart-define="ENEM_MANIFEST_URL=$MANIFEST_URL")
  fi
  if [[ -n "$DB_DIR" ]]; then
    FLUTTER_BUILD_CMD+=(--dart-define="ENEM_DB_DIR=$DB_DIR")
  fi
  "${FLUTTER_BUILD_CMD[@]}"
  popd >/dev/null

  [[ -d "$BUNDLE_DIR" ]] || die "bundle linux nao encontrado: $BUNDLE_DIR"
  [[ -x "$BUNDLE_DIR/enem_offline_client" ]] || die "binario linux nao encontrado: $BUNDLE_DIR/enem_offline_client"

  LINUX_ARCHIVE="$RELEASE_DIR/enem_offline_client_linux_x64_${VERSION}.tar.gz"
  log "empacotando binario linux em: $LINUX_ARCHIVE"
  tar -C "$APP_DIR/build/linux/x64/release" -czf "$LINUX_ARCHIVE" bundle
  sha256sum "$LINUX_ARCHIVE" > "$LINUX_ARCHIVE.sha256"

  ROOT_LINUX_ARCHIVE="$REPO_ROOT/enem_offline_client_linux_x64_${VERSION}.tar.gz"
  ROOT_LINUX_BUNDLE_DIR="$REPO_ROOT/enem_offline_client_linux_x64_${VERSION}"
  if [[ "$ROOT_EXPORT" -eq 1 ]]; then
    log "copiando artefatos Linux para a raiz do repo..."
    cp -f "$LINUX_ARCHIVE" "$ROOT_LINUX_ARCHIVE"
    cp -f "$LINUX_ARCHIVE.sha256" "$ROOT_LINUX_ARCHIVE.sha256"
    mkdir -p "$ROOT_LINUX_BUNDLE_DIR"
    cp -a "$BUNDLE_DIR/." "$ROOT_LINUX_BUNDLE_DIR/"
    [[ -x "$ROOT_LINUX_BUNDLE_DIR/enem_offline_client" ]] || die "binario nao encontrado na copia da raiz: $ROOT_LINUX_BUNDLE_DIR/enem_offline_client"
    log "app Linux (pasta) na raiz: $ROOT_LINUX_BUNDLE_DIR"
    log "app Linux (tar.gz) na raiz: $ROOT_LINUX_ARCHIVE"
  else
    ROOT_LINUX_ARCHIVE=""
    ROOT_LINUX_BUNDLE_DIR=""
    log "root-export desativado: artefatos Linux ficam em $RELEASE_DIR"
  fi

  if [[ "$LINUX_PACKAGES" != "none" ]]; then
    [[ -x "$LINUX_PACKAGE_SCRIPT" ]] || die "script de empacotamento Linux nao encontrado: $LINUX_PACKAGE_SCRIPT"
    log "gerando pacotes Linux: $LINUX_PACKAGES"
    "$LINUX_PACKAGE_SCRIPT" \
      --version "$VERSION" \
      --bundle-dir "$BUNDLE_DIR" \
      --release-dir "$RELEASE_DIR" \
      --repo-root "$REPO_ROOT" \
      --packages "$LINUX_PACKAGES" \
      --copy-to-root "$ROOT_EXPORT"

    if [[ -f "$RELEASE_DIR/enem_offline_client_linux_x64_${VERSION}.deb" ]]; then
      LINUX_DEB="$RELEASE_DIR/enem_offline_client_linux_x64_${VERSION}.deb"
      if [[ "$ROOT_EXPORT" -eq 1 && -f "$REPO_ROOT/enem_offline_client_linux_x64_${VERSION}.deb" ]]; then
        ROOT_LINUX_DEB="$REPO_ROOT/enem_offline_client_linux_x64_${VERSION}.deb"
      fi
    fi
    if [[ -f "$RELEASE_DIR/enem_offline_client_linux_x64_${VERSION}.AppImage" ]]; then
      LINUX_APPIMAGE="$RELEASE_DIR/enem_offline_client_linux_x64_${VERSION}.AppImage"
      if [[ "$ROOT_EXPORT" -eq 1 && -f "$REPO_ROOT/enem_offline_client_linux_x64_${VERSION}.AppImage" ]]; then
        ROOT_LINUX_APPIMAGE="$REPO_ROOT/enem_offline_client_linux_x64_${VERSION}.AppImage"
      fi
    fi
  fi
else
  log "--skip-flutter ativo: build do app ignorado"
fi

SUMMARY_PATH="$RELEASE_DIR/dist_summary.txt"
{
  printf 'version=%s\n' "$VERSION"
  printf 'generated_at_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'manifest=%s\n' "$MANIFEST_PATH"
  if [[ -n "$MANIFEST_URL" ]]; then
    printf 'build_manifest_url_override=%s\n' "$MANIFEST_URL"
  fi
  if [[ -n "$DB_DIR" ]]; then
    printf 'build_db_dir_override=%s\n' "$DB_DIR"
  fi
  if [[ -f "$LINUX_ARCHIVE" ]]; then
    printf 'linux_archive=%s\n' "$LINUX_ARCHIVE"
    printf 'linux_archive_sha256_file=%s\n' "$LINUX_ARCHIVE.sha256"
    if [[ -n "$ROOT_LINUX_ARCHIVE" ]]; then
      printf 'root_linux_archive=%s\n' "$ROOT_LINUX_ARCHIVE"
      printf 'root_linux_archive_sha256_file=%s\n' "$ROOT_LINUX_ARCHIVE.sha256"
    fi
    if [[ -n "$ROOT_LINUX_BUNDLE_DIR" ]]; then
      printf 'root_linux_bundle_dir=%s\n' "$ROOT_LINUX_BUNDLE_DIR"
    fi
    if [[ -n "$LINUX_DEB" ]]; then
      printf 'linux_deb=%s\n' "$LINUX_DEB"
      if [[ -n "$ROOT_LINUX_DEB" ]]; then
        printf 'root_linux_deb=%s\n' "$ROOT_LINUX_DEB"
      fi
    fi
    if [[ -n "$LINUX_APPIMAGE" ]]; then
      printf 'linux_appimage=%s\n' "$LINUX_APPIMAGE"
      if [[ -n "$ROOT_LINUX_APPIMAGE" ]]; then
        printf 'root_linux_appimage=%s\n' "$ROOT_LINUX_APPIMAGE"
      fi
    fi
  else
    printf 'linux_archive=skipped\n'
  fi
} > "$SUMMARY_PATH"

log "resumo: $SUMMARY_PATH"
log "release pronto em: $RELEASE_DIR"
if [[ -z "$BASE_URL" ]]; then
  log "base-url nao informada: use manifest local via HTTP."
  log "exemplo: (cd \"$RELEASE_DIR\" && python3 -m http.server 8787)"
  log "manifest local: http://127.0.0.1:8787/manifest.json"
fi

if [[ "$INSTALL_LINUX" -eq 1 ]]; then
  [[ -x "$LINUX_INSTALL_SCRIPT" ]] || die "script de instalacao Linux nao encontrado: $LINUX_INSTALL_SCRIPT"
  log "instalando no Linux (tipo: $INSTALL_TYPE)..."
  "$LINUX_INSTALL_SCRIPT" \
    --type "$INSTALL_TYPE" \
    --version "$VERSION" \
    --release-dir "$RELEASE_DIR" \
    --bundle-dir "$BUNDLE_DIR"
fi

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
