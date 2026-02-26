#!/usr/bin/env python3
"""Gera intercorrelacao entre modulos do livro e questoes reais do ENEM.

Saida principal:
- questoes/mapeamento_habilidades/intercorrelacao/modulo_questao_matches.csv

Objetivo:
- criar vinculos com score entre `modulo` do livro e `questao` do banco mapeado;
- permitir filtros por aderencia (direto/relacionado/interdisciplinar) e confianca;
- apoiar aprofundamento com base em competencia/habilidade + tema + keywords.
"""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path
import re
import unicodedata

DEFAULT_QUESTIONS_CSV = Path("questoes/mapeamento_habilidades/questoes_mapeadas.csv")
DEFAULT_MODULES_CSV = Path("plano/indice_livros_6_volumes.csv")
DEFAULT_TAGS_CSV = Path("questoes/mapeamento_habilidades/intercorrelacao/tags_assunto_canonicas.csv")
DEFAULT_OUT_CSV = Path("questoes/mapeamento_habilidades/intercorrelacao/modulo_questao_matches.csv")
DEFAULT_SUMMARY_MD = Path("questoes/mapeamento_habilidades/intercorrelacao/resumo_modulo_questao_matches.md")

TOKEN_RE = re.compile(r"[a-z0-9]+")
COMPETENCY_RE = re.compile(r"^c(\d+)$", re.IGNORECASE)
SKILL_RE = re.compile(r"^h(\d+)$", re.IGNORECASE)
COMPOSITE_RE = re.compile(r"^c(\d+)-h(\d+)$", re.IGNORECASE)
TRAILING_NUMBER_RE = re.compile(r"\s+\d+$")

STOPWORDS = {
    "a",
    "ao",
    "aos",
    "as",
    "com",
    "como",
    "da",
    "das",
    "de",
    "do",
    "dos",
    "e",
    "em",
    "na",
    "nas",
    "no",
    "nos",
    "o",
    "os",
    "ou",
    "para",
    "por",
    "que",
    "se",
    "sem",
    "tema",
    "tecnologias",
    "suas",
    "suas",
    "geral",
    "sobre",
    "uma",
    "um",
    "mais",
    "menos",
    "matriz",
    "score",
    "media",
    "alta",
    "baixa",
    "fallback",
    "keywords",
    "disciplina",
    "motivo",
    "questao",
    "questoes",
}


@dataclass
class TagRule:
    tag: str
    terms: list[str]
    area_keys: set[str]
    disciplina_keys: set[str]


@dataclass
class ModuleItem:
    volume: int
    area: str
    area_key: str
    materia: str
    disciplina_key: str
    modulo: int
    competencias: list[str]
    habilidades: list[str]
    text_norm: str
    tokens: set[str]
    tag_hits: set[str]


@dataclass
class QuestionItem:
    ano: int
    dia: int
    numero: int
    variacao: int
    area: str
    area_key: str
    disciplina: str
    disciplina_key: str
    tema_estimado: str
    competencia: str
    habilidade: str
    text_norm: str
    tokens: set[str]
    tag_hits: set[str]


@dataclass
class MatchItem:
    question: QuestionItem
    module: ModuleItem
    assuntos_match: str
    score_match: float
    tipo_match: str
    confianca: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Gera CSV de intercorrelacao modulo x questao.",
    )
    parser.add_argument(
        "--questions-csv",
        type=Path,
        default=DEFAULT_QUESTIONS_CSV,
        help="CSV de questoes mapeadas.",
    )
    parser.add_argument(
        "--modules-csv",
        type=Path,
        default=DEFAULT_MODULES_CSV,
        help="CSV de modulos/livros.",
    )
    parser.add_argument(
        "--tags-csv",
        type=Path,
        default=DEFAULT_TAGS_CSV,
        help="CSV de tags canonicas e sinonimos.",
    )
    parser.add_argument(
        "--out-csv",
        type=Path,
        default=DEFAULT_OUT_CSV,
        help="CSV de saida com os matches.",
    )
    parser.add_argument(
        "--summary-md",
        type=Path,
        default=DEFAULT_SUMMARY_MD,
        help="Resumo markdown da geracao.",
    )
    parser.add_argument(
        "--min-score",
        type=float,
        default=0.40,
        help="Score minimo para manter um vinculo.",
    )
    parser.add_argument(
        "--max-matches-per-question",
        type=int,
        default=5,
        help="Quantidade maxima de modulos por questao.",
    )
    parser.add_argument("--year-from", type=int, default=2015)
    parser.add_argument("--year-to", type=int, default=2025)
    return parser.parse_args()


def strip_diacritics(raw_text: str) -> str:
    normalized = unicodedata.normalize("NFKD", raw_text)
    return "".join(ch for ch in normalized if not unicodedata.combining(ch))


def normalize_text(raw_text: str) -> str:
    normalized = strip_diacritics(raw_text).casefold()
    normalized = re.sub(r"[^a-z0-9\s]+", " ", normalized)
    normalized = re.sub(r"\s+", " ", normalized).strip()
    return normalized


def tokenize(raw_text: str) -> set[str]:
    text = normalize_text(raw_text)
    return {
        token
        for token in TOKEN_RE.findall(text)
        if len(token) >= 3 and token not in STOPWORDS
    }


def normalize_area_key(raw_area: str) -> str:
    text = normalize_text(raw_area)
    if "human" in text:
        return "humanas"
    if "linguag" in text:
        return "linguagens"
    if "matemat" in text:
        return "matematica"
    if "natureza" in text:
        return "natureza"
    return ""


def normalize_disciplina_key(raw_disciplina: str) -> str:
    text = normalize_text(raw_disciplina)
    text = text.replace(" ciencias humanas geral ", " ").strip()
    text = text.replace(" ciencias da natureza geral ", " ").strip()
    text = text.replace(" ciencias humanas", " ").strip() if text == "ciencias humanas geral" else text
    text = text.replace("( geral )", " ").replace(" geral", "").strip()
    text = TRAILING_NUMBER_RE.sub("", text).strip()

    if not text:
        return ""

    aliases = {
        "lingua portuguesa": "lingua portuguesa",
        "literatura": "literatura",
        "ingles": "ingles",
        "espanhol": "espanhol",
        "lingua estrangeira": "lingua estrangeira",
        "historia": "historia",
        "geografia": "geografia",
        "filosofia": "filosofia",
        "sociologia": "sociologia",
        "fisica": "fisica",
        "quimica": "quimica",
        "biologia": "biologia",
        "matematica": "matematica",
        "redacao": "redacao",
        "artes e comunicacao": "artes e comunicacao",
        "ciencias humanas": "ciencias humanas",
        "ciencias da natureza": "ciencias da natureza",
    }
    for alias, canonical in aliases.items():
        if alias in text:
            return canonical
    return text


def dedupe_preserve_order(items: list[str]) -> list[str]:
    result: list[str] = []
    seen: set[str] = set()
    for item in items:
        if not item or item in seen:
            continue
        seen.add(item)
        result.append(item)
    return result


def parse_module_habilidades(raw_value: str) -> tuple[list[str], list[str]]:
    competencias: list[str] = []
    habilidades: list[str] = []
    if not raw_value.strip():
        return competencias, habilidades

    parts = [chunk.strip() for chunk in re.split(r"[;,]+", raw_value) if chunk.strip()]
    for part in parts:
        token = normalize_text(part).replace(" ", "")
        composite_match = COMPOSITE_RE.fullmatch(token)
        if composite_match:
            competencias.append(f"C{int(composite_match.group(1))}")
            habilidades.append(f"H{int(composite_match.group(2))}")
            continue

        competency_match = COMPETENCY_RE.fullmatch(token)
        if competency_match:
            competencias.append(f"C{int(competency_match.group(1))}")
            continue

        skill_match = SKILL_RE.fullmatch(token)
        if skill_match:
            habilidades.append(f"H{int(skill_match.group(1))}")

    return dedupe_preserve_order(competencias), dedupe_preserve_order(habilidades)


def normalize_competency(raw_value: str) -> str:
    match = COMPETENCY_RE.fullmatch(normalize_text(raw_value).replace(" ", ""))
    if not match:
        return ""
    return f"C{int(match.group(1))}"


def normalize_skill(raw_value: str) -> str:
    match = SKILL_RE.fullmatch(normalize_text(raw_value).replace(" ", ""))
    if not match:
        return ""
    return f"H{int(match.group(1))}"


def split_semicolon_list(raw_value: str) -> list[str]:
    if not raw_value.strip():
        return []
    return [chunk.strip() for chunk in raw_value.split(";") if chunk.strip()]


def load_tags(tags_csv: Path) -> list[TagRule]:
    if not tags_csv.exists():
        return []

    rules: list[TagRule] = []
    with tags_csv.open("r", encoding="utf-8", newline="") as file_obj:
        reader = csv.DictReader(file_obj)
        for row in reader:
            tag_raw = (row.get("tag") or "").strip()
            if not tag_raw:
                continue

            normalized_tag = normalize_text(tag_raw).replace(" ", "_")
            terms = [normalize_text(tag_raw)]
            terms.extend(normalize_text(term) for term in split_semicolon_list(row.get("sinonimos", "")))
            terms = [term for term in dedupe_preserve_order(terms) if term and len(term) >= 3]
            if not terms:
                continue

            area_keys = {
                normalize_area_key(area)
                for area in split_semicolon_list(row.get("areas", ""))
                if normalize_area_key(area)
            }
            disciplina_keys = {
                normalize_disciplina_key(disciplina)
                for disciplina in split_semicolon_list(row.get("disciplinas", ""))
                if normalize_disciplina_key(disciplina)
            }

            rules.append(
                TagRule(
                    tag=normalized_tag,
                    terms=terms,
                    area_keys=area_keys,
                    disciplina_keys=disciplina_keys,
                )
            )
    return rules


def detect_tag_hits(
    text_norm: str,
    area_key: str,
    disciplina_key: str,
    tag_rules: list[TagRule],
) -> set[str]:
    if not text_norm:
        return set()

    hits: set[str] = set()
    for rule in tag_rules:
        if rule.area_keys and area_key not in rule.area_keys:
            continue
        if rule.disciplina_keys and disciplina_key not in rule.disciplina_keys:
            continue
        if any(term in text_norm for term in rule.terms):
            hits.add(rule.tag)
    return hits


def to_int(raw_value: str) -> int:
    try:
        return int(raw_value)
    except ValueError:
        return 0


def is_exercise_module(row: dict[str, str]) -> bool:
    raw_type = (
        row.get("tipo_modulo")
        or row.get("tipo")
        or row.get("modulo_exercicios")
        or ""
    ).strip()
    normalized = normalize_text(raw_type).replace(" ", "")
    return normalized in {"exercicios", "exercicio", "listaexercicios", "sim", "true", "1"}


def load_modules(modules_csv: Path, tag_rules: list[TagRule]) -> list[ModuleItem]:
    modules: list[ModuleItem] = []
    with modules_csv.open("r", encoding="utf-8", newline="") as file_obj:
        reader = csv.DictReader(file_obj)
        for row in reader:
            if is_exercise_module(row):
                continue

            volume = to_int((row.get("volume") or "").strip())
            modulo = to_int((row.get("modulo") or "").strip())
            area = (row.get("area") or "").strip()
            materia = (row.get("materia") or "").strip()
            titulo = (row.get("titulo") or "").strip()
            expectativas = (row.get("expectativas_aprendizagem") or "").strip()
            habilidades_raw = (row.get("habilidades") or "").strip()

            if volume <= 0 or modulo <= 0 or not area or not materia:
                continue
            if not any((titulo, expectativas, habilidades_raw)):
                continue

            competencias, habilidades = parse_module_habilidades(habilidades_raw)
            text_for_match = " ".join(
                part for part in (materia, titulo, expectativas, habilidades_raw) if part
            )
            text_norm = normalize_text(text_for_match)
            tokens = tokenize(text_for_match)
            if not text_norm:
                continue

            area_key = normalize_area_key(area)
            disciplina_key = normalize_disciplina_key(materia)
            tag_hits = detect_tag_hits(text_norm, area_key, disciplina_key, tag_rules)

            modules.append(
                ModuleItem(
                    volume=volume,
                    area=area,
                    area_key=area_key,
                    materia=materia,
                    disciplina_key=disciplina_key,
                    modulo=modulo,
                    competencias=competencias,
                    habilidades=habilidades,
                    text_norm=text_norm,
                    tokens=tokens,
                    tag_hits=tag_hits,
                )
            )
    return modules


def load_questions(
    questions_csv: Path,
    tag_rules: list[TagRule],
    year_from: int,
    year_to: int,
) -> list[QuestionItem]:
    questions: list[QuestionItem] = []
    with questions_csv.open("r", encoding="utf-8", newline="") as file_obj:
        reader = csv.DictReader(file_obj)
        for row in reader:
            ano = to_int((row.get("ano") or "").strip())
            if ano < year_from or ano > year_to:
                continue
            dia = to_int((row.get("dia") or "").strip())
            numero = to_int((row.get("numero") or "").strip())
            variacao = to_int((row.get("variacao") or "").strip())
            area = (row.get("area") or "").strip()
            disciplina = (row.get("disciplina") or "").strip()
            tema_estimado = (row.get("tema_estimado") or "").strip()
            competencia = normalize_competency((row.get("competencia_estimada") or "").strip())
            habilidade = normalize_skill((row.get("habilidade_estimada") or "").strip())
            preview = (row.get("preview") or "").strip()

            if ano <= 0 or dia <= 0 or numero <= 0 or variacao <= 0:
                continue

            text_for_match = " ".join(
                part for part in (disciplina, tema_estimado, preview) if part
            )
            text_norm = normalize_text(text_for_match)
            tokens = tokenize(text_for_match)
            area_key = normalize_area_key(area)
            disciplina_key = normalize_disciplina_key(disciplina)
            tag_hits = detect_tag_hits(text_norm, area_key, disciplina_key, tag_rules)

            questions.append(
                QuestionItem(
                    ano=ano,
                    dia=dia,
                    numero=numero,
                    variacao=variacao,
                    area=area,
                    area_key=area_key,
                    disciplina=disciplina,
                    disciplina_key=disciplina_key,
                    tema_estimado=tema_estimado,
                    competencia=competencia,
                    habilidade=habilidade,
                    text_norm=text_norm,
                    tokens=tokens,
                    tag_hits=tag_hits,
                )
            )
    return questions


def infer_tipo_match(
    discipline_match: bool,
    competence_match: bool,
    skill_match: bool,
    overlap_count: int,
    tag_count: int,
    interdisciplinar: bool,
) -> str:
    if skill_match or (competence_match and discipline_match and (overlap_count > 0 or tag_count > 0)):
        return "direto"
    if interdisciplinar and (competence_match or skill_match or overlap_count > 0 or tag_count > 0):
        return "interdisciplinar"
    return "relacionado"


def infer_confianca(score_match: float) -> str:
    if score_match >= 0.62:
        return "alta"
    if score_match >= 0.48:
        return "media"
    return "baixa"


def choose_assuntos_match(tag_overlap: set[str], overlap_tokens: set[str], tema_estimado: str) -> str:
    if tag_overlap:
        return "; ".join(sorted(tag_overlap))
    if overlap_tokens:
        top_tokens = sorted(overlap_tokens, key=lambda token: (-len(token), token))[:4]
        return "; ".join(top_tokens)
    if tema_estimado and normalize_text(tema_estimado) != "tema geral":
        return tema_estimado
    return ""


def score_module_question(question: QuestionItem, module: ModuleItem) -> tuple[float, str, str]:
    area_match = bool(question.area_key and question.area_key == module.area_key)
    discipline_match = bool(
        question.disciplina_key
        and module.disciplina_key
        and question.disciplina_key == module.disciplina_key
    )
    competence_match = bool(question.competencia and question.competencia in module.competencias)
    skill_match = bool(question.habilidade and question.habilidade in module.habilidades)

    overlap_tokens = question.tokens & module.tokens
    overlap_count = len(overlap_tokens)
    tag_overlap = question.tag_hits & module.tag_hits
    tag_count = len(tag_overlap)

    score = 0.0
    if area_match:
        score += 0.12
    if discipline_match:
        score += 0.18
    if competence_match:
        score += 0.20
    if skill_match:
        score += 0.28
    score += min(0.12, 0.03 * overlap_count)
    score += min(0.10, 0.05 * tag_count)
    score = min(score, 1.0)

    interdisciplinar = bool(
        question.disciplina_key
        and module.disciplina_key
        and question.disciplina_key != module.disciplina_key
    )
    tipo_match = infer_tipo_match(
        discipline_match=discipline_match,
        competence_match=competence_match,
        skill_match=skill_match,
        overlap_count=overlap_count,
        tag_count=tag_count,
        interdisciplinar=interdisciplinar,
    )
    assuntos_match = choose_assuntos_match(tag_overlap, overlap_tokens, question.tema_estimado)
    return score, tipo_match, assuntos_match


def build_matches(
    questions: list[QuestionItem],
    modules: list[ModuleItem],
    min_score: float,
    max_matches_per_question: int,
) -> list[MatchItem]:
    modules_by_area: dict[str, list[ModuleItem]] = {}
    for module in modules:
        modules_by_area.setdefault(module.area_key, []).append(module)

    matches: list[MatchItem] = []
    for question in questions:
        candidates = modules_by_area.get(question.area_key, modules)
        scored_matches: list[MatchItem] = []
        for module in candidates:
            # Gate rapido para evitar pares sem nenhum sinal de relacao.
            has_primary_signal = any(
                (
                    question.habilidade and question.habilidade in module.habilidades,
                    question.competencia and question.competencia in module.competencias,
                    question.disciplina_key
                    and module.disciplina_key
                    and question.disciplina_key == module.disciplina_key,
                    bool(question.tokens & module.tokens),
                    bool(question.tag_hits & module.tag_hits),
                )
            )
            if not has_primary_signal:
                continue

            score, tipo_match, assuntos_match = score_module_question(question, module)
            if score < min_score:
                continue

            scored_matches.append(
                MatchItem(
                    question=question,
                    module=module,
                    assuntos_match=assuntos_match,
                    score_match=score,
                    tipo_match=tipo_match,
                    confianca=infer_confianca(score),
                )
            )

        scored_matches.sort(
            key=lambda item: (
                -item.score_match,
                item.module.materia,
                item.module.modulo,
            )
        )
        matches.extend(scored_matches[:max(max_matches_per_question, 1)])
    return matches


def write_matches_csv(out_csv: Path, matches: list[MatchItem]) -> None:
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "ano",
        "dia",
        "numero",
        "variacao",
        "area",
        "disciplina",
        "materia",
        "volume",
        "modulo",
        "competencias",
        "habilidades",
        "assuntos_match",
        "score_match",
        "tipo_match",
        "confianca",
        "revisado_manual",
    ]
    with out_csv.open("w", encoding="utf-8", newline="") as file_obj:
        writer = csv.DictWriter(file_obj, fieldnames=fieldnames, quoting=csv.QUOTE_MINIMAL)
        writer.writeheader()
        for match in matches:
            writer.writerow(
                {
                    "ano": match.question.ano,
                    "dia": match.question.dia,
                    "numero": match.question.numero,
                    "variacao": match.question.variacao,
                    "area": match.question.area,
                    "disciplina": match.question.disciplina,
                    "materia": match.module.materia,
                    "volume": match.module.volume,
                    "modulo": match.module.modulo,
                    "competencias": "; ".join(match.module.competencias),
                    "habilidades": "; ".join(match.module.habilidades),
                    "assuntos_match": match.assuntos_match,
                    "score_match": f"{match.score_match:.4f}",
                    "tipo_match": match.tipo_match,
                    "confianca": match.confianca,
                    "revisado_manual": "False",
                }
            )


def write_summary(summary_md: Path, matches: list[MatchItem], questions_total: int, modules_total: int) -> None:
    summary_md.parent.mkdir(parents=True, exist_ok=True)
    confidence_counter: dict[str, int] = {"alta": 0, "media": 0, "baixa": 0}
    tipo_counter: dict[str, int] = {"direto": 0, "relacionado": 0, "interdisciplinar": 0}
    module_counter: dict[str, int] = {}

    for match in matches:
        confidence_counter[match.confianca] = confidence_counter.get(match.confianca, 0) + 1
        tipo_counter[match.tipo_match] = tipo_counter.get(match.tipo_match, 0) + 1
        module_key = f"{match.module.materia} | V{match.module.volume} M{match.module.modulo}"
        module_counter[module_key] = module_counter.get(module_key, 0) + 1

    lines: list[str] = []
    lines.append("# Resumo — Intercorrelacao Modulo x Questao")
    lines.append("")
    lines.append(f"- Questoes analisadas: **{questions_total}**")
    lines.append(f"- Modulos com conteudo analisados: **{modules_total}**")
    lines.append(f"- Vinculos gerados: **{len(matches)}**")
    lines.append("")
    lines.append("## Distribuicao por confianca")
    lines.append("")
    lines.append(f"- alta: **{confidence_counter.get('alta', 0)}**")
    lines.append(f"- media: **{confidence_counter.get('media', 0)}**")
    lines.append(f"- baixa: **{confidence_counter.get('baixa', 0)}**")
    lines.append("")
    lines.append("## Distribuicao por tipo de match")
    lines.append("")
    lines.append(f"- direto: **{tipo_counter.get('direto', 0)}**")
    lines.append(f"- relacionado: **{tipo_counter.get('relacionado', 0)}**")
    lines.append(f"- interdisciplinar: **{tipo_counter.get('interdisciplinar', 0)}**")
    lines.append("")
    lines.append("## Top modulos por quantidade de vinculos")
    lines.append("")
    lines.append("| Modulo | Vinculos |")
    lines.append("|---|---:|")
    for module_key, count in sorted(module_counter.items(), key=lambda item: (-item[1], item[0]))[:20]:
        lines.append(f"| {module_key} | {count} |")
    lines.append("")

    summary_md.write_text("\n".join(lines), encoding="utf-8")


def ensure_files_exist(*paths: Path) -> None:
    for path in paths:
        if not path.exists():
            raise FileNotFoundError(f"Arquivo nao encontrado: {path}")


def main() -> int:
    args = parse_args()
    ensure_files_exist(args.questions_csv, args.modules_csv)

    tag_rules = load_tags(args.tags_csv)
    modules = load_modules(args.modules_csv, tag_rules)
    questions = load_questions(
        args.questions_csv,
        tag_rules=tag_rules,
        year_from=args.year_from,
        year_to=args.year_to,
    )
    matches = build_matches(
        questions=questions,
        modules=modules,
        min_score=max(0.0, min(args.min_score, 1.0)),
        max_matches_per_question=max(args.max_matches_per_question, 1),
    )

    write_matches_csv(args.out_csv, matches)
    write_summary(
        summary_md=args.summary_md,
        matches=matches,
        questions_total=len(questions),
        modules_total=len(modules),
    )

    print(f"[ok] tags canonicas carregadas: {len(tag_rules)}")
    print(f"[ok] modulos com conteudo: {len(modules)}")
    print(f"[ok] questoes consideradas: {len(questions)}")
    print(f"[ok] matches gerados: {len(matches)}")
    print(f"[ok] csv: {args.out_csv}")
    print(f"[ok] resumo: {args.summary_md}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
