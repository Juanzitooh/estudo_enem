# T2.13 - Implementação do fluxo de prova oficial ENEM (ano/dia)

Data: 2026-03-06  
Status: implementado no app offline

## Escopo entregue

- Seleção de prova oficial por `ano` e `dia` no card de simulados.
- Inicialização de caderno oficial em sequência fechada (`number ASC`, `variation ASC`).
- Resolução do caderno via sessão de treino ativa.
- Conclusão da sessão com resumo de acertos/erros/acurácia.
- Bloqueio de resposta no reels enquanto prova oficial estiver em andamento (evita intervenções adaptativas durante a prova).

## Arquivos alterados

- `app_flutter/enem_offline_client/lib/src/ui/home_page.dart`
- `app_flutter/enem_offline_client/lib/src/ui/home_page_advanced_cards.dart`

## Regras implementadas

1. `Iniciar prova oficial` exige `ano` e `dia` válidos.
2. Caderno oficial não usa embaralhamento.
3. Resposta de prova oficial é registrada em `progress.answer_source='prova_oficial'`.
4. Durante prova oficial ativa, o reels não aceita respostas e orienta finalizar o caderno.
5. Ao fim da última questão, sessão é marcada como concluída por mensagem de status.

## Checklist de aceite (`T2.13`)

- [x] usuário seleciona `ano/dia`;
- [x] usuário resolve caderno em sequência fechada;
- [x] sessão conclui sem roteamento pós-erro durante a prova.

## Observação de validação local

- Não foi possível executar `flutter analyze` no ambiente do agente porque `flutter/dart` não estão no PATH desta sessão.
