# Roadmap

Fonte consolidada desta estrutura:
- `plano/roadmap_geral.md`
- `plano/roadmap_proximos_passos.md`

## Direções (médio/longo prazo)

## R1 - Consolidação de dados e qualidade de extração
Status: `em_andamento`
- Fechar validação manual por amostra das questões reais.
- Estabilizar regra de atualização incremental por ano.
- Manter qualidade dos metadados por habilidade/competência/dificuldade.

## R2 - Motor de prática e planejamento
Status: `em_andamento`
- Completar integração planner -> abertura direta de treino/módulo.
- Fechar rotina operacional semanal com tracker por habilidade.
- Consolidar métricas e priorização determinística por lacuna.
- Introduzir camada de conceitos com Q-matrix e dependências em piloto incremental por área.
- Evoluir feed inteligente para seleção híbrida (`habilidade + conceito`) com knowledge tracing leve.
- Incluir diagnóstico pós-erro curto para identificar lacuna conceitual acionável.
- Definir política de roteamento pós-erro (`reels -> recuperação rápida` vs `aula completa`).
- Exibir no perfil métricas combinadas (`matriz INEP + grafo de conceitos + aulas concluídas`).
- Oferecer modos de sessão: `adaptativo` e `prova oficial ENEM por ano/dia`.
- Garantir execução de prova oficial em sequência fechada, sem intervenções adaptativas durante o caderno.

## R3 - Aulas por módulo (geração assistida)
Status: `em_andamento`
- Operacionalizar lote piloto com rubrica e redução de retrabalho.
- Completar workflow editorial de revisão em lote.
- Integrar aprofundamento por vídeo com minutagem.
- Consolidar convivência dos 3 tipos de aula: habilidade, módulo completo e recuperação rápida.
- Entregar player de aula no app com visualização para aluno e questões interativas com gabarito oculto.
- Formalizar interrelação `aula <-> questão` para rastrear tentativas por aula/versão e atualização de conteúdo.
- Desbloquear seção de aprofundamento somente após tentativa mínima de questões na própria aula.

## R4 - Conteúdo versionado e publicação offline
Status: `parcialmente_concluido`
- Estrutura canônica e metadados editoriais já definidos.
- Pipeline `manifest + assets + checksum` já funcional.
- Próximo: evolução contínua de contratos por domínio e compatibilidade.

## R5 - App open source e distribuição
Status: `em_andamento`
- Expandir cobertura de simulado e fluxo de revisão.
- Fechar geração opcional de APK no pipeline de dist.
- Consolidar checklist de release estável.

## R6 - Pós-catálogo (bloqueado)
Status: `bloqueado`
- Trilha transversal entre módulos.
- Revisão editorial 2019 -> 2026 por módulo.
- Metadados de atualização final e gate de publicação.

## R7 - Vitrine web e portfólio
Status: `concluido`
- Apresentar o produto com uma experiência web responsiva e visualmente autoral.
- Permitir exploração demonstrativa sem backend obrigatório.
- Automatizar a publicação estática no GitHub Pages.
