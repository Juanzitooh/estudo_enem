# Conteúdo Versionado (offline-first)

Estrutura canônica para produção e publicação de conteúdo consumido pelo app offline.

```text
conteudo/
  raw/
  generated/
  reviewed/
  published/
    banco_questoes/
    banco_aulas/
    banco_videos/
    banco_redacao/
```

## Regras operacionais
- `raw/`: fontes brutas e extrações iniciais.
- `generated/`: saídas de scripts/agents antes de revisão final.
- `reviewed/`: itens revisados manualmente.
- `published/`: artefatos versionados prontos para distribuição.

## Snapshot de publicação
O script `scripts/build_assets_release.py` pode publicar snapshot em
`conteudo/published/<versao>/` com:
- `manifest.json`
- `assets_<versao>.zip`
- `assets_<versao>.zip.sha256`

Use a flag `--write-content-tree` para habilitar o snapshot.
