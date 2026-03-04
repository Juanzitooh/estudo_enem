# Checklist de Legibilidade — Bloco 13

Data da validação: 2026-03-04

## Escopo validado
- Plataformas de layout: desktop e mobile (simulação por `surfaceSize` em widget test).
- Tema visual: `light`, `dark` e `system`.
- Escala de fonte: `1.40` (máxima, cenário de estresse para acessibilidade).
- Navegação mínima: abas `Aulas`, `Questões` e `Perfil`.

## Cenários executados
- `desktop_light_font_max` (`1366x768`, `ThemeMode.light`, brilho claro)
- `desktop_dark_font_max` (`1366x768`, `ThemeMode.dark`, brilho escuro)
- `desktop_system_font_max` (`1366x768`, `ThemeMode.system`, brilho escuro)
- `mobile_light_font_max` (`390x844`, `ThemeMode.light`, brilho claro)
- `mobile_dark_font_max` (`390x844`, `ThemeMode.dark`, brilho escuro)
- `mobile_system_font_max` (`390x844`, `ThemeMode.system`, brilho claro)

## Comando de validação
```bash
export PATH=/home/jp/tools/flutter/bin:$PATH
cd app_flutter/enem_offline_client
flutter test
```

## Resultado
- Status: **aprovado**.
- Resultado da suíte: `All tests passed!`.
- Observação: foram exibidos apenas warnings do `sqflite` sobre troca de `default factory` em ambiente de teste, sem falha funcional.

## Ajustes aplicados para aprovação
- `DropdownButtonFormField` configurados com `isExpanded: true` em telas do perfil/filtros para evitar overflow horizontal em fonte ampliada.
- Teste legado (`widget_test.dart`) atualizado para assertions compatíveis com a UI atual.
