# M3 - Operação Editorial (Sem Dependência de Catalogação)

Status: aprovado  
Data: 2026-03-06  
Cobertura: `T3.3`, `T3.4`, `T3.6`

## 1) Taxonomia dos 3 tipos de aula (`T3.6`)

### 1.1 Aula por habilidade (`aula_habilidade_enem`)
- Objetivo: fechar lacuna específica de habilidade INEP (`Hxx`).
- Gatilho de entrada:
  - erro recorrente na mesma habilidade;
  - diagnóstico de baixa cobertura por habilidade.
- Duração alvo: curta a média.
- Saída esperada: melhoria de acerto naquela habilidade e redução de erro recorrente.

### 1.2 Aula por módulo completo (`aula_modulo_enem`)
- Objetivo: consolidar base conceitual de um módulo do livro e aplicação ENEM.
- Gatilho de entrada:
  - primeiro contato com tema estruturante;
  - baixa base conceitual no grafo;
  - necessidade de estudo completo fora do fluxo pós-erro.
- Duração alvo: média a longa.
- Saída esperada: domínio de conceitos centrais + resolução guiada + questões da aula.

### 1.3 Recuperação rápida (`aula_modulo_recuperacao_rapida_enem`)
- Objetivo: intervenção curta pós-erro para retomada imediata.
- Gatilho de entrada:
  - usuário já teve contato prévio com o tema;
  - erro pontual em conceito específico durante feed de questões.
- Duração alvo: curta.
- Saída esperada: retorno rápido ao feed com correção de ponto crítico.

## 2) Workflow editorial em lote (`T3.4`)

Estados canônicos:
1. `rascunho`
2. `revisado`
3. `aprovado`
4. `publicado`

Regras:
- Somente `aprovado`/`publicado` pode virar payload de aluno.
- Mudança de `revisado -> aprovado` exige validação humana mínima:
  - aderência ao template;
  - correção factual;
  - legibilidade para aluno final;
  - consistência de questões (5 alternativas + gabarito + comentário).
- Alteração após `publicado` incrementa versão e preserva histórico.

Checklist por lote:
- cobertura das seções obrigatórias;
- remoção de instruções internas no payload do aluno;
- validação de vínculo `lesson_id` e consistência de `source_question_id` quando existir;
- atualização de changelog de conteúdo.

## 3) Integração de aprofundamento por vídeo (`T3.3`)

Objetivo:
- permitir aprofundamento opcional após tentativa mínima de questões da aula.

Contrato recomendado para o payload (seção `deepening_videos`):
- `provider`: `youtube|interno|outro`.
- `video_id`: identificador da plataforma.
- `url`: link completo.
- `title`: título curto para exibição.
- `start_sec`: início recomendado.
- `end_sec`: fim recomendado (opcional).
- `duration_sec`: duração total (opcional).
- `why_watch`: justificativa pedagógica (1 linha).
- `relation_type`: `conceito|resolucao|revisao`.
- `priority`: `1..5` (1 = mais recomendado).

Regras de UX no app:
- seção só aparece destravada após tentativa mínima (já implementado).
- renderizar primeiro os vídeos de maior prioridade.
- abrir player externo com minutagem (`t=start_sec` quando suportado).
- registrar evento local de clique/consumo para analytics offline.

Critérios de curadoria:
- no mínimo 1 e no máximo 3 recomendações por aula;
- evitar duplicar vídeo em múltiplas aulas sem justificativa;
- preferir vídeos com foco direto no conceito alvo da aula.
