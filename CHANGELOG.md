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

### Security
- `prompts/contexto_sessao.md` configurado para não ser versionado via `.gitignore`.
