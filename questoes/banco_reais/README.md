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

## Onde ver as questões reais

Arquivos principais por ano:

- `questoes/banco_reais/enem_2015/dia1_questoes_reais.md`
- `questoes/banco_reais/enem_2015/dia2_questoes_reais.md`
- ...
- `questoes/banco_reais/enem_2025/dia1_questoes_reais.md`
- `questoes/banco_reais/enem_2025/dia2_questoes_reais.md`

Para ver de forma filtrada com metadados (área, disciplina, competência, habilidade, tema, imagem), use:

```bash
python3 scripts/consultar_banco_questoes.py --limit 30
```

Para listar rapidamente casos de OCR vazio (com fallback de imagem):

```bash
python3 scripts/consultar_banco_questoes.py \
  --ano 2015 \
  --dia 2 \
  --limit 20 \
  --formato md
```

## Teste de extração e OCR

Para auditar se a extração está capturando cabeçalho, metadados, texto e gabarito:

```bash
python3 scripts/test_extracao_ocr_questoes.py --sample-size 20
```

Saída:
- relatório em `questoes/banco_reais/teste_ocr_extracao.md`;
- resumo no terminal com totais e falhas.

## Fallback por imagem (questões vazias)

Quando houver questão vazia no markdown, é possível recortar a imagem diretamente do PDF:

```bash
python3 scripts/recortar_questoes_vazias_pdf.py --ano 2015 --dia 1
python3 scripts/recortar_questoes_vazias_pdf.py --ano 2015 --dia 2
```

Saídas por dia:
- `.../diaX_questoes_vazias_imagens/images/*.png` (recortes);
- `.../diaX_questoes_vazias_imagens/manifest.csv` (metadados dos recortes);
- `.../diaX_questoes_vazias_imagens/resumo.md` (resumo da execução).

Observação:
- o recorte já descarta automaticamente faixas de topo/cabeçalho sem conteúdo útil (ex.: trecho só com código do caderno ou sem texto).
