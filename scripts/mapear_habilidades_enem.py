#!/usr/bin/env python3
"""Mapeia questões reais ENEM por disciplina, tema e habilidade estimada.

Classificação baseada em regras (keywords), sem IA.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import re
import unicodedata
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path


QUESTION_HEADER_RE = re.compile(r"^## Questão\s+(\d{3})(?:\s+\(variação\s+(\d+)\))?\s*$", re.MULTILINE)
CONTROL_CHAR_PATTERN = re.compile(r"[\x00-\x08\x0B-\x1F\x7F]")
REPEATED_ENEM_BANNER_PATTERN = re.compile(r"(?:\bENEM\s*\d{4}\b[\s|]*){2,}", re.IGNORECASE)
IMAGE_MARKER_RE = re.compile(
    r"\b("
    r"figura|grafico|tabela|imagem|esquema|diagrama|mapa|charge|tirinha|cartum|"
    r"infografico|ilustracao|desenho|foto|quadrinho|projecao"
    r")s?\b"
)
MATRIX_COMPETENCE_RE = re.compile(r"^###\s+Compet[eê]ncia de área\s+(\d+)\s*[-–]\s*(.+)$", re.IGNORECASE)
MATRIX_SKILL_RE = re.compile(r"^- \*\*H(\d{1,2})\*\*:\s*(.+)$")
TOKEN_RE = re.compile(r"[a-z]{3,}")


@dataclass(frozen=True)
class QuestionRaw:
    ano: int
    dia: int
    numero: int
    variacao: int
    area: str
    gabarito: str
    texto: str
    texto_vazio: bool


@dataclass(frozen=True)
class QuestionMapped:
    ano: int
    dia: int
    numero: int
    variacao: int
    area: str
    disciplina: str
    competencia_estimada: str
    tema_estimado: str
    habilidade_estimada: str
    confianca: str
    motivo: str
    tem_imagem: bool
    texto_vazio: bool
    fallback_image_paths: tuple[str, ...]
    gabarito: str
    preview: str


@dataclass(frozen=True)
class ManualOverride:
    ano: int
    dia: int
    numero: int
    variacao: int
    preview_match: str
    disciplina: str
    competencia_estimada: str
    tema_estimado: str
    habilidade_estimada: str
    confianca: str
    motivo_curto: str
    lote: str


@dataclass(frozen=True)
class MatrixSkill:
    area: str
    competencia_num: int
    competencia_codigo: str
    competencia_descricao: str
    habilidade_num: int
    habilidade_codigo: str
    habilidade_descricao: str
    keywords: tuple[str, ...]


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
    parser.add_argument(
        "--matrix-dir",
        type=Path,
        default=Path("matriz/habilidades_por_area"),
        help="Diretório com arquivos da matriz por área.",
    )
    parser.add_argument("--year-from", type=int, default=2015)
    parser.add_argument("--year-to", type=int, default=2025)
    parser.add_argument(
        "--manual-overrides",
        type=Path,
        default=Path("questoes/mapeamento_habilidades/revisao_manual/overrides.csv"),
        help="CSV de revisões manuais para sobrescrever classificação automática.",
    )
    parser.add_argument(
        "--apply-manual-overrides",
        action="store_true",
        help="Aplica o arquivo de overrides manuais após a classificação automática.",
    )
    return parser.parse_args()


def normalize_text(text: str) -> str:
    lowered = text.lower()
    normalized = unicodedata.normalize("NFD", lowered)
    normalized = "".join(ch for ch in normalized if unicodedata.category(ch) != "Mn")
    return normalized


def sanitize_ocr_line(raw_line: str) -> str:
    line = raw_line.replace("\uFFFD", "")
    line = CONTROL_CHAR_PATTERN.sub(" ", line)
    line = REPEATED_ENEM_BANNER_PATTERN.sub(" ", line)
    line = re.sub(r"\s{2,}", " ", line)
    return line.strip()


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

        area = sanitize_ocr_line(area_match.group(1)) if area_match else "Área não identificada"
        gabarito = sanitize_ocr_line(gabarito_match.group(1)) if gabarito_match else "Não encontrado"

        cleaned_lines: list[str] = []
        for line in block.splitlines():
            stripped = sanitize_ocr_line(line)
            if not stripped:
                continue
            if stripped.startswith("- Área:"):
                continue
            if stripped.startswith("- Gabarito:"):
                continue
            cleaned_lines.append(stripped)
        texto = "\n".join(cleaned_lines)
        texto_vazio = not bool(texto.strip())

        result.append(
            QuestionRaw(
                ano=ano,
                dia=dia,
                numero=numero,
                variacao=variacao,
                area=area,
                gabarito=gabarito,
                texto=texto,
                texto_vazio=texto_vazio,
            )
        )
    return result


def load_fallback_image_index(
    banco_dir: Path,
    year_from: int,
    year_to: int,
) -> dict[tuple[int, int, int, int], tuple[str, ...]]:
    grouped: dict[tuple[int, int, int, int], list[tuple[int, str]]] = defaultdict(list)

    for ano in range(year_from, year_to + 1):
        for dia in (1, 2):
            manifest_path = (
                banco_dir
                / f"enem_{ano}"
                / f"dia{dia}_questoes_vazias_imagens"
                / "manifest.csv"
            )
            if not manifest_path.exists():
                continue

            with manifest_path.open("r", encoding="utf-8", newline="") as file_obj:
                reader = csv.DictReader(file_obj)
                for row in reader:
                    try:
                        numero = int(row.get("numero", "0") or 0)
                        variacao = int(row.get("variacao", "1") or 1)
                        parte = int(row.get("parte", "1") or 1)
                    except ValueError:
                        continue

                    image_path = (row.get("image_path") or "").strip().replace("\\", "/")
                    if numero <= 0 or variacao <= 0 or not image_path:
                        continue

                    key = (ano, dia, numero, variacao)
                    grouped[key].append((parte, image_path))

    result: dict[tuple[int, int, int, int], tuple[str, ...]] = {}
    for key, rows in grouped.items():
        ordered = [path for _, path in sorted(rows, key=lambda item: (item[0], item[1]))]
        deduped = tuple(dict.fromkeys(ordered))
        if deduped:
            result[key] = deduped
    return result


def build_keywords(*items: str) -> tuple[str, ...]:
    return tuple(items)


AREA_MATRIX_FILES: dict[str, str] = {
    "Linguagens": "linguagens.md",
    "Ciências Humanas": "humanas.md",
    "Ciências da Natureza": "natureza.md",
    "Matemática": "matematica.md",
}


# Palavras muito genéricas para aproximar semântica das habilidades.
MATRIX_STOPWORDS = {
    "para",
    "com",
    "como",
    "entre",
    "sobre",
    "pelos",
    "pelas",
    "pelo",
    "pela",
    "das",
    "dos",
    "que",
    "uma",
    "uns",
    "uma",
    "mais",
    "menos",
    "este",
    "esta",
    "esse",
    "essa",
    "sao",
    "ser",
    "sendo",
    "seus",
    "suas",
    "seu",
    "sua",
    "processo",
    "processos",
    "problema",
    "problemas",
    "situacao",
    "situacoes",
    "utilizar",
    "utilizacao",
    "identificar",
    "analisar",
    "reconhecer",
    "avaliar",
    "relacionar",
    "compreender",
    "construir",
    "conhecimentos",
    "conhecimento",
    "diferentes",
    "realidade",
    "sociais",
    "sociedade",
    "vida",
    "humana",
    "humanas",
    "contexto",
    "contextos",
    "tecnologias",
    "tecnologica",
    "tecnologico",
    "cientificas",
    "cientifico",
}


def build_range(*intervals: tuple[int, int]) -> set[int]:
    result: set[int] = set()
    for start, end in intervals:
        result.update(range(start, end + 1))
    return result


DISCIPLINE_SKILL_HINTS: dict[str, dict[str, set[int]]] = {
    "Linguagens": {
        "Inglês": build_range((5, 8)),
        "Espanhol": build_range((5, 8)),
        "Língua Estrangeira": build_range((5, 8)),
        "Artes e Comunicação": build_range((12, 14)),
        "Literatura": build_range((15, 17)),
        "Língua Portuguesa": build_range((18, 30)),
    },
    "Ciências Humanas": {
        "História": build_range((1, 5), (11, 15), (21, 25)),
        "Geografia": build_range((6, 10), (16, 20), (26, 30)),
        "Filosofia": {15, 23, 24, 25},
        "Sociologia": {10, 13, 20, 22, 24, 25},
    },
    "Ciências da Natureza": {
        "Física": build_range((1, 7), (17, 23)),
        "Química": build_range((8, 12), (17, 19), (24, 27)),
        "Biologia": build_range((8, 16), (17, 19), (28, 30)),
    },
    "Matemática": {
        "Matemática": build_range((1, 30)),
    },
}


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


def extract_tokens(text: str) -> list[str]:
    normalized = normalize_text(text)
    tokens = TOKEN_RE.findall(normalized)
    result: list[str] = []
    for token in tokens:
        if token in MATRIX_STOPWORDS:
            continue
        if len(token) < 4 and token != "lem":
            continue
        result.append(token)
    return result


def parse_matrix_file(path: Path, area: str) -> list[MatrixSkill]:
    if not path.exists():
        return []

    skills: list[MatrixSkill] = []
    competence_num: int | None = None
    competence_desc = ""

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line:
            continue

        competence_match = MATRIX_COMPETENCE_RE.match(line)
        if competence_match:
            competence_num = int(competence_match.group(1))
            competence_desc = competence_match.group(2).strip().rstrip(".")
            continue

        skill_match = MATRIX_SKILL_RE.match(line)
        if not skill_match or competence_num is None:
            continue

        habilidade_num = int(skill_match.group(1))
        habilidade_desc = skill_match.group(2).strip().rstrip(".")
        keywords = extract_tokens(f"{competence_desc} {habilidade_desc}")
        skills.append(
            MatrixSkill(
                area=area,
                competencia_num=competence_num,
                competencia_codigo=f"C{competence_num}",
                competencia_descricao=competence_desc,
                habilidade_num=habilidade_num,
                habilidade_codigo=f"H{habilidade_num}",
                habilidade_descricao=habilidade_desc,
                keywords=tuple(sorted(set(keywords))),
            )
        )
    return skills


def load_matrix_catalog(matrix_dir: Path) -> dict[str, list[MatrixSkill]]:
    catalog: dict[str, list[MatrixSkill]] = {}
    for area, file_name in AREA_MATRIX_FILES.items():
        catalog[area] = parse_matrix_file(matrix_dir / file_name, area=area)
    return catalog


def build_matrix_idf(catalog: dict[str, list[MatrixSkill]]) -> dict[str, dict[str, float]]:
    area_idf: dict[str, dict[str, float]] = {}
    for area, skills in catalog.items():
        total = len(skills)
        if total == 0:
            area_idf[area] = {}
            continue

        df: Counter[str] = Counter()
        for skill in skills:
            df.update(set(skill.keywords))

        area_idf[area] = {
            token: math.log((total + 1) / (count + 1)) + 1.0
            for token, count in df.items()
        }
    return area_idf


def build_competencia_lookup(catalog: dict[str, list[MatrixSkill]]) -> dict[tuple[str, str], str]:
    result: dict[tuple[str, str], str] = {}
    for area, skills in catalog.items():
        for skill in skills:
            result[(area, skill.habilidade_codigo)] = skill.competencia_codigo
    return result


def hinted_habilidades(area: str, disciplina: str) -> set[int]:
    by_area = DISCIPLINE_SKILL_HINTS.get(area, {})
    return by_area.get(disciplina, set())


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


def estimate_skill_legacy(area: str, discipline: str, theme: str) -> tuple[str, str]:
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


def estimate_skill_from_matrix(
    question: QuestionRaw,
    discipline: str,
    theme: str,
    catalog: dict[str, list[MatrixSkill]],
    idf_by_area: dict[str, dict[str, float]],
) -> tuple[str, str, str, float]:
    area = question.area
    candidates = catalog.get(area, [])
    if not candidates:
        fallback_skill, fallback_conf = estimate_skill_legacy(area, discipline, theme)
        return ("", fallback_skill, fallback_conf, 0.0)

    legacy_skill, _ = estimate_skill_legacy(area, discipline, theme)
    legacy_num = int(legacy_skill[1:]) if legacy_skill.startswith("H") else None
    hint_set = hinted_habilidades(area, discipline)
    idf = idf_by_area.get(area, {})
    text_tokens = Counter(extract_tokens(question.texto))
    theme_tokens = set(extract_tokens(theme)) if theme != "Tema geral" else set()

    best: MatrixSkill | None = None
    best_score = -1.0
    second_score = -1.0

    for skill in candidates:
        score = 0.0
        for token in skill.keywords:
            tf = text_tokens.get(token, 0)
            if not tf:
                continue
            score += tf * idf.get(token, 1.0)

        if hint_set and skill.habilidade_num in hint_set:
            score += 1.5
        if legacy_num is not None and skill.habilidade_num == legacy_num:
            score += 1.0
        if theme_tokens:
            theme_hits = sum(1 for token in theme_tokens if token in skill.keywords)
            score += 0.4 * theme_hits

        if score > best_score:
            second_score = best_score
            best_score = score
            best = skill
        elif score > second_score:
            second_score = score

    if best is None:
        fallback_skill, fallback_conf = estimate_skill_legacy(area, discipline, theme)
        return ("", fallback_skill, fallback_conf, 0.0)

    margin = best_score - max(second_score, 0.0)
    if best_score >= 5.0 and margin >= 1.2:
        skill_conf = "alta"
    elif best_score >= 1.0:
        skill_conf = "média"
    else:
        skill_conf = "baixa"

    return (
        best.competencia_codigo,
        best.habilidade_codigo,
        skill_conf,
        best_score,
    )


def confidence_from_scores(
    discipline_score: int,
    theme_score: int,
    skill_confidence: str,
    discipline_reason: str,
    discipline: str,
) -> str:
    is_fallback = discipline_reason.startswith("Fallback por área")
    base = 0
    if discipline_score >= 5:
        base += 2
    elif discipline_score >= 2:
        base += 1
    elif discipline_score >= 1 and not is_fallback:
        # Um match fraco de keyword ainda é melhor que fallback puro da área.
        base += 1

    if not is_fallback and "(geral)" not in discipline:
        # Disciplina específica por keyword reduz ambiguidade frente às classes gerais.
        base += 1

    if theme_score >= 3:
        base += 2
    elif theme_score >= 1:
        base += 1

    if skill_confidence == "alta":
        base += 2
    elif skill_confidence == "média":
        base += 1

    if base >= 5:
        return "alta"
    if base >= 1:
        return "média"
    return "baixa"


def preview_text(text: str, max_len: int = 120) -> str:
    single_line = " ".join(text.splitlines()).strip()
    if not single_line:
        return ""
    if len(single_line) <= max_len:
        return single_line
    return single_line[: max_len - 3].rstrip() + "..."


def detect_has_image(text: str, fallback_image_paths: tuple[str, ...]) -> bool:
    if fallback_image_paths:
        return True
    text_norm = normalize_text(text)
    return IMAGE_MARKER_RE.search(text_norm) is not None


def map_question(
    question: QuestionRaw,
    matrix_catalog: dict[str, list[MatrixSkill]],
    matrix_idf: dict[str, dict[str, float]],
    competencia_lookup: dict[tuple[str, str], str],
    fallback_image_paths: tuple[str, ...],
) -> QuestionMapped:
    discipline, discipline_score, discipline_reason = classify_discipline(question)
    theme, theme_score = classify_theme(discipline, question.texto)
    competencia, skill, skill_confidence, matrix_score = estimate_skill_from_matrix(
        question=question,
        discipline=discipline,
        theme=theme,
        catalog=matrix_catalog,
        idf_by_area=matrix_idf,
    )
    if not competencia and skill.startswith("H"):
        competencia = competencia_lookup.get((question.area, skill), "")
    confidence = confidence_from_scores(
        discipline_score=discipline_score,
        theme_score=theme_score,
        skill_confidence=skill_confidence,
        discipline_reason=discipline_reason,
        discipline=discipline,
    )

    reason = (
        f"{discipline_reason}; score_disciplina={discipline_score}; "
        f"score_tema={theme_score}; matriz={competencia}-{skill}({skill_confidence}); "
        f"score_matriz={matrix_score:.2f}"
    )
    preview = preview_text(question.texto)
    if not preview and fallback_image_paths:
        preview = "Texto OCR indisponível (usar imagem fallback)."
    elif not preview:
        preview = "Texto OCR indisponível."

    return QuestionMapped(
        ano=question.ano,
        dia=question.dia,
        numero=question.numero,
        variacao=question.variacao,
        area=question.area,
        disciplina=discipline,
        competencia_estimada=competencia or "C?",
        tema_estimado=theme,
        habilidade_estimada=skill,
        confianca=confidence,
        motivo=reason,
        tem_imagem=detect_has_image(question.texto, fallback_image_paths),
        texto_vazio=question.texto_vazio,
        fallback_image_paths=fallback_image_paths,
        gabarito=question.gabarito,
        preview=preview,
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


def normalize_confidence(value: str) -> str:
    cleaned = value.strip().lower()
    if cleaned in {"alta", "média", "media", "baixa"}:
        return "média" if cleaned == "media" else cleaned
    return "média"


def load_manual_overrides(path: Path) -> list[ManualOverride]:
    if not path.exists():
        return []

    result: list[ManualOverride] = []
    with path.open("r", encoding="utf-8", newline="") as file_obj:
        reader = csv.DictReader(file_obj)
        for row in reader:
            try:
                override = ManualOverride(
                    ano=int(row["ano"]),
                    dia=int(row["dia"]),
                    numero=int(row["numero"]),
                    variacao=int(row.get("variacao", "1") or "1"),
                    preview_match=row.get("preview_match", "").strip(),
                    disciplina=row["disciplina"].strip(),
                    competencia_estimada=(row.get("competencia_estimada", "").strip() or ""),
                    tema_estimado=row["tema_estimado"].strip(),
                    habilidade_estimada=row["habilidade_estimada"].strip(),
                    confianca=normalize_confidence(row.get("confianca", "média")),
                    motivo_curto=row.get("motivo_curto", "revisao_manual").strip() or "revisao_manual",
                    lote=row.get("lote", "manual").strip() or "manual",
                )
            except (KeyError, ValueError):
                continue
            result.append(override)
    return result


def apply_manual_overrides(
    mapped_questions: list[QuestionMapped],
    overrides: list[ManualOverride],
    competencia_lookup: dict[tuple[str, str], str],
) -> tuple[list[QuestionMapped], dict[str, int], list[ManualOverride]]:
    if not overrides:
        return (
            mapped_questions,
            {
                "overrides_loaded": 0,
                "overrides_applied": 0,
                "questions_overridden": 0,
            },
            [],
        )

    grouped: dict[tuple[int, int, int, int], list[tuple[int, ManualOverride]]] = defaultdict(list)
    for index, override in enumerate(overrides):
        key = (override.ano, override.dia, override.numero, override.variacao)
        grouped[key].append((index, override))

    used_override_indexes: set[int] = set()
    questions_overridden = 0
    result: list[QuestionMapped] = []

    for item in mapped_questions:
        key = (item.ano, item.dia, item.numero, item.variacao)
        candidates = grouped.get(key, [])
        selected_index: int | None = None
        selected_override: ManualOverride | None = None
        preview_norm = normalize_text(item.preview)

        for candidate_index, candidate in candidates:
            preview_match = normalize_text(candidate.preview_match)
            if preview_match and preview_match not in preview_norm:
                continue
            selected_index = candidate_index
            selected_override = candidate
            break

        if selected_override is None:
            result.append(item)
            continue

        used_override_indexes.add(selected_index)
        questions_overridden += 1
        motivo = (
            f"Revisão manual ({selected_override.lote}: {selected_override.motivo_curto}); "
            f"auto={item.motivo}"
        )
        competencia = selected_override.competencia_estimada
        if not competencia and selected_override.habilidade_estimada.startswith("H"):
            competencia = competencia_lookup.get((item.area, selected_override.habilidade_estimada), "")
        result.append(
            QuestionMapped(
                ano=item.ano,
                dia=item.dia,
                numero=item.numero,
                variacao=item.variacao,
                area=item.area,
                disciplina=selected_override.disciplina,
                competencia_estimada=competencia or item.competencia_estimada,
                tema_estimado=selected_override.tema_estimado,
                habilidade_estimada=selected_override.habilidade_estimada,
                confianca=selected_override.confianca,
                motivo=motivo,
                tem_imagem=item.tem_imagem,
                texto_vazio=item.texto_vazio,
                fallback_image_paths=item.fallback_image_paths,
                gabarito=item.gabarito,
                preview=item.preview,
            )
        )

    unused_overrides = [ov for idx, ov in enumerate(overrides) if idx not in used_override_indexes]
    stats = {
        "overrides_loaded": len(overrides),
        "overrides_applied": len(used_override_indexes),
        "questions_overridden": questions_overridden,
    }
    return result, stats, unused_overrides


def write_manual_overrides_report(
    path: Path,
    stats: dict[str, int],
    unused_overrides: list[ManualOverride],
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

    lines: list[str] = []
    lines.append("# Relatório de Revisão Manual")
    lines.append("")
    lines.append(f"- Overrides carregados: **{stats['overrides_loaded']}**")
    lines.append(f"- Overrides aplicados: **{stats['overrides_applied']}**")
    lines.append(f"- Questões sobrescritas: **{stats['questions_overridden']}**")
    lines.append(f"- Overrides sem correspondência: **{len(unused_overrides)}**")
    lines.append("")

    if unused_overrides:
        lines.append("## Overrides não aplicados")
        lines.append("")
        lines.append("| Ano | Dia | Questão | Variação | Lote | Motivo curto |")
        lines.append("|---:|---:|---:|---:|---|---|")
        for override in unused_overrides:
            lines.append(
                "| {ano} | {dia} | {questao} | {variacao} | {lote} | {motivo} |".format(
                    ano=override.ano,
                    dia=override.dia,
                    questao=f"{override.numero:03d}",
                    variacao=override.variacao,
                    lote=override.lote,
                    motivo=override.motivo_curto,
                )
            )
        lines.append("")

    path.write_text("\n".join(lines), encoding="utf-8")


def write_jsonl(path: Path, mapped_questions: list[QuestionMapped]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as file_obj:
        for item in mapped_questions:
            payload = {
                **item.__dict__,
                "fallback_image_paths": list(item.fallback_image_paths),
            }
            file_obj.write(json.dumps(payload, ensure_ascii=False) + "\n")


def write_csv(path: Path, mapped_questions: list[QuestionMapped]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "ano",
        "dia",
        "numero",
        "variacao",
        "area",
        "disciplina",
        "competencia_estimada",
        "tema_estimado",
        "habilidade_estimada",
        "confianca",
        "motivo",
        "tem_imagem",
        "texto_vazio",
        "fallback_image_paths",
        "gabarito",
        "preview",
    ]
    with path.open("w", encoding="utf-8", newline="") as file_obj:
        writer = csv.DictWriter(file_obj, fieldnames=fieldnames)
        writer.writeheader()
        for item in mapped_questions:
            writer.writerow(
                {
                    **item.__dict__,
                    "fallback_image_paths": ";".join(item.fallback_image_paths),
                }
            )


def write_summary(path: Path, mapped_questions: list[QuestionMapped]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    by_discipline = Counter(item.disciplina for item in mapped_questions)
    by_theme = Counter((item.disciplina, item.tema_estimado) for item in mapped_questions)
    by_competence = Counter((item.area, item.competencia_estimada) for item in mapped_questions)
    by_confidence = Counter(item.confianca for item in mapped_questions)
    with_image = sum(1 for item in mapped_questions if item.tem_imagem)
    without_image = len(mapped_questions) - with_image
    empty_text = sum(1 for item in mapped_questions if item.texto_vazio)
    with_fallback = sum(1 for item in mapped_questions if item.fallback_image_paths)

    lines: list[str] = []
    lines.append("# Resumo do Mapeamento")
    lines.append("")
    lines.append(f"- Total de questões mapeadas: **{len(mapped_questions)}**")
    lines.append(
        "- Confiança: "
        + ", ".join(f"{key}={value}" for key, value in sorted(by_confidence.items()))
    )
    lines.append(
        "- Indicador de imagem: "
        f"com imagem={with_image}, sem imagem={without_image} "
        f"({(with_image / len(mapped_questions) * 100):.1f}% com imagem)"
    )
    lines.append(
        f"- Texto vazio no markdown: **{empty_text}** (com fallback de imagem: **{with_fallback}**)"
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

    lines.append("## Competências mais recorrentes (top 30)")
    lines.append("")
    lines.append("| Área | Competência | Quantidade |")
    lines.append("|---|---|---:|")
    for (area, comp), qty in by_competence.most_common(30):
        lines.append(f"| {area} | {comp} | {qty} |")
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
    lines.append(
        "| Ano | Dia | Questão | Área | Disciplina | Competência | Tema | Habilidade estimada | Imagem | Motivo |"
    )
    lines.append("|---:|---:|---:|---|---|---|---|---|---|---|")

    for item in pending:
        lines.append(
            "| {ano} | {dia} | {questao:03d} | {area} | {disciplina} | {competencia} | {tema} | {habilidade} | {imagem} | {motivo} |".format(
                ano=item.ano,
                dia=item.dia,
                questao=item.numero,
                area=item.area,
                disciplina=item.disciplina,
                competencia=item.competencia_estimada,
                tema=item.tema_estimado,
                habilidade=item.habilidade_estimada,
                imagem="sim" if item.tem_imagem else "não",
                motivo=item.motivo.replace("|", "/"),
            )
        )

    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def write_review_batches(base_dir: Path, mapped_questions: list[QuestionMapped], batch_size: int = 50) -> None:
    pending = [item for item in mapped_questions if item.confianca == "baixa"]
    pending.sort(key=lambda item: (item.ano, item.dia, item.numero, item.variacao))

    target_dir = base_dir / "lotes_revisao"
    target_dir.mkdir(parents=True, exist_ok=True)
    for existing in target_dir.glob("lote_*.md"):
        existing.unlink()

    if not pending:
        lines = [
            "# Índice de Lotes de Revisão",
            "",
            "- Pendentes atuais: **0**",
            f"- Tamanho do lote: **{batch_size}**",
            "- Total de lotes: **0**",
            "",
            "Sem pendências de baixa confiança no momento.",
            "",
        ]
        (target_dir / "README.md").write_text("\n".join(lines), encoding="utf-8")
        return

    total_batches = (len(pending) + batch_size - 1) // batch_size

    for batch_idx in range(total_batches):
        start = batch_idx * batch_size
        end = min(start + batch_size, len(pending))
        items = pending[start:end]
        lot_name = f"lote_{batch_idx + 1:02d}.md"
        path = target_dir / lot_name

        lines: list[str] = []
        lines.append(f"# Lote de Revisão {batch_idx + 1:02d}")
        lines.append("")
        lines.append(f"- Itens: **{len(items)}**")
        lines.append(f"- Faixa global: **{start + 1}–{end}** de **{len(pending)}** pendentes")
        lines.append("")
        lines.append(
            "| Ano | Dia | Questão | Área | Disciplina atual | Competência atual | Tema atual | Habilidade atual | Imagem |"
        )
        lines.append("|---:|---:|---:|---|---|---|---|---|---|")

        for item in items:
            lines.append(
                "| {ano} | {dia} | {questao:03d} | {area} | {disciplina} | {competencia} | {tema} | {habilidade} | {imagem} |".format(
                    ano=item.ano,
                    dia=item.dia,
                    questao=item.numero,
                    area=item.area,
                    disciplina=item.disciplina,
                    competencia=item.competencia_estimada,
                    tema=item.tema_estimado,
                    habilidade=item.habilidade_estimada,
                    imagem="sim" if item.tem_imagem else "não",
                )
            )

        lines.append("")
        path.write_text("\n".join(lines), encoding="utf-8")

    index_lines: list[str] = []
    index_lines.append("# Índice de Lotes de Revisão")
    index_lines.append("")
    index_lines.append(f"- Pendentes atuais: **{len(pending)}**")
    index_lines.append(f"- Tamanho do lote: **{batch_size}**")
    index_lines.append(f"- Total de lotes: **{total_batches}**")
    index_lines.append("")
    index_lines.append("| Lote | Itens |")
    index_lines.append("|---|---:|")

    for batch_idx in range(total_batches):
        start = batch_idx * batch_size
        end = min(start + batch_size, len(pending))
        items_count = end - start
        index_lines.append(f"| `lote_{batch_idx + 1:02d}.md` | {items_count} |")

    index_lines.append("")
    (target_dir / "README.md").write_text("\n".join(index_lines), encoding="utf-8")


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
        lines.append(
            "| Ano | Dia | Questão | Área | Competência | Tema | Habilidade estimada | Confiança | Imagem | Preview |"
        )
        lines.append("|---:|---:|---:|---|---|---|---|---|---|---|")

        for item in items:
            lines.append(
                "| {ano} | {dia} | {questao:03d} | {area} | {competencia} | {tema} | {habilidade} | {conf} | {imagem} | {preview} |".format(
                    ano=item.ano,
                    dia=item.dia,
                    questao=item.numero,
                    area=item.area,
                    competencia=item.competencia_estimada,
                    tema=item.tema_estimado,
                    habilidade=item.habilidade_estimada,
                    conf=item.confianca,
                    imagem="sim" if item.tem_imagem else "não",
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


def write_image_lots_summary(path: Path, mapped_questions: list[QuestionMapped]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

    lot_ranges = [
        ("Lote 1", 2015, 2017),
        ("Lote 2", 2018, 2020),
        ("Lote 3", 2021, 2023),
        ("Lote 4", 2024, 2025),
    ]

    year_stats: dict[int, dict[str, int]] = {}
    for item in mapped_questions:
        stats = year_stats.setdefault(item.ano, {"total": 0, "com_imagem": 0})
        stats["total"] += 1
        if item.tem_imagem:
            stats["com_imagem"] += 1

    lines: list[str] = []
    lines.append("# Resumo por Lotes — Sinalização de Imagem")
    lines.append("")
    lines.append(
        "Consolidação dos lotes de sinalização `tem_imagem` para o banco 2015–2025 "
        "(detecção heurística por texto)."
    )
    lines.append("")
    lines.append("| Lote | Faixa de anos | Questões | Com imagem | Sem imagem | % com imagem | Status |")
    lines.append("|---|---|---:|---:|---:|---:|---|")

    for lot_name, year_from, year_to in lot_ranges:
        total = 0
        with_image = 0
        for year in range(year_from, year_to + 1):
            stats = year_stats.get(year, {"total": 0, "com_imagem": 0})
            total += stats["total"]
            with_image += stats["com_imagem"]

        without_image = total - with_image
        pct = (with_image / total * 100) if total else 0.0
        lines.append(
            f"| {lot_name} | {year_from}–{year_to} | {total} | {with_image} | "
            f"{without_image} | {pct:.1f}% | concluído |"
        )

    lines.append("")
    lines.append("## Detalhe por ano")
    lines.append("")
    lines.append("| Ano | Questões | Com imagem | Sem imagem | % com imagem |")
    lines.append("|---:|---:|---:|---:|---:|")

    for year in sorted(year_stats):
        total = year_stats[year]["total"]
        with_image = year_stats[year]["com_imagem"]
        without_image = total - with_image
        pct = (with_image / total * 100) if total else 0.0
        lines.append(f"| {year} | {total} | {with_image} | {without_image} | {pct:.1f}% |")

    lines.append("")
    lines.append("## Observação")
    lines.append("")
    lines.append("- `tem_imagem` indica menções textuais (figura/gráfico/tabela/tirinha/etc.).")
    lines.append(
        "- O recorte do asset visual por questão (`asset_path` + coordenadas) permanece como etapa futura."
    )
    lines.append("")

    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    args = parse_args()
    matrix_catalog = load_matrix_catalog(args.matrix_dir)
    matrix_idf = build_matrix_idf(matrix_catalog)
    competencia_lookup = build_competencia_lookup(matrix_catalog)

    questions = load_all_questions(
        banco_dir=args.banco_dir,
        year_from=args.year_from,
        year_to=args.year_to,
    )
    fallback_image_index = load_fallback_image_index(
        banco_dir=args.banco_dir,
        year_from=args.year_from,
        year_to=args.year_to,
    )

    if not questions:
        raise FileNotFoundError("Nenhuma questão encontrada no intervalo informado.")

    mapped_auto = [
        map_question(
            question,
            matrix_catalog=matrix_catalog,
            matrix_idf=matrix_idf,
            competencia_lookup=competencia_lookup,
            fallback_image_paths=fallback_image_index.get(
                (question.ano, question.dia, question.numero, question.variacao),
                (),
            ),
        )
        for question in questions
    ]

    manual_overrides = (
        load_manual_overrides(args.manual_overrides)
        if args.apply_manual_overrides
        else []
    )
    mapped, override_stats, unused_overrides = apply_manual_overrides(
        mapped_auto,
        manual_overrides,
        competencia_lookup=competencia_lookup,
    )
    mapped.sort(key=lambda item: (item.ano, item.dia, item.numero, item.variacao))

    out_dir = args.out_dir
    write_jsonl(out_dir / "questoes_mapeadas.jsonl", mapped)
    write_csv(out_dir / "questoes_mapeadas.csv", mapped)
    write_summary(out_dir / "resumo_por_disciplina_tema.md", mapped)
    write_requested_disciplines_summary(
        out_dir / "resumo_materias_chave.md",
        mapped,
    )
    write_image_lots_summary(out_dir / "resumo_lotes_tem_imagem.md", mapped)
    write_review_pending(out_dir / "revisao_pendente.md", mapped)
    write_review_batches(out_dir, mapped)
    write_discipline_files(out_dir, mapped)
    write_manual_overrides_report(
        out_dir / "revisao_manual" / "aplicacao_overrides.md",
        stats=override_stats,
        unused_overrides=unused_overrides,
    )

    print(f"[ok] questões lidas: {len(questions)}")
    print(f"[ok] questões com fallback de imagem: {sum(1 for item in mapped if item.fallback_image_paths)}")
    print(f"[ok] questões mapeadas: {len(mapped)}")
    print(f"[ok] modo matriz: ativo ({args.matrix_dir})")
    print(f"[ok] overrides habilitados: {'sim' if args.apply_manual_overrides else 'não'}")
    print(f"[ok] overrides carregados: {override_stats['overrides_loaded']}")
    print(f"[ok] overrides aplicados: {override_stats['overrides_applied']}")
    print(f"[ok] questões sobrescritas: {override_stats['questions_overridden']}")
    print(f"[ok] saída: {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
