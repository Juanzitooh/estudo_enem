# Politica de publicacao incremental - Questoes geradas

## Objetivo

Permitir liberar lotes aprovados sem bloquear o banco real e sem perder rastreabilidade.

## Regras obrigatorias

1. Somente itens com gate humano passam para publicacao:
   - `review_status=aprovado`
   - `reviewed_by` preenchido
   - `approved_at` preenchido
2. Itens com similaridade suspeita com base real sao bloqueados.
3. Publicacao sempre gera:
   - JSONL de saida (`questoes_publicadas.jsonl`)
   - resumo da rodada (`resumo_publicacao.md`)
   - manifest da release (`manifest_publicacao.json`)
   - historico append-only (`historico_publicacao.jsonl`)

## Modos de publicacao

- `merge-id` (padrao): atualiza por `id` sem duplicar.
- `append`: so concatena no final.
- `overwrite`: substitui todo o arquivo de saida.

## Fluxo recomendado

1. Gerar lote com `scripts/gerar_lote_questoes_por_habilidade.py`.
2. Curar/revisar manualmente e marcar itens aprovados.
3. Validar:

```bash
python3 scripts/validar_questoes_geradas.py \
  --input <arquivo_lote.jsonl> \
  --expected-distribution 5,3,2 \
  --require-approved
```

4. Publicar incremental:

```bash
python3 scripts/publicar_questoes_geradas.py \
  --input questoes/generateds \
  --publish-mode merge-id \
  --release-version qgen.2026.02.27.1 \
  --out-jsonl questoes/generateds/published/questoes_publicadas.jsonl \
  --summary-md questoes/generateds/published/resumo_publicacao.md \
  --manifest-json questoes/generateds/published/manifest_publicacao.json \
  --history-jsonl questoes/generateds/published/historico_publicacao.jsonl
```

## Criterio de rollback

- Se uma release vier com bloqueios inesperados, manter o arquivo de saida anterior e repetir rodada com `--fail-on-blocked`.
- Se houver problema de merge por `id`, rodar `--publish-mode overwrite` com snapshot validado.
