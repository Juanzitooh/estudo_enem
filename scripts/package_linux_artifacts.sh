#!/usr/bin/env bash
set -euo pipefail

VERSION=""
BUNDLE_DIR=""
RELEASE_DIR=""
REPO_ROOT=""
PACKAGES="all"
COPY_TO_ROOT="0"

APP_NAME="enem_offline_client"
APP_ID="enem-offline-client"
APP_DISPLAY_NAME="ENEM Offline Client"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/package_linux_artifacts.sh \
    --version <v> \
    --bundle-dir <dir> \
    --release-dir <dir> \
    --repo-root <dir> \
    [--packages all|deb|appimage|none] \
    [--copy-to-root 0|1]

Exemplo:
  ./scripts/package_linux_artifacts.sh \
    --version local.0.1 \
    --bundle-dir app_flutter/enem_offline_client/build/linux/x64/release/bundle \
    --release-dir app_flutter/releases/local.0.1 \
    --repo-root . \
    --packages all
USAGE
}

log() {
  printf '[pkg-linux] %s\n' "$*"
}

die() {
  printf '[pkg-linux][erro] %s\n' "$*" >&2
  exit 1
}

normalize_deb_version() {
  local raw="$1"
  local normalized
  normalized="$(printf '%s' "$raw" | tr -c 'A-Za-z0-9.+:~-' '-')"
  normalized="${normalized#-}"
  normalized="${normalized%-}"
  if [[ -z "$normalized" ]]; then
    normalized="0.0.0"
  fi
  if [[ ! "$normalized" =~ ^[0-9] ]]; then
    normalized="0~${normalized}"
  fi
  printf '%s\n' "$normalized"
}

write_icon_png() {
  local out_path="$1"
  base64 -d >"$out_path" <<'EOF'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg==
EOF
}

ensure_appimagetool() {
  if command -v appimagetool >/dev/null 2>&1; then
    command -v appimagetool
    return
  fi

  local cache_dir tool_path
  cache_dir="${HOME}/.cache/estudo_enem/tools"
  tool_path="${cache_dir}/appimagetool-x86_64.AppImage"
  mkdir -p "$cache_dir"

  if [[ ! -x "$tool_path" ]]; then
    printf '[pkg-linux] baixando appimagetool (cache local)...\n' >&2
    command -v curl >/dev/null 2>&1 || die "curl nao encontrado para baixar appimagetool"
    curl -fL --retry 3 --retry-delay 2 \
      "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" \
      -o "$tool_path"
    chmod +x "$tool_path"
  fi

  printf '%s\n' "$tool_path"
}

build_deb() {
  local temp_dir deb_root deb_version installed_size control_path
  local release_deb root_deb

  temp_dir="$(mktemp -d -t enem_deb_pkg_XXXXXX)"
  deb_root="${temp_dir}/deb_root"
  deb_version="$(normalize_deb_version "$VERSION")"

  mkdir -p \
    "${deb_root}/DEBIAN" \
    "${deb_root}/opt/${APP_NAME}" \
    "${deb_root}/usr/bin" \
    "${deb_root}/usr/share/applications" \
    "${deb_root}/usr/share/icons/hicolor/256x256/apps"

  cp -a "${BUNDLE_DIR}/." "${deb_root}/opt/${APP_NAME}/"
  [[ -x "${deb_root}/opt/${APP_NAME}/enem_offline_client" ]] || die "binario ausente no bundle para .deb"

  cat >"${deb_root}/usr/bin/${APP_ID}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec /opt/enem_offline_client/enem_offline_client "$@"
EOF
  chmod +x "${deb_root}/usr/bin/${APP_ID}"

  cat >"${deb_root}/usr/share/applications/${APP_ID}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${APP_DISPLAY_NAME}
Comment=Cliente offline para estudo ENEM
Exec=${APP_ID}
Icon=${APP_ID}
Categories=Education;
Terminal=false
StartupNotify=true
EOF

  write_icon_png "${deb_root}/usr/share/icons/hicolor/256x256/apps/${APP_ID}.png"

  installed_size="$(du -sk "${deb_root}/opt/${APP_NAME}" | awk '{print $1}')"
  control_path="${deb_root}/DEBIAN/control"
  cat >"$control_path" <<EOF
Package: ${APP_ID}
Version: ${deb_version}
Section: education
Priority: optional
Architecture: amd64
Maintainer: estudo_enem
Depends: libc6 (>= 2.35), libgcc-s1, libstdc++6, libgtk-3-0
Installed-Size: ${installed_size}
Description: Cliente offline para estudo ENEM
 Aplicativo Flutter desktop com banco local SQLite e update por manifest.
EOF

  release_deb="${RELEASE_DIR}/enem_offline_client_linux_x64_${VERSION}.deb"

  dpkg-deb --build "$deb_root" "$release_deb" >/dev/null

  log ".deb gerado: $release_deb"
  if [[ "$COPY_TO_ROOT" -eq 1 ]]; then
    root_deb="${REPO_ROOT}/enem_offline_client_linux_x64_${VERSION}.deb"
    cp -f "$release_deb" "$root_deb"
    log ".deb copiado para raiz: $root_deb"
  fi
  rm -rf "$temp_dir"
}

build_appimage() {
  local temp_dir appdir appimagetool output_release output_root
  appimagetool="$(ensure_appimagetool)"

  temp_dir="$(mktemp -d -t enem_appimage_pkg_XXXXXX)"
  appdir="${temp_dir}/${APP_DISPLAY_NAME}.AppDir"
  mkdir -p "$appdir"

  cp -a "${BUNDLE_DIR}/." "$appdir/"
  [[ -x "${appdir}/enem_offline_client" ]] || die "binario ausente no bundle para AppImage"

  cat >"${appdir}/AppRun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
exec "${HERE}/enem_offline_client" "$@"
EOF
  chmod +x "${appdir}/AppRun"

  cat >"${appdir}/${APP_ID}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${APP_DISPLAY_NAME}
Comment=Cliente offline para estudo ENEM
Exec=enem_offline_client
Icon=${APP_ID}
Categories=Education;
Terminal=false
StartupNotify=true
EOF

  write_icon_png "${appdir}/${APP_ID}.png"

  output_release="${RELEASE_DIR}/enem_offline_client_linux_x64_${VERSION}.AppImage"

  APPIMAGE_EXTRACT_AND_RUN=1 ARCH=x86_64 "$appimagetool" "$appdir" "$output_release" >/dev/null
  chmod +x "$output_release"

  log "AppImage gerado: $output_release"
  if [[ "$COPY_TO_ROOT" -eq 1 ]]; then
    output_root="${REPO_ROOT}/enem_offline_client_linux_x64_${VERSION}.AppImage"
    cp -f "$output_release" "$output_root"
    chmod +x "$output_root"
    log "AppImage copiado para raiz: $output_root"
  fi
  rm -rf "$temp_dir"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || die "faltou valor para --version"
      VERSION="$2"
      shift 2
      ;;
    --bundle-dir)
      [[ $# -ge 2 ]] || die "faltou valor para --bundle-dir"
      BUNDLE_DIR="$2"
      shift 2
      ;;
    --release-dir)
      [[ $# -ge 2 ]] || die "faltou valor para --release-dir"
      RELEASE_DIR="$2"
      shift 2
      ;;
    --repo-root)
      [[ $# -ge 2 ]] || die "faltou valor para --repo-root"
      REPO_ROOT="$2"
      shift 2
      ;;
    --packages)
      [[ $# -ge 2 ]] || die "faltou valor para --packages"
      PACKAGES="$2"
      shift 2
      ;;
    --copy-to-root)
      [[ $# -ge 2 ]] || die "faltou valor para --copy-to-root"
      COPY_TO_ROOT="$2"
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

[[ -n "$VERSION" ]] || die "--version obrigatorio"
[[ -n "$BUNDLE_DIR" ]] || die "--bundle-dir obrigatorio"
[[ -n "$RELEASE_DIR" ]] || die "--release-dir obrigatorio"
[[ -n "$REPO_ROOT" ]] || die "--repo-root obrigatorio"

case "$PACKAGES" in
  all|deb|appimage|none) ;;
  *) die "--packages invalido: $PACKAGES (use all, deb, appimage, none)" ;;
esac
case "$COPY_TO_ROOT" in
  0|1) ;;
  *) die "--copy-to-root invalido: $COPY_TO_ROOT (use 0 ou 1)" ;;
esac

[[ -d "$BUNDLE_DIR" ]] || die "bundle-dir nao encontrado: $BUNDLE_DIR"
[[ -x "$BUNDLE_DIR/enem_offline_client" ]] || die "binario nao encontrado em $BUNDLE_DIR/enem_offline_client"
mkdir -p "$RELEASE_DIR"

if [[ "$PACKAGES" == "none" ]]; then
  log "pacotes Linux desativados (--packages none)"
  exit 0
fi

if [[ "$PACKAGES" == "all" || "$PACKAGES" == "deb" ]]; then
  build_deb
fi

if [[ "$PACKAGES" == "all" || "$PACKAGES" == "appimage" ]]; then
  build_appimage
fi

log "finalizado"
