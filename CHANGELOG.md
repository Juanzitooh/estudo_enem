# Changelog

Todas as mudanças relevantes deste projeto serão documentadas aqui.

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

## [Unreleased]

### Added
- Estrutura base do projeto para estudo do ENEM (`sources/`, `matriz/`, `plano/`, `prompts/`).
- Conversão da Matriz de Referência do INEP para Markdown em `matriz/matriz_referencia_enem.md`.
- Arquivos derivados por área em `matriz/habilidades_por_area/`.
- Resumo dos eixos cognitivos em `matriz/eixos_cognitivos.md`.
- Templates de contexto de sessão em `prompts/contexto_sessao.md` e `prompts/contexto_sessao.example.md`.
- Guia operacional no `README.md` para uso com Codex.
- Template definitivo de aula por habilidade em `templates/aula_habilidade_enem.md`.
- Estrutura para material final (`aulas/` e `questoes/`) com `.gitkeep`.
- Pasta de notas de pesquisa (`notes/`) com guia em `notes/README.md` e exemplo em `notes/H18_linguagens.md`.
- Imagens de apoio para aula H18 em `assets/img/`.
- Script `scripts/extrair_banco_enem_real.py` para extrair provas reais (PDF) para Markdown e JSON.
- Banco real inicial em `questoes/banco_reais/enem_2025/` com Dia 1 e Dia 2 extraídos.
- Documentação do banco real em `questoes/banco_reais/README.md` e `questoes/banco_reais/enem_2025/README.md`.
- Script de lote `scripts/extrair_banco_enem_lote.py` para extrair 2015–2025 com mapeamento de nomenclaturas.
- Bancos reais adicionais em `questoes/banco_reais/enem_2015` até `questoes/banco_reais/enem_2024`.
- Relatório consolidado de extração em `questoes/banco_reais/STATUS_EXTRACAO.md`.
- Resumo operacional do edital em `plano/resumo_edital_2025.md`.
- Scaffold do cliente Flutter offline em `app_flutter/enem_offline_client/` com app mínimo e SQLite.
- Script `scripts/build_assets_release.py` para gerar `assets.zip` + `manifest.json` com SHA256.
- Script raiz `dist.sh` para pipeline idempotente de release (conteúdo + build Linux + execução final).
- Guia dedicado de cliente offline em `app_flutter/README.md`.
- Suporte no bundle para `questions` + `book_modules` (índice dos livros) com update offline.
- Trilha de planejamento em `docs/roadmap/` para feed híbrido (`habilidade + conceito`) com Q-matrix, dependências e diagnóstico pós-erro (T2.4 a T2.8).
- Referência técnica de grafo movida para `docs/roadmap/references/aprendizado_grafo.md`.
- Template de recuperação rápida pós-erro em `templates/aula_modulo_recuperacao_rapida_enem.md`.
- Planejamento canônico atualizado para explicitar os 3 tipos de aula (`habilidade`, `módulo completo`, `recuperação rápida`) e a política `reels -> rápida/completa`.
- Planejamento canônico atualizado com pesos fundacionais do grafo e métricas de perfil (`matriz INEP + conceitos + aulas concluídas`).
- Planejamento canônico atualizado com 2 modos de sessão: `adaptativo` (plano comum) e `prova oficial ENEM por ano/dia` em caderno fechado sem adaptação durante a resolução.
- POC de player de aula no Flutter com payload de conteúdo para aluno, questões interativas com gabarito oculto e seção de aprofundamento desbloqueada após tentativa mínima.
- Planejamento ajustado para aprovação parcial de template/player e avanço da trilha técnica, deixando decisão editorial final para pós-catalogação dos 6 volumes.
- Persistência mínima local da aula adicionada no app (retomada de respostas/finalização) com interrelação versionada `aula <-> questão` e marcação de tentativas desatualizadas por versão.
- Fluxo de aula validado manualmente (`T3.8`/`T3.9`) e UI com aviso de tentativas desatualizadas por mudança de versão da aula.
- `T3.10` concluída no app com histórico de tentativas por versão da aula e identificação de tentativas desatualizadas.
- `T3.7` concluída com especificação formal do contrato `lesson_payload_aluno` e regra de transformação `md -> payload`.
- `T3.3`, `T3.4` e `T3.6` concluídas com especificação operacional unificada para taxonomia editorial, workflow de revisão em lote e aprofundamento por vídeo com minutagem.
- `T4.3` concluída com estratégia de versionamento incremental por módulo no manifesto de conteúdo.
- `T5.2` concluída com fluxo de assinatura Android (`debug/local` vs `release`) e checklist mínimo de validação.
- `T3.5` concluída com piloto real de recuperação rápida no módulo `V1_M1_antiguidade_oriental` e relatório de aceite do fluxo pós-erro.
- `T3.2` concluída com hardening de template/prompt: limpeza pré-publicação, remoção de placeholders/instruções internas e novo prompt dedicado para recuperação rápida.

### Changed
- `README.md` ampliado com tipos de interação, fluxo semanal/diário e práticas de privacidade.
- `agents.global.md` e `prompts/agents.global.md` alinhados para integrar README, CHANGELOG e regras globais.
- `teste_aula_habilidade_base_h18.md` reestruturado no padrão de template definitivo e com imagens incorporadas.
- `teste_aula_habilidade_base_h18.md` atualizado para 10 questões ENEM-like (5 fáceis, 3 médias, 2 difíceis).
- `teste_aula_habilidade_base_h18.md` ajustado para exibir alternativas A/B/C/D/E em linhas separadas (mais legível em MD e PDF).
- `scripts/md_to_pdf_prince.sh` ajustado para converter Markdown com imagens relativas para PDF via `--baseurl`.
- `README.md` atualizado com orientação de uso do template definitivo e seção de conversão MD -> PDF com imagens.
- `templates/aula_habilidade_enem.md`, `prompts/agents.global.md` e `README.md` padronizados com a regra de 10 questões por aula e alternativas em linhas separadas.
- `README.md`, `agents.global.md` e `prompts/agents.global.md` atualizados para incluir uso de `questoes/banco_reais/` na calibração de questões.
- `scripts/extrair_banco_enem_real.py` generalizado para diferentes anos (detecção de `QUESTÃO`, ordem de áreas e parsing de gabaritos antigos).
- `README.md`, `agents.global.md` e `prompts/agents.global.md` atualizados para usar `questoes/provas_anteriores` e incluir `edital.pdf` como fonte complementar.
- `README.md` e `plano/roadmap_geral.md` atualizados para estratégia de distribuição multiplataforma via cliente local e atualização de conteúdo por manifest.
- Cliente Flutter MVP ajustado para cruzar histórico de acertos (`progress`) com habilidades fracas e sugerir módulos de livro.

### Security
- `prompts/contexto_sessao.md` configurado para não ser versionado via `.gitignore`.
