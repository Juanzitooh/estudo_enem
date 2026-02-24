# Mapeamento de Questões (Disciplina, Tema e Habilidade Estimada)

Este diretório contém classificação automática das questões reais, baseada em regras e palavras-chave (sem IA).

## Gerar mapeamento

```bash
python3 scripts/mapear_habilidades_enem.py \
  --banco-dir questoes/banco_reais \
  --out-dir questoes/mapeamento_habilidades \
  --year-from 2015 \
  --year-to 2025
```

## Arquivos gerados

- `questoes_mapeadas.csv`: base tabular completa por questão.
- `questoes_mapeadas.jsonl`: base completa em JSONL.
- `resumo_materias_chave.md`: resumo direto das matérias principais.
- `resumo_por_disciplina_tema.md`: visão agregada por disciplina e tema.
- `revisao_pendente.md`: questões de baixa confiança para revisão manual.
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

A classificação de disciplina/tema/habilidade é heurística. Use `revisao_pendente.md` para revisão dos casos de baixa confiança.
