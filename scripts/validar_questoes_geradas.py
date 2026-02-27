#!/usr/bin/env python3
"""Valida lotes JSONL de questoes geradas para manter contrato minimo."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
from pathlib import Path
import re
import sys


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


def validate_record(record: object) -> list[str]:
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

    return errors


def validate_file(file_path: Path, max_errors: int) -> tuple[FileValidationResult, list[str]]:
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

        line_errors = validate_record(record)
        if line_errors:
            result.invalid_lines += 1
            if len(detailed_errors) < max_errors:
                detail = "; ".join(line_errors)
                detailed_errors.append(f"{file_path}:{line_number}: {detail}")
        else:
            result.valid_lines += 1

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
        "| Arquivo | Registros | Validos | Invalidos |",
        "|---|---:|---:|---:|",
    ]

    for result in file_results:
        relative_path = result.path.as_posix()
        lines.append(
            f"| `{relative_path}` | {result.total_lines} | {result.valid_lines} | {result.invalid_lines} |",
        )

    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()

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
        result, file_errors = validate_file(jsonl_file, args.max_errors)
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
