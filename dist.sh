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
SKIP_LINUX_BUILD="0"
BOOTSTRAP_FLUTTER="1"
FLUTTER_DIR="${HOME}/tools/flutter"
LINUX_PACKAGES="all"
INSTALL_LINUX="1"
INSTALL_TYPE="deb"
ROOT_EXPORT="0"
MANIFEST_URL=""
DB_DIR=""
BUILD_ANDROID_APK="1"
BUILD_WEB="1"
TAG_ALIAS=""
DEPLOY_LOCAL="1"
DEPLOY_ROOT="app_flutter/local_deploy"

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
  --skip-linux-build  Nao gera binario Linux/DEB/AppImage (mantem conteudo/web/android)
  --no-bootstrap-flutter
                      Nao tenta instalar/configurar Flutter automaticamente
  --flutter-dir <dir> Diretorio alvo do Flutter no bootstrap (padrao: ~/tools/flutter)
  --linux-packages <m>
                      Pacotes Linux: all, deb, appimage, none (padrao: all)
  --manifest-url <u>  Override da URL padrao no app (ENEM_MANIFEST_URL)
  --db-dir <dir>      Override do diretorio padrao do banco no app (ENEM_DB_DIR)
  --android-apk       Forca gerar APK Android release
  --no-android-apk    Nao gera APK Android release
  --web               Forca gerar build Web release
  --no-web            Nao gera build Web release
  --tag-alias <nome>  Gera aliases estaveis por tag (ex.: stable) para assets/binarios
  --deploy-local      Publica web+conteudo em pasta local pronta para servidor HTTP
  --deploy-root <dir> Pasta de publicacao local (padrao: app_flutter/local_deploy)
  --root-export       Copia artefatos gerados tambem para a raiz do repositorio
  --install-linux     Instala app no Linux ao final do dist
  --no-install-linux  Nao instala app no Linux ao final do dist
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

sha256_file() {
  local input="$1"
  sha256sum "$input" | awk '{print $1}'
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
    --skip-linux-build)
      SKIP_LINUX_BUILD="1"
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
    --android-apk)
      BUILD_ANDROID_APK="1"
      shift
      ;;
    --no-android-apk)
      BUILD_ANDROID_APK="0"
      shift
      ;;
    --web)
      BUILD_WEB="1"
      shift
      ;;
    --no-web)
      BUILD_WEB="0"
      shift
      ;;
    --tag-alias)
      [[ $# -ge 2 ]] || die "faltou valor para --tag-alias"
      TAG_ALIAS="$2"
      shift 2
      ;;
    --deploy-local)
      DEPLOY_LOCAL="1"
      shift
      ;;
    --deploy-root)
      [[ $# -ge 2 ]] || die "faltou valor para --deploy-root"
      DEPLOY_ROOT="$2"
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
    --no-install-linux)
      INSTALL_LINUX="0"
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

if [[ "$SKIP_LINUX_BUILD" -eq 1 ]]; then
  LINUX_PACKAGES="none"
  if [[ "$INSTALL_LINUX" -eq 1 ]]; then
    INSTALL_LINUX="0"
  fi
fi

if [[ "$SKIP_FLUTTER" -eq 1 ]]; then
  INSTALL_LINUX="0"
  RUN_LINUX="0"
fi

if [[ -z "$VERSION" ]]; then
  VERSION="$(date -u +%Y.%m.%d.%H%M%S)"
fi

if [[ -n "$TAG_ALIAS" ]]; then
  if [[ ! "$TAG_ALIAS" =~ ^[A-Za-z0-9._-]+$ ]]; then
    die "--tag-alias invalido: use apenas letras, numeros, ponto, underline ou hífen."
  fi
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
ASSET_ARCHIVE_FILE="$(
  python3 - "$MANIFEST_PATH" <<'PY'
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
payload = json.loads(manifest_path.read_text(encoding="utf-8"))
print((payload.get("archive_file") or "").strip())
PY
)"
[[ -n "$ASSET_ARCHIVE_FILE" ]] || die "manifest sem archive_file: $MANIFEST_PATH"
ASSET_ARCHIVE_PATH="$RELEASE_DIR/$ASSET_ARCHIVE_FILE"
[[ -f "$ASSET_ARCHIVE_PATH" ]] || die "asset zip nao encontrado: $ASSET_ARCHIVE_PATH"
if [[ ! -f "$ASSET_ARCHIVE_PATH.sha256" ]]; then
  sha256sum "$ASSET_ARCHIVE_PATH" > "$ASSET_ARCHIVE_PATH.sha256"
fi

LINUX_ARCHIVE=""
BUNDLE_DIR="$APP_DIR/build/linux/x64/release/bundle"
ROOT_LINUX_ARCHIVE=""
ROOT_LINUX_BUNDLE_DIR=""
LINUX_DEB=""
ROOT_LINUX_DEB=""
LINUX_APPIMAGE=""
ROOT_LINUX_APPIMAGE=""
ANDROID_APK=""
ROOT_ANDROID_APK=""
WEB_ARCHIVE=""
ROOT_WEB_ARCHIVE=""
TAG_ASSET_FILE=""
TAG_ASSET_PATH=""
TAG_MANIFEST_PATH=""
TAG_LINUX_ARCHIVE=""
TAG_ANDROID_APK=""
TAG_WEB_ARCHIVE=""
RELEASE_MANIFEST_PATH="$RELEASE_DIR/release_manifest.json"

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

  if [[ "$SKIP_LINUX_BUILD" -eq 0 ]]; then
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
  fi

  log "preparando build do app..."
  pushd "$APP_DIR" >/dev/null
  if [[ "$SKIP_LINUX_BUILD" -eq 0 ]]; then
    flutter config --enable-linux-desktop >/dev/null
  fi
  if [[ "$BUILD_ANDROID_APK" -eq 1 ]]; then
    flutter config --enable-android >/dev/null
  fi
  if [[ "$BUILD_WEB" -eq 1 ]]; then
    flutter config --enable-web >/dev/null
  fi

  MISSING_PLATFORMS=()
  if [[ "$SKIP_LINUX_BUILD" -eq 0 && ! -f "$APP_DIR/linux/CMakeLists.txt" ]]; then
    MISSING_PLATFORMS+=("linux")
  fi
  if [[ "$BUILD_ANDROID_APK" -eq 1 && ! -d "$APP_DIR/android" ]]; then
    MISSING_PLATFORMS+=("android")
  fi
  if [[ "$BUILD_WEB" -eq 1 && ! -d "$APP_DIR/web" ]]; then
    MISSING_PLATFORMS+=("web")
  fi
  if [[ "${#MISSING_PLATFORMS[@]}" -gt 0 ]]; then
    PLATFORMS_CSV="$(IFS=,; echo "${MISSING_PLATFORMS[*]}")"
    log "projeto sem plataforma(s) ${PLATFORMS_CSV}. executando flutter create --platforms=${PLATFORMS_CSV} ..."
    flutter create --platforms="$PLATFORMS_CSV" .
  fi
  flutter pub get
  popd >/dev/null

  if [[ "$SKIP_LINUX_BUILD" -eq 0 ]]; then
    FLUTTER_BUILD_CMD=(flutter build linux --release)
    if [[ -n "$MANIFEST_URL" ]]; then
      FLUTTER_BUILD_CMD+=(--dart-define="ENEM_MANIFEST_URL=$MANIFEST_URL")
    fi
    if [[ -n "$DB_DIR" ]]; then
      FLUTTER_BUILD_CMD+=(--dart-define="ENEM_DB_DIR=$DB_DIR")
    fi
    pushd "$APP_DIR" >/dev/null
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
    log "--skip-linux-build ativo: pulando binario Linux/DEB/AppImage"
    ROOT_LINUX_ARCHIVE=""
    ROOT_LINUX_BUNDLE_DIR=""
  fi

  if [[ "$BUILD_ANDROID_APK" -eq 1 ]]; then
    log "gerando APK Android release..."
    FLUTTER_BUILD_APK_CMD=(flutter build apk --release)
    if [[ -n "$MANIFEST_URL" ]]; then
      FLUTTER_BUILD_APK_CMD+=(--dart-define="ENEM_MANIFEST_URL=$MANIFEST_URL")
    fi
    if [[ -n "$DB_DIR" ]]; then
      FLUTTER_BUILD_APK_CMD+=(--dart-define="ENEM_DB_DIR=$DB_DIR")
    fi
    pushd "$APP_DIR" >/dev/null
    "${FLUTTER_BUILD_APK_CMD[@]}"
    popd >/dev/null

    GENERATED_APK="$APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
    [[ -f "$GENERATED_APK" ]] || die "APK nao encontrado apos build: $GENERATED_APK"
    ANDROID_APK="$RELEASE_DIR/enem_offline_client_android_${VERSION}.apk"
    cp -f "$GENERATED_APK" "$ANDROID_APK"
    sha256sum "$ANDROID_APK" > "$ANDROID_APK.sha256"
    if [[ "$ROOT_EXPORT" -eq 1 ]]; then
      ROOT_ANDROID_APK="$REPO_ROOT/enem_offline_client_android_${VERSION}.apk"
      cp -f "$ANDROID_APK" "$ROOT_ANDROID_APK"
      cp -f "$ANDROID_APK.sha256" "$ROOT_ANDROID_APK.sha256"
    fi
  fi

  if [[ "$BUILD_WEB" -eq 1 ]]; then
    log "gerando build Web release..."
    FLUTTER_BUILD_WEB_CMD=(flutter build web --release)
    if [[ -n "$MANIFEST_URL" ]]; then
      FLUTTER_BUILD_WEB_CMD+=(--dart-define="ENEM_MANIFEST_URL=$MANIFEST_URL")
    fi
    if [[ -n "$DB_DIR" ]]; then
      FLUTTER_BUILD_WEB_CMD+=(--dart-define="ENEM_DB_DIR=$DB_DIR")
    fi
    pushd "$APP_DIR" >/dev/null
    "${FLUTTER_BUILD_WEB_CMD[@]}"
    popd >/dev/null

    GENERATED_WEB_DIR="$APP_DIR/build/web"
    [[ -d "$GENERATED_WEB_DIR" ]] || die "build Web nao encontrado apos build: $GENERATED_WEB_DIR"
    WEB_ARCHIVE="$RELEASE_DIR/enem_offline_client_web_${VERSION}.tar.gz"
    tar -C "$APP_DIR/build" -czf "$WEB_ARCHIVE" web
    sha256sum "$WEB_ARCHIVE" > "$WEB_ARCHIVE.sha256"
    if [[ "$ROOT_EXPORT" -eq 1 ]]; then
      ROOT_WEB_ARCHIVE="$REPO_ROOT/enem_offline_client_web_${VERSION}.tar.gz"
      cp -f "$WEB_ARCHIVE" "$ROOT_WEB_ARCHIVE"
      cp -f "$WEB_ARCHIVE.sha256" "$ROOT_WEB_ARCHIVE.sha256"
    fi
  fi
else
  log "--skip-flutter ativo: build do app ignorado"
  if [[ "$BUILD_ANDROID_APK" -eq 1 || "$BUILD_WEB" -eq 1 ]]; then
    log "flags --android-apk/--web foram ignoradas porque --skip-flutter esta ativo"
  fi
fi

if [[ -n "$TAG_ALIAS" ]]; then
  log "gerando aliases de tag: $TAG_ALIAS"
  TAG_ASSET_FILE="assets_${TAG_ALIAS}.zip"
  TAG_ASSET_PATH="$RELEASE_DIR/$TAG_ASSET_FILE"
  cp -f "$ASSET_ARCHIVE_PATH" "$TAG_ASSET_PATH"
  sha256sum "$TAG_ASSET_PATH" > "$TAG_ASSET_PATH.sha256"

  TAG_MANIFEST_PATH="$RELEASE_DIR/manifest_${TAG_ALIAS}.json"
  python3 - "$MANIFEST_PATH" "$TAG_MANIFEST_PATH" "$TAG_ASSET_FILE" "$TAG_ALIAS" <<'PY'
import json
import sys
from pathlib import Path

source_manifest = Path(sys.argv[1])
target_manifest = Path(sys.argv[2])
asset_file = sys.argv[3]
tag_alias = sys.argv[4]

payload = json.loads(source_manifest.read_text(encoding="utf-8"))
payload["archive_file"] = asset_file
payload["download_url"] = ""
payload["channel"] = tag_alias
target_manifest.write_text(
    json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY

  if [[ -f "$LINUX_ARCHIVE" ]]; then
    TAG_LINUX_ARCHIVE="$RELEASE_DIR/enem_offline_client_linux_x64_${TAG_ALIAS}.tar.gz"
    cp -f "$LINUX_ARCHIVE" "$TAG_LINUX_ARCHIVE"
    sha256sum "$TAG_LINUX_ARCHIVE" > "$TAG_LINUX_ARCHIVE.sha256"
  fi
  if [[ -f "$ANDROID_APK" ]]; then
    TAG_ANDROID_APK="$RELEASE_DIR/enem_offline_client_android_${TAG_ALIAS}.apk"
    cp -f "$ANDROID_APK" "$TAG_ANDROID_APK"
    sha256sum "$TAG_ANDROID_APK" > "$TAG_ANDROID_APK.sha256"
  fi
  if [[ -f "$WEB_ARCHIVE" ]]; then
    TAG_WEB_ARCHIVE="$RELEASE_DIR/enem_offline_client_web_${TAG_ALIAS}.tar.gz"
    cp -f "$WEB_ARCHIVE" "$TAG_WEB_ARCHIVE"
    sha256sum "$TAG_WEB_ARCHIVE" > "$TAG_WEB_ARCHIVE.sha256"
  fi
fi

RELEASE_ARTIFACT_ITEMS=(
  "manifest_json=$MANIFEST_PATH"
  "assets_zip=$ASSET_ARCHIVE_PATH"
)
if [[ -n "$TAG_MANIFEST_PATH" && -f "$TAG_MANIFEST_PATH" ]]; then
  RELEASE_ARTIFACT_ITEMS+=("manifest_tag=$TAG_MANIFEST_PATH")
fi
if [[ -n "$TAG_ASSET_PATH" && -f "$TAG_ASSET_PATH" ]]; then
  RELEASE_ARTIFACT_ITEMS+=("assets_tag=$TAG_ASSET_PATH")
fi
if [[ -f "$LINUX_ARCHIVE" ]]; then
  RELEASE_ARTIFACT_ITEMS+=("linux_tar_gz=$LINUX_ARCHIVE")
fi
if [[ -f "$LINUX_DEB" ]]; then
  RELEASE_ARTIFACT_ITEMS+=("linux_deb=$LINUX_DEB")
fi
if [[ -f "$LINUX_APPIMAGE" ]]; then
  RELEASE_ARTIFACT_ITEMS+=("linux_appimage=$LINUX_APPIMAGE")
fi
if [[ -f "$ANDROID_APK" ]]; then
  RELEASE_ARTIFACT_ITEMS+=("android_apk=$ANDROID_APK")
fi
if [[ -f "$WEB_ARCHIVE" ]]; then
  RELEASE_ARTIFACT_ITEMS+=("web_tar_gz=$WEB_ARCHIVE")
fi
if [[ -f "$TAG_LINUX_ARCHIVE" ]]; then
  RELEASE_ARTIFACT_ITEMS+=("linux_tag_tar_gz=$TAG_LINUX_ARCHIVE")
fi
if [[ -f "$TAG_ANDROID_APK" ]]; then
  RELEASE_ARTIFACT_ITEMS+=("android_tag_apk=$TAG_ANDROID_APK")
fi
if [[ -f "$TAG_WEB_ARCHIVE" ]]; then
  RELEASE_ARTIFACT_ITEMS+=("web_tag_tar_gz=$TAG_WEB_ARCHIVE")
fi

python3 - "$RELEASE_MANIFEST_PATH" "$VERSION" "$TAG_ALIAS" "${RELEASE_ARTIFACT_ITEMS[@]}" <<'PY'
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

release_manifest_path = Path(sys.argv[1])
version = sys.argv[2]
tag_alias = sys.argv[3]

artifacts = {}
for item in sys.argv[4:]:
    name, file_path = item.split("=", maxsplit=1)
    target = Path(file_path)
    if not target.is_file():
        continue
    payload = target.read_bytes()
    artifacts[name] = {
        "file": target.name,
        "sha256": hashlib.sha256(payload).hexdigest(),
        "size": len(payload),
    }

output = {
    "version": version,
    "channel": tag_alias,
    "generated_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "artifacts": artifacts,
}
release_manifest_path.write_text(
    json.dumps(output, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY

DEPLOY_ROOT_ABS=""
if [[ "$DEPLOY_LOCAL" -eq 1 ]]; then
  DEPLOY_ROOT_ABS="$(resolve_path "$DEPLOY_ROOT")"
  DEPLOY_STAGE_DIR="$(mktemp -d)"
  mkdir -p "$DEPLOY_STAGE_DIR/content" "$DEPLOY_STAGE_DIR/downloads"

  DEPLOY_WEB_SOURCE=""
  if [[ -d "$APP_DIR/build/web" ]]; then
    DEPLOY_WEB_SOURCE="$APP_DIR/build/web"
  elif [[ -f "$WEB_ARCHIVE" ]]; then
    tar -C "$DEPLOY_STAGE_DIR" -xzf "$WEB_ARCHIVE"
    if [[ -d "$DEPLOY_STAGE_DIR/web" ]]; then
      DEPLOY_WEB_SOURCE="$DEPLOY_STAGE_DIR/web"
    fi
  fi

  if [[ -n "$DEPLOY_WEB_SOURCE" ]]; then
    cp -a "$DEPLOY_WEB_SOURCE/." "$DEPLOY_STAGE_DIR/"
  else
    cat > "$DEPLOY_STAGE_DIR/index.html" <<'HTML'
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Estudo ENEM - Deploy Local</title>
</head>
<body>
  <h1>Deploy local sem build Web</h1>
  <p>Execute o dist com <code>--web</code> para publicar a interface web neste diretório.</p>
</body>
</html>
HTML
  fi

  DEPLOY_MANIFEST_SOURCE="$MANIFEST_PATH"
  DEPLOY_ASSET_SOURCE="$ASSET_ARCHIVE_PATH"
  if [[ -n "$TAG_MANIFEST_PATH" && -f "$TAG_MANIFEST_PATH" && -n "$TAG_ASSET_PATH" && -f "$TAG_ASSET_PATH" ]]; then
    DEPLOY_MANIFEST_SOURCE="$TAG_MANIFEST_PATH"
    DEPLOY_ASSET_SOURCE="$TAG_ASSET_PATH"
  fi

  cp -f "$DEPLOY_MANIFEST_SOURCE" "$DEPLOY_STAGE_DIR/content/manifest.json"
  cp -f "$DEPLOY_ASSET_SOURCE" "$DEPLOY_STAGE_DIR/content/$(basename "$DEPLOY_ASSET_SOURCE")"
  if [[ -f "$DEPLOY_ASSET_SOURCE.sha256" ]]; then
    cp -f "$DEPLOY_ASSET_SOURCE.sha256" "$DEPLOY_STAGE_DIR/content/$(basename "$DEPLOY_ASSET_SOURCE").sha256"
  fi
  cp -f "$RELEASE_MANIFEST_PATH" "$DEPLOY_STAGE_DIR/content/release_manifest.json"

  for file_path in \
    "$LINUX_ARCHIVE" "$LINUX_DEB" "$LINUX_APPIMAGE" \
    "$ANDROID_APK" "$WEB_ARCHIVE" \
    "$TAG_LINUX_ARCHIVE" "$TAG_ANDROID_APK" "$TAG_WEB_ARCHIVE"; do
    if [[ -f "$file_path" ]]; then
      cp -f "$file_path" "$DEPLOY_STAGE_DIR/downloads/$(basename "$file_path")"
      if [[ -f "$file_path.sha256" ]]; then
        cp -f "$file_path.sha256" "$DEPLOY_STAGE_DIR/downloads/$(basename "$file_path").sha256"
      fi
    fi
  done

  mkdir -p "$DEPLOY_ROOT_ABS"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$DEPLOY_STAGE_DIR/" "$DEPLOY_ROOT_ABS/"
  else
    [[ "$DEPLOY_ROOT_ABS" != "/" ]] || die "deploy-root invalido: /"
    [[ -n "$DEPLOY_ROOT_ABS" ]] || die "deploy-root vazio"
    rm -rf "$DEPLOY_ROOT_ABS"
    mkdir -p "$DEPLOY_ROOT_ABS"
    cp -a "$DEPLOY_STAGE_DIR/." "$DEPLOY_ROOT_ABS/"
  fi
  rm -rf "$DEPLOY_STAGE_DIR"

  log "deploy local publicado em: $DEPLOY_ROOT_ABS"
  log "web local: http://127.0.0.1:8787/"
  log "manifest local: http://127.0.0.1:8787/content/manifest.json"
fi

SUMMARY_PATH="$RELEASE_DIR/dist_summary.txt"
{
  printf 'version=%s\n' "$VERSION"
  printf 'generated_at_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'manifest=%s\n' "$MANIFEST_PATH"
  printf 'assets_zip=%s\n' "$ASSET_ARCHIVE_PATH"
  printf 'assets_zip_sha256_file=%s\n' "$ASSET_ARCHIVE_PATH.sha256"
  printf 'release_manifest=%s\n' "$RELEASE_MANIFEST_PATH"
  if [[ -n "$TAG_ALIAS" ]]; then
    printf 'tag_alias=%s\n' "$TAG_ALIAS"
  fi
  if [[ -n "$MANIFEST_URL" ]]; then
    printf 'build_manifest_url_override=%s\n' "$MANIFEST_URL"
  fi
  if [[ -n "$DB_DIR" ]]; then
    printf 'build_db_dir_override=%s\n' "$DB_DIR"
  fi
  if [[ -n "$TAG_MANIFEST_PATH" && -f "$TAG_MANIFEST_PATH" ]]; then
    printf 'manifest_tag=%s\n' "$TAG_MANIFEST_PATH"
  fi
  if [[ -n "$TAG_ASSET_PATH" && -f "$TAG_ASSET_PATH" ]]; then
    printf 'assets_tag=%s\n' "$TAG_ASSET_PATH"
    printf 'assets_tag_sha256_file=%s\n' "$TAG_ASSET_PATH.sha256"
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
  if [[ -f "$ANDROID_APK" ]]; then
    printf 'android_apk=%s\n' "$ANDROID_APK"
    printf 'android_apk_sha256_file=%s\n' "$ANDROID_APK.sha256"
    if [[ -n "$ROOT_ANDROID_APK" ]]; then
      printf 'root_android_apk=%s\n' "$ROOT_ANDROID_APK"
      printf 'root_android_apk_sha256_file=%s\n' "$ROOT_ANDROID_APK.sha256"
    fi
  else
    printf 'android_apk=skipped\n'
  fi
  if [[ -f "$WEB_ARCHIVE" ]]; then
    printf 'web_archive=%s\n' "$WEB_ARCHIVE"
    printf 'web_archive_sha256_file=%s\n' "$WEB_ARCHIVE.sha256"
    if [[ -n "$ROOT_WEB_ARCHIVE" ]]; then
      printf 'root_web_archive=%s\n' "$ROOT_WEB_ARCHIVE"
      printf 'root_web_archive_sha256_file=%s\n' "$ROOT_WEB_ARCHIVE.sha256"
    fi
  else
    printf 'web_archive=skipped\n'
  fi
  if [[ -f "$TAG_LINUX_ARCHIVE" ]]; then
    printf 'linux_tag_archive=%s\n' "$TAG_LINUX_ARCHIVE"
    printf 'linux_tag_archive_sha256_file=%s\n' "$TAG_LINUX_ARCHIVE.sha256"
  fi
  if [[ -f "$TAG_ANDROID_APK" ]]; then
    printf 'android_tag_apk=%s\n' "$TAG_ANDROID_APK"
    printf 'android_tag_apk_sha256_file=%s\n' "$TAG_ANDROID_APK.sha256"
  fi
  if [[ -f "$TAG_WEB_ARCHIVE" ]]; then
    printf 'web_tag_archive=%s\n' "$TAG_WEB_ARCHIVE"
    printf 'web_tag_archive_sha256_file=%s\n' "$TAG_WEB_ARCHIVE.sha256"
  fi
  if [[ "$DEPLOY_LOCAL" -eq 1 ]]; then
    printf 'local_deploy_root=%s\n' "$DEPLOY_ROOT_ABS"
  fi
} > "$SUMMARY_PATH"

log "resumo: $SUMMARY_PATH"
log "release pronto em: $RELEASE_DIR"
if [[ "$DEPLOY_LOCAL" -eq 1 ]]; then
  log "deploy local pronto: $DEPLOY_ROOT_ABS"
  log "ao servir essa pasta, use:"
  log "  web: http://127.0.0.1:8787/"
  log "  manifest de conteudo: http://127.0.0.1:8787/content/manifest.json"
elif [[ -z "$BASE_URL" ]]; then
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

if [[ "$RUN_LINUX" -eq 1 && "$SKIP_FLUTTER" -eq 0 && "$SKIP_LINUX_BUILD" -eq 0 ]]; then
  if [[ "$INSTALL_LINUX" -eq 1 && "$INSTALL_TYPE" == "deb" ]] && command -v enem-offline-client >/dev/null 2>&1; then
    log "executando app instalado (.deb): enem-offline-client"
    enem-offline-client
  else
    log "executando app linux do bundle para teste manual..."
    (
      cd "$BUNDLE_DIR"
      ./enem_offline_client
    )
  fi
else
  log "execucao final no linux desativada (--no-run, --skip-flutter ou --skip-linux-build)"
fi

log "finalizado"
