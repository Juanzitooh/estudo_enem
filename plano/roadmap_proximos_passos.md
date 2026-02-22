# Roadmap — Próximos Passos (continuação)

## Objetivo imediato
Consolidar o banco de questões reais e evoluir para um gerador de treino por habilidade da matriz ENEM.

## Bloco 1 — Qualidade da extração (curto prazo)
- [ ] Revisar manualmente amostra de 20 questões do Dia 1 e 20 do Dia 2.
- [ ] Identificar ruídos em enunciados com imagem/tabela/fórmula.
- [ ] Definir critérios de limpeza mínima para manter fidelidade sem perder contexto.

## Bloco 2 — Indexação por habilidade (curto prazo)
- [ ] Criar esquema de metadados por questão (`ano`, `dia`, `numero`, `area`, `habilidade`, `dificuldade`).
- [ ] Mapear questões reais para habilidades da matriz (`Hxx`).
- [ ] Gerar arquivo consolidado para consulta rápida do agente.

## Bloco 3 — Geração orientada por base real (médio prazo)
- [ ] Criar prompt-padrão para gerar questões novas por habilidade usando o banco real como referência de estilo.
- [ ] Incluir validação automática: distribuição 5/3/2 e alternativas A–E em linhas separadas.
- [ ] Incluir checklist de qualidade para detectar cópia literal de enunciados reais.

## Bloco 4 — Operação semanal (médio prazo)
- [ ] Integrar banco real ao fluxo de revisão semanal.
- [ ] Atualizar `plano/tracker.md` com campo de erro por habilidade (`Hxx`).
- [ ] Definir rotina de atualização quando novos cadernos forem adicionados ao repositório.

## Próxima sessão sugerida
1. Validar extração e corrigir regras de parsing.
2. Implementar indexação por habilidade em lote.
3. Gerar primeiro simulado de treino totalmente ancorado no banco real.
