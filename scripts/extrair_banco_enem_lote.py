#!/usr/bin/env python3
"""Executa extração em lote de provas ENEM por ano e dia.

- Usa `scripts/extrair_banco_enem_real.py` internamente.
- Considera a nomenclatura padronizada em `questoes/provas_anteriores`:
  - `{ano}_dia{dia}_prova.pdf`
  - `{ano}_dia{dia}_gabarito.pdf`
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass
class ExtractionResult:
    year: int
    day: int
    status: str
    prova_file: str
    gabarito_file: str
    blocks: int = 0
    unique_questions: int = 0
    answer_count: int = 0
    note: str = ""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extrai banco ENEM em lote.")
    parser.add_argument(
        "--provas-dir",
        type=Path,
        default=Path("questoes/provas_anteriores"),
        help="Diretório com PDFs de provas e gabaritos.",
    )
    parser.add_argument(
        "--out-base",
        type=Path,
        default=Path("questoes/banco_reais"),
        help="Diretório base de saída para os bancos por ano.",
    )
    parser.add_argument("--year-from", type=int, default=2015)
    parser.add_argument("--year-to", type=int, default=2025)
    parser.add_argument("--status-file", type=Path, default=Path("questoes/banco_reais/STATUS_EXTRACAO.md"))
    return parser.parse_args()


def default_prova_name(year: int, day: int) -> str:
    return f"{year}_dia{day}_prova.pdf"


def default_gabarito_name(year: int, day: int) -> str:
    return f"{year}_dia{day}_gabarito.pdf"


def resolve_files(year: int, day: int) -> tuple[str, str]:
    return default_prova_name(year, day), default_gabarito_name(year, day)


def read_counts(year_dir: Path, day: int) -> tuple[int, int, int]:
    idx_path = year_dir / f"dia{day}_questoes_index.json"
    gab_path = year_dir / f"dia{day}_gabarito.json"

    idx = json.loads(idx_path.read_text(encoding="utf-8"))
    gab = json.loads(gab_path.read_text(encoding="utf-8"))

    blocks = len(idx)
    unique = len({item["numero"] for item in idx})
    answers = len(gab)
    return blocks, unique, answers


def run_single(
    year: int,
    day: int,
    provas_dir: Path,
    out_base: Path,
    extractor_path: Path,
) -> ExtractionResult:
    prova_name, gabarito_name = resolve_files(year, day)
    prova_path = provas_dir / prova_name
    gabarito_path = provas_dir / gabarito_name

    if not prova_path.exists() or not gabarito_path.exists():
        note = ""
        if not prova_path.exists() and not gabarito_path.exists():
            note = "prova e gabarito ausentes"
        elif not prova_path.exists():
            note = "prova ausente"
        else:
            note = "gabarito ausente"

        return ExtractionResult(
            year=year,
            day=day,
            status="missing",
            prova_file=prova_name,
            gabarito_file=gabarito_name,
            note=note,
        )

    out_year = out_base / f"enem_{year}"
    command = [
        sys.executable,
        str(extractor_path),
        "--ano",
        str(year),
        "--dia",
        str(day),
        "--prova",
        str(prova_path),
        "--gabarito",
        str(gabarito_path),
        "--outdir",
        str(out_year),
    ]

    completed = subprocess.run(command, capture_output=True, text=True)
    if completed.returncode != 0:
        note = (completed.stderr or completed.stdout).strip().splitlines()
        return ExtractionResult(
            year=year,
            day=day,
            status="error",
            prova_file=prova_name,
            gabarito_file=gabarito_name,
            note=note[-1] if note else "erro sem saída",
        )

    blocks, unique, answers = read_counts(out_year, day)
    return ExtractionResult(
        year=year,
        day=day,
        status="ok",
        prova_file=prova_name,
        gabarito_file=gabarito_name,
        blocks=blocks,
        unique_questions=unique,
        answer_count=answers,
    )


def write_status_report(results: list[ExtractionResult], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    lines: list[str] = []
    lines.append("# Status de Extração do Banco Real")
    lines.append("")

    ok_count = sum(1 for result in results if result.status == "ok")
    missing_count = sum(1 for result in results if result.status == "missing")
    error_count = sum(1 for result in results if result.status == "error")

    lines.append(f"- Extrações OK: **{ok_count}**")
    lines.append(f"- Pendências de arquivo: **{missing_count}**")
    lines.append(f"- Erros de processamento: **{error_count}**")
    lines.append("")

    lines.append("## Detalhe por ano/dia")
    lines.append("")
    lines.append("| Ano | Dia | Status | Blocos | Únicas | Gabaritos | Prova | Gabarito | Obs |")
    lines.append("|---|---:|---|---:|---:|---:|---|---|---|")

    for result in sorted(results, key=lambda item: (item.year, item.day)):
        obs = result.note or ""
        lines.append(
            "| {year} | {day} | {status} | {blocks} | {unique} | {answers} | `{prova}` | `{gabarito}` | {obs} |".format(
                year=result.year,
                day=result.day,
                status=result.status,
                blocks=result.blocks,
                unique=result.unique_questions,
                answers=result.answer_count,
                prova=result.prova_file,
                gabarito=result.gabarito_file,
                obs=obs,
            )
        )

    output_path.write_text("\n".join(lines).strip() + "\n", encoding="utf-8")


def read_redacao_payload(year_dir: Path) -> dict[str, object] | None:
    redacao_path = year_dir / "dia1_redacao.json"
    if not redacao_path.exists():
        return None
    return json.loads(redacao_path.read_text(encoding="utf-8"))


def write_redacao_panorama(results: list[ExtractionResult], out_base: Path, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    day1_results = sorted(
        (item for item in results if item.day == 1),
        key=lambda item: item.year,
    )

    lines: list[str] = []
    lines.append("# Panorama de Temas de Redação")
    lines.append("")
    lines.append("Consolidado automático por ano (Dia 1).")
    lines.append("")
    lines.append("| Ano | Tema | Status | Arquivo |")
    lines.append("|---:|---|---|---|")

    found_count = 0
    missing_count = 0

    for result in day1_results:
        md_path = f"enem_{result.year}/dia1_redacao.md"

        if result.status != "ok":
            missing_count += 1
            lines.append(
                f"| {result.year} | [não disponível] | extração {result.status} | `{md_path}` |"
            )
            continue

        payload = read_redacao_payload(out_base / f"enem_{result.year}")
        if not payload:
            missing_count += 1
            lines.append(f"| {result.year} | [não disponível] | arquivo ausente | `{md_path}` |")
            continue

        theme = str(payload.get("tema") or "").strip()
        redacao_found = bool(payload.get("redacao_encontrada"))
        theme_found = bool(payload.get("tema_encontrado"))

        if theme_found and theme:
            found_count += 1
            theme_text = theme
            status = "ok"
        elif redacao_found:
            missing_count += 1
            theme_text = "[tema não identificado]"
            status = "seção encontrada"
        else:
            missing_count += 1
            theme_text = "[seção de redação não encontrada]"
            status = "não encontrada"

        lines.append(f"| {result.year} | {theme_text} | {status} | `{md_path}` |")

    lines.insert(3, f"- Temas identificados: **{found_count}**")
    lines.insert(4, f"- Pendências: **{missing_count}**")
    lines.insert(5, "")

    output_path.write_text("\n".join(lines).strip() + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()

    extractor_path = Path(__file__).with_name("extrair_banco_enem_real.py")
    if not extractor_path.exists():
        raise FileNotFoundError(f"Extrator base não encontrado: {extractor_path}")

    results: list[ExtractionResult] = []

    for year in range(args.year_from, args.year_to + 1):
        for day in (1, 2):
            result = run_single(
                year=year,
                day=day,
                provas_dir=args.provas_dir,
                out_base=args.out_base,
                extractor_path=extractor_path,
            )
            results.append(result)
            print(
                f"[{result.status}] {result.year} dia {result.day} | "
                f"blocos={result.blocks} únicas={result.unique_questions} gabaritos={result.answer_count}"
            )

    write_status_report(results, args.status_file)
    redacao_panorama_path = args.out_base / "PANORAMA_TEMAS_REDACAO.md"
    write_redacao_panorama(results, args.out_base, redacao_panorama_path)
    print(f"[ok] relatório: {args.status_file}")
    print(f"[ok] panorama redação: {redacao_panorama_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
