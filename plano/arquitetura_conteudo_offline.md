# Arquitetura de Conteúdo Offline (Repo -> Flutter)

## Objetivo
Separar claramente:
- app Flutter offline-first (consumo);
- repositório de geração/curadoria (produção de conteúdo);
- publicação versionada para atualização incremental.

## Princípios
- O app funciona sem internet com o conteúdo já instalado.
- A internet entra apenas para atualizar pacotes (`manifest.json` + `assets.zip`).
- Conteúdo gerado por IA sempre passa por revisão humana antes de publicação.
- Todo item publicado tem rastreabilidade de fonte e revisão.
- Limpeza/retencao segue politica dedicada em `plano/politica_retencao_repositorio.md`.

## Estrutura proposta de pastas
```text
conteudo/
  raw/                 # extrações brutas (provas, OCR, fontes)
  generated/           # saídas de IA/agentes e automações
  reviewed/            # itens revisados manualmente
  published/           # produto final versionado para o app
    banco_questoes/
    banco_aulas/
    banco_videos/
    banco_redacao/
```

## Estado editorial obrigatório
`rascunho -> revisado -> aprovado -> publicado`

Campos mínimos em todos os itens:
- `id`
- `version`
- `generated_by`
- `reviewed_by`
- `review_status`
- `source_type`
- `source_url`
- `source_date`
- `updated_at`

## Contratos mínimos por domínio

### 1) Questões (`banco_questoes`)
- `area`, `disciplina`, `materia`
- `competencia`, `habilidade`
- `enunciado`, `alternativas`, `gabarito`, `explicacao`
- `dificuldade`, `tags`
- `tem_imagem`, `asset_path` (quando existir)

### 2) Aulas (`banco_aulas`)
- `area`, `materia`, `volume`, `modulo`, `titulo`
- `expectativas_aprendizagem`
- `competencias_habilidades`
- `conteudo_aula` (template editorial)
- `ia_updated_at`, `manual_reviewed_at`, `manual_reviewed_by`

### 3) Vídeos (`banco_videos`)
- `platform`, `video_id`, `title`, `channel`
- `segment_title`, `start_sec`, `end_sec`
- `skill_id` (opcional via tabela de relação)
- `availability` (`public`/`external`)

### 4) Redação (`banco_redacao`)
- `tema`, `ano_base`, `status_editorial`
- `textos_motivadores` com fonte e data
- prompts (`geracao`, `correcao`, `reescrita`)

## Geração por agentes (questões inéditas)
- Entrada: habilidade alvo + estilo ENEM + restrições.
- Saída: questão no schema oficial já com competência/habilidade/dificuldade/tags/fontes.
- Estudo prévio obrigatório do estilo ENEM por área (linguagem, tamanho, comando e tipo de distrator).
- Qualidade obrigatória antes de publicar: validação de formato, consistência gabarito-explicação, score de similaridade com banco real (evitar cópia literal) e revisão humana com aprovação.

## Publicação e consumo no app
1. Build de conteúdo gera `manifest.json`, `assets.zip` e `checksum`.
2. Flutter baixa pacote (quando online), valida checksum e importa para SQLite local.
3. App segue 100% offline até próxima atualização.

## Papel do repositório
Este repositório funciona como:
- base de dados versionada;
- pipeline de geração/curadoria;
- origem dos pacotes de atualização consumidos pelo app.
