# enem_offline_client

MVP Flutter para estudo ENEM offline.

## Rodar

```bash
flutter pub get
flutter run -d linux
```

## Configuração padrão (manifest + banco)

O app usa, por padrão:
- URL de update: `http://127.0.0.1:8787/manifest.json`
- Banco SQLite no Linux: `~/.local/share/estudo_enem_offline_client/enem_offline.db`

Arquivo para ajustar defaults no código:
- `app_flutter/enem_offline_client/lib/src/config/app_config.dart`

Override no build (sem editar código):

```bash
flutter build linux --release \
  --dart-define=ENEM_MANIFEST_URL=http://127.0.0.1:8787/manifest.json \
  --dart-define=ENEM_DB_DIR=/home/jp/.local/share/estudo_enem_offline_client
```

Override no release (via script na raiz):

```bash
./dist.sh --version 2026.02.24.1 \
  --manifest-url http://127.0.0.1:8787/manifest.json \
  --db-dir /home/jp/.local/share/estudo_enem_offline_client
```

Observação:
- `ENEM_DB_DIR` é opcional; quando vazio, o app usa o caminho estável acima.
- Em Linux/Snap, o app tenta migrar automaticamente banco legado para o caminho estável.

## Estrutura

- `lib/main.dart`: entrada do app.
- `lib/src/ui/home_page.dart`: interface mínima.
- `lib/src/data/local_database.dart`: banco SQLite local.
- `lib/src/essay/essay_prompt_builder.dart`: gera prompts de tema/correção de redação.
- `lib/src/essay/essay_feedback_parser.dart`: parser de feedback IA (`livre`/`validado`) + legibilidade.
- `lib/src/update/content_manifest.dart`: modelo de manifest.
- `lib/src/update/content_updater.dart`: fluxo de update com SHA256.

O app mostra:
- status do conteúdo local;
- habilidades com maior erro pelo histórico;
- sugestão de módulos do livro para revisar (incluindo módulos marcados por competência).
- filtro local de questões em cards (ano, dia, área, disciplina, matéria, competência, habilidade, `tem_imagem` e limite).
- montador de simulado rápido com base nos filtros atuais (quantidade, minutos por questão e distribuição por área).
- filtro local de intercorrelação módulo x questão (matéria, assunto/tag, tipo de match e score).
- prompt builder de redação para IA externa (gerar tema e prompt de correção com cópia rápida).
- prompt automático de reescrita pós-correção (baseado no feedback da IA e no texto do aluno).
- salvamento local de sessões de redação (`essay_sessions`) com notas C1..C5/final e alerta de `[ILEGÍVEL]`.
- ranking de redação por faixa de nota (Base/Bronze/Prata/Ouro/Elite) e visão de evolução local.
