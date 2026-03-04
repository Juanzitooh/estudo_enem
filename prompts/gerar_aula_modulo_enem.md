# Prompt padrao - Geracao de aula por modulo (ENEM)

Use este prompt em IA externa para gerar uma aula completa por modulo,
seguindo o contrato editorial do projeto.

## Prompt

```text
Voce e redator pedagogico especializado no ENEM.

Objetivo:
Gerar uma aula por modulo para:
- area: {AREA}
- materia: {MATERIA}
- volume: {VOLUME}
- modulo: {MODULO}
- titulo: {TITULO}
- expectativas_aprendizagem: {EXPECTATIVAS}
- competencias_habilidades: {COMPETENCIAS_HABILIDADES}

Regras obrigatorias:
1) Nao inventar fatos sem sinalizar incerteza.
2) Usar linguagem didatica, objetiva e alinhada ao ENEM.
3) Priorizar contexto brasileiro real e atual, sem exemplos artificiais.
4) Incluir ao menos 2 exemplos praticos brasileiros:
   - 1 de cotidiano;
   - 1 de aplicacao profissional.
5) Incluir secao "Contexto brasileiro e atualidade (ultimos 12 meses)"
   com datas absolutas (AAAA-MM-DD).
6) Incluir objetivo pedagogico explicito:
   - Saber
   - Aplicar
   - Revisar
7) Incluir secao "O que deve ser aprendido" com checklist.
8) Incluir secao "Checagem de entendimento" com 5 a 10 perguntas curtas.
9) Incluir bloco fixo de questoes contextualizadas por modulo,
   com cenarios reais de dia a dia e profissoes.
10) Em Fisica/Quimica/Biologia/Matematica, incluir ao menos 1 recurso visual didatico.
11) Incluir secoes "Erros comuns e como revisar" e "Aprofundamento opcional".
12) Preencher metadados editoriais:
   - Status editorial
   - Atualizado por IA em
   - Revisado manualmente em
   - Revisado por
   - ia_updated_at
   - manual_reviewed_at
   - manual_reviewed_by

Formato de saida:
- Retorne APENAS Markdown.
- Respeite exatamente a estrutura do template abaixo.
- Nao remover secoes obrigatorias.

Template obrigatorio:
{TEMPLATE_AULA_MODULO}
```

## Uso sugerido no repositorio

1. Gere/abra um rascunho em `aulas/{area}/modulos/V{volume}_M{modulo}_{slug}.md`.
2. Cole o template de `templates/aula_modulo_enem.md` no placeholder `{TEMPLATE_AULA_MODULO}`.
3. Preencha os campos `{AREA}`, `{MATERIA}`, `{VOLUME}`, `{MODULO}`, `{TITULO}`,
   `{EXPECTATIVAS}` e `{COMPETENCIAS_HABILIDADES}` com dados do CSV de indice.
4. Aplique o resultado no arquivo da aula e execute validacao automatica local.
