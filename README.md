# estudo_enem

Organização de estudo para o ENEM baseada na Matriz de Referência do INEP, com fluxo de uso no Codex.

## Objetivo

Este repositório foi estruturado para você estudar com:
- fonte oficial da matriz;
- planejamento semanal;
- sessões de estudo guiadas por habilidade;
- registro de progresso.

## Estrutura do projeto

- `sources/inep_matriz_referencia.pdf`: PDF base oficial.
- `matriz/matriz_referencia_enem.md`: matriz completa em Markdown.
- `matriz/eixos_cognitivos.md`: eixos cognitivos resumidos.
- `matriz/habilidades_por_area/`: habilidades por área.
- `plano/plano_semanal.md`: planejamento da semana.
- `plano/tracker.md`: histórico de progresso e erros.
- `prompts/agents.global.md`: regras globais de atuação do agente.
- `prompts/contexto_sessao.md`: template para contexto da sessão.
- `prompts/contexto_sessao.example.md`: exemplo preenchido.
- `CHANGELOG.md`: histórico de mudanças do projeto.

## Quick Start

1. Preencha `prompts/contexto_sessao.md`.
2. Inicie uma sessão no Codex com o comando padrão abaixo.
3. Estude por habilidade e registre no tracker.
4. Feche a semana com revisão e replanejamento.

## Como usar no dia a dia

### 1) Preencha o contexto da sessão

Edite `prompts/contexto_sessao.md` com seus dados reais:
- horas disponíveis;
- áreas prioritárias;
- dificuldade atual;
- objetivo da sessão de hoje.

Se preferir, copie o exemplo:
- base: `prompts/contexto_sessao.example.md`
- destino: `prompts/contexto_sessao.md`

### 2) Inicie a sessão no Codex com comando padrão

No começo da conversa, envie este prompt:

```text
Leia prompts/contexto_sessao.md e monte o plano da sessão de hoje seguindo prompts/agents.global.md e os arquivos em matriz/ e plano/.
```

### 3) Comando para aula profunda por habilidade

Use quando quiser ir a fundo em um tema específico:

```text
Com base em prompts/contexto_sessao.md, conduza uma sessão profunda da habilidade [AREA-Hx]:
1) explicação objetiva,
2) exemplos resolvidos,
3) 10 questões originais estilo ENEM (5 fáceis, 3 médias, 2 difíceis),
4) gabarito comentado curto,
5) resumo final com erros comuns.
No fim, gere o registro para eu colar em plano/tracker.md.
```

Exemplo de habilidade:
- Matemática H16
- Natureza H21

### 4) Atualize plano e tracker após estudar

Ao fim da sessão, peça:

```text
Com base no que fizemos hoje, atualize:
- plano/plano_semanal.md (situação da semana)
- plano/tracker.md (linha de progresso da sessão)
Mostre as edições propostas.
```

### 5) Revisão semanal

No fim da semana, rode uma revisão:

```text
Leia plano/tracker.md e matriz/habilidades_por_area/*.md.
Gere:
1) diagnóstico da semana,
2) habilidades com mais erro,
3) plano da próxima semana em plano/plano_semanal.md com foco em correção de lacunas.
```

## Tipos de interação com o Codex

### Planejamento semanal

```text
Leia prompts/contexto_sessao.md, plano/tracker.md e matriz/habilidades_por_area/*.md.
Crie o planejamento da semana em plano/plano_semanal.md com prioridades, metas e revisão.
```

### Aula profunda por habilidade

```text
Com base em prompts/contexto_sessao.md, conduza sessão profunda da habilidade [AREA-Hx] com:
explicação, exemplos resolvidos, 10 questões originais ENEM, gabarito comentado e resumo final.
```

### Treino focado em erro recorrente

```text
Leia plano/tracker.md e identifique meus 3 erros mais recorrentes.
Gere treino direcionado para corrigi-los, com questões curtas e correção objetiva.
```

### Revisão antes de simulado

```text
Monte revisão de 60 minutos focada em alto retorno, com base no meu contexto e no tracker.
No fim, proponha checklist rápido de revisão.
```

### Pós-simulado

```text
Vou enviar meu resultado de simulado.
Classifique os erros por habilidade da matriz e atualize plano/plano_semanal.md e plano/tracker.md.
```

## Conversao MD para PDF (Prince)

Se a extensao do VSCode falhar na exportacao, use o conversor do projeto:

```bash
scripts/md_to_pdf_prince.sh <arquivo.md> [arquivo.pdf]
```

Exemplo com o arquivo de teste:

```bash
scripts/md_to_pdf_prince.sh teste_aula_habilidade_base_h18.md
```

Saida esperada:
- `teste_aula_habilidade_base_h18.pdf`

Atalho no VSCode (sem extensao):
1. `Ctrl+Shift+P`
2. `Tasks: Run Task`
3. `MD -> PDF (Prince) arquivo atual`

## Fluxo recomendado (simples)

1. Planejar a semana em `plano/plano_semanal.md`.
2. Estudar por habilidade com sessão profunda.
3. Praticar questões e corrigir.
4. Registrar no `plano/tracker.md`.
5. Replanejar a próxima semana com base nos erros.

## Regras importantes do projeto

- Base principal: `sources/inep_matriz_referencia.pdf` e arquivos em `matriz/`.
- Não inventar habilidades fora da matriz.
- Questões de treino devem ser originais.
- Sempre registrar progresso no tracker.

## Privacidade e dados pessoais

- O arquivo `prompts/contexto_sessao.md` contém dados pessoais e está no `.gitignore`.
- Versione apenas `prompts/contexto_sessao.example.md` como modelo público.

## Changelog e convenção de commits

- Registre mudanças relevantes em `CHANGELOG.md`.
- Use commits atômicos e curtos.
- Prefixos adotados neste projeto:
- `fix`: correção de bug.
- `feat`: nova funcionalidade.
- `imp`: melhoria/refactor sem feature nova.
- `docs`: documentação.
- `codex`: ajustes em arquivos de agente/overrides e arquivos usados apenas pelo Codex.

## Estado atual

O repositório já contém:
- matriz convertida para Markdown;
- eixos cognitivos;
- habilidades por área;
- templates de contexto e planejamento.

Próximo passo natural: preencher `prompts/contexto_sessao.md` e iniciar a primeira sessão com o comando padrão.
