# Cliente Flutter Offline (MVP)

Este diretório contém o ponto de partida para um cliente local (desktop + Android) com:
- execução offline;
- SQLite local;
- update de conteúdo via `manifest.json + SHA256`;
- cruzamento de histórico do aluno com habilidades e módulos do livro.

## 1) Instalar Flutter no Linux

### Opção recomendada (automática e idempotente)

```bash
./scripts/setup_flutter_linux.sh
```

O script:
- instala dependências de sistema (Ubuntu/Debian) quando possível;
- baixa Flutter stable oficial;
- adiciona `~/tools/flutter/bin` no `PATH` (`~/.bashrc`);
- habilita Linux desktop e roda `flutter doctor`.

### Dependências de sistema (manual, Ubuntu)

```bash
sudo apt update
sudo apt install -y curl git unzip xz-utils zip libglu1-mesa clang cmake ninja-build pkg-config libgtk-3-dev
```

### Opção A: Snap (manual)

```bash
sudo snap install flutter --classic
flutter doctor
```

### Opção B: Manual (controlada)

```bash
mkdir -p "$HOME/tools"
cd "$HOME/tools"
# Baixe o SDK estável no site oficial do Flutter e extraia aqui.
# Exemplo de arquivo: flutter_linux_<versao>-stable.tar.xz

tar xf flutter_linux_*.tar.xz

echo 'export PATH="$HOME/tools/flutter/bin:$PATH"' >> "$HOME/.bashrc"
source "$HOME/.bashrc"
flutter doctor
```

## 2) Criar / rodar app mínimo

O scaffold já está criado em `app_flutter/enem_offline_client/`.

```bash
cd app_flutter/enem_offline_client
flutter pub get
flutter run -d linux
```

Para Android (APK debug):

```bash
flutter run -d android
```

## 3) SQLite no app

Arquivos principais:
- `app_flutter/enem_offline_client/lib/src/data/local_database.dart`
- `app_flutter/enem_offline_client/lib/src/ui/home_page.dart`

O app cria localmente:
- `app_meta` (versão de conteúdo)
- `questions` (questões para treino)
- `progress` (histórico de resposta)
- `book_modules` (módulos do livro com habilidades)

No desktop usa `sqflite_common_ffi`; no mobile usa `sqflite`.

## 4) Update por manifest + SHA256

Arquivos principais:
- `app_flutter/enem_offline_client/lib/src/update/content_manifest.dart`
- `app_flutter/enem_offline_client/lib/src/update/content_updater.dart`
- `scripts/build_assets_release.py`

Fluxo:
1. App baixa `manifest.json`.
2. App baixa `assets_<version>.zip`.
3. Valida `SHA256` e tamanho.
4. Extrai `content_bundle.json`.
5. Upsert no SQLite local (`questions` + `book_modules`).
6. Salva `content_version`.

Com isso, o app consegue:
- detectar habilidades fracas pelo histórico (`progress`);
- recomendar módulos de livro que tenham as habilidades correspondentes.

### Gerar pacote de conteúdo

```bash
python3 scripts/build_assets_release.py \
  --questions-csv questoes/mapeamento_habilidades/questoes_mapeadas.csv \
  --modules-csv plano/indice_livros_6_volumes.csv \
  --out-dir app_flutter/releases \
  --version 2026.02.24.1 \
  --base-url https://SEU_HOST/releases/2026.02.24.1
```

Saída:
- `app_flutter/releases/<version>/assets_<version>.zip`
- `app_flutter/releases/<version>/manifest.json`
- `app_flutter/releases/manifest.json` (latest)
- `app_flutter/releases/manifest.example.json` (modelo de referência)

## 5) Publicar releases e atualizar clientes

Estratégia recomendada:
1. Publicar binários do app (Windows/Linux/macOS/APK) em release própria.
2. Publicar `manifest.json` + `assets.zip` em URL estável.
3. App roda offline e só atualiza conteúdo quando houver internet.

## 6) Build de release

### Linux

```bash
cd app_flutter/enem_offline_client
flutter build linux --release
```

### Android APK

```bash
cd app_flutter/enem_offline_client
flutter build apk --release
```

### Windows/macOS

Faça build em máquina do próprio sistema operacional:

```bash
flutter build windows --release
flutter build macos --release
```

## 7) One-command release (`dist.sh`)

Se quiser fazer tudo com um comando (conteúdo + build Linux + abrir app no final):

```bash
./dist.sh --version 2026.02.24.1
```

O script:
- gera `assets_<version>.zip` + `manifest.json` com SHA256;
- tenta instalar/configurar Flutter automaticamente se não estiver no `PATH`;
- roda `flutter pub get` + `flutter build linux --release`;
- empacota o bundle Linux em `.tar.gz` dentro da pasta versionada;
- executa o app Linux no final para teste manual.

Se você quiser publicar update remoto, use `--base-url`:

```bash
./dist.sh --version 2026.02.24.1 --base-url https://SEU_HOST/releases
```

Se quiser setup + build + servidor local em um único comando (na raiz do repositório):

```bash
./run_local.sh
```

### Teste local sem servidor remoto (somente localhost)

Sem `--base-url`, o manifest aponta o ZIP relativo ao próprio `manifest.json`.

Depois do `dist.sh`, sirva a pasta da versão local:

```bash
cd app_flutter/releases/2026.02.24.1
python3 -m http.server 8787
```

No app, use:

```text
http://127.0.0.1:8787/manifest.json
```

Se aparecer erro de linker Linux como:
- `Failed to find any of [ld.lld, ld] in LocalDirectory: '/usr/lib/llvm-18/bin'`

Rode novamente:

```bash
./scripts/setup_flutter_linux.sh
```

Opções úteis:

```bash
# gera só conteúdo (sem flutter build)
./dist.sh --version 2026.02.24.1 --skip-flutter --no-run

# não abre o app ao final
./dist.sh --version 2026.02.24.1 --no-run

# desativa bootstrap automático do Flutter
./dist.sh --version 2026.02.24.1 --no-bootstrap-flutter
```
