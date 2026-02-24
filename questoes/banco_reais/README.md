# Banco de Questões Reais

Pasta para versões estruturadas de provas reais do ENEM por ano.

## Estrutura sugerida

- `questoes/banco_reais/enem_2025/`
- `questoes/banco_reais/enem_2024/`
- `questoes/banco_reais/enem_2023/`

Cada ano deve conter:

- questões em Markdown por dia;
- gabaritos em JSON;
- índice em JSON;
- proposta de redação do dia 1 em `dia1_redacao.md` e `dia1_redacao.json`;
- `README.md` com origem dos PDFs e comando de geração.

## Extração em lote recomendada

Padrão esperado na pasta `questoes/provas_anteriores/`:

- `{ano}_dia1_prova.pdf`
- `{ano}_dia1_gabarito.pdf`
- `{ano}_dia2_prova.pdf`
- `{ano}_dia2_gabarito.pdf`

```bash
python3 scripts/extrair_banco_enem_lote.py \
  --provas-dir questoes/provas_anteriores \
  --out-base questoes/banco_reais \
  --year-from 2015 \
  --year-to 2025 \
  --status-file questoes/banco_reais/STATUS_EXTRACAO.md
```

Saídas consolidadas geradas no lote:

- `questoes/banco_reais/STATUS_EXTRACAO.md`
- `questoes/banco_reais/PANORAMA_TEMAS_REDACAO.md`
