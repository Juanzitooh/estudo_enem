#!/usr/bin/env python3
"""Valida requisitos minimos das aulas por modulo em Markdown."""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path

DEFAULT_GLOB = "aulas/*/modulos/*.md"

REQUIRED_HEADINGS = [
    "## Metadados editoriais",
    "## 1. Ficha do módulo",
    "## 2. Objetivo pedagógico do módulo",
    "### 2.1 O que deve ser aprendido",
    "## 3. Contexto brasileiro e atualidade (últimos 12 meses)",
    "## 4. Explicação do módulo (didática e objetiva)",
    "## 5. Exemplos práticos contextualizados (mínimo 2)",
    "## 6. Problema real aplicado (estudo de caso)",
    "## 8. Checagem de entendimento (5–10 perguntas curtas)",
    "## 9. Bloco fixo de questões contextualizadas por módulo",
    "## 10. Erros comuns e como revisar",
    "## 11. Aprofundamento opcional",
    "## 12. Fechamento e CTA para treino relacionado",
]

EDITORIAL_FIELDS = [
    "**Status editorial:**",
    "**Atualizado por IA em:**",
    "**Revisado manualmente em:**",
    "**Revisado por:**",
    "`ia_updated_at`:",
    "`manual_reviewed_at`:",
    "`manual_reviewed_by`:",
]

PLACEHOLDER_PATTERN = re.compile(r"\{[^{}\n]+\}")
NUMBERED_ITEM_PATTERN = re.compile(r"^\d+\.\s")
QUESTION_PATTERN = re.compile(r"^\*\*Q\d+\b")
EXAMPLE_PATTERN = re.compile(r"^### Exemplo\s+\d+")


@dataclass
class ValidationResult:
    file_path: Path
    score: int
    total: int
    passed: bool
    errors: list[str]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Valida estrutura minima das aulas por modulo."
    )
    parser.add_argument(
        "--input-glob",
        default=DEFAULT_GLOB,
        help="Padrao glob para localizar arquivos markdown de aula.",
    )
    parser.add_argument(
        "--allow-placeholders",
        action="store_true",
        help="Permite placeholders {...} no texto (rascunho).",
    )
    parser.add_argument(
        "--report-md",
        type=Path,
        default=None,
        help="Caminho opcional para salvar relatorio em markdown.",
    )
    return parser.parse_args()


def section_slice(lines: list[str], start_prefix: str, end_prefix: str | None) -> list[str]:
    start_index = -1
    for index, line in enumerate(lines):
        if line.startswith(start_prefix):
            start_index = index
            break

    if start_index < 0:
        return []

    end_index = len(lines)
    if end_prefix:
        for index in range(start_index + 1, len(lines)):
            if lines[index].startswith(end_prefix):
                end_index = index
                break

    return lines[start_index + 1 : end_index]


def validate_file(file_path: Path, allow_placeholders: bool) -> ValidationResult:
    text = file_path.read_text(encoding="utf-8")
    lines = text.splitlines()
    errors: list[str] = []

    score = 0
    total = 6

    missing_headings = [heading for heading in REQUIRED_HEADINGS if heading not in text]
    if missing_headings:
        errors.append(f"secoes obrigatorias ausentes: {len(missing_headings)}")
    else:
        score += 1

    missing_fields = [field for field in EDITORIAL_FIELDS if field not in text]
    if missing_fields:
        errors.append(f"campos editoriais ausentes: {len(missing_fields)}")
    else:
        score += 1

    examples_found = sum(1 for line in lines if EXAMPLE_PATTERN.match(line.strip()))
    if examples_found < 2:
        errors.append("menos de 2 exemplos praticos")
    else:
        score += 1

    section_8 = section_slice(lines, "## 8.", "## 9.")
    section_8_count = sum(
        1 for line in section_8 if NUMBERED_ITEM_PATTERN.match(line.strip())
    )
    if section_8_count < 5 or section_8_count > 10:
        errors.append("checagem final fora do intervalo 5-10")
    else:
        score += 1

    section_91 = section_slice(lines, "### 9.1", "### 9.2")
    questions_count = sum(1 for line in section_91 if QUESTION_PATTERN.match(line.strip()))
    if questions_count < 6:
        errors.append("bloco 9.1 com menos de 6 questoes")
    else:
        score += 1

    if allow_placeholders:
        score += 1
    else:
        unresolved = PLACEHOLDER_PATTERN.findall(text)
        if unresolved:
            errors.append("placeholders nao resolvidos detectados")
        else:
            score += 1

    passed = not errors
    return ValidationResult(
        file_path=file_path,
        score=score,
        total=total,
        passed=passed,
        errors=errors,
    )


def render_report(results: list[ValidationResult]) -> str:
    lines: list[str] = []
    lines.append("# Relatorio de validacao de aulas por modulo")
    lines.append("")
    lines.append("| Arquivo | Score | Status | Observacoes |")
    lines.append("|---|---:|---|---|")

    for result in results:
        status = "ok" if result.passed else "falhou"
        notes = "; ".join(result.errors) if result.errors else "-"
        lines.append(
            f"| `{result.file_path}` | {result.score}/{result.total} | {status} | {notes} |"
        )

    total_files = len(results)
    passed_files = sum(1 for result in results if result.passed)
    lines.append("")
    lines.append(f"- Total de arquivos: {total_files}")
    lines.append(f"- Aprovados: {passed_files}")
    lines.append(f"- Reprovados: {total_files - passed_files}")

    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()

    files = sorted(Path(".").glob(args.input_glob))
    if not files:
        print(f"[erro] nenhum arquivo encontrado para o padrao: {args.input_glob}")
        return 1

    results = [validate_file(path, allow_placeholders=args.allow_placeholders) for path in files]

    for result in results:
        status = "OK" if result.passed else "FALHOU"
        print(f"[{status}] {result.file_path} ({result.score}/{result.total})")
        for error in result.errors:
            print(f"  - {error}")

    if args.report_md:
        report_content = render_report(results)
        args.report_md.parent.mkdir(parents=True, exist_ok=True)
        args.report_md.write_text(report_content, encoding="utf-8")
        print(f"[ok] relatorio salvo em {args.report_md}")

    return 0 if all(result.passed for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
