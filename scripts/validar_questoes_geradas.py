#!/usr/bin/env python3
"""Valida lotes JSONL de questoes geradas para manter contrato minimo."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from difflib import SequenceMatcher
import json
from pathlib import Path
import re
import sys
import unicodedata


EXPECTED_ALTERNATIVES = ("A", "B", "C", "D", "E")
ALLOWED_TYPES = {"treino", "simulado", "redacao"}
ALLOWED_DIFFICULTIES = {"facil", "media", "dificil"}
ALLOWED_REVIEW_STATUS = {"rascunho", "revisado", "aprovado", "publicado"}
REQUIRED_FIELDS = (
    "id",
    "area",
    "disciplina",
    "materia",
    "tipo",
    "enunciado",
    "alternativas",
    "gabarito",
    "explicacao",
    "competencia",
    "habilidade",
    "dificuldade",
    "tags",
    "fontes",
)
COMPETENCY_RE = re.compile(r"^C[0-9]{1,2}$")
SKILL_RE = re.compile(r"^H[0-9]{1,3}$")


@dataclass(slots=True)
class FileValidationResult:
    path: Path
    total_lines: int = 0
    valid_lines: int = 0
    invalid_lines: int = 0
    facil_count: int = 0
    media_count: int = 0
    dificil_count: int = 0
    similarity_flags: int = 0


@dataclass(slots=True)
class RealQuestionSnippet:
    id_questao: str
    area: str
    disciplina: str
    preview: str
    preview_normalized: str


@dataclass(slots=True)
class SimilarityMatch:
    id_questao: str
    sequence_ratio: float
    jaccard: float
    containment: float
    preview: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Valida schema minimo de lotes JSONL em questoes/generateds.",
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=Path("questoes/generateds"),
        help="Arquivo .jsonl ou diretorio para varrer recursivamente.",
    )
    parser.add_argument(
        "--summary-md",
        type=Path,
        default=None,
        help="Arquivo markdown opcional com resumo da validacao.",
    )
    parser.add_argument(
        "--max-errors",
        type=int,
        default=100,
        help="Limite de erros detalhados exibidos no terminal.",
    )
    parser.add_argument(
        "--expected-distribution",
        type=str,
        default="",
        help=(
            "Distribuicao esperada de dificuldade no formato facil,media,dificil "
            "(ex.: 5,3,2)."
        ),
    )
    parser.add_argument(
        "--real-questions-csv",
        type=Path,
        default=Path("questoes/mapeamento_habilidades/questoes_metadados_consolidados.csv"),
        help="CSV da base real para detector de similaridade.",
    )
    parser.add_argument(
        "--skip-similarity-check",
        action="store_true",
        help="Desativa detector de similaridade com base real.",
    )
    parser.add_argument(
        "--similarity-threshold",
        type=float,
        default=0.88,
        help="Threshold minimo de SequenceMatcher para marcar similaridade suspeita.",
    )
    parser.add_argument(
        "--jaccard-threshold",
        type=float,
        default=0.66,
        help="Threshold minimo de Jaccard para marcar similaridade suspeita.",
    )
    parser.add_argument(
        "--max-real-snippets",
        type=int,
        default=0,
        help="Limita quantidade de snippets reais carregados (0=todos).",
    )
    parser.add_argument(
        "--require-approved",
        action="store_true",
        help="Exige gate editorial de publicacao: review_status=aprovado + reviewed_by + approved_at.",
    )
    return parser.parse_args()


def iter_jsonl_files(input_path: Path) -> list[Path]:
    if input_path.is_file():
        return [input_path]
    if input_path.is_dir():
        return sorted(input_path.rglob("*.jsonl"))
    raise FileNotFoundError(f"Caminho nao encontrado: {input_path}")


def ensure_non_empty_string(value: object, field_name: str, errors: list[str]) -> None:
    if not isinstance(value, str) or not value.strip():
        errors.append(f"campo `{field_name}` deve ser string nao vazia")


def validate_alternatives(
    alternatives: object,
    errors: list[str],
) -> None:
    if not isinstance(alternatives, dict):
        errors.append("campo `alternativas` deve ser objeto com A-E")
        return

    for key in EXPECTED_ALTERNATIVES:
        option_value = alternatives.get(key)
        if not isinstance(option_value, str) or not option_value.strip():
            errors.append(f"alternativa `{key}` ausente ou vazia")


def validate_tags(tags: object, errors: list[str]) -> None:
    if not isinstance(tags, list) or not tags:
        errors.append("campo `tags` deve ser lista nao vazia")
        return
    for tag in tags:
        if not isinstance(tag, str) or not tag.strip():
            errors.append("todas as tags devem ser strings nao vazias")
            break


def validate_sources(sources: object, errors: list[str]) -> None:
    if not isinstance(sources, list) or not sources:
        errors.append("campo `fontes` deve ser lista nao vazia")
        return

    for source in sources:
        if isinstance(source, str) and source.strip():
            continue
        if isinstance(source, dict):
            title = source.get("titulo")
            if isinstance(title, str) and title.strip():
                continue
        errors.append("cada item de `fontes` deve ser string ou objeto com `titulo`")
        break


def validate_record(record: object, require_approved: bool = False) -> list[str]:
    errors: list[str] = []
    if not isinstance(record, dict):
        return ["linha nao contem JSON objeto"]

    for field_name in REQUIRED_FIELDS:
        if field_name not in record:
            errors.append(f"campo obrigatorio ausente: `{field_name}`")

    for field_name in ("id", "area", "disciplina", "materia", "enunciado", "explicacao"):
        if field_name in record:
            ensure_non_empty_string(record[field_name], field_name, errors)

    question_type = record.get("tipo")
    if question_type not in ALLOWED_TYPES:
        errors.append("campo `tipo` invalido; use treino/simulado/redacao")

    difficulty = record.get("dificuldade")
    if difficulty not in ALLOWED_DIFFICULTIES:
        errors.append("campo `dificuldade` invalido; use facil/media/dificil")

    answer = record.get("gabarito")
    if answer not in EXPECTED_ALTERNATIVES:
        errors.append("campo `gabarito` invalido; use A, B, C, D ou E")

    competency = record.get("competencia", "")
    if not isinstance(competency, str) or not COMPETENCY_RE.match(competency):
        errors.append("campo `competencia` invalido; esperado formato Cn")

    skill = record.get("habilidade", "")
    if not isinstance(skill, str) or not SKILL_RE.match(skill):
        errors.append("campo `habilidade` invalido; esperado formato Hn")

    validate_alternatives(record.get("alternativas"), errors)
    validate_tags(record.get("tags"), errors)
    validate_sources(record.get("fontes"), errors)

    review_status = record.get("review_status")
    if review_status and review_status not in ALLOWED_REVIEW_STATUS:
        errors.append("campo `review_status` invalido")
    if require_approved:
        if review_status != "aprovado":
            errors.append("gate de publicacao: `review_status` deve ser `aprovado`")
        reviewed_by = record.get("reviewed_by")
        approved_at = record.get("approved_at")
        if not isinstance(reviewed_by, str) or not reviewed_by.strip():
            errors.append("gate de publicacao: `reviewed_by` obrigatorio")
        if not isinstance(approved_at, str) or not approved_at.strip():
            errors.append("gate de publicacao: `approved_at` obrigatorio")

    return errors


def parse_expected_distribution(raw_value: str) -> tuple[int, int, int] | None:
    if not raw_value.strip():
        return None

    parts = [chunk.strip() for chunk in raw_value.split(",")]
    if len(parts) != 3:
        raise ValueError("distribuicao invalida; use o formato facil,media,dificil (ex.: 5,3,2)")

    try:
        parsed = tuple(int(part) for part in parts)
    except ValueError as exc:
        raise ValueError("distribuicao invalida; todos os valores devem ser inteiros") from exc

    if any(value < 0 for value in parsed):
        raise ValueError("distribuicao invalida; valores negativos nao sao permitidos")
    return parsed


def strip_diacritics(raw_text: str) -> str:
    normalized = unicodedata.normalize("NFKD", raw_text)
    return "".join(ch for ch in normalized if not unicodedata.combining(ch))


def normalize_text_for_similarity(raw_text: str) -> str:
    base = strip_diacritics(raw_text).casefold()
    base = base.replace("...", " ")
    base = re.sub(r"[^a-z0-9]+", " ", base)
    base = re.sub(r"\s+", " ", base).strip()
    return base


def normalize_area_key(raw_value: str) -> str:
    normalized = normalize_text_for_similarity(raw_value)
    if "linguagens" in normalized:
        return "linguagens"
    if "human" in normalized:
        return "humanas"
    if "natureza" in normalized:
        return "natureza"
    if "matemat" in normalized:
        return "matematica"
    return normalized


def build_real_question_id(row: dict[str, str], fallback_index: int) -> str:
    direct_id = (row.get("id_questao") or "").strip()
    if direct_id:
        return direct_id
    year = (row.get("ano") or "").strip()
    day = (row.get("dia") or "").strip()
    number = (row.get("numero") or "").strip()
    if year and day and number:
        return f"{year}-d{day}-q{number.zfill(3)}"
    return f"real_{fallback_index:05d}"


def load_real_question_snippets(
    csv_path: Path,
    max_snippets: int,
) -> list[RealQuestionSnippet]:
    if not csv_path.exists():
        raise FileNotFoundError(f"CSV real nao encontrado: {csv_path}")

    snippets: list[RealQuestionSnippet] = []
    with csv_path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for index, row in enumerate(reader, start=1):
            preview = (row.get("preview") or row.get("enunciado") or "").strip()
            normalized_preview = normalize_text_for_similarity(preview)
            if len(normalized_preview) < 32:
                continue

            snippets.append(
                RealQuestionSnippet(
                    id_questao=build_real_question_id(row, index),
                    area=normalize_area_key(row.get("area", "")),
                    disciplina=normalize_text_for_similarity(row.get("disciplina", "")),
                    preview=preview,
                    preview_normalized=normalized_preview,
                ),
            )
            if max_snippets > 0 and len(snippets) >= max_snippets:
                break

    return snippets


def compute_jaccard(tokens_a: set[str], tokens_b: set[str]) -> float:
    union = tokens_a | tokens_b
    if not union:
        return 0.0
    return len(tokens_a & tokens_b) / len(union)


def compute_containment(source_tokens: set[str], target_tokens: set[str]) -> float:
    if not target_tokens:
        return 0.0
    return len(source_tokens & target_tokens) / len(target_tokens)


def detect_similarity_match(
    enunciado: str,
    area: str,
    disciplina: str,
    snippets: list[RealQuestionSnippet],
    similarity_threshold: float,
    jaccard_threshold: float,
) -> SimilarityMatch | None:
    normalized_enunciado = normalize_text_for_similarity(enunciado)
    if len(normalized_enunciado) < 32 or not snippets:
        return None

    area_key = normalize_area_key(area)
    disciplina_key = normalize_text_for_similarity(disciplina)

    candidates = [item for item in snippets if item.area == area_key]
    if disciplina_key:
        discipline_candidates = [item for item in candidates if item.disciplina == disciplina_key]
        if discipline_candidates:
            candidates = discipline_candidates
    if not candidates:
        candidates = snippets

    enunciado_tokens = set(normalized_enunciado.split())
    best_match: SimilarityMatch | None = None
    best_rank = -1.0

    for candidate in candidates:
        candidate_text = candidate.preview_normalized
        if not candidate_text:
            continue

        candidate_tokens = set(candidate_text.split())
        sequence_ratio = SequenceMatcher(None, normalized_enunciado, candidate_text).ratio()
        jaccard = compute_jaccard(enunciado_tokens, candidate_tokens)
        containment = compute_containment(enunciado_tokens, candidate_tokens)
        has_substring = candidate_text in normalized_enunciado and len(candidate_text) >= 40
        is_suspicious = (
            has_substring
            or sequence_ratio >= similarity_threshold
            or (
                jaccard >= jaccard_threshold
                and containment >= 0.75
                and len(enunciado_tokens & candidate_tokens) >= 10
            )
        )
        if not is_suspicious:
            continue

        rank = max(sequence_ratio, jaccard, containment * 0.95)
        if rank <= best_rank:
            continue

        best_rank = rank
        best_match = SimilarityMatch(
            id_questao=candidate.id_questao,
            sequence_ratio=sequence_ratio,
            jaccard=jaccard,
            containment=containment,
            preview=candidate.preview,
        )

    return best_match


def validate_file(
    file_path: Path,
    max_errors: int,
    expected_distribution: tuple[int, int, int] | None,
    real_question_snippets: list[RealQuestionSnippet],
    similarity_threshold: float,
    jaccard_threshold: float,
    skip_similarity_check: bool,
    require_approved: bool,
) -> tuple[FileValidationResult, list[str]]:
    result = FileValidationResult(path=file_path)
    detailed_errors: list[str] = []

    for line_number, raw_line in enumerate(
        file_path.read_text(encoding="utf-8").splitlines(),
        start=1,
    ):
        if not raw_line.strip():
            continue
        result.total_lines += 1
        try:
            record = json.loads(raw_line)
        except json.JSONDecodeError as exc:
            result.invalid_lines += 1
            if len(detailed_errors) < max_errors:
                detailed_errors.append(
                    f"{file_path}:{line_number}: JSON invalido ({exc.msg})",
                )
            continue

        if isinstance(record, dict):
            difficulty = record.get("dificuldade")
            if difficulty == "facil":
                result.facil_count += 1
            elif difficulty == "media":
                result.media_count += 1
            elif difficulty == "dificil":
                result.dificil_count += 1

        line_errors = validate_record(record, require_approved=require_approved)
        if isinstance(record, dict) and not skip_similarity_check:
            similarity_match = detect_similarity_match(
                enunciado=str(record.get("enunciado", "")),
                area=str(record.get("area", "")),
                disciplina=str(record.get("disciplina", "")),
                snippets=real_question_snippets,
                similarity_threshold=similarity_threshold,
                jaccard_threshold=jaccard_threshold,
            )
            if similarity_match is not None:
                result.similarity_flags += 1
                line_errors.append(
                    (
                        "similaridade suspeita com base real "
                        f"(id={similarity_match.id_questao}, "
                        f"seq={similarity_match.sequence_ratio:.3f}, "
                        f"jaccard={similarity_match.jaccard:.3f}, "
                        f"containment={similarity_match.containment:.3f})"
                    ),
                )

        if line_errors:
            result.invalid_lines += 1
            if len(detailed_errors) < max_errors:
                detail = "; ".join(line_errors)
                detailed_errors.append(f"{file_path}:{line_number}: {detail}")
        else:
            result.valid_lines += 1

    if expected_distribution is not None:
        actual_distribution = (result.facil_count, result.media_count, result.dificil_count)
        if actual_distribution != expected_distribution:
            result.invalid_lines += 1
            expected_text = ",".join(str(value) for value in expected_distribution)
            actual_text = ",".join(str(value) for value in actual_distribution)
            detailed_errors.append(
                (
                    f"{file_path}:0: distribuicao de dificuldade fora do esperado "
                    f"(esperado {expected_text}; encontrado {actual_text})"
                ),
            )

    return result, detailed_errors


def write_summary_markdown(
    output_path: Path,
    file_results: list[FileValidationResult],
    total_files: int,
    total_records: int,
    total_invalid: int,
) -> None:
    lines = [
        "# Relatorio de validacao de questoes geradas",
        "",
        f"- Arquivos validados: **{total_files}**",
        f"- Registros processados: **{total_records}**",
        f"- Registros invalidos: **{total_invalid}**",
        "",
        "| Arquivo | Registros | Validos | Invalidos | Similaridade suspeita |",
        "|---|---:|---:|---:|---:|",
    ]

    for result in file_results:
        relative_path = result.path.as_posix()
        lines.append(
            (
                f"| `{relative_path}` | {result.total_lines} | {result.valid_lines} | "
                f"{result.invalid_lines} | {result.similarity_flags} |"
            ),
        )

    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    try:
        expected_distribution = parse_expected_distribution(args.expected_distribution)
    except ValueError as exc:
        print(f"[erro] {exc}")
        return 2

    if not 0.0 <= args.similarity_threshold <= 1.0:
        print("[erro] --similarity-threshold deve ficar entre 0 e 1.")
        return 2
    if not 0.0 <= args.jaccard_threshold <= 1.0:
        print("[erro] --jaccard-threshold deve ficar entre 0 e 1.")
        return 2

    real_question_snippets: list[RealQuestionSnippet] = []
    if not args.skip_similarity_check:
        try:
            real_question_snippets = load_real_question_snippets(
                csv_path=args.real_questions_csv,
                max_snippets=args.max_real_snippets,
            )
        except FileNotFoundError as exc:
            print(f"[erro] {exc}")
            return 2
        if not real_question_snippets:
            print(
                "[erro] nenhum snippet de base real foi carregado; "
                "use --skip-similarity-check ou ajuste --real-questions-csv.",
            )
            return 2

    try:
        jsonl_files = iter_jsonl_files(args.input)
    except FileNotFoundError as exc:
        print(f"[erro] {exc}")
        return 2

    if not jsonl_files:
        print("[erro] nenhum arquivo .jsonl encontrado.")
        return 2

    all_errors: list[str] = []
    all_results: list[FileValidationResult] = []
    total_records = 0
    total_invalid = 0

    for jsonl_file in jsonl_files:
        result, file_errors = validate_file(
            file_path=jsonl_file,
            max_errors=args.max_errors,
            expected_distribution=expected_distribution,
            real_question_snippets=real_question_snippets,
            similarity_threshold=args.similarity_threshold,
            jaccard_threshold=args.jaccard_threshold,
            skip_similarity_check=args.skip_similarity_check,
            require_approved=args.require_approved,
        )
        all_results.append(result)
        all_errors.extend(file_errors)
        total_records += result.total_lines
        total_invalid += result.invalid_lines

    print(
        "[resumo] arquivos={} registros={} invalidos={}".format(
            len(jsonl_files),
            total_records,
            total_invalid,
        ),
    )

    if all_errors:
        print("[detalhes] erros encontrados:")
        for error_line in all_errors[: args.max_errors]:
            print(f"- {error_line}")
        if len(all_errors) > args.max_errors:
            hidden = len(all_errors) - args.max_errors
            print(f"- ... {hidden} erro(s) adicional(is) nao exibido(s)")

    if args.summary_md:
        write_summary_markdown(
            output_path=args.summary_md,
            file_results=all_results,
            total_files=len(jsonl_files),
            total_records=total_records,
            total_invalid=total_invalid,
        )
        print(f"[ok] resumo markdown salvo em {args.summary_md}")

    return 0 if total_invalid == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
