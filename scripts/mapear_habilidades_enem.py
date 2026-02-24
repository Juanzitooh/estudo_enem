#!/usr/bin/env python3
"""Mapeia questões reais ENEM por disciplina, tema e habilidade estimada.

Classificação baseada em regras (keywords), sem IA.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import unicodedata
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path


QUESTION_HEADER_RE = re.compile(r"^## Questão\s+(\d{3})(?:\s+\(variação\s+(\d+)\))?\s*$", re.MULTILINE)


@dataclass(frozen=True)
class QuestionRaw:
    ano: int
    dia: int
    numero: int
    variacao: int
    area: str
    gabarito: str
    texto: str


@dataclass(frozen=True)
class QuestionMapped:
    ano: int
    dia: int
    numero: int
    variacao: int
    area: str
    disciplina: str
    tema_estimado: str
    habilidade_estimada: str
    confianca: str
    motivo: str
    gabarito: str
    preview: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Mapeia questões ENEM por disciplina e tema.")
    parser.add_argument(
        "--banco-dir",
        type=Path,
        default=Path("questoes/banco_reais"),
        help="Diretório do banco real por ano.",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path("questoes/mapeamento_habilidades"),
        help="Diretório de saída dos artefatos de mapeamento.",
    )
    parser.add_argument("--year-from", type=int, default=2015)
    parser.add_argument("--year-to", type=int, default=2025)
    return parser.parse_args()


def normalize_text(text: str) -> str:
    lowered = text.lower()
    normalized = unicodedata.normalize("NFD", lowered)
    normalized = "".join(ch for ch in normalized if unicodedata.category(ch) != "Mn")
    return normalized


def parse_questions_from_file(path: Path, ano: int, dia: int) -> list[QuestionRaw]:
    content = path.read_text(encoding="utf-8")
    matches = list(QUESTION_HEADER_RE.finditer(content))
    result: list[QuestionRaw] = []

    for index, match in enumerate(matches):
        numero = int(match.group(1))
        variacao = int(match.group(2)) if match.group(2) else 1
        start = match.end()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(content)
        block = content[start:end].strip()

        area_match = re.search(r"^- Área:\s*(.+)$", block, re.MULTILINE)
        gabarito_match = re.search(r"^- Gabarito:\s*(.+)$", block, re.MULTILINE)

        area = area_match.group(1).strip() if area_match else "Área não identificada"
        gabarito = gabarito_match.group(1).strip() if gabarito_match else "Não encontrado"

        cleaned_lines: list[str] = []
        for line in block.splitlines():
            stripped = line.strip()
            if not stripped:
                continue
            if stripped.startswith("- Área:"):
                continue
            if stripped.startswith("- Gabarito:"):
                continue
            cleaned_lines.append(stripped)
        texto = "\n".join(cleaned_lines)
        if not texto:
            continue

        result.append(
            QuestionRaw(
                ano=ano,
                dia=dia,
                numero=numero,
                variacao=variacao,
                area=area,
                gabarito=gabarito,
                texto=texto,
            )
        )
    return result


def build_keywords(*items: str) -> tuple[str, ...]:
    return tuple(items)


NATURE_DISCIPLINE_KEYWORDS: dict[str, tuple[str, ...]] = {
    "Física": build_keywords(
        "velocidade",
        "aceleracao",
        "forca",
        "energia",
        "potencia",
        "circuito",
        "corrente",
        "tensao",
        "resistencia",
        "frequencia",
        "onda",
        "optica",
        "espelho",
        "lente",
        "calor",
        "termodinamica",
        "pressao",
        "gravidade",
    ),
    "Química": build_keywords(
        "mol",
        "mols",
        "acido",
        "base",
        "ph",
        "reacao",
        "oxidacao",
        "reducao",
        "elemento",
        "atomo",
        "molecula",
        "substancia",
        "solucao",
        "solvente",
        "soluto",
        "ligacao quimica",
        "hidrocarboneto",
        "equilibrio quimico",
    ),
    "Biologia": build_keywords(
        "celula",
        "dna",
        "rna",
        "gene",
        "genetica",
        "organismo",
        "especie",
        "ecossistema",
        "bioma",
        "fotossintese",
        "evolucao",
        "enzima",
        "bacteria",
        "virus",
        "fisiologia",
        "metabolismo",
    ),
}


HUMAN_DISCIPLINE_KEYWORDS: dict[str, tuple[str, ...]] = {
    "História": build_keywords(
        "seculo",
        "imperio",
        "colonia",
        "revolucao",
        "guerra",
        "escrav",
        "ditadura",
        "republica",
        "idade media",
        "renascimento",
        "industrializacao",
        "primeira guerra",
        "segunda guerra",
        "era vargas",
    ),
    "Geografia": build_keywords(
        "territorio",
        "fronteira",
        "paisagem",
        "clima",
        "relevo",
        "bacia",
        "cartograf",
        "latitude",
        "longitude",
        "urbanizacao",
        "migracao",
        "demograf",
        "bioma",
        "geopolitica",
        "espaco geografico",
    ),
    "Filosofia": build_keywords(
        "etica",
        "moral",
        "razao",
        "conhecimento",
        "verdade",
        "filosofo",
        "metafisica",
        "epistemologia",
        "aristoteles",
        "platao",
        "kant",
        "descartes",
        "socrates",
        "nietzsche",
    ),
    "Sociologia": build_keywords(
        "sociedade",
        "classe social",
        "desigualdade",
        "movimento social",
        "cidadania",
        "cultura",
        "trabalho",
        "identidade",
        "preconceito",
        "socializacao",
        "consumo",
        "genero",
    ),
}


LANG_DISCIPLINE_KEYWORDS: dict[str, tuple[str, ...]] = {
    "Literatura": build_keywords(
        "poema",
        "poetico",
        "romance",
        "conto",
        "personagem",
        "narrador",
        "eu lirico",
        "modernismo",
        "romantismo",
        "barroco",
        "arcadismo",
        "realismo",
        "naturalismo",
    ),
    "Língua Portuguesa": build_keywords(
        "coesao",
        "coerencia",
        "conectivo",
        "funcao da linguagem",
        "genero textual",
        "variacao linguistica",
        "norma padrao",
        "pronome",
        "verbo",
        "sintaxe",
        "argumentativo",
        "interlocucao",
    ),
    "Artes e Comunicação": build_keywords(
        "fotografia",
        "pintura",
        "cinema",
        "musica",
        "teatro",
        "linguagem corporal",
        "midia",
        "publicidade",
        "tecnologia da comunicacao",
        "arte",
    ),
}


MATH_THEME_KEYWORDS: dict[str, tuple[str, ...]] = {
    "Aritmética e Proporções": build_keywords(
        "porcentagem",
        "percentual",
        "razao",
        "proporcao",
        "juros",
        "fracao",
        "escala",
        "regra de tres",
    ),
    "Geometria": build_keywords(
        "triangulo",
        "angulo",
        "circulo",
        "esfera",
        "perimetro",
        "area",
        "volume",
        "poligono",
        "distancia",
    ),
    "Álgebra e Funções": build_keywords(
        "funcao",
        "equacao",
        "inequacao",
        "grafico",
        "variavel",
        "sistema linear",
        "polinomio",
        "expoente",
        "logaritmo",
    ),
    "Estatística e Probabilidade": build_keywords(
        "probabilidade",
        "amostra",
        "frequencia",
        "media",
        "mediana",
        "desvio",
        "tabela",
        "combinatoria",
        "chance",
    ),
}


DISCIPLINE_TO_THEME_KEYWORDS: dict[str, dict[str, tuple[str, ...]]] = {
    "Física": {
        "Mecânica": build_keywords("velocidade", "aceleracao", "forca", "movimento", "trabalho"),
        "Termologia": build_keywords("calor", "temperatura", "termodinamica"),
        "Eletricidade e Magnetismo": build_keywords("circuito", "corrente", "tensao", "resistencia"),
        "Ondulatória e Óptica": build_keywords("onda", "frequencia", "luz", "lente", "espelho"),
    },
    "Química": {
        "Química Geral": build_keywords("atomo", "molecula", "elemento", "ligacao", "substancia"),
        "Físico-Química": build_keywords("ph", "equilibrio", "entalpia", "energia", "velocidade de reacao"),
        "Química Orgânica": build_keywords("hidrocarboneto", "funcao organica", "alcool", "acido carboxilico"),
        "Química Ambiental": build_keywords("poluente", "tratamento", "reciclagem", "impacto ambiental"),
    },
    "Biologia": {
        "Ecologia": build_keywords("ecossistema", "bioma", "cadeia alimentar", "biodiversidade"),
        "Genética e Evolução": build_keywords("dna", "gene", "genetica", "heranca", "evolucao"),
        "Fisiologia e Saúde": build_keywords("organismo", "fisiologia", "sistema", "saude", "doenca"),
        "Citologia e Bioquímica": build_keywords("celula", "enzima", "metabolismo", "organelas"),
    },
    "História": {
        "História do Brasil": build_keywords("brasil", "vargas", "ditadura", "escrav", "republica"),
        "História Geral": build_keywords("imperio", "revolucao", "guerra", "idade media"),
        "História Cultural": build_keywords("patrimonio", "memoria", "manifestacao cultural"),
    },
    "Geografia": {
        "Geografia Humana": build_keywords("urbanizacao", "migracao", "demograf", "populacao"),
        "Geografia Física": build_keywords("clima", "relevo", "bacia", "solo", "bioma"),
        "Geopolítica": build_keywords("fronteira", "territorio", "nacao", "geopolitica"),
    },
    "Filosofia": {
        "Ética e Política": build_keywords("etica", "moral", "justica", "politica"),
        "Teoria do Conhecimento": build_keywords("conhecimento", "razao", "verdade", "epistemologia"),
    },
    "Sociologia": {
        "Estrutura Social": build_keywords("classe social", "desigualdade", "estratificacao"),
        "Cultura e Identidade": build_keywords("cultura", "identidade", "preconceito"),
        "Cidadania e Trabalho": build_keywords("cidadania", "trabalho", "movimento social"),
    },
    "Língua Portuguesa": {
        "Interpretação Textual": build_keywords("texto", "sentido", "inferir", "interpreta"),
        "Linguagem e Argumentação": build_keywords("argument", "tese", "convencimento", "interlocucao"),
        "Gramática e Variação": build_keywords("norma padrao", "variacao linguistica", "pronome", "sintaxe"),
    },
    "Literatura": {
        "Leitura Literária": build_keywords("poema", "personagem", "narrador", "eu lirico"),
        "Escolas Literárias": build_keywords("modernismo", "romantismo", "barroco", "realismo"),
    },
    "Inglês": {
        "Interpretação em Língua Estrangeira": build_keywords("text", "english", "reading", "author"),
    },
    "Espanhol": {
        "Interpretação em Língua Estrangeira": build_keywords("texto", "espanol", "autor", "lectura"),
    },
    "Língua Estrangeira": {
        "Interpretação em Língua Estrangeira": build_keywords("texto", "idioma", "interpreta"),
    },
    "Artes e Comunicação": {
        "Arte e Mídia": build_keywords("arte", "cinema", "musica", "publicidade", "midia"),
    },
    "Matemática": MATH_THEME_KEYWORDS,
}


def keyword_score(text_normalized: str, keywords: tuple[str, ...]) -> int:
    return sum(text_normalized.count(term) for term in keywords)


def choose_from_keywords(
    text_normalized: str,
    candidates: dict[str, tuple[str, ...]],
    fallback: str,
) -> tuple[str, int]:
    best_name = fallback
    best_score = 0
    for name, keywords in candidates.items():
        score = keyword_score(text_normalized, keywords)
        if score > best_score:
            best_score = score
            best_name = name
    return best_name, best_score


def detect_foreign_language(text_normalized: str) -> tuple[str, int]:
    english_markers = (
        " the ",
        " and ",
        " with ",
        " from ",
        " this ",
        " that ",
        " for ",
        " are ",
        " was ",
        " were ",
    )
    spanish_markers = (
        " el ",
        " la ",
        " los ",
        " las ",
        " pero ",
        " que ",
        " con ",
        " para ",
        " una ",
        " del ",
    )

    padded = f" {text_normalized} "
    english_score = sum(padded.count(marker) for marker in english_markers)
    spanish_score = sum(padded.count(marker) for marker in spanish_markers)

    if english_score >= spanish_score + 2 and english_score > 0:
        return ("Inglês", english_score)
    if spanish_score >= english_score + 2 and spanish_score > 0:
        return ("Espanhol", spanish_score)
    return ("Língua Estrangeira", max(english_score, spanish_score))


def classify_discipline(question: QuestionRaw) -> tuple[str, int, str]:
    area = question.area
    text_norm = normalize_text(question.texto)

    if area == "Matemática":
        return ("Matemática", 10, "Área Matemática")

    if area == "Ciências da Natureza":
        discipline, score = choose_from_keywords(
            text_norm,
            NATURE_DISCIPLINE_KEYWORDS,
            "Ciências da Natureza (geral)",
        )
        if score == 0:
            return (discipline, 1, "Fallback por área")
        return (discipline, score, "Keywords de Ciências da Natureza")

    if area == "Ciências Humanas":
        discipline, score = choose_from_keywords(
            text_norm,
            HUMAN_DISCIPLINE_KEYWORDS,
            "Ciências Humanas (geral)",
        )
        if score == 0:
            return (discipline, 1, "Fallback por área")
        return (discipline, score, "Keywords de Ciências Humanas")

    if area == "Linguagens":
        if question.dia == 1 and question.numero <= 5:
            foreign_discipline, foreign_score = detect_foreign_language(text_norm)
            return (
                foreign_discipline,
                max(2, foreign_score),
                "Faixa de idioma + detecção textual",
            )

        discipline, score = choose_from_keywords(
            text_norm,
            LANG_DISCIPLINE_KEYWORDS,
            "Língua Portuguesa",
        )
        if score == 0:
            return ("Língua Portuguesa", 1, "Fallback por área")
        return (discipline, score, "Keywords de Linguagens")

    return ("Área não identificada", 0, "Área ausente")


def classify_theme(discipline: str, text: str) -> tuple[str, int]:
    text_norm = normalize_text(text)
    candidates = DISCIPLINE_TO_THEME_KEYWORDS.get(discipline, {})
    if not candidates:
        return ("Tema geral", 0)
    theme, score = choose_from_keywords(text_norm, candidates, "Tema geral")
    return (theme, score)


def estimate_skill(area: str, discipline: str, theme: str) -> tuple[str, str]:
    if area == "Matemática":
        mapping = {
            "Aritmética e Proporções": "H3",
            "Geometria": "H8",
            "Álgebra e Funções": "H21",
            "Estatística e Probabilidade": "H28",
            "Tema geral": "H21",
        }
        return (mapping.get(theme, "H21"), "média")

    if area == "Ciências da Natureza":
        if discipline == "Física":
            return ("H21", "média")
        if discipline == "Química":
            return ("H25", "média")
        if discipline == "Biologia":
            return ("H30", "média")
        return ("H19", "baixa")

    if area == "Ciências Humanas":
        if discipline == "História":
            return ("H14", "baixa")
        if discipline == "Geografia":
            return ("H27", "baixa")
        if discipline == "Filosofia":
            return ("H23", "baixa")
        if discipline == "Sociologia":
            return ("H24", "baixa")
        return ("H15", "baixa")

    if area == "Linguagens":
        if discipline in {"Inglês", "Espanhol", "Língua Estrangeira"}:
            return ("H6", "média")
        if discipline == "Literatura":
            return ("H16", "média")
        if discipline == "Língua Portuguesa":
            if theme == "Gramática e Variação":
                return ("H26", "média")
            if theme == "Linguagem e Argumentação":
                return ("H23", "média")
            return ("H18", "média")
        if discipline == "Artes e Comunicação":
            return ("H13", "baixa")
        return ("H18", "baixa")

    return ("N/A", "baixa")


def confidence_from_scores(
    discipline_score: int,
    theme_score: int,
    skill_confidence: str,
) -> str:
    base = 0
    if discipline_score >= 5:
        base += 2
    elif discipline_score >= 2:
        base += 1

    if theme_score >= 3:
        base += 2
    elif theme_score >= 1:
        base += 1

    if skill_confidence == "média":
        base += 1

    if base >= 4:
        return "alta"
    if base >= 2:
        return "média"
    return "baixa"


def preview_text(text: str, max_len: int = 120) -> str:
    single_line = " ".join(text.splitlines())
    if len(single_line) <= max_len:
        return single_line
    return single_line[: max_len - 3].rstrip() + "..."


def map_question(question: QuestionRaw) -> QuestionMapped:
    discipline, discipline_score, discipline_reason = classify_discipline(question)
    theme, theme_score = classify_theme(discipline, question.texto)
    skill, skill_confidence = estimate_skill(question.area, discipline, theme)
    confidence = confidence_from_scores(
        discipline_score=discipline_score,
        theme_score=theme_score,
        skill_confidence=skill_confidence,
    )

    reason = (
        f"{discipline_reason}; score_disciplina={discipline_score}; "
        f"score_tema={theme_score}; skill={skill}({skill_confidence})"
    )

    return QuestionMapped(
        ano=question.ano,
        dia=question.dia,
        numero=question.numero,
        variacao=question.variacao,
        area=question.area,
        disciplina=discipline,
        tema_estimado=theme,
        habilidade_estimada=skill,
        confianca=confidence,
        motivo=reason,
        gabarito=question.gabarito,
        preview=preview_text(question.texto),
    )


def load_all_questions(banco_dir: Path, year_from: int, year_to: int) -> list[QuestionRaw]:
    questions: list[QuestionRaw] = []
    for ano in range(year_from, year_to + 1):
        year_dir = banco_dir / f"enem_{ano}"
        if not year_dir.exists():
            continue
        for dia in (1, 2):
            file_path = year_dir / f"dia{dia}_questoes_reais.md"
            if not file_path.exists():
                continue
            questions.extend(parse_questions_from_file(file_path, ano=ano, dia=dia))
    return questions


def write_jsonl(path: Path, mapped_questions: list[QuestionMapped]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as file_obj:
        for item in mapped_questions:
            file_obj.write(json.dumps(item.__dict__, ensure_ascii=False) + "\n")


def write_csv(path: Path, mapped_questions: list[QuestionMapped]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "ano",
        "dia",
        "numero",
        "variacao",
        "area",
        "disciplina",
        "tema_estimado",
        "habilidade_estimada",
        "confianca",
        "motivo",
        "gabarito",
        "preview",
    ]
    with path.open("w", encoding="utf-8", newline="") as file_obj:
        writer = csv.DictWriter(file_obj, fieldnames=fieldnames)
        writer.writeheader()
        for item in mapped_questions:
            writer.writerow(item.__dict__)


def write_summary(path: Path, mapped_questions: list[QuestionMapped]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    by_discipline = Counter(item.disciplina for item in mapped_questions)
    by_theme = Counter((item.disciplina, item.tema_estimado) for item in mapped_questions)
    by_confidence = Counter(item.confianca for item in mapped_questions)

    lines: list[str] = []
    lines.append("# Resumo do Mapeamento")
    lines.append("")
    lines.append(f"- Total de questões mapeadas: **{len(mapped_questions)}**")
    lines.append(
        "- Confiança: "
        + ", ".join(f"{key}={value}" for key, value in sorted(by_confidence.items()))
    )
    lines.append("")

    lines.append("## Questões por disciplina")
    lines.append("")
    lines.append("| Disciplina | Quantidade |")
    lines.append("|---|---:|")
    for discipline, qty in by_discipline.most_common():
        lines.append(f"| {discipline} | {qty} |")
    lines.append("")

    lines.append("## Temas mais recorrentes (top 40)")
    lines.append("")
    lines.append("| Disciplina | Tema | Quantidade |")
    lines.append("|---|---|---:|")
    for (discipline, theme), qty in by_theme.most_common(40):
        lines.append(f"| {discipline} | {theme} | {qty} |")
    lines.append("")

    path.write_text("\n".join(lines), encoding="utf-8")


def write_review_pending(path: Path, mapped_questions: list[QuestionMapped]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pending = [item for item in mapped_questions if item.confianca == "baixa"]
    pending.sort(key=lambda item: (item.ano, item.dia, item.numero, item.variacao))

    lines: list[str] = []
    lines.append("# Revisão Pendente (baixa confiança)")
    lines.append("")
    lines.append(f"- Itens pendentes: **{len(pending)}**")
    lines.append("")
    lines.append("| Ano | Dia | Questão | Área | Disciplina | Tema | Habilidade estimada | Motivo |")
    lines.append("|---:|---:|---:|---|---|---|---|---|")

    for item in pending:
        lines.append(
            "| {ano} | {dia} | {questao:03d} | {area} | {disciplina} | {tema} | {habilidade} | {motivo} |".format(
                ano=item.ano,
                dia=item.dia,
                questao=item.numero,
                area=item.area,
                disciplina=item.disciplina,
                tema=item.tema_estimado,
                habilidade=item.habilidade_estimada,
                motivo=item.motivo.replace("|", "/"),
            )
        )

    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def slugify(value: str) -> str:
    value = normalize_text(value)
    value = re.sub(r"[^a-z0-9]+", "_", value).strip("_")
    return value or "sem_nome"


def write_discipline_files(base_dir: Path, mapped_questions: list[QuestionMapped]) -> None:
    target_dir = base_dir / "por_disciplina"
    target_dir.mkdir(parents=True, exist_ok=True)

    grouped: dict[str, list[QuestionMapped]] = defaultdict(list)
    for item in mapped_questions:
        grouped[item.disciplina].append(item)

    for discipline, items in grouped.items():
        items.sort(key=lambda item: (item.ano, item.dia, item.numero, item.variacao))
        file_name = f"{slugify(discipline)}.md"
        path = target_dir / file_name

        lines: list[str] = []
        lines.append(f"# Banco por Disciplina — {discipline}")
        lines.append("")
        lines.append(f"- Total de questões: **{len(items)}**")
        lines.append("")
        lines.append("| Ano | Dia | Questão | Área | Tema | Habilidade estimada | Confiança | Preview |")
        lines.append("|---:|---:|---:|---|---|---|---|---|")

        for item in items:
            lines.append(
                "| {ano} | {dia} | {questao:03d} | {area} | {tema} | {habilidade} | {conf} | {preview} |".format(
                    ano=item.ano,
                    dia=item.dia,
                    questao=item.numero,
                    area=item.area,
                    tema=item.tema_estimado,
                    habilidade=item.habilidade_estimada,
                    conf=item.confianca,
                    preview=item.preview.replace("|", "/"),
                )
            )
        lines.append("")
        path.write_text("\n".join(lines), encoding="utf-8")


def write_requested_disciplines_summary(path: Path, mapped_questions: list[QuestionMapped]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    by_discipline = Counter(item.disciplina for item in mapped_questions)

    requested = [
        "Língua Portuguesa",
        "Literatura",
        "Inglês",
        "Espanhol",
        "História",
        "Geografia",
        "Filosofia",
        "Sociologia",
        "Física",
        "Química",
        "Biologia",
        "Matemática",
    ]

    lines: list[str] = []
    lines.append("# Resumo por Matérias-Chave")
    lines.append("")
    lines.append("Separação das questões nas disciplinas pedidas para estudo por matéria.")
    lines.append("")
    lines.append("| Disciplina | Quantidade | Arquivo |")
    lines.append("|---|---:|---|")

    for discipline in requested:
        qty = by_discipline.get(discipline, 0)
        file_name = f"por_disciplina/{slugify(discipline)}.md"
        lines.append(f"| {discipline} | {qty} | `{file_name}` |")

    lines.append("")
    lines.append("## Observações")
    lines.append("")
    lines.append("- Algumas questões podem cair em categorias gerais quando o texto não dá evidência forte.")
    lines.append("- Confira também: `resumo_por_disciplina_tema.md` e `revisao_pendente.md`.")
    lines.append("")

    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    args = parse_args()
    questions = load_all_questions(
        banco_dir=args.banco_dir,
        year_from=args.year_from,
        year_to=args.year_to,
    )

    if not questions:
        raise FileNotFoundError("Nenhuma questão encontrada no intervalo informado.")

    mapped = [map_question(question) for question in questions]
    mapped.sort(key=lambda item: (item.ano, item.dia, item.numero, item.variacao))

    out_dir = args.out_dir
    write_jsonl(out_dir / "questoes_mapeadas.jsonl", mapped)
    write_csv(out_dir / "questoes_mapeadas.csv", mapped)
    write_summary(out_dir / "resumo_por_disciplina_tema.md", mapped)
    write_requested_disciplines_summary(
        out_dir / "resumo_materias_chave.md",
        mapped,
    )
    write_review_pending(out_dir / "revisao_pendente.md", mapped)
    write_discipline_files(out_dir, mapped)

    print(f"[ok] questões lidas: {len(questions)}")
    print(f"[ok] questões mapeadas: {len(mapped)}")
    print(f"[ok] saída: {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
