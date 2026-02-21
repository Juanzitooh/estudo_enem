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

### Changed
- `README.md` ampliado com tipos de interação, fluxo semanal/diário e práticas de privacidade.
- `agents.global.md` e `prompts/agents.global.md` alinhados para integrar README, CHANGELOG e regras globais.

### Security
- `prompts/contexto_sessao.md` configurado para não ser versionado via `.gitignore`.
