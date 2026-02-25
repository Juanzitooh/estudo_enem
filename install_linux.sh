#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

TYPE="deb"
VERSION=""
RELEASE_DIR=""
BUNDLE_DIR=""

usage() {
  cat <<'USAGE'
Uso:
  ./install_linux.sh [opcoes]

Opcoes:
  --type <deb|appimage|bundle> Tipo de instalacao (padrao: deb)
  --version <v>                Versao do artefato (padrao: detecta o mais recente)
  --release-dir <dir>          Diretorio da release (prioritario para .deb/.AppImage)
  --bundle-dir <dir>           Diretorio do bundle Linux (prioritario para --type bundle)
  -h, --help                   Mostra esta ajuda

Exemplos:
  ./install_linux.sh
  ./install_linux.sh --type appimage
  ./install_linux.sh --type deb --version local.20260225095640
USAGE
}

log() {
  printf '[install-linux] %s\n' "$*"
}

die() {
  printf '[install-linux][erro] %s\n' "$*" >&2
  exit 1
}

detect_latest_version() {
  local pattern="$1"
  local search_dir="$2"
  local latest=""
  shopt -s nullglob
  local files=("$search_dir"/$pattern)
  shopt -u nullglob
  if [[ "${#files[@]}" -eq 0 ]]; then
    return 1
  fi
  latest="$(printf '%s\n' "${files[@]}" | sort -V | tail -n 1)"
  latest="${latest##*_x64_}"
  latest="${latest%.deb}"
  latest="${latest%.AppImage}"
  printf '%s\n' "$latest"
}

detect_latest_bundle_version() {
  local search_dir="$1"
  local latest=""
  local filtered=()
  shopt -s nullglob
  local dirs=("$search_dir"/enem_offline_client_linux_x64_*)
  shopt -u nullglob

  if [[ "${#dirs[@]}" -eq 0 ]]; then
    return 1
  fi

  for path in "${dirs[@]}"; do
    if [[ -d "$path" ]]; then
      filtered+=("$path")
    fi
  done

  if [[ "${#filtered[@]}" -eq 0 ]]; then
    return 1
  fi

  latest="$(printf '%s\n' "${filtered[@]}" | sort -V | tail -n 1)"
  [[ -n "$latest" ]] || return 1
  latest="${latest##*_x64_}"
  printf '%s\n' "$latest"
}

install_deb() {
  local package_path=""
  if [[ -n "$RELEASE_DIR" && -f "$RELEASE_DIR/enem_offline_client_linux_x64_${VERSION}.deb" ]]; then
    package_path="$RELEASE_DIR/enem_offline_client_linux_x64_${VERSION}.deb"
  else
    package_path="$REPO_ROOT/enem_offline_client_linux_x64_${VERSION}.deb"
  fi
  [[ -f "$package_path" ]] || die "arquivo .deb nao encontrado: $package_path"

  command -v sudo >/dev/null 2>&1 || die "sudo nao encontrado para instalar .deb"

  log "instalando .deb via apt..."
  sudo apt-get install -y "$package_path"
  log "instalado. Execute pelo menu ou comando: enem-offline-client"
}

install_appimage() {
  local appimage_path=""
  if [[ -n "$RELEASE_DIR" && -f "$RELEASE_DIR/enem_offline_client_linux_x64_${VERSION}.AppImage" ]]; then
    appimage_path="$RELEASE_DIR/enem_offline_client_linux_x64_${VERSION}.AppImage"
  else
    appimage_path="$REPO_ROOT/enem_offline_client_linux_x64_${VERSION}.AppImage"
  fi
  [[ -f "$appimage_path" ]] || die "arquivo AppImage nao encontrado: $appimage_path"

  local dest_dir="${HOME}/.local/bin"
  local dest_app="${dest_dir}/enem_offline_client.AppImage"
  local desktop_dir="${HOME}/.local/share/applications"
  local desktop_file="${desktop_dir}/enem-offline-client.desktop"

  mkdir -p "$dest_dir" "$desktop_dir"
  cp -f "$appimage_path" "$dest_app"
  chmod +x "$dest_app"

  cat >"$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=ENEM Offline Client
Comment=Cliente offline para estudo ENEM
Exec=${dest_app}
Icon=applications-education
Terminal=false
Categories=Education;
StartupNotify=true
EOF

  log "AppImage instalado em: $dest_app"
  log "atalho desktop criado em: $desktop_file"
}

install_bundle() {
  local bundle_dir=""
  if [[ -n "$BUNDLE_DIR" && -d "$BUNDLE_DIR" ]]; then
    bundle_dir="$BUNDLE_DIR"
  else
    bundle_dir="$REPO_ROOT/enem_offline_client_linux_x64_${VERSION}"
  fi
  [[ -d "$bundle_dir" ]] || die "pasta do app nao encontrada: $bundle_dir"
  [[ -x "$bundle_dir/enem_offline_client" ]] || die "binario nao encontrado: $bundle_dir/enem_offline_client"

  log "executando app direto da pasta local..."
  "$bundle_dir/enem_offline_client"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)
      [[ $# -ge 2 ]] || die "faltou valor para --type"
      TYPE="$2"
      shift 2
      ;;
    --version)
      [[ $# -ge 2 ]] || die "faltou valor para --version"
      VERSION="$2"
      shift 2
      ;;
    --release-dir)
      [[ $# -ge 2 ]] || die "faltou valor para --release-dir"
      RELEASE_DIR="$2"
      shift 2
      ;;
    --bundle-dir)
      [[ $# -ge 2 ]] || die "faltou valor para --bundle-dir"
      BUNDLE_DIR="$2"
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

case "$TYPE" in
  deb|appimage|bundle) ;;
  *) die "--type invalido: $TYPE (use deb, appimage ou bundle)" ;;
esac

if [[ -z "$VERSION" ]]; then
  case "$TYPE" in
    deb)
      VERSION="$(detect_latest_version 'enem_offline_client_linux_x64_*.deb' "${RELEASE_DIR:-$REPO_ROOT}" 2>/dev/null || true)"
      if [[ -z "$VERSION" && -n "$RELEASE_DIR" ]]; then
        VERSION="$(detect_latest_version 'enem_offline_client_linux_x64_*.deb' "$REPO_ROOT" 2>/dev/null || true)"
      fi
      [[ -n "$VERSION" ]] || die "nenhum .deb encontrado"
      ;;
    appimage)
      VERSION="$(detect_latest_version 'enem_offline_client_linux_x64_*.AppImage' "${RELEASE_DIR:-$REPO_ROOT}" 2>/dev/null || true)"
      if [[ -z "$VERSION" && -n "$RELEASE_DIR" ]]; then
        VERSION="$(detect_latest_version 'enem_offline_client_linux_x64_*.AppImage' "$REPO_ROOT" 2>/dev/null || true)"
      fi
      [[ -n "$VERSION" ]] || die "nenhum AppImage encontrado"
      ;;
    bundle)
      VERSION="$(detect_latest_bundle_version "${RELEASE_DIR:-$REPO_ROOT}" 2>/dev/null || true)"
      if [[ -z "$VERSION" && -n "$RELEASE_DIR" ]]; then
        VERSION="$(detect_latest_bundle_version "$REPO_ROOT" 2>/dev/null || true)"
      fi
      if [[ -z "$VERSION" ]]; then
        VERSION="$(detect_latest_version 'enem_offline_client_linux_x64_*.AppImage' "${RELEASE_DIR:-$REPO_ROOT}" 2>/dev/null || true)"
      fi
      if [[ -z "$VERSION" ]]; then
        VERSION="$(detect_latest_version 'enem_offline_client_linux_x64_*.deb' "${RELEASE_DIR:-$REPO_ROOT}" 2>/dev/null || true)"
      fi
      [[ -n "$VERSION" ]] || die "nao foi possivel detectar versao para bundle"
      ;;
  esac
fi

log "tipo: $TYPE"
log "versao: $VERSION"

case "$TYPE" in
  deb) install_deb ;;
  appimage) install_appimage ;;
  bundle) install_bundle ;;
esac
