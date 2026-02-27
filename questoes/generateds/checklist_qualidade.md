# Checklist de qualidade - Questoes geradas

Use este checklist antes de publicar qualquer lote em `questoes/generateds/`.

## 1) Formato e contrato

- [ ] Arquivo em JSONL (1 questao por linha).
- [ ] Campos obrigatorios presentes em todas as linhas.
- [ ] Alternativas A-E preenchidas e gabarito valido.
- [ ] Distribuicao de dificuldade validada (ex.: 5/3/2 quando aplicavel).
- [ ] `review_status` iniciado como `rascunho`.

## 2) Qualidade pedagogica

- [ ] Questao esta alinhada com `competencia` e `habilidade`.
- [ ] Enunciado tem comando claro e sem ambiguidade.
- [ ] Distratores sao plausiveis, mas incorretos.
- [ ] Explicacao justifica o gabarito com raciocinio objetivo.
- [ ] Contexto esta aderente ao ENEM (preferencia por cotidiano brasileiro).

## 3) Risco de copia literal

- [ ] Nao ha trechos suspeitos iguais a questoes reais do banco oficial.
- [ ] Temas podem ser parecidos, mas texto e estrutura sao originais.
- [ ] Se houver semelhanca alta, reescrever antes de revisar.

## 4) Fontes e rastreabilidade

- [ ] Cada questao possui ao menos 1 fonte (`fontes`).
- [ ] Lote possui `prompt_ref` e `generated_by` preenchidos.
- [ ] Revisao humana registrada antes de publicar (`review_status=aprovado`, `reviewed_by`, `approved_at`).

## Comando de validacao rapida

```bash
python3 scripts/validar_questoes_geradas.py \
  --input <arquivo_lote.jsonl> \
  --expected-distribution 5,3,2
```
