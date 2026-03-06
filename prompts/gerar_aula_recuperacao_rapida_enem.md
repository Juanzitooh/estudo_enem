# Prompt padrao v1 - Geracao de recuperacao rapida por modulo (ENEM)

Use este prompt em IA externa para gerar uma recuperacao curta pos-erro,
seguindo o contrato editorial do projeto.

## Prompt

```text
Voce e redator pedagogico especializado no ENEM.

Objetivo:
Gerar uma aula de recuperacao rapida para:
- area: {AREA}
- materia: {MATERIA}
- volume: {VOLUME}
- modulo: {MODULO}
- titulo_modulo_base: {TITULO}
- trigger_question_id: {TRIGGER_QUESTION_ID}
- trigger_skill: {TRIGGER_SKILL}
- target_concepts: {TARGET_CONCEPTS}

Regras obrigatorias:
1) A aula deve caber em 10-15 min.
2) Foco em correcao de erro recorrente, sem virar aula completa.
3) Linguagem objetiva e direta para aluno final.
4) Incluir:
   - objetivo micro (saber/aplicar/revisar);
   - microdiagnostico (3 perguntas);
   - microtreino (3 questoes: facil, media, aplicada);
   - regra de saida (>=2/3 volta feed; <2/3 abre aula completa).
5) Incluir ao menos 1 exemplo brasileiro de aplicacao rapida.
6) Incluir bloco de aprofundamento opcional por video com minutagem.
7) Preencher metadados editoriais e campos tecnicos.
8) Nao deixar placeholders (`{...}`), reticencias (`...`) ou trechos incompletos.
9) Nao incluir instrucoes internas no texto final (ex.: "preencher campo", "minimo 2").

Formato de saida:
- Retorne APENAS Markdown.
- Respeite exatamente a estrutura do template abaixo.

Template obrigatorio:
{TEMPLATE_AULA_RECUPERACAO_RAPIDA}
```

## Uso sugerido no repositorio

1. Gere/abra um rascunho em `aulas/{area}/modulos/V{volume}_M{modulo}_{slug}_recuperacao_rapida.md`.
2. Cole o template de `templates/aula_modulo_recuperacao_rapida_enem.md` no placeholder `{TEMPLATE_AULA_RECUPERACAO_RAPIDA}`.
3. Preencha os campos de contexto do erro (`TRIGGER_QUESTION_ID`, `TRIGGER_SKILL`, `TARGET_CONCEPTS`).
4. Revise o resultado para confirmar foco de recuperacao curta e ausencia de placeholders.
