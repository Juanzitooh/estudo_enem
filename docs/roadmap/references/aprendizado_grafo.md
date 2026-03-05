# Canvas de Arquitetura – Sistema de Estudo ENEM Baseado em Grafo de Conhecimento

## 1. Objetivo do Sistema

Criar uma plataforma de estudo offline-first para o ENEM baseada em:

* feed contínuo de questões (estilo reels)
* diagnóstico automático de lacunas de conhecimento
* grafo de conceitos interdisciplinares
* micro‑módulos de aprendizado

O sistema deve funcionar **100% offline no cliente Flutter**, consumindo apenas arquivos estruturados gerados previamente.

---

# 2. Princípio Pedagógico

Questões do ENEM não dependem apenas de uma disciplina, mas de uma combinação de conceitos.

Exemplo:

Questão: queda de uma bola de boliche de um prédio.

Conceitos envolvidos:

* física: queda livre
* física: MRUV
* matemática: manipulação algébrica
* interpretação de texto

Logo:

```
questão → conjunto de conceitos
```

---

# 3. Estrutura Central: Grafo de Conhecimento

## Tipos de nós

### Conceitos

Exemplos:

* queda_livre
* MRUV
* energia_potencial
* equacao_segundo_grau
* interpretacao_enunciado

### Questões

Cada questão aponta para múltiplos conceitos.

### Módulos de Aprendizado

Micro‑conteúdo para recuperar conhecimento:

* explicação curta
* exemplo resolvido
* exercício simples

---

# 4. Q‑Matrix

Tabela que relaciona questões aos conceitos necessários.

Exemplo:

| Questão | Queda Livre | MRUV | Álgebra | Interpretação |
| ------- | ----------- | ---- | ------- | ------------- |
| Q1      | 1           | 1    | 1       | 1             |
| Q2      | 0           | 1    | 1       | 0             |
| Q3      | 1           | 0    | 0       | 1             |

Onde:

```
1 = conceito necessário
0 = não necessário
```

---

# 5. Estrutura do Grafo

Dependências entre conceitos:

```
MRUV
  ├── velocidade_media
  ├── aceleracao
  └── queda_livre
```

Exemplo em matemática:

```
equacoes
  ├── isolamento
  ├── fracoes
  └── potencia
```

---

# 6. Fluxo de Interação do Usuário

```
questão
↓
resposta
↓
acerto / erro
↓
atualiza domínio de conceitos
↓
seleciona próxima questão
```

Se domínio baixo:

```
conceito fraco
↓
mostrar micro aula
↓
nova questão
```

---

# 7. Diagnóstico Pós‑Erro

Após erro o sistema faz perguntas rápidas para identificar a causa.

Exemplo:

Pergunta 1:

"A aceleração na queda livre é constante?"

Pergunta 2:

"Você sabe isolar a variável t na equação?"

Pergunta 3:

"Você entendeu o que o enunciado pede?"

Cada resposta atualiza a probabilidade de domínio do conceito.

---

# 8. Knowledge Tracing Simplificado

Cada conceito possui um valor entre 0 e 1.

Exemplo:

```
queda_livre = 0.4
MRUV = 0.7
algebra = 0.8
```

Após resposta:

acerto:

```
conceito += 0.1
```

erro:

```
conceito -= 0.1
```

---

# 9. Estrutura de Dados (JSON)

## questions.json

```
{
  "id": "enem_2019_q45",
  "concepts": [
    "queda_livre",
    "MRUV",
    "algebra_isolamento"
  ]
}
```

## concepts.json

```
{
  "id": "queda_livre",
  "depends_on": ["MRUV"],
  "difficulty": 2
}
```

## lessons.json

```
{
  "concept": "queda_livre",
  "explanation": "Em queda livre a aceleração é constante...",
  "example": "Uma pedra é solta de 20m...",
  "exercise": "Calcule o tempo de queda..."
}
```

---

# 10. Estrutura de Pastas

```
content/
 ├── questions.json
 ├── concepts.json
 ├── lessons.json
 ├── dependencies.json
 ├── diagnostic_questions.json
```

---

# 11. Pipeline de Geração de Conteúdo

O conteúdo é gerado offline.

```
IA gera
↓
questões
↓
conceitos envolvidos
↓
micro aulas
↓
validação humana
↓
export JSON
↓
app Flutter offline
```

Python pode automatizar:

* geração
* verificação
* empacotamento

---

# 12. Estrutura de Nível Cognitivo

Baseado na taxonomia de Bloom.

Exemplo:

```
conceito: queda_livre
nível: aplicação
```

Tipos possíveis:

* lembrar
* entender
* aplicar
* analisar

---

# 13. Feed Estilo Reels

O app apresenta uma sequência infinita de questões.

```
questão
↓
resposta
↓
feedback imediato
↓
próxima questão
```

Seleção baseada em:

* conceitos fracos
* dificuldade
* mistura com questões reais

---

# 14. Fontes de Questões

Mistura de:

* provas reais do ENEM
* questões sintéticas geradas por IA

Todas passam por:

```
validação humana
```

---

# 15. Objetivo Final

Construir um sistema de aprendizado adaptativo offline que:

* identifica lacunas conceituais
* direciona estudo automaticamente
* reduz tempo de estudo
* melhora desempenho em provas complexas como o ENEM.
