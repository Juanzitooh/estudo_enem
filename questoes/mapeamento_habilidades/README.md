# Mapeamento de Questões (Disciplina, Competência, Tema e Habilidade)

Este diretório contém classificação automática das questões reais, baseada em matriz ENEM + regras de palavras-chave (sem IA).

## Gerar mapeamento

```bash
python3 scripts/mapear_habilidades_enem.py \
  --banco-dir questoes/banco_reais \
  --out-dir questoes/mapeamento_habilidades \
  --matrix-dir matriz/habilidades_por_area \
  --year-from 2015 \
  --year-to 2025
```

Para aplicar correções manuais opcionais:

```bash
python3 scripts/mapear_habilidades_enem.py \
  --banco-dir questoes/banco_reais \
  --out-dir questoes/mapeamento_habilidades \
  --matrix-dir matriz/habilidades_por_area \
  --manual-overrides questoes/mapeamento_habilidades/revisao_manual/overrides.csv \
  --apply-manual-overrides \
  --year-from 2015 \
  --year-to 2025
```

Gerar metadados consolidados para consulta rápida do agente:

```bash
python3 scripts/gerar_metadados_questoes_consolidados.py \
  --mapped-csv questoes/mapeamento_habilidades/questoes_mapeadas.csv \
  --out-csv questoes/mapeamento_habilidades/questoes_metadados_consolidados.csv \
  --out-jsonl questoes/mapeamento_habilidades/questoes_metadados_consolidados.jsonl \
  --out-summary questoes/mapeamento_habilidades/resumo_metadados_consolidados.md
```

## Intercorrelação módulo x questão

Gerar vínculos entre módulos do livro e questões reais com `score_match`:

```bash
python3 scripts/gerar_intercorrelacao_modulo_questao.py \
  --questions-csv questoes/mapeamento_habilidades/questoes_mapeadas.csv \
  --modules-csv plano/indice_livros_6_volumes.csv \
  --tags-csv questoes/mapeamento_habilidades/intercorrelacao/tags_assunto_canonicas.csv \
  --out-csv questoes/mapeamento_habilidades/intercorrelacao/modulo_questao_matches.csv \
  --summary-md questoes/mapeamento_habilidades/intercorrelacao/resumo_modulo_questao_matches.md
```

Arquivos dessa camada:

- `intercorrelacao/tags_assunto_canonicas.csv`: taxonomia de tags/assuntos com sinônimos.
- `intercorrelacao/modulo_questao_matches.csv`: vínculos módulo-questão com tipo, score e confiança.
- `intercorrelacao/resumo_modulo_questao_matches.md`: resumo da execução e distribuição de vínculos.

## Consultar e filtrar o banco

Script de consulta:

```bash
python3 scripts/consultar_banco_questoes.py --limit 30
```

Filtros úteis:

```bash
# Matemática (com imagem), competência C2, habilidade H24
python3 scripts/consultar_banco_questoes.py \
  --area "Matemática" \
  --tem-imagem sim \
  --competencia C2 \
  --habilidade H24 \
  --limit 50

# Buscar por palavra no enunciado completo (com texto)
python3 scripts/consultar_banco_questoes.py \
  --disciplina Química \
  --buscar grafico \
  --com-texto \
  --limit 20

# Exportar consulta filtrada para arquivo
python3 scripts/consultar_banco_questoes.py \
  --ano-from 2020 \
  --ano-to 2025 \
  --disciplina Biologia \
  --formato md \
  --saida questoes/mapeamento_habilidades/banco_questoes_view.md
```

## Arquivos gerados

- `questoes_mapeadas.csv`: base tabular completa por questão.
- `questoes_mapeadas.jsonl`: base completa em JSONL.
- `questoes_metadados_consolidados.csv`: esquema padrão para filtros rápidos (`ano`, `dia`, `numero`, `area`, `disciplina`, `competencia`, `habilidade`, `dificuldade`, `tem_imagem`).
- `questoes_metadados_consolidados.jsonl`: versão JSONL do consolidado.
- `resumo_metadados_consolidados.md`: estatísticas do consolidado para auditoria.
- `banco_questoes_view.md`: visão gerada por consulta/filtro (quando exportado).
- Campos centrais: `disciplina`, `competencia_estimada`, `tema_estimado`, `habilidade_estimada`.
- Campo `tem_imagem`: sinalizador heurístico (`true/false`) para indicar menção a elemento visual (figura, gráfico, tabela, tirinha etc.).
- Campo `texto_vazio`: marca quando o OCR não trouxe enunciado textual.
- Campo `fallback_image_paths`: caminhos dos recortes PNG da questão (quando `texto_vazio=true` e houver fallback disponível).
- `resumo_materias_chave.md`: resumo direto das matérias principais.
- `resumo_por_disciplina_tema.md`: visão agregada por disciplina e tema.
- `resumo_lotes_tem_imagem.md`: fechamento dos lotes da flag `tem_imagem` (2015–2025).
- `revisao_pendente.md`: questões de baixa confiança para revisão manual.
- `lotes_revisao/`: pendentes divididos em lotes operacionais (`lote_01.md`, `lote_02.md`, ...).
- `revisao_manual/overrides.csv`: decisões manuais para sobrescrever classificação automática.
- `revisao_manual/aplicacao_overrides.md`: relatório de quantos overrides foram aplicados.
- `por_disciplina/*.md`: bancos separados por matéria.

## Disciplinas cobertas

- Língua Portuguesa
- Literatura
- Inglês
- Espanhol
- História
- Geografia
- Filosofia
- Sociologia
- Física
- Química
- Biologia
- Matemática

## Observação de qualidade

A classificação é heurística, mas guiada pela matriz oficial por área. `revisao_pendente.md` fica disponível apenas como trilha de auditoria quando houver baixa confiança.
