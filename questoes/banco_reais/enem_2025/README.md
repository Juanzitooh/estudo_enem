# Banco ENEM 2025 (real)

Este diretório contém a extração estruturada dos cadernos reais de 2025 (Dia 1 e Dia 2), com gabarito integrado.

## Arquivos gerados

- `dia1_questoes_reais.md`: questões extraídas do Dia 1.
- `dia2_questoes_reais.md`: questões extraídas do Dia 2.
- `dia1_gabarito.json`: gabarito estruturado do Dia 1.
- `dia2_gabarito.json`: gabarito estruturado do Dia 2.
- `dia1_questoes_index.json`: índice por questão do Dia 1 (para automações).
- `dia2_questoes_index.json`: índice por questão do Dia 2 (para automações).
- `dia1_texto_limpo.txt`: texto limpo intermediário do Dia 1.
- `dia2_texto_limpo.txt`: texto limpo intermediário do Dia 2.

## Observações de extração

- No Dia 1, as questões `01` a `05` aparecem em duas variações (Inglês e Espanhol), então o índice traz 95 blocos para 90 números únicos.
- O parser reorganiza páginas em duas colunas (esquerda -> direita) para reduzir mistura de enunciados.
- Pode haver pequenos ruídos de OCR/layout em questões com tabelas, figuras ou fórmulas.

## Como regenerar

```bash
python3 scripts/extrair_banco_enem_real.py \
  --ano 2025 \
  --dia 1 \
  --prova 'questoes/provas_anteriores/2025_PV_impresso_D1_CD1.pdf' \
  --gabarito 'questoes/provas_anteriores/2025_GB_impresso_D1_CD1.pdf' \
  --outdir 'questoes/banco_reais/enem_2025'

python3 scripts/extrair_banco_enem_real.py \
  --ano 2025 \
  --dia 2 \
  --prova 'questoes/provas_anteriores/2025_PV_impresso_D2_CD5.pdf' \
  --gabarito 'questoes/provas_anteriores/2025_GB_impresso_D2_CD5.pdf' \
  --outdir 'questoes/banco_reais/enem_2025'
```

## Uso recomendado no estudo

- Use este banco para identificar padrão real de comando, distratores e nível de dificuldade.
- Ao gerar novas questões, preserve o estilo ENEM, mas mantenha enunciados originais (não copiar literalmente).
