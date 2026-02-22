#!/usr/bin/env python3
"""Extrai questões reais do ENEM (PDF) e gera banco em Markdown.

Uso típico:
  python3 scripts/extrair_banco_enem_real.py \
    --ano 2025 \
    --dia 1 \
    --prova 'questoes/provas anteriores/prova_dia_1_2025.pdf' \
    --gabarito 'questoes/provas anteriores/prova_dia_1_2025_gabarito.pdf' \
    --outdir 'questoes/banco_reais/enem_2025'
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any

QUESTION_PATTERN = re.compile(r"(?m)^Questão\s+(\d{1,3})\s*$")
DATE_TIME_PATTERN = re.compile(r"\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2}")


@dataclass
class QuestionRecord:
    numero: int
    variacao: int
    area: str
    gabarito: Any
    texto_markdown: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extrai questões reais do ENEM para Markdown.")
    parser.add_argument("--ano", type=int, required=True, help="Ano da prova (ex.: 2025)")
    parser.add_argument("--dia", type=int, choices=[1, 2], required=True, help="Dia da prova")
    parser.add_argument("--prova", type=Path, required=True, help="PDF do caderno de prova")
    parser.add_argument("--gabarito", type=Path, required=True, help="PDF do gabarito")
    parser.add_argument("--outdir", type=Path, required=True, help="Diretório de saída")
    return parser.parse_args()


def read_pdf_text(pdf_path: Path, *, layout: bool = False) -> str:
    command = ["pdftotext"]
    if layout:
        command.append("-layout")
    command.extend([str(pdf_path), "-"])
    completed = subprocess.run(command, capture_output=True, text=True, check=True)
    return completed.stdout


def reflow_multicolumn_pages(layout_text: str) -> str:
    pages = layout_text.split("\f")
    output_pages: list[str] = []

    for page in pages:
        lines = page.splitlines()
        if not lines:
            continue

        max_line_length = max((len(line) for line in lines), default=0)
        if max_line_length < 280:
            output_pages.append("\n".join(lines))
            continue

        split_at = max_line_length // 2
        left_column: list[str] = []
        right_column: list[str] = []

        for line in lines:
            left_part = line[:split_at].strip()
            right_part = line[split_at:].strip()
            if left_part:
                left_column.append(left_part)
            if right_part:
                right_column.append(right_part)

        merged_page = "\n".join(left_column + [""] + right_column)
        output_pages.append(merged_page)

    return "\n\n".join(output_pages)


def read_exam_text(pdf_path: Path) -> str:
    layout_text = read_pdf_text(pdf_path, layout=True)
    return reflow_multicolumn_pages(layout_text)


def should_drop_line(line: str) -> bool:
    stripped = line.strip()
    if not stripped:
        return False

    if "ENEM2025ENEM2025" in stripped:
        return True
    if stripped.startswith("*") and stripped.endswith("*") and len(stripped) > 5:
        return True
    if ".indb" in stripped:
        return True
    if DATE_TIME_PATTERN.search(stripped):
        return True
    if re.fullmatch(r"\d+", stripped):
        return True
    if stripped in {"2025", "ENEN2"}:
        return True
    if re.fullmatch(r"ENEM\d*|ENEN\d*", stripped):
        return True

    header_snippets = (
        "| 1º DIA | CADERNO",
        "| 2º DIA | CADERNO",
        "| 1º DIA",
        "| 2º DIA",
        "CADERNO 1 | AZUL",
        "CADERNO 5 | AMARELO",
        "1º Dia",
        "2º DIA",
        "Capa",
        "Azul 1",
        "relo 2",
        "nco 3",
        "rde 4",
        "1diaº",
        "2diaº",
    )
    if any(snippet in stripped for snippet in header_snippets):
        return True

    if stripped.startswith("Questões de 01 a 05"):
        return True

    return False


def clean_text(raw_text: str) -> str:
    normalized = raw_text.replace("\f", "\n")
    cleaned_lines: list[str] = []

    for raw_line in normalized.splitlines():
        line = raw_line.rstrip().replace("\uFFFD", "")
        if should_drop_line(line):
            continue

        stripped = line.strip()
        if not stripped:
            if cleaned_lines and cleaned_lines[-1] != "":
                cleaned_lines.append("")
            continue

        cleaned_lines.append(stripped)

    return "\n".join(cleaned_lines).strip() + "\n"


def split_question_blocks(cleaned_text: str) -> list[tuple[int, str]]:
    matches = list(QUESTION_PATTERN.finditer(cleaned_text))
    blocks: list[tuple[int, str]] = []

    for index, match in enumerate(matches):
        number = int(match.group(1))
        start = match.start()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(cleaned_text)
        block = cleaned_text[start:end].strip()
        if block:
            blocks.append((number, block))

    return blocks


def parse_day1_gabarito(gabarito_text: str) -> dict[int, Any]:
    answers: dict[int, Any] = {}

    for raw_line in gabarito_text.splitlines():
        line = raw_line.strip()
        if not line:
            continue

        tokens = line.split()
        if not tokens or not tokens[0].isdigit():
            continue

        if len(tokens) == 5 and tokens[3].isdigit():
            left_q = int(tokens[0])
            answers[left_q] = {"ingles": tokens[1], "espanhol": tokens[2]}

            right_q = int(tokens[3])
            answers[right_q] = tokens[4]
            continue

        if len(tokens) == 4 and tokens[2].isdigit():
            left_q = int(tokens[0])
            answers[left_q] = tokens[1]

            right_q = int(tokens[2])
            answers[right_q] = tokens[3]

    return answers


def parse_day2_gabarito(gabarito_text: str) -> dict[int, str]:
    answers: dict[int, str] = {}

    for raw_line in gabarito_text.splitlines():
        line = raw_line.strip()
        if not line:
            continue

        match = re.match(r"^(\d{2,3})\s+(Anulado|[A-E])\s+(\d{2,3})\s+(Anulado|[A-E])$", line)
        if not match:
            continue

        left_q = int(match.group(1))
        left_answer = match.group(2)
        right_q = int(match.group(3))
        right_answer = match.group(4)

        answers[left_q] = left_answer
        answers[right_q] = right_answer

    return answers


def infer_area(day: int, question_number: int) -> str:
    if day == 1:
        if 1 <= question_number <= 45:
            return "Linguagens"
        if 46 <= question_number <= 90:
            return "Ciências Humanas"
    if day == 2:
        if 91 <= question_number <= 135:
            return "Ciências da Natureza"
        if 136 <= question_number <= 180:
            return "Matemática"

    return "Área não identificada"


def format_question_block(block: str) -> str:
    lines = block.splitlines()
    if not lines:
        return ""

    body_lines = lines[1:]
    options_start_index = find_options_start_index(body_lines)
    formatted_lines: list[str] = []

    for index, line in enumerate(body_lines):
        stripped = line.strip()
        if not stripped:
            continue

        option_match = re.match(r"^([A-E])(?:\)|\.)?\s+(.*)$", stripped)
        if options_start_index is not None and index >= options_start_index and option_match:
            letter = option_match.group(1)
            text = option_match.group(2).strip()
            formatted_lines.append(f"- {letter}) {text}")
            continue

        formatted_lines.append(stripped)

    return "\n".join(formatted_lines).strip()


def find_options_start_index(lines: list[str]) -> int | None:
    """Detecta início do bloco de alternativas A-E.

    Regra prática: encontrar um 'A ...' com 'B ...' próximo
    e sequência B, C, D, E em ordem.
    """

    total = len(lines)
    for start in range(total):
        if not re.match(r"^A(?:\)|\.)?\s+", lines[start].strip()):
            continue

        next_positions: dict[str, int] = {}
        search_from = start + 1
        for letter in "BCDE":
            found = None
            for index in range(search_from, total):
                candidate = lines[index].strip()
                if re.match(rf"^{letter}(?:\)|\.)?\s+", candidate):
                    found = index
                    break
            if found is None:
                next_positions = {}
                break
            next_positions[letter] = found
            search_from = found + 1

        if not next_positions:
            continue

        # Se houver outro "A ..." antes do primeiro "B ...", o primeiro
        # candidato costuma ser parte do enunciado (ex.: "A perda...").
        first_b = next_positions["B"]
        has_second_a_before_b = any(
            re.match(r"^A(?:\)|\.)?\s+", lines[index].strip())
            for index in range(start + 1, first_b)
        )
        if has_second_a_before_b:
            continue

        if next_positions["B"] - start <= 7 and next_positions["E"] - start <= 35:
            return start

    return None


def format_gabarito(answer: Any) -> str:
    if answer is None:
        return "Não encontrado"
    if isinstance(answer, dict):
        english = answer.get("ingles", "?")
        spanish = answer.get("espanhol", "?")
        return f"Inglês: {english} | Espanhol: {spanish}"
    return str(answer)


def build_records(day: int, blocks: list[tuple[int, str]], answers: dict[int, Any]) -> list[QuestionRecord]:
    counter: defaultdict[int, int] = defaultdict(int)
    records: list[QuestionRecord] = []

    for number, block in blocks:
        counter[number] += 1
        variation = counter[number]

        area = infer_area(day, number)
        answer = answers.get(number)
        content = format_question_block(block)

        record = QuestionRecord(
            numero=number,
            variacao=variation,
            area=area,
            gabarito=answer,
            texto_markdown=content,
        )
        records.append(record)

    return records


def records_to_markdown(year: int, day: int, records: list[QuestionRecord]) -> str:
    lines: list[str] = []
    lines.append(f"# Banco ENEM {year} — Dia {day}")
    lines.append("")
    lines.append("Gerado automaticamente a partir do PDF oficial e gabarito oficial.")
    lines.append("")
    lines.append(f"Total de blocos extraídos: **{len(records)}**")
    lines.append("")

    for record in records:
        question_id = f"{record.numero:03d}"
        if record.variacao > 1:
            title = f"## Questão {question_id} (variação {record.variacao})"
        else:
            title = f"## Questão {question_id}"

        lines.append(title)
        lines.append("")
        lines.append(f"- Área: {record.area}")
        lines.append(f"- Gabarito: {format_gabarito(record.gabarito)}")
        lines.append("")
        lines.append(record.texto_markdown)
        lines.append("")

    return "\n".join(lines).strip() + "\n"


def records_to_index_json(records: list[QuestionRecord]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []

    for record in records:
        result.append(
            {
                "numero": record.numero,
                "variacao": record.variacao,
                "area": record.area,
                "gabarito": record.gabarito,
                "preview": record.texto_markdown.splitlines()[0] if record.texto_markdown else "",
            }
        )

    return result


def write_output_files(
    output_dir: Path,
    day: int,
    cleaned_text: str,
    answers: dict[int, Any],
    records: list[QuestionRecord],
    markdown_content: str,
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    cleaned_path = output_dir / f"dia{day}_texto_limpo.txt"
    answers_path = output_dir / f"dia{day}_gabarito.json"
    index_path = output_dir / f"dia{day}_questoes_index.json"
    markdown_path = output_dir / f"dia{day}_questoes_reais.md"

    cleaned_path.write_text(cleaned_text, encoding="utf-8")
    answers_path.write_text(json.dumps(answers, ensure_ascii=False, indent=2), encoding="utf-8")
    index_path.write_text(
        json.dumps(records_to_index_json(records), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    markdown_path.write_text(markdown_content, encoding="utf-8")


def main() -> int:
    args = parse_args()

    if not args.prova.exists():
        raise FileNotFoundError(f"PDF da prova não encontrado: {args.prova}")
    if not args.gabarito.exists():
        raise FileNotFoundError(f"PDF do gabarito não encontrado: {args.gabarito}")

    prova_raw_text = read_exam_text(args.prova)
    gabarito_raw_text = read_pdf_text(args.gabarito, layout=True)

    cleaned_text = clean_text(prova_raw_text)
    question_blocks = split_question_blocks(cleaned_text)

    if args.dia == 1:
        answers = parse_day1_gabarito(gabarito_raw_text)
    else:
        answers = parse_day2_gabarito(gabarito_raw_text)

    records = build_records(args.dia, question_blocks, answers)
    markdown_content = records_to_markdown(args.ano, args.dia, records)

    write_output_files(args.outdir, args.dia, cleaned_text, answers, records, markdown_content)

    print(f"[ok] Dia {args.dia}: {len(records)} blocos extraídos")
    print(f"[ok] Saída: {args.outdir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
