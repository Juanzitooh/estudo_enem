# Banco de Questoes Geradas (agent + revisao humana)

Este diretorio guarda lotes de questoes ineditas para treino/simulado/redacao.

## Estrutura base

```text
questoes/generateds/
  linguagens/{treino,simulado,redacao}/
  humanas/{treino,simulado,redacao}/
  natureza/{treino,simulado,redacao}/
  matematica/{treino,simulado,redacao}/
```

## Contrato obrigatorio por questao (JSONL)

Cada linha JSON deve conter, no minimo:

- `id`
- `area`
- `disciplina`
- `materia`
- `tipo` (`treino`, `simulado`, `redacao`)
- `enunciado`
- `alternativas` com chaves `A`, `B`, `C`, `D`, `E`
- `gabarito` (`A`..`E`)
- `explicacao`
- `competencia` (ex.: `C3`)
- `habilidade` (ex.: `H10`)
- `dificuldade` (`facil`, `media`, `dificil`)
- `tags` (lista nao vazia)
- `fontes` (lista nao vazia)

Schema de referencia:

- `questoes/generateds/schema_questao_gerada.json`

Template inicial:

- `questoes/generateds/natureza/treino/lote_template.jsonl`
- `prompts/gerar_questoes_habilidade_enem.md` (prompt padrao para IA externa)
- `questoes/generateds/checklist_qualidade.md` (revisao manual de qualidade)

## Validacao de lotes

Criar lote auditavel por habilidade (prompt + manifest + saida jsonl):

```bash
python3 scripts/gerar_lote_questoes_por_habilidade.py \
  --area-key natureza \
  --tipo treino \
  --disciplina Biologia \
  --materia Biologia \
  --competencia C3 \
  --habilidade H10 \
  --total-questoes 10 \
  --distribution 5,3,2
```

Validar um arquivo:

```bash
python3 scripts/validar_questoes_geradas.py \
  --input questoes/generateds/natureza/treino/lote_template.jsonl
```

Validar tudo:

```bash
python3 scripts/validar_questoes_geradas.py \
  --input questoes/generateds \
  --summary-md questoes/generateds/relatorio_validacao.md
```

Validar lote no padrao ENEM 5/3/2:

```bash
python3 scripts/validar_questoes_geradas.py \
  --input questoes/generateds/natureza/treino/lote_template.jsonl \
  --expected-distribution 5,3,2
```

O detector de similaridade com base real e executado por padrao usando:
- `questoes/mapeamento_habilidades/questoes_metadados_consolidados.csv`

Parametros uteis:

```bash
python3 scripts/validar_questoes_geradas.py \
  --input <arquivo_lote.jsonl> \
  --similarity-threshold 0.88 \
  --jaccard-threshold 0.66
```

Para desativar apenas a checagem de similaridade (nao recomendado):

```bash
python3 scripts/validar_questoes_geradas.py \
  --input <arquivo_lote.jsonl> \
  --skip-similarity-check
```

## Publicacao com gate humano

Publicar somente itens aprovados (com `review_status=aprovado`, `reviewed_by` e `approved_at`):

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

Validar gate de aprovacao antes de publicar:

```bash
python3 scripts/validar_questoes_geradas.py \
  --input <arquivo_lote.jsonl> \
  --require-approved
```

Politica completa:

- `questoes/generateds/politica_publicacao_incremental.md`
