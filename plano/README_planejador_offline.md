# Planejador Offline (sem IA)

Este módulo transforma feedback real de desempenho por habilidade em um plano semanal automático, sem inferência de LLM.

## Arquivos usados

- Configuração do motor:
  - `prompts/contexto_planejador.json` (local, não versionado)
  - base: `prompts/contexto_planejador.example.json`
- Feedback de desempenho:
  - `plano/desempenho_habilidades.csv` (local, não versionado)
  - base: `plano/desempenho_habilidades.example.csv`
- Saídas:
  - `plano/plano_semanal_gerado.md`
  - `plano/prioridades_habilidades.csv`
  - `plano/sugestoes_questoes_por_bloco.md` (quando houver mapeamento)

## Como o score é calculado

Para cada habilidade:

1. `componente_erro = 1 - acurácia_média`
2. `componente_cobertura = gap de questões feitas na semana`
3. `componente_recência = dias sem estudar (normalizado)`
4. `prioridade = peso_da_area * (0.60*erro + 0.25*cobertura + 0.15*recência) + bônus_habilidade_fixa`

Isso permite o plano reagir ao seu feedback (acertos/erros), mantendo foco em lacunas reais.

## Fluxo operacional

1. Copie o contexto:
   - `cp prompts/contexto_planejador.example.json prompts/contexto_planejador.json`
2. Copie o CSV de exemplo:
   - `cp plano/desempenho_habilidades.example.csv plano/desempenho_habilidades.csv`
3. Gere o plano:
   - `python3 scripts/gerar_plano_offline.py`
4. Estude os blocos do arquivo `plano/plano_semanal_gerado.md`.
5. Registre novo feedback e rode novamente o script.

## Cruzamento com banco real por disciplina/tema

1. Gere o mapeamento das questões reais:
   - `python3 scripts/mapear_habilidades_enem.py --banco-dir questoes/banco_reais --out-dir questoes/mapeamento_habilidades --year-from 2015 --year-to 2025`
2. Gere/recalcule o plano offline:
   - `python3 scripts/gerar_plano_offline.py`
3. Use `plano/sugestoes_questoes_por_bloco.md` para saber quais questões reais resolver em cada bloco.

## Interface PySide6 (opcional)

```bash
pip install PySide6
python3 scripts/app_planejador_pyside6.py
```

No app:

1. Registre resultado por habilidade (`acertos`, `total`, `tempo`).
2. Clique em recalcular.
3. O plano e o ranking são atualizados automaticamente.
