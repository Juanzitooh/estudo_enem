# Prompt padrao - Geracao de questoes por habilidade (ENEM)

Use este prompt em uma IA externa para gerar lotes de questoes ineditas por habilidade.

## Prompt

```text
Voce e elaborador de itens educacionais no estilo ENEM.

Objetivo:
Gerar {TOTAL_QUESTOES} questoes ineditas para a habilidade {HABILIDADE} da competencia {COMPETENCIA}, na area {AREA} e disciplina {DISCIPLINA}.

Regras obrigatorias:
1) Nao copiar texto literal de questoes reais do ENEM.
2) Priorizar contexto brasileiro e situacoes de cotidiano/profissoes.
3) Linguagem clara, comando objetivo e distratores plausiveis.
4) Distribuicao de dificuldade:
   - {QTD_FACIL} faceis
   - {QTD_MEDIA} medias
   - {QTD_DIFICIL} dificeis
5) Cada questao deve ter exatamente 5 alternativas:
   A)
   B)
   C)
   D)
   E)
6) Incluir gabarito e explicacao curta do raciocinio correto.
7) Incluir tags de assunto e ao menos 1 fonte de referencia.

Formato de saida:
- Retorne APENAS JSONL.
- Uma questao por linha.
- Use este contrato obrigatorio:
  id, area, disciplina, materia, tipo, enunciado, alternativas(A-E), gabarito, explicacao, competencia, habilidade, dificuldade, tags, fontes, generated_by, prompt_ref, review_status, version, updated_at.

Dados do lote:
- area: {AREA}
- disciplina: {DISCIPLINA}
- materia: {MATERIA}
- tipo: {TIPO}
- competencia: {COMPETENCIA}
- habilidade: {HABILIDADE}
- prompt_ref: {PROMPT_REF}
- generated_by: {GENERATED_BY}
- review_status: rascunho
- version: 1.0.0
- updated_at: {UPDATED_AT_ISO}
```

## Pos-processamento local

Depois de gerar, validar no repositorio:

```bash
python3 scripts/validar_questoes_geradas.py \
  --input <arquivo_lote.jsonl> \
  --expected-distribution 5,3,2
```
