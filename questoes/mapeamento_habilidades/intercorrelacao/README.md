# Intercorrelacao Modulo x Questao

Camada de vinculo entre:
- modulos do livro (`plano/indice_livros_6_volumes.csv`);
- questoes reais mapeadas (`questoes/mapeamento_habilidades/questoes_mapeadas.csv`).

## Gerar

```bash
python3 scripts/gerar_intercorrelacao_modulo_questao.py
```

Saidas:
- `modulo_questao_matches.csv`
- `resumo_modulo_questao_matches.md`

## Taxonomia

- `tags_assunto_canonicas.csv`: tags canônicas por area/disciplina com sinonimos.

## Campos do `modulo_questao_matches.csv`

- `ano`, `dia`, `numero`, `variacao`: identificadores da questao.
- `area`, `disciplina`: metadados da questao.
- `materia`, `volume`, `modulo`: destino pedagogico no livro.
- `competencias`, `habilidades`: tags do modulo (extraidas do campo `habilidades` do livro).
- `assuntos_match`: tags/keywords que sustentam o vinculo.
- `score_match`: score continuo de aderencia (0 a 1).
- `tipo_match`: `direto`, `relacionado` ou `interdisciplinar`.
- `confianca`: `alta`, `media` ou `baixa`.
- `revisado_manual`: flag para controle futuro de curadoria humana.
