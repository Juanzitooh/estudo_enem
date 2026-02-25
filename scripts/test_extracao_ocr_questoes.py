#!/usr/bin/env python3
"""Audita extração das questões reais e ruído de OCR."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


QUESTION_HEADER_RE = re.compile(r"^## Questão\s+(\d{3})(?:\s+\(variação\s+(\d+)\))?\s*$", re.MULTILINE)
CONTROL_CHAR_PATTERN = re.compile(r"[\x00-\x08\x0B-\x1F\x7F]")
REPEATED_ENEM_BANNER_PATTERN = re.compile(r"(?:\bENEM\s*\d{4}\b[\s|]*){2,}", re.IGNORECASE)
GABARITO_SIMPLES_PATTERN = re.compile(r"^(?:[A-E]|Anulado)$", re.IGNORECASE)
GABARITO_VARIANTE_PATTERN = re.compile(
    r"^Ingl[eê]s:\s*[A-E]\s*\|\s*Espanhol:\s*[A-E]$",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class AuditItem:
    ano: int
    dia: int
    numero: int
    variacao: int
    area: str
    gabarito: str
    text_len_clean: int
    metadata_ok: bool
    gabarito_ok: bool
    text_ok: bool
    raw_has_control: bool
    raw_has_repeated_banner: bool
    clean_has_control: bool
    clean_has_repeated_banner: bool
    preview_clean: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Audita qualidade da extração OCR das questões reais.")
    parser.add_argument(
        "--banco-dir",
        type=Path,
        default=Path("questoes/banco_reais"),
        help="Diretório do banco real por ano.",
    )
    parser.add_argument("--year-from", type=int, default=2015)
    parser.add_argument("--year-to", type=int, default=2025)
    parser.add_argument(
        "--sample-size",
        type=int,
        default=20,
        help="Quantidade de itens na amostra do relatório.",
    )
    parser.add_argument(
        "--out-report",
        type=Path,
        default=Path("questoes/banco_reais/teste_ocr_extracao.md"),
        help="Arquivo markdown com resultado da auditoria.",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Retorna erro se houver falhas de metadata/gabarito/texto.",
    )
    return parser.parse_args()


def sanitize_ocr_line(raw_line: str) -> str:
    line = raw_line.replace("\uFFFD", "")
    line = CONTROL_CHAR_PATTERN.sub(" ", line)
    line = REPEATED_ENEM_BANNER_PATTERN.sub(" ", line)
    line = re.sub(r"\s{2,}", " ", line)
    return line.strip()


def normalize_gabarito(raw_value: str) -> str:
    return sanitize_ocr_line(raw_value)


def is_valid_gabarito(gabarito: str) -> bool:
    value = gabarito.strip()
    if not value or value == "Não encontrado":
        return False
    return bool(
        GABARITO_SIMPLES_PATTERN.fullmatch(value)
        or GABARITO_VARIANTE_PATTERN.fullmatch(value)
    )


def preview_text(text: str, max_len: int = 120) -> str:
    flat = " ".join(text.splitlines())
    if len(flat) <= max_len:
        return flat
    return flat[: max_len - 3].rstrip() + "..."


def iter_markdown_files(banco_dir: Path, year_from: int, year_to: int) -> list[tuple[int, int, Path]]:
    files: list[tuple[int, int, Path]] = []
    for ano in range(year_from, year_to + 1):
        for dia in (1, 2):
            path = banco_dir / f"enem_{ano}" / f"dia{dia}_questoes_reais.md"
            if path.exists():
                files.append((ano, dia, path))
    return files


def parse_file(ano: int, dia: int, path: Path) -> list[AuditItem]:
    content = path.read_text(encoding="utf-8")
    matches = list(QUESTION_HEADER_RE.finditer(content))
    items: list[AuditItem] = []

    for index, match in enumerate(matches):
        numero = int(match.group(1))
        variacao = int(match.group(2)) if match.group(2) else 1
        start = match.end()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(content)
        block = content[start:end].strip()

        area_match = re.search(r"^- Área:\s*(.+)$", block, re.MULTILINE)
        gabarito_match = re.search(r"^- Gabarito:\s*(.+)$", block, re.MULTILINE)

        area = sanitize_ocr_line(area_match.group(1)) if area_match else ""
        gabarito = normalize_gabarito(gabarito_match.group(1)) if gabarito_match else ""

        raw_lines: list[str] = []
        clean_lines: list[str] = []
        for line in block.splitlines():
            raw_stripped = line.strip()
            if raw_stripped.startswith("- Área:") or raw_stripped.startswith("- Gabarito:"):
                continue
            if raw_stripped:
                raw_lines.append(raw_stripped)

            clean_stripped = sanitize_ocr_line(line)
            if clean_stripped.startswith("- Área:") or clean_stripped.startswith("- Gabarito:"):
                continue
            if clean_stripped:
                clean_lines.append(clean_stripped)

        raw_text = "\n".join(raw_lines)
        clean_text = "\n".join(clean_lines)
        metadata_ok = bool(area and gabarito)

        items.append(
            AuditItem(
                ano=ano,
                dia=dia,
                numero=numero,
                variacao=variacao,
                area=area or "Área não identificada",
                gabarito=gabarito or "Não encontrado",
                text_len_clean=len(clean_text),
                metadata_ok=metadata_ok,
                gabarito_ok=is_valid_gabarito(gabarito),
                text_ok=bool(clean_text.strip()),
                raw_has_control=CONTROL_CHAR_PATTERN.search(raw_text) is not None,
                raw_has_repeated_banner=REPEATED_ENEM_BANNER_PATTERN.search(raw_text) is not None,
                clean_has_control=CONTROL_CHAR_PATTERN.search(clean_text) is not None,
                clean_has_repeated_banner=REPEATED_ENEM_BANNER_PATTERN.search(clean_text) is not None,
                preview_clean=preview_text(clean_text),
            )
        )

    return items


def select_sample(items: list[AuditItem], sample_size: int) -> list[AuditItem]:
    if sample_size <= 0:
        return []

    noisy = [item for item in items if item.raw_has_control or item.raw_has_repeated_banner]
    regular = [item for item in items if item not in noisy]

    noisy_quota = min(len(noisy), sample_size // 2)
    sample = noisy[:noisy_quota]
    sample.extend(regular[: sample_size - len(sample)])

    if len(sample) < sample_size:
        extras = noisy[noisy_quota:] + regular[sample_size - noisy_quota :]
        needed = sample_size - len(sample)
        sample.extend(extras[:needed])

    sample.sort(key=lambda item: (item.ano, item.dia, item.numero, item.variacao))
    return sample


def build_report(
    items: list[AuditItem],
    sample: list[AuditItem],
    args: argparse.Namespace,
) -> str:
    total = len(items)
    metadata_missing = sum(1 for item in items if not item.metadata_ok)
    gabarito_invalid = sum(1 for item in items if not item.gabarito_ok)
    text_empty = sum(1 for item in items if not item.text_ok)
    raw_control = sum(1 for item in items if item.raw_has_control)
    raw_banner = sum(1 for item in items if item.raw_has_repeated_banner)
    clean_control = sum(1 for item in items if item.clean_has_control)
    clean_banner = sum(1 for item in items if item.clean_has_repeated_banner)

    lines: list[str] = []
    lines.append("# Teste de Extração OCR — Questões Reais")
    lines.append("")
    lines.append(
        f"- Intervalo: **{args.year_from}–{args.year_to}** | Itens auditados: **{total}**"
    )
    lines.append(f"- Falhas de metadata (área/gabarito): **{metadata_missing}**")
    lines.append(f"- Gabarito inválido/ausente: **{gabarito_invalid}**")
    lines.append(f"- Texto vazio após limpeza: **{text_empty}**")
    lines.append(
        f"- Ruído OCR (antes): controle={raw_control}, banner repetido={raw_banner}"
    )
    lines.append(
        f"- Ruído OCR (depois da limpeza): controle={clean_control}, banner repetido={clean_banner}"
    )
    lines.append("")
    lines.append("## Amostra de questões")
    lines.append("")
    lines.append(
        "| Ano | Dia | Questão | Área | Gabarito | Metadata ok | Texto ok | OCR antes | OCR depois | Preview limpo |"
    )
    lines.append("|---:|---:|---:|---|---|---|---|---|---|---|")

    for item in sample:
        raw_noise = "sim" if item.raw_has_control or item.raw_has_repeated_banner else "não"
        clean_noise = "sim" if item.clean_has_control or item.clean_has_repeated_banner else "não"
        lines.append(
            "| {ano} | {dia} | {questao:03d} | {area} | {gabarito} | {meta} | {texto} | {raw_noise} | {clean_noise} | {preview} |".format(
                ano=item.ano,
                dia=item.dia,
                questao=item.numero,
                area=item.area,
                gabarito=item.gabarito.replace("|", "/"),
                meta="sim" if item.metadata_ok else "não",
                texto="sim" if item.text_ok else "não",
                raw_noise=raw_noise,
                clean_noise=clean_noise,
                preview=item.preview_clean.replace("|", "/"),
            )
        )

    critical = [
        item
        for item in items
        if (not item.metadata_ok) or (not item.gabarito_ok) or (not item.text_ok)
    ]
    if critical:
        lines.append("")
        lines.append("## Itens com falha")
        lines.append("")
        lines.append("| Ano | Dia | Questão | Área | Gabarito | Metadata ok | Gabarito ok | Texto ok |")
        lines.append("|---:|---:|---:|---|---|---|---|---|")
        for item in critical[:100]:
            lines.append(
                "| {ano} | {dia} | {questao:03d} | {area} | {gabarito} | {meta} | {gab} | {texto} |".format(
                    ano=item.ano,
                    dia=item.dia,
                    questao=item.numero,
                    area=item.area,
                    gabarito=item.gabarito.replace("|", "/"),
                    meta="sim" if item.metadata_ok else "não",
                    gab="sim" if item.gabarito_ok else "não",
                    texto="sim" if item.text_ok else "não",
                )
            )
        lines.append("")

    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()
    files = iter_markdown_files(args.banco_dir, args.year_from, args.year_to)
    if not files:
        raise FileNotFoundError("Nenhum arquivo `dia*_questoes_reais.md` encontrado no intervalo informado.")

    items: list[AuditItem] = []
    for ano, dia, path in files:
        items.extend(parse_file(ano, dia, path))

    if not items:
        raise RuntimeError("Nenhuma questão encontrada para auditoria.")

    items.sort(key=lambda item: (item.ano, item.dia, item.numero, item.variacao))
    sample = select_sample(items, args.sample_size)
    report = build_report(items, sample, args)

    args.out_report.parent.mkdir(parents=True, exist_ok=True)
    args.out_report.write_text(report, encoding="utf-8")

    print(f"[ok] arquivos auditados: {len(files)}")
    print(f"[ok] questões auditadas: {len(items)}")
    print(f"[ok] relatório: {args.out_report}")

    has_failures = any((not item.metadata_ok) or (not item.gabarito_ok) or (not item.text_ok) for item in items)
    if args.strict and has_failures:
        print("[erro] modo estrito: existem falhas na auditoria.")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
