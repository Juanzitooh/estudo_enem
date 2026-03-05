# Contrato `lesson_payload_aluno`

Status: aprovado (`T3.7`)  
Data: 2026-03-05  
Escopo: derivação de `aula_modulo_enem` (Markdown editorial) para payload consumido pelo app.

## 1) Objetivo

Definir um contrato estável para experiência do aluno no app, separando:
- campos pedagógicos exibíveis;
- campos editoriais internos (não exibidos ao aluno);
- regra de transformação `md -> payload`.

## 2) Fonte e artefato

- Fonte editorial: `aulas/*/modulos/*.md`.
- Pré-condição de publicação: estado editorial `aprovado` ou `publicado`.
- Artefato final: arquivo JSON em `app_flutter/enem_offline_client/assets/lessons/`.

## 3) Campos pedagógicos exibíveis (payload aluno)

Campos obrigatórios:
- `id` (string): identificador canônico da aula.
- `version` (string): versão do payload publicada.
- `title` (string): título da aula para o aluno.
- `area` (string): área ENEM.
- `materia` (string): disciplina.
- `volume` (int): volume do livro.
- `modulo` (int): módulo do livro.
- `learning_expectations` (string[]): objetivos de aprendizagem.
- `concepts` (string[]): conceitos centrais.
- `resolution_steps` (string[]): passo a passo (seção 4.2).
- `enem_patterns` (string[]): padrões de cobrança no ENEM (seção 4.3).
- `questions` (array): questões exibidas no player.

Campos opcionais recomendados:
- `competencies` (string[]): competências/habilidades referenciadas.
- `context_12m` (obj): eventos e conexão com atualidades.
- `examples` (array): exemplos práticos contextualizados.
- `case_study` (obj): problema real aplicado.
- `deepening` (obj): aprofundamento (liberado por gatilho no app).
- `quick_check` (string[]): checagem rápida.
- `summary` (string): resumo de fechamento.

Contrato mínimo de `questions[]`:
- `id` (string): id da questão dentro da aula.
- `level` (string): nível (`facil|media|dificil` ou equivalente editorial).
- `statement` (string): enunciado.
- `options` (array): alternativas (`id`, `text`).
- `answer` (string): gabarito (oculto até envio/finalização no app).
- `commentary` (string): comentário pós-correção.
- `source_question_id` (string, opcional): vínculo com questão canônica do banco.

## 4) Campos editoriais internos (não exibíveis ao aluno)

Exemplos típicos no markdown de autoria/revisão:
- instruções de geração (`mínimo 2`, `usar cenário X`, `incluir Y`).
- checklist de rubrica interna.
- notas para revisor humano (`TODO`, `ajustar tom`, `validar fonte`).
- status de workflow (`rascunho`, `revisado`, `aprovado`, `publicado`).
- metadados de processo (autor, revisor, data de revisão, versão do prompt).

Regra:
- esses campos permanecem no documento editorial e/ou metadados de pipeline;
- não entram em `lesson_payload_aluno`.

## 5) Regra de transformação `md -> payload`

1. Validar estado editorial (`aprovado`/`publicado`).
2. Parsear seções canônicas da aula módulo.
3. Extrair apenas blocos pedagógicos exibíveis.
4. Remover linhas instrucionais internas de template.
5. Normalizar ids e tipos:
   - `id` em `snake_case`;
   - alternativas em maiúsculas (`A-E`);
   - listas como arrays limpos (sem itens vazios).
6. Gerar `version` do payload (incremental por publicação da aula).
7. Validar consistência:
   - todas as questões com 5 alternativas;
   - `answer` presente para cada questão;
   - `learning_expectations` e `concepts` não vazios.
8. Publicar no bundle de assets offline.

## 6) Regras de versionamento

- Uma alteração em conteúdo pedagógico da aula incrementa `version`.
- Alteração de qualquer `question` deve manter `source_question_id` quando houver equivalência.
- Tentativas antigas do aluno permanecem no histórico e podem ser marcadas como desatualizadas no app quando `version` mudar.

## 7) Exemplo mínimo

```json
{
  "id": "v1_historia1_m1_antiguidade_oriental",
  "version": "2026.03.05.1",
  "title": "Antiguidade Oriental",
  "area": "Ciências Humanas e suas Tecnologias",
  "materia": "História 1",
  "volume": 1,
  "modulo": 1,
  "learning_expectations": ["..."],
  "concepts": ["..."],
  "resolution_steps": ["..."],
  "enem_patterns": ["..."],
  "questions": [
    {
      "id": "Q1",
      "level": "Fácil",
      "statement": "...",
      "options": [
        {"id": "A", "text": "..."},
        {"id": "B", "text": "..."},
        {"id": "C", "text": "..."},
        {"id": "D", "text": "..."},
        {"id": "E", "text": "..."}
      ],
      "answer": "B",
      "commentary": "...",
      "source_question_id": "2023_1_45_1"
    }
  ]
}
```
