#!/usr/bin/env python3
"""Gera plano semanal determinístico com base em feedback por habilidade."""

from __future__ import annotations

import argparse
import csv
from datetime import datetime
from pathlib import Path
import sys

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from planner import (
    build_plan,
    ensure_attempts_csv,
    load_attempts_csv,
    load_planner_config,
    write_plan_markdown,
    write_priority_csv,
)


def skill_number(habilidade: str) -> int:
    match = habilidade.upper().strip()
    if match.startswith("H"):
        try:
            return int(match[1:])
        except ValueError:
            return 0
    return 0


def infer_disciplines(area: str, habilidade: str) -> list[str]:
    number = skill_number(habilidade)
    if area == "Matemática":
        return ["Matemática"]
    if area == "Ciências da Natureza":
        if 20 <= number <= 23:
            return ["Física"]
        if 24 <= number <= 27:
            return ["Química"]
        if 28 <= number <= 30:
            return ["Biologia"]
        return ["Física", "Química", "Biologia"]
    if area == "Ciências Humanas":
        if number <= 5 or 11 <= number <= 15:
            return ["História"]
        if 6 <= number <= 10 or 26 <= number <= 30:
            return ["Geografia"]
        if number in {23}:
            return ["Filosofia"]
        if number in {24, 25}:
            return ["Sociologia"]
        return ["História", "Geografia", "Filosofia", "Sociologia"]
    if area == "Linguagens":
        if 5 <= number <= 8:
            return ["Inglês", "Espanhol", "Língua Estrangeira"]
        if 15 <= number <= 17:
            return ["Literatura"]
        if 25 <= number <= 27:
            return ["Língua Portuguesa"]
        if 12 <= number <= 14:
            return ["Artes e Comunicação"]
        return ["Língua Portuguesa", "Literatura", "Artes e Comunicação"]
    return []


def load_mapping_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8", newline="") as file_obj:
        return list(csv.DictReader(file_obj))


def confidence_rank(confidence: str) -> int:
    order = {"alta": 3, "média": 2, "media": 2, "baixa": 1}
    return order.get(confidence.lower().strip(), 0)


def build_question_suggestions_markdown(
    plan,
    mapping_rows: list[dict[str, str]],
    output_path: Path,
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    lines: list[str] = []
    lines.append("# Sugestões de Questões Reais por Bloco")
    lines.append("")
    lines.append(
        "Sugestões automáticas usando `questoes/mapeamento_habilidades/questoes_mapeadas.csv`."
    )
    lines.append("")

    global_used_keys: set[tuple[str, str, str, str]] = set()

    for block in plan.blocos:
        lines.append(
            f"## {block.data.isoformat()} | {block.dia_semana} | Bloco {block.bloco} | "
            f"{block.skill.area} {block.skill.habilidade}"
        )
        lines.append("")
        lines.append(f"- Foco do bloco: {block.foco}")
        lines.append(f"- Alvo de questões: {block.alvo_questoes}")
        lines.append("")
        lines.append("| Ano | Dia | Questão | Disciplina | Tema | Habilidade estimada | Confiança |")
        lines.append("|---:|---:|---:|---|---|---|---|")

        preferred_disciplines = set(infer_disciplines(block.skill.area, block.skill.habilidade))
        used_keys: set[tuple[str, str, str, str]] = set()

        exact = []
        related = []
        broad = []

        for row in mapping_rows:
            if row.get("area", "") != block.skill.area:
                continue

            key = (
                row.get("ano", ""),
                row.get("dia", ""),
                row.get("numero", ""),
                row.get("variacao", ""),
            )
            if key in global_used_keys:
                continue
            if key in used_keys:
                continue

            row_skill = row.get("habilidade_estimada", "")
            row_discipline = row.get("disciplina", "")
            if row_skill == block.skill.habilidade:
                exact.append(row)
                continue
            if preferred_disciplines and row_discipline in preferred_disciplines:
                related.append(row)
                continue
            broad.append(row)

        def row_sort_key(item: dict[str, str]) -> tuple[int, int]:
            return (
                confidence_rank(item.get("confianca", "")),
                int(item.get("ano", "0") or 0),
            )

        exact.sort(key=row_sort_key, reverse=True)
        related.sort(key=row_sort_key, reverse=True)
        broad.sort(key=row_sort_key, reverse=True)

        chosen = []
        for bucket in (exact, related, broad):
            for row in bucket:
                key = (
                    row.get("ano", ""),
                    row.get("dia", ""),
                    row.get("numero", ""),
                    row.get("variacao", ""),
                )
                if key in used_keys:
                    continue
                chosen.append(row)
                used_keys.add(key)
                global_used_keys.add(key)
                if len(chosen) >= 8:
                    break
            if len(chosen) >= 8:
                break

        if not chosen:
            lines.append("| - | - | - | - | - | - | - |")
            lines.append("")
            continue

        for row in chosen:
            lines.append(
                "| {ano} | {dia} | {numero} | {disc} | {tema} | {hab} | {conf} |".format(
                    ano=row.get("ano", "-"),
                    dia=row.get("dia", "-"),
                    numero=row.get("numero", "-"),
                    disc=row.get("disciplina", "-"),
                    tema=row.get("tema_estimado", "-"),
                    hab=row.get("habilidade_estimada", "-"),
                    conf=row.get("confianca", "-"),
                )
            )
        lines.append("")

    output_path.write_text("\n".join(lines), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Gera plano semanal offline (sem IA).")
    parser.add_argument(
        "--config",
        type=Path,
        default=Path("prompts/contexto_planejador.json"),
        help="Configuração de planejamento em JSON.",
    )
    parser.add_argument(
        "--attempts",
        type=Path,
        default=Path("plano/desempenho_habilidades.csv"),
        help="CSV com feedback de desempenho por habilidade.",
    )
    parser.add_argument(
        "--out-md",
        type=Path,
        default=Path("plano/plano_semanal_gerado.md"),
        help="Arquivo Markdown de saída.",
    )
    parser.add_argument(
        "--out-prioridades",
        type=Path,
        default=Path("plano/prioridades_habilidades.csv"),
        help="Arquivo CSV com ranking de prioridades.",
    )
    parser.add_argument(
        "--data-ref",
        type=str,
        default="",
        help="Data de referência no formato YYYY-MM-DD (opcional).",
    )
    parser.add_argument(
        "--mapped-questions",
        type=Path,
        default=Path("questoes/mapeamento_habilidades/questoes_mapeadas.csv"),
        help="CSV de questões mapeadas por disciplina/tema/habilidade estimada.",
    )
    parser.add_argument(
        "--out-sugestoes",
        type=Path,
        default=Path("plano/sugestoes_questoes_por_bloco.md"),
        help="Arquivo markdown com sugestões de questões reais por bloco.",
    )
    return parser.parse_args()


def resolve_config_path(path: Path) -> Path:
    if path.exists():
        return path

    fallback = Path("prompts/contexto_planejador.example.json")
    if fallback.exists():
        print(f"[warn] config não encontrado: {path}")
        print(f"[warn] usando exemplo: {fallback}")
        return fallback

    raise FileNotFoundError(
        f"Configuração ausente: {path} e fallback prompts/contexto_planejador.example.json."
    )


def main() -> int:
    args = parse_args()

    config_path = resolve_config_path(args.config)
    config = load_planner_config(config_path)

    ensure_attempts_csv(args.attempts)
    attempts = load_attempts_csv(args.attempts)

    reference_date = None
    if args.data_ref:
        reference_date = datetime.strptime(args.data_ref, "%Y-%m-%d").date()

    plan = build_plan(attempts=attempts, config=config, reference_date=reference_date)
    write_plan_markdown(args.out_md, plan)
    write_priority_csv(args.out_prioridades, plan)

    mapping_rows = load_mapping_rows(args.mapped_questions)
    if mapping_rows:
        build_question_suggestions_markdown(plan, mapping_rows, args.out_sugestoes)
        print(f"[ok] sugestões por bloco: {args.out_sugestoes}")
    else:
        print(f"[warn] mapeamento não encontrado em {args.mapped_questions}")

    print(f"[ok] prioridades calculadas: {len(plan.prioridades)}")
    print(f"[ok] blocos gerados: {len(plan.blocos)}")
    print(f"[ok] markdown: {args.out_md}")
    print(f"[ok] csv prioridades: {args.out_prioridades}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
