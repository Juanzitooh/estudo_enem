#!/usr/bin/env bash
set -euo pipefail

METHOD="auto"
FLUTTER_DIR="${HOME}/tools/flutter"
SHELL_RC="${HOME}/.bashrc"
INSTALL_DEPS="1"
RUN_DOCTOR="1"
FORCE_INSTALL="0"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/setup_flutter_linux.sh [opcoes]

Opcoes:
  --method <auto|manual|snap>  Metodo de instalacao (padrao: auto -> manual)
  --flutter-dir <dir>          Diretorio de instalacao do Flutter (padrao: ~/tools/flutter)
  --shell-rc <arquivo>         Arquivo para persistir PATH (padrao: ~/.bashrc)
  --skip-deps                  Nao instala dependencias de sistema via apt
  --skip-doctor                Nao roda flutter doctor no fim
  --force                      Reinstala Flutter mesmo se ja existir
  -h, --help                   Mostra esta ajuda

Exemplos:
  ./scripts/setup_flutter_linux.sh
  ./scripts/setup_flutter_linux.sh --flutter-dir "$HOME/tools/flutter"
  ./scripts/setup_flutter_linux.sh --method snap
USAGE
}

log() {
  printf '[setup-flutter] %s\n' "$*"
}

warn() {
  printf '[setup-flutter][aviso] %s\n' "$*" >&2
}

die() {
  printf '[setup-flutter][erro] %s\n' "$*" >&2
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ensure_linux_deps() {
  local packages=(
    curl
    git
    unzip
    xz-utils
    zip
    libglu1-mesa
    clang
    lld
    cmake
    ninja-build
    pkg-config
    libgtk-3-dev
    binutils
  )

  if [[ "$INSTALL_DEPS" -eq 0 ]]; then
    return
  fi

  if ! have_cmd apt-get; then
    warn "apt-get nao encontrado. Instale dependencias manualmente."
    return
  fi

  log "instalando dependencias de sistema (Ubuntu/Debian)..."
  if [[ "$(id -u)" -eq 0 ]]; then
    apt-get update
    apt-get install -y "${packages[@]}"
    return
  fi

  if have_cmd sudo; then
    if sudo -n true >/dev/null 2>&1; then
      sudo apt-get update
      sudo apt-get install -y "${packages[@]}"
      return
    fi

    if [[ -t 0 ]]; then
      log "sudo pode pedir senha para instalar dependencias."
      sudo apt-get update
      sudo apt-get install -y "${packages[@]}"
      return
    fi

    warn "sudo requer senha e o shell atual nao e interativo. Pulando apt."
    return
  fi

  warn "sem permissao root/sudo para instalar dependencias automaticamente."
}

fetch_flutter_release_meta() {
  have_cmd python3 || die "python3 nao encontrado"
  python3 - <<'PY'
import json
import sys
import urllib.request

url = "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"
with urllib.request.urlopen(url, timeout=60) as response:
    payload = json.load(response)

base_url = str(payload.get("base_url", "")).rstrip("/")
stable_hash = payload.get("current_release", {}).get("stable", "")
releases = payload.get("releases", [])

release = next((item for item in releases if item.get("hash") == stable_hash), None)
if not release:
    print("falha ao localizar release estavel atual", file=sys.stderr)
    raise SystemExit(1)

archive = str(release.get("archive", "")).strip()
version = str(release.get("version", "stable")).strip()
sha256 = str(release.get("sha256", "")).strip()

if not base_url or not archive:
    print("metadados de release invalidos", file=sys.stderr)
    raise SystemExit(1)

print(f"{base_url}/{archive}|{version}|{sha256}")
PY
}

persist_path() {
  [[ -x "$FLUTTER_DIR/bin/flutter" ]] || return

  local path_line
  path_line="export PATH=\"$FLUTTER_DIR/bin:\$PATH\""
  touch "$SHELL_RC"

  if ! grep -Fqx "$path_line" "$SHELL_RC"; then
    {
      printf '\n# Flutter SDK (estudo_enem)\n'
      printf '%s\n' "$path_line"
    } >>"$SHELL_RC"
    log "PATH adicionado em: $SHELL_RC"
  fi

  export PATH="$FLUTTER_DIR/bin:$PATH"
}

install_manual() {
  local parent_dir
  parent_dir="$(dirname "$FLUTTER_DIR")"

  if [[ -x "$FLUTTER_DIR/bin/flutter" && "$FORCE_INSTALL" -eq 0 ]]; then
    log "flutter ja existe em $FLUTTER_DIR (skip)."
    return
  fi

  mkdir -p "$parent_dir"

  local meta archive_url version sha256
  meta="$(fetch_flutter_release_meta)"
  IFS='|' read -r archive_url version sha256 <<<"$meta"

  log "baixando Flutter stable ($version)..."
  local tmp_dir archive_path
  tmp_dir="$(mktemp -d -t flutter_setup_XXXXXX)"
  archive_path="$tmp_dir/flutter_linux_stable.tar.xz"

  have_cmd curl || die "curl nao encontrado"
  curl -fL --retry 3 --retry-delay 2 "$archive_url" -o "$archive_path"

  if [[ -n "$sha256" ]]; then
    local computed
    computed="$(sha256sum "$archive_path" | awk '{print $1}')"
    if [[ "${computed,,}" != "${sha256,,}" ]]; then
      rm -rf "$tmp_dir"
      die "SHA256 do SDK nao confere (esperado: $sha256 | atual: $computed)"
    fi
  fi

  rm -rf "$FLUTTER_DIR"
  tar -xJf "$archive_path" -C "$parent_dir"
  rm -rf "$tmp_dir"

  [[ -x "$FLUTTER_DIR/bin/flutter" ]] || die "instalacao manual falhou (flutter/bin/flutter ausente)"
  log "Flutter instalado em: $FLUTTER_DIR"
}

install_snap() {
  have_cmd snap || die "snap nao encontrado"

  log "instalando Flutter via snap..."
  if [[ "$(id -u)" -eq 0 ]]; then
    if snap list flutter >/dev/null 2>&1; then
      snap refresh flutter --classic
    else
      snap install flutter --classic
    fi
    return
  fi

  if have_cmd sudo; then
    if sudo snap list flutter >/dev/null 2>&1; then
      sudo snap refresh flutter --classic
    else
      sudo snap install flutter --classic
    fi
    return
  fi

  die "sem permissao root/sudo para instalar via snap"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --method)
      [[ $# -ge 2 ]] || die "faltou valor para --method"
      METHOD="$2"
      shift 2
      ;;
    --flutter-dir)
      [[ $# -ge 2 ]] || die "faltou valor para --flutter-dir"
      FLUTTER_DIR="$2"
      shift 2
      ;;
    --shell-rc)
      [[ $# -ge 2 ]] || die "faltou valor para --shell-rc"
      SHELL_RC="$2"
      shift 2
      ;;
    --skip-deps)
      INSTALL_DEPS="0"
      shift
      ;;
    --skip-doctor)
      RUN_DOCTOR="0"
      shift
      ;;
    --force)
      FORCE_INSTALL="1"
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

case "$METHOD" in
  auto) METHOD="manual" ;;
  manual|snap) ;;
  *) die "metodo invalido: $METHOD (use auto, manual ou snap)" ;;
esac

ensure_linux_deps

if have_cmd flutter && [[ "$FORCE_INSTALL" -eq 0 ]]; then
  log "flutter ja disponivel em: $(command -v flutter)"
else
  case "$METHOD" in
    manual) install_manual ;;
    snap) install_snap ;;
    *) die "metodo nao suportado: $METHOD" ;;
  esac
fi

persist_path

if ! have_cmd flutter; then
  die "flutter nao encontrado apos setup. Abra novo shell ou adicione PATH manualmente."
fi

log "flutter em uso: $(command -v flutter)"
flutter --version

log "habilitando suporte Linux desktop..."
flutter config --enable-linux-desktop >/dev/null

if [[ ! -x "/usr/lib/llvm-18/bin/ld.lld" && ! -x "/usr/lib/llvm-18/bin/ld" ]]; then
  if ! have_cmd ld.lld; then
    warn "linker LLVM nao encontrado (ld.lld). Para build Linux, rode: sudo apt install -y lld"
  fi
fi

if [[ "$RUN_DOCTOR" -eq 1 ]]; then
  log "rodando flutter doctor (itens opcionais podem aparecer como pendentes)..."
  if ! flutter doctor -v; then
    warn "flutter doctor reportou pendencias opcionais. Continue se build Linux estiver OK."
  fi
fi

log "setup concluido."
