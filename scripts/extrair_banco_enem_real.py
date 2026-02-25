#!/usr/bin/env python3
"""Extrai questões reais do ENEM (PDF) e gera banco em Markdown.

Uso típico:
  python3 scripts/extrair_banco_enem_real.py \
    --ano 2025 \
    --dia 1 \
    --prova 'questoes/provas_anteriores/2025_dia1_prova.pdf' \
    --gabarito 'questoes/provas_anteriores/2025_dia1_gabarito.pdf' \
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

QUESTION_PATTERN = re.compile(r"(?i)\bQUEST[ÃA]O\s+(\d{1,3})\b")
DATE_TIME_PATTERN = re.compile(r"\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2}")
CONTROL_CHAR_PATTERN = re.compile(r"[\x00-\x08\x0B-\x1F\x7F]")
REPEATED_ENEM_BANNER_PATTERN = re.compile(r"(?:\bENEM\s*\d{4}\b[\s|]*){2,}", re.IGNORECASE)
REDACAO_PATTERN = re.compile(r"(?im)^PROPOSTA DE REDA[ÇC][AÃ]O\b")
REDACAO_END_HINT_PATTERN = re.compile(
    r"(?im)^QUEST[ÕO]ES DE\s+\d{1,3}\s+A\s+\d{1,3}\b|"
    r"^CI[ÊE]NCIAS HUMANAS\b|"
    r"^CI[ÊE]NCIAS HUMANAS E SUAS TECNOLOGIAS\b|"
    r"^LC\s*-\s*1[ºo]?\s*dia\b|"
    r"^CH\s*-\s*1[ºo]?\s*dia\b|"
    r"^PROVA DE CI[ÊE]NCIAS HUMANAS E SUAS TECNOLOGIAS\b"
)
REDACAO_INSTRUCTIONS_PATTERN = re.compile(r"(?i)^INSTRU[ÇC][ÕO]ES PARA A REDA[ÇC][AÃ]O")


@dataclass
class QuestionRecord:
    numero: int
    variacao: int
    area: str
    gabarito: Any
    texto_markdown: str


@dataclass
class RedacaoRecord:
    tema: str | None
    texto_markdown: str


def normalize_answer(raw_value: str) -> str | None:
    value = raw_value.strip()
    if re.fullmatch(r"(?i)anulad[ao]", value):
        return "Anulado"
    if re.fullmatch(r"(?i)[A-E]", value):
        return value.upper()
    return None


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

    if re.search(r"(ENEM\d{4}){2,}", stripped):
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
    if REPEATED_ENEM_BANNER_PATTERN.search(stripped):
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


def sanitize_ocr_line(raw_line: str) -> str:
    line = raw_line.rstrip().replace("\uFFFD", "")
    line = CONTROL_CHAR_PATTERN.sub(" ", line)
    line = REPEATED_ENEM_BANNER_PATTERN.sub(" ", line)
    line = re.sub(r"\s{2,}", " ", line)
    return line.strip()


def clean_text(raw_text: str) -> str:
    normalized = raw_text.replace("\f", "\n")
    cleaned_lines: list[str] = []

    for raw_line in normalized.splitlines():
        line = sanitize_ocr_line(raw_line)
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


def normalize_whitespace(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def extract_redacao_theme(section_text: str) -> str | None:
    normalized = normalize_whitespace(section_text)
    normalized = normalized.replace("“", '"').replace("”", '"').replace("’", "'")

    patterns = (
        r'sobre o tema\s*"([^"]{8,240})"',
        r"sobre o tema\s*'([^']{8,240})'",
        r"sobre o tema\s+([^.;:]{8,240})\s+(?:apresentando|redija|elabore)\b",
    )

    for pattern in patterns:
        match = re.search(pattern, normalized, flags=re.IGNORECASE)
        if match:
            return normalize_whitespace(match.group(1))

    return None


def extract_redacao_record(cleaned_text: str, day: int) -> RedacaoRecord | None:
    if day != 1:
        return None

    start_match = REDACAO_PATTERN.search(cleaned_text)
    if not start_match:
        return None

    end_candidates: list[int] = [len(cleaned_text)]

    next_question = QUESTION_PATTERN.search(cleaned_text, start_match.end())
    if next_question:
        end_candidates.append(next_question.start())

    transition_hint = REDACAO_END_HINT_PATTERN.search(cleaned_text, start_match.end())
    if transition_hint:
        end_candidates.append(transition_hint.start())

    end_position = min(end_candidates)
    section = cleaned_text[start_match.start() : end_position].strip()
    if not section:
        return None

    lines = [line.strip() for line in section.splitlines() if line.strip()]
    instructions_index = next(
        (
            index
            for index, line in enumerate(lines)
            if REDACAO_INSTRUCTIONS_PATTERN.match(line)
        ),
        None,
    )
    if instructions_index is not None:
        last_instruction_line = next(
            (
                index
                for index in range(len(lines) - 1, instructions_index - 1, -1)
                if re.match(r"^4\.4\.", lines[index])
            ),
            None,
        )
        if last_instruction_line is not None:
            lines = lines[: last_instruction_line + 1]

    normalized_section = "\n".join(lines)
    theme = extract_redacao_theme(normalized_section)

    return RedacaoRecord(tema=theme, texto_markdown=normalized_section)


def normalize_area_name(raw_name: str) -> str | None:
    normalized = raw_name.upper()
    if "LINGUAGENS" in normalized:
        return "Linguagens"
    if "CIÊNCIAS HUMANAS" in normalized or "CIENCIAS HUMANAS" in normalized:
        return "Ciências Humanas"
    if "CIÊNCIAS DA NATUREZA" in normalized or "CIENCIAS DA NATUREZA" in normalized:
        return "Ciências da Natureza"
    if "MATEMÁTICA" in normalized or "MATEMATICA" in normalized:
        return "Matemática"
    return None


def detect_area_order(exam_text: str) -> tuple[str, str] | None:
    order: list[str] = []
    for line in exam_text.splitlines()[:500]:
        match = re.search(r"PROVA DE\s+(.+)", line, flags=re.IGNORECASE)
        if not match:
            continue
        area_name = normalize_area_name(match.group(1).strip())
        if area_name and area_name not in order:
            order.append(area_name)
        if len(order) >= 2:
            break

    if len(order) >= 2:
        return (order[0], order[1])
    return None


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
            left_en = normalize_answer(tokens[1])
            left_es = normalize_answer(tokens[2])
            right_answer = normalize_answer(tokens[4])
            if left_en is None or left_es is None or right_answer is None:
                continue
            left_q = int(tokens[0])
            answers[left_q] = {"ingles": left_en, "espanhol": left_es}

            right_q = int(tokens[3])
            answers[right_q] = right_answer
            continue

        if len(tokens) == 4 and tokens[2].isdigit():
            left_answer = normalize_answer(tokens[1])
            right_answer = normalize_answer(tokens[3])
            if left_answer is None or right_answer is None:
                continue
            left_q = int(tokens[0])
            answers[left_q] = left_answer

            right_q = int(tokens[2])
            answers[right_q] = right_answer

    return answers


def parse_day2_gabarito(gabarito_text: str) -> dict[int, Any]:
    answers: dict[int, Any] = {}

    for raw_line in gabarito_text.splitlines():
        line = raw_line.strip()
        if not line:
            continue

        tokens = line.split()
        if (
            len(tokens) == 5
            and tokens[0].isdigit()
            and normalize_answer(tokens[1]) is not None
            and normalize_answer(tokens[2]) is not None
            and tokens[3].isdigit()
            and normalize_answer(tokens[4]) is not None
        ):
            left_q = int(tokens[0])
            right_q = int(tokens[3])
            left_1 = normalize_answer(tokens[1])
            left_2 = normalize_answer(tokens[2])
            right_answer = normalize_answer(tokens[4])
            if left_1 is None or left_2 is None or right_answer is None:
                continue
            if not 91 <= left_q <= 180 or not 91 <= right_q <= 180:
                continue
            if 1 <= left_q <= 5 or 91 <= left_q <= 95:
                answers[left_q] = {"ingles": left_1, "espanhol": left_2}
            else:
                answers[left_q] = left_1
            answers[right_q] = right_answer
            continue

        for number, answer in re.findall(r"(\d{1,3})\s+([A-E]|[aA]nulad[ao])", line):
            question_number = int(number)
            parsed_answer = normalize_answer(answer)
            if parsed_answer is None:
                continue
            if 91 <= question_number <= 180:
                answers[question_number] = parsed_answer

    return answers


def infer_area(day: int, question_number: int, area_order: tuple[str, str] | None = None) -> str:
    if area_order:
        if 1 <= question_number <= 45 or 91 <= question_number <= 135:
            return area_order[0]
        if 46 <= question_number <= 90 or 136 <= question_number <= 180:
            return area_order[1]

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


def build_records(
    day: int,
    blocks: list[tuple[int, str]],
    answers: dict[int, Any],
    area_order: tuple[str, str] | None = None,
) -> list[QuestionRecord]:
    counter: defaultdict[int, int] = defaultdict(int)
    records: list[QuestionRecord] = []

    for number, block in blocks:
        counter[number] += 1
        variation = counter[number]

        area = infer_area(day, number, area_order=area_order)
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


def redacao_to_markdown(year: int, record: RedacaoRecord | None) -> str:
    lines: list[str] = []
    lines.append(f"# Redação ENEM {year} — Dia 1")
    lines.append("")
    lines.append("Gerado automaticamente a partir do PDF oficial.")
    lines.append("")
    lines.append("## Tema")
    lines.append("")

    if record and record.tema:
        lines.append(record.tema)
    else:
        lines.append("[TEMA NÃO IDENTIFICADO]")

    lines.append("")
    lines.append("## Proposta e textos motivadores")
    lines.append("")

    if record:
        lines.append(record.texto_markdown)
    else:
        lines.append("[SEÇÃO DE REDAÇÃO NÃO IDENTIFICADA NESTA EXTRAÇÃO]")

    lines.append("")
    return "\n".join(lines)


def write_output_files(
    output_dir: Path,
    year: int,
    day: int,
    cleaned_text: str,
    answers: dict[int, Any],
    records: list[QuestionRecord],
    markdown_content: str,
    redacao_record: RedacaoRecord | None,
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

    if day == 1:
        redacao_json_path = output_dir / "dia1_redacao.json"
        redacao_md_path = output_dir / "dia1_redacao.md"

        redacao_payload = {
            "ano": year,
            "dia": 1,
            "redacao_encontrada": redacao_record is not None,
            "tema": redacao_record.tema if redacao_record else None,
            "tema_encontrado": bool(redacao_record and redacao_record.tema),
        }
        redacao_json_path.write_text(
            json.dumps(redacao_payload, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        redacao_md_path.write_text(redacao_to_markdown(year, redacao_record), encoding="utf-8")


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
    area_order = detect_area_order(prova_raw_text)

    if args.dia == 1:
        answers = parse_day1_gabarito(gabarito_raw_text)
    else:
        answers = parse_day2_gabarito(gabarito_raw_text)

    records = build_records(args.dia, question_blocks, answers, area_order=area_order)
    markdown_content = records_to_markdown(args.ano, args.dia, records)
    redacao_record = extract_redacao_record(cleaned_text, args.dia)

    write_output_files(
        args.outdir,
        args.ano,
        args.dia,
        cleaned_text,
        answers,
        records,
        markdown_content,
        redacao_record,
    )

    print(f"[ok] Dia {args.dia}: {len(records)} blocos extraídos")
    print(f"[ok] Saída: {args.outdir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
