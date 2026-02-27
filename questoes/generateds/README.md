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
