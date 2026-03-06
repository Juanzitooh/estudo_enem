# Tracker de Progresso

## Legenda
- [ ] Não iniciado
- [~] Em progresso
- [x] Concluído

## Objetivo
Registrar desempenho por habilidade (`Hxx`) com evidência de erro e ação prática de revisão.

## Registro (modelo operacional)
| Data | Área | Habilidade (Hxx) | Status | Acertos/Total | Erro por habilidade (Hxx) | Tipo de erro | Evidência curta | Ação de revisão | Reavaliação |
|---|---|---|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |  |  |  |

## Tipos de erro (padrão)
- `conceitual`: não dominou o conteúdo da habilidade.
- `interpretacao`: leu o comando/texto-base de forma incorreta.
- `metodo`: soube o conceito, mas errou procedimento/estratégia.
- `tempo`: acertaria com mais tempo, mas pressionou execução.

## Exemplo preenchido (local)
| Data | Área | Habilidade (Hxx) | Status | Acertos/Total | Erro por habilidade (Hxx) | Tipo de erro | Evidência curta | Ação de revisão | Reavaliação |
|---|---|---|---|---|---|---|---|---|---|
| 2026-03-06 | Ciências Humanas | H13 | [~] | 2/5 | H13 | interpretacao | confundiu comando "principalmente" em item de civilizações hidráulicas | recuperação rápida do módulo + 10 questões focadas em comando | 2026-03-09 |

## Regras de uso
1. Sempre preencher `Habilidade (Hxx)` e `Erro por habilidade (Hxx)` quando houver erro.
2. Se a linha for de manutenção sem erro, repetir a própria habilidade no campo de erro (`Hxx`) e registrar `tipo de erro = n/a`.
3. Em `Evidência curta`, descrever em 1 linha o padrão observado (sem texto longo).
4. Em `Ação de revisão`, registrar ação executável (aula rápida, aula completa, treino com quantidade).
5. Em `Reavaliação`, registrar data alvo para medir melhora na mesma habilidade.
