# Rotina de Atualização ao Adicionar Novos Cadernos

Objetivo: manter o fluxo de atualização reproduzível quando entra um novo ano de prova no repositório.

## 1) Pré-requisitos

- PDFs no padrão em `questoes/provas_anteriores/`:
  - `{ano}_dia1_prova.pdf`
  - `{ano}_dia1_gabarito.pdf`
  - `{ano}_dia2_prova.pdf`
  - `{ano}_dia2_gabarito.pdf`
- Python 3 disponível.

## 2) Extração do banco real

### Opção recomendada (lote)
```bash
python3 scripts/extrair_banco_enem_lote.py \
  --provas-dir questoes/provas_anteriores \
  --out-base questoes/banco_reais \
  --year-from 2015 \
  --year-to 2026 \
  --status-file questoes/banco_reais/STATUS_EXTRACAO.md
```

### Opção pontual (ano/dia)
```bash
python3 scripts/extrair_banco_enem_real.py \
  --ano 2026 \
  --dia 1 \
  --prova questoes/provas_anteriores/2026_dia1_prova.pdf \
  --gabarito questoes/provas_anteriores/2026_dia1_gabarito.pdf \
  --outdir questoes/banco_reais/enem_2026
```

Repetir para `--dia 2`.

## 3) Auditoria de qualidade OCR

```bash
python3 scripts/test_extracao_ocr_questoes.py \
  --banco-dir questoes/banco_reais \
  --year-from 2015 \
  --year-to 2026 \
  --sample-size 20
```

Saídas de verificação:
- `questoes/banco_reais/teste_ocr_extracao.md`
- `questoes/banco_reais/STATUS_EXTRACAO.md`

## 4) Correção de vazios por imagem (se necessário)

Quando houver questões vazias:
```bash
python3 scripts/recortar_questoes_vazias_pdf.py --ano 2026 --dia 1
python3 scripts/recortar_questoes_vazias_pdf.py --ano 2026 --dia 2
```

## 5) Atualizar mapeamento por habilidade

```bash
python3 scripts/mapear_habilidades_enem.py \
  --banco-dir questoes/banco_reais \
  --out-dir questoes/mapeamento_habilidades \
  --year-from 2015 \
  --year-to 2026
```

Artefatos esperados:
- `questoes/mapeamento_habilidades/questoes_mapeadas.csv`
- `questoes/mapeamento_habilidades/questoes_mapeadas.jsonl`
- `questoes/mapeamento_habilidades/revisao_pendente.md`

## 6) Atualizar pacote offline

Gerar pacote de conteúdo com versão nova:
```bash
python3 scripts/build_assets_release.py \
  --questions-csv questoes/mapeamento_habilidades/questoes_mapeadas.csv \
  --modules-csv plano/indice_livros_6_volumes.csv \
  --out-dir app_flutter/releases \
  --version 2026.03.06.1
```

Validar existência de:
- `app_flutter/releases/<versao>/manifest.json`
- `app_flutter/releases/<versao>/assets_<versao>.zip`
- checksum `.sha256`.

## 7) Checklist de conclusão

- [ ] PDFs dos dois dias no padrão de nome.
- [ ] Extração por lote/ano concluída sem erro crítico.
- [ ] `STATUS_EXTRACAO.md` atualizado com novo ano.
- [ ] Auditoria OCR executada e relatório revisado.
- [ ] Mapeamento por habilidade regenerado.
- [ ] Bundle offline gerado (manifest + zip + checksum).
- [ ] `docs/roadmap/status.md` e `CHANGELOG.md` atualizados.

## 8) Critério de rollback rápido

Se houver regressão:
1. manter versão anterior do bundle no `manifest` como referência;
2. não promover novo pacote para canal estável;
3. registrar falha no `status.md` com ação corretiva e data.
