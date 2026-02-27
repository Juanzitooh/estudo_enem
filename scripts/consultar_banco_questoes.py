#!/usr/bin/env python3
"""Consulta e filtra o banco de questões reais mapeadas."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path


QUESTION_HEADER_RE = re.compile(r"^## Questão\s+(\d{3})(?:\s+\(variação\s+(\d+)\))?\s*$", re.MULTILINE)
CONTROL_CHAR_PATTERN = re.compile(r"[\x00-\x08\x0B-\x1F\x7F]")
REPEATED_ENEM_BANNER_PATTERN = re.compile(r"(?:\bENEM\s*\d{4}\b[\s|]*){2,}", re.IGNORECASE)


@dataclass(frozen=True)
class QuestionRecord:
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
    tem_imagem: bool
    texto_vazio: bool
    fallback_image_paths: tuple[str, ...]
    gabarito: str
    preview: str


@dataclass(frozen=True)
class QueryResult:
    record: QuestionRecord
    source_path: Path
    texto_completo: str


def parse_args() -> argparse.Namespace:
    default_mapped_csv = Path(
        "questoes/mapeamento_habilidades/questoes_metadados_consolidados.csv"
    )
    if not default_mapped_csv.exists():
        default_mapped_csv = Path("questoes/mapeamento_habilidades/questoes_mapeadas.csv")

    parser = argparse.ArgumentParser(
        description="Consulta o banco de questões reais com filtros por metadados."
    )
    parser.add_argument(
        "--mapped-csv",
        type=Path,
        default=default_mapped_csv,
        help="CSV com o mapeamento consolidado.",
    )
    parser.add_argument(
        "--banco-dir",
        type=Path,
        default=Path("questoes/banco_reais"),
        help="Diretório com os arquivos reais por ano e dia.",
    )
    parser.add_argument("--ano", type=int, help="Ano exato (ex.: 2023).")
    parser.add_argument("--ano-from", type=int, help="Ano inicial.")
    parser.add_argument("--ano-to", type=int, help="Ano final.")
    parser.add_argument("--dia", type=int, choices=[1, 2], help="Dia da prova (1 ou 2).")
    parser.add_argument("--area", type=str, help="Filtro por área (contém).")
    parser.add_argument("--disciplina", type=str, help="Filtro por disciplina (contém).")
    parser.add_argument("--competencia", type=str, help="Filtro por competência (ex.: C5).")
    parser.add_argument("--habilidade", type=str, help="Filtro por habilidade (ex.: H19).")
    parser.add_argument("--tema", type=str, help="Filtro por tema (contém).")
    parser.add_argument(
        "--confianca",
        type=str,
        choices=["alta", "média", "media", "baixa"],
        help="Filtro por confiança.",
    )
    parser.add_argument(
        "--tem-imagem",
        type=str,
        choices=["sim", "nao", "não"],
        help="Filtra por presença de imagem.",
    )
    parser.add_argument(
        "--buscar",
        type=str,
        help="Busca textual em preview ou texto completo (quando --com-texto estiver ativo).",
    )
    parser.add_argument(
        "--com-texto",
        action="store_true",
        help="Inclui texto completo da questão na saída e habilita busca no enunciado completo.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=50,
        help="Quantidade máxima de itens na saída (0 = sem limite).",
    )
    parser.add_argument(
        "--offset",
        type=int,
        default=0,
        help="Deslocamento para paginação.",
    )
    parser.add_argument(
        "--formato",
        type=str,
        choices=["md", "csv", "jsonl"],
        default="md",
        help="Formato da saída.",
    )
    parser.add_argument(
        "--saida",
        type=Path,
        help="Arquivo de saída. Se omitido, imprime no terminal.",
    )
    return parser.parse_args()


def normalize_text(text: str) -> str:
    lowered = text.lower()
    normalized = unicodedata.normalize("NFD", lowered)
    return "".join(ch for ch in normalized if unicodedata.category(ch) != "Mn")


def sanitize_ocr_line(raw_line: str) -> str:
    line = raw_line.replace("\uFFFD", "")
    line = CONTROL_CHAR_PATTERN.sub(" ", line)
    line = REPEATED_ENEM_BANNER_PATTERN.sub(" ", line)
    line = re.sub(r"\s{2,}", " ", line)
    return line.strip()


def parse_bool(value: str) -> bool:
    normalized = value.strip().lower()
    return normalized in {"true", "1", "sim", "yes"}


def parse_fallback_image_paths(raw_value: str) -> tuple[str, ...]:
    if not raw_value.strip():
        return ()
    result: list[str] = []
    seen: set[str] = set()
    for chunk in raw_value.split(";"):
        cleaned = chunk.strip().replace("\\", "/")
        if not cleaned or cleaned in seen:
            continue
        seen.add(cleaned)
        result.append(cleaned)
    return tuple(result)


def load_records(path: Path) -> list[QuestionRecord]:
    if not path.exists():
        raise FileNotFoundError(f"Arquivo não encontrado: {path}")

    rows: list[QuestionRecord] = []
    with path.open("r", encoding="utf-8", newline="") as file_obj:
        reader = csv.DictReader(file_obj)
        for row in reader:
            competencia = sanitize_ocr_line(
                row.get("competencia_estimada")
                or row.get("competencia")
                or ""
            )
            habilidade = sanitize_ocr_line(
                row.get("habilidade_estimada")
                or row.get("habilidade")
                or ""
            )
            tema = sanitize_ocr_line(
                row.get("tema_estimado")
                or row.get("tema")
                or ""
            )
            confianca = sanitize_ocr_line(
                row.get("confianca")
                or row.get("confianca_mapeamento")
                or ""
            )
            rows.append(
                QuestionRecord(
                    ano=int(row["ano"]),
                    dia=int(row["dia"]),
                    numero=int(row["numero"]),
                    variacao=int(row.get("variacao", "1") or "1"),
                    area=sanitize_ocr_line(row["area"]),
                    disciplina=sanitize_ocr_line(row["disciplina"]),
                    competencia_estimada=competencia,
                    tema_estimado=tema,
                    habilidade_estimada=habilidade,
                    confianca=confianca,
                    tem_imagem=parse_bool(row.get("tem_imagem", "false")),
                    texto_vazio=parse_bool(row.get("texto_vazio", "false")),
                    fallback_image_paths=parse_fallback_image_paths(
                        row.get("fallback_image_paths", "")
                    ),
                    gabarito=sanitize_ocr_line(row.get("gabarito", "")),
                    preview=sanitize_ocr_line(row.get("preview", "")),
                )
            )
    return rows


def parse_questions_from_file(path: Path, ano: int, dia: int) -> dict[tuple[int, int, int, int], str]:
    content = path.read_text(encoding="utf-8")
    matches = list(QUESTION_HEADER_RE.finditer(content))
    result: dict[tuple[int, int, int, int], str] = {}

    for index, match in enumerate(matches):
        numero = int(match.group(1))
        variacao = int(match.group(2)) if match.group(2) else 1
        start = match.end()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(content)
        block = content[start:end].strip()

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
        result[(ano, dia, numero, variacao)] = "\n".join(cleaned_lines)
    return result


def build_text_index(
    banco_dir: Path,
    records: list[QuestionRecord],
) -> dict[tuple[int, int, int, int], str]:
    needed_pairs = {(item.ano, item.dia) for item in records}
    text_index: dict[tuple[int, int, int, int], str] = {}

    for ano, dia in sorted(needed_pairs):
        file_path = banco_dir / f"enem_{ano}" / f"dia{dia}_questoes_reais.md"
        if not file_path.exists():
            continue
        parsed = parse_questions_from_file(file_path, ano=ano, dia=dia)
        text_index.update(parsed)
    return text_index


def contains_text(haystack: str, needle: str) -> bool:
    return normalize_text(needle) in normalize_text(haystack)


def record_matches(record: QuestionRecord, args: argparse.Namespace, text_index: dict[tuple[int, int, int, int], str]) -> bool:
    if args.ano is not None and record.ano != args.ano:
        return False
    if args.ano_from is not None and record.ano < args.ano_from:
        return False
    if args.ano_to is not None and record.ano > args.ano_to:
        return False
    if args.dia is not None and record.dia != args.dia:
        return False
    if args.area and not contains_text(record.area, args.area):
        return False
    if args.disciplina and not contains_text(record.disciplina, args.disciplina):
        return False
    if args.tema and not contains_text(record.tema_estimado, args.tema):
        return False

    if args.competencia:
        comp = args.competencia.strip().upper()
        if record.competencia_estimada.upper() != comp:
            return False

    if args.habilidade:
        hab = args.habilidade.strip().upper()
        if record.habilidade_estimada.upper() != hab:
            return False

    if args.confianca:
        conf = "média" if args.confianca == "media" else args.confianca
        if record.confianca != conf:
            return False

    if args.tem_imagem:
        has_image = args.tem_imagem == "sim"
        if record.tem_imagem != has_image:
            return False

    if args.buscar:
        haystacks = [record.preview]
        if args.com_texto:
            key = (record.ano, record.dia, record.numero, record.variacao)
            haystacks.append(text_index.get(key, ""))
        if not any(contains_text(item, args.buscar) for item in haystacks):
            return False

    return True


def apply_pagination(items: list[QueryResult], offset: int, limit: int) -> list[QueryResult]:
    if offset < 0:
        offset = 0
    paged = items[offset:]
    if limit > 0:
        return paged[:limit]
    return paged


def format_markdown(
    filtered: list[QueryResult],
    paged: list[QueryResult],
    args: argparse.Namespace,
) -> str:
    lines: list[str] = []
    lines.append("# Consulta do Banco de Questões")
    lines.append("")
    lines.append(f"- Total após filtros: **{len(filtered)}**")
    lines.append(f"- Offset: **{args.offset}**")
    lines.append(f"- Limit: **{args.limit}** (0 = sem limite)")
    lines.append("")
    lines.append(
        "| Ano | Dia | Questão | Área | Disciplina | Competência | Habilidade | Tema | Imagem | Texto vazio | Fallback | Gabarito | Preview |"
    )
    lines.append("|---:|---:|---:|---|---|---|---|---|---|---|---:|---|---|")

    for item in paged:
        record = item.record
        lines.append(
            "| {ano} | {dia} | {numero:03d} | {area} | {disciplina} | {comp} | {hab} | {tema} | {img} | {texto_vazio} | {fallback} | {gabarito} | {preview} |".format(
                ano=record.ano,
                dia=record.dia,
                numero=record.numero,
                area=record.area,
                disciplina=record.disciplina,
                comp=record.competencia_estimada,
                hab=record.habilidade_estimada,
                tema=record.tema_estimado,
                img="sim" if record.tem_imagem else "não",
                texto_vazio="sim" if record.texto_vazio else "não",
                fallback=len(record.fallback_image_paths),
                gabarito=record.gabarito,
                preview=record.preview.replace("|", "/"),
            )
        )

    if args.com_texto and paged:
        lines.append("")
        lines.append("## Texto completo")
        lines.append("")
        for item in paged:
            record = item.record
            lines.append(
                f"### {record.ano} D{record.dia} Q{record.numero:03d} (var {record.variacao}) - {record.disciplina}"
            )
            lines.append(f"- Fonte: `{item.source_path}`")
            lines.append(
                f"- Fallback imagens: {len(record.fallback_image_paths)}"
            )
            if record.fallback_image_paths:
                lines.append(
                    f"- Paths fallback: `{'; '.join(record.fallback_image_paths)}`"
                )
            lines.append("")
            lines.append(item.texto_completo or "_Texto não encontrado no arquivo fonte._")
            lines.append("")

    return "\n".join(lines) + "\n"


def format_csv(items: list[QueryResult], with_text: bool) -> str:
    headers = [
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
        "tem_imagem",
        "texto_vazio",
        "fallback_image_paths",
        "gabarito",
        "preview",
        "source_path",
    ]
    if with_text:
        headers.append("texto_completo")

    output_rows: list[dict[str, str]] = []
    for item in items:
        record = item.record
        row = {
            "ano": str(record.ano),
            "dia": str(record.dia),
            "numero": str(record.numero),
            "variacao": str(record.variacao),
            "area": record.area,
            "disciplina": record.disciplina,
            "competencia_estimada": record.competencia_estimada,
            "tema_estimado": record.tema_estimado,
            "habilidade_estimada": record.habilidade_estimada,
            "confianca": record.confianca,
            "tem_imagem": "true" if record.tem_imagem else "false",
            "texto_vazio": "true" if record.texto_vazio else "false",
            "fallback_image_paths": ";".join(record.fallback_image_paths),
            "gabarito": record.gabarito,
            "preview": record.preview,
            "source_path": str(item.source_path),
        }
        if with_text:
            row["texto_completo"] = item.texto_completo
        output_rows.append(row)

    output_buffer: list[str] = []
    output_buffer.append(",".join(headers))
    for row in output_rows:
        encoded = []
        for header in headers:
            value = row.get(header, "")
            escaped = value.replace('"', '""')
            encoded.append(f'"{escaped}"')
        output_buffer.append(",".join(encoded))
    return "\n".join(output_buffer) + "\n"


def format_jsonl(items: list[QueryResult], with_text: bool) -> str:
    lines: list[str] = []
    for item in items:
        record = item.record
        payload = {
            "ano": record.ano,
            "dia": record.dia,
            "numero": record.numero,
            "variacao": record.variacao,
            "area": record.area,
            "disciplina": record.disciplina,
            "competencia_estimada": record.competencia_estimada,
            "tema_estimado": record.tema_estimado,
            "habilidade_estimada": record.habilidade_estimada,
            "confianca": record.confianca,
            "tem_imagem": record.tem_imagem,
            "texto_vazio": record.texto_vazio,
            "fallback_image_paths": list(record.fallback_image_paths),
            "gabarito": record.gabarito,
            "preview": record.preview,
            "source_path": str(item.source_path),
        }
        if with_text:
            payload["texto_completo"] = item.texto_completo
        lines.append(json.dumps(payload, ensure_ascii=False))
    return "\n".join(lines) + ("\n" if lines else "")


def build_source_path(banco_dir: Path, record: QuestionRecord) -> Path:
    return banco_dir / f"enem_{record.ano}" / f"dia{record.dia}_questoes_reais.md"


def write_output(content: str, out_path: Path | None) -> None:
    if out_path is None:
        sys.stdout.write(content)
        return
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(content, encoding="utf-8")


def main() -> int:
    args = parse_args()
    records = load_records(args.mapped_csv)

    requires_text = args.com_texto
    text_index: dict[tuple[int, int, int, int], str] = {}
    if requires_text:
        text_index = build_text_index(args.banco_dir, records)

    filtered: list[QueryResult] = []
    for record in records:
        if not record_matches(record, args, text_index):
            continue
        key = (record.ano, record.dia, record.numero, record.variacao)
        filtered.append(
            QueryResult(
                record=record,
                source_path=build_source_path(args.banco_dir, record),
                texto_completo=text_index.get(key, ""),
            )
        )

    filtered.sort(key=lambda item: (item.record.ano, item.record.dia, item.record.numero, item.record.variacao))
    paged = apply_pagination(filtered, offset=args.offset, limit=args.limit)

    if args.formato == "md":
        output = format_markdown(filtered=filtered, paged=paged, args=args)
    elif args.formato == "csv":
        output = format_csv(items=paged, with_text=args.com_texto)
    else:
        output = format_jsonl(items=paged, with_text=args.com_texto)

    write_output(output, args.saida)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
