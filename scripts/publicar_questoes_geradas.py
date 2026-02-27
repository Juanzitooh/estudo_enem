#!/usr/bin/env python3
"""Publica somente questoes geradas aprovadas por revisao humana."""

from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import sys

from validar_questoes_geradas import (
    detect_similarity_match,
    iter_jsonl_files,
    load_real_question_snippets,
    validate_record,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Filtra lotes gerados e publica apenas itens com gate editorial aprovado.",
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=Path("questoes/generateds"),
        help="Arquivo .jsonl ou diretorio com lotes gerados.",
    )
    parser.add_argument(
        "--out-jsonl",
        type=Path,
        default=Path("questoes/generateds/published/questoes_publicadas.jsonl"),
        help="Arquivo JSONL de saida com itens publicados.",
    )
    parser.add_argument(
        "--summary-md",
        type=Path,
        default=Path("questoes/generateds/published/resumo_publicacao.md"),
        help="Resumo markdown da publicacao.",
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
        help="Desativa detector de similaridade com base real na publicacao.",
    )
    parser.add_argument(
        "--similarity-threshold",
        type=float,
        default=0.88,
        help="Threshold de similaridade textual para bloquear item.",
    )
    parser.add_argument(
        "--jaccard-threshold",
        type=float,
        default=0.66,
        help="Threshold de jaccard para bloquear item.",
    )
    parser.add_argument(
        "--max-real-snippets",
        type=int,
        default=0,
        help="Limita snippets reais carregados (0=todos).",
    )
    parser.add_argument(
        "--fail-on-blocked",
        action="store_true",
        help="Retorna exit code 1 se qualquer item for bloqueado.",
    )
    parser.add_argument(
        "--max-error-lines",
        type=int,
        default=80,
        help="Maximo de linhas detalhadas no resumo markdown.",
    )
    return parser.parse_args()


def is_relative_to(path: Path, base_dir: Path) -> bool:
    try:
        path.resolve().relative_to(base_dir.resolve())
        return True
    except ValueError:
        return False


def ensure_range(name: str, value: float) -> None:
    if not 0.0 <= value <= 1.0:
        raise ValueError(f"{name} deve ficar entre 0 e 1")


def write_jsonl(output_path: Path, records: list[dict[str, object]]) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as handle:
        for record in records:
            handle.write(json.dumps(record, ensure_ascii=False) + "\n")


def write_summary_markdown(
    summary_path: Path,
    *,
    input_path: Path,
    output_path: Path,
    source_files: int,
    total_records: int,
    published_records: int,
    blocked_records: int,
    blocked_reasons: Counter[str],
    blocked_details: list[str],
    max_error_lines: int,
) -> None:
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Resumo de publicacao de questoes geradas",
        "",
        f"- Origem: `{input_path}`",
        f"- Saida: `{output_path}`",
        f"- Arquivos fonte: **{source_files}**",
        f"- Registros processados: **{total_records}**",
        f"- Registros publicados: **{published_records}**",
        f"- Registros bloqueados: **{blocked_records}**",
        "",
    ]

    if blocked_reasons:
        lines.extend(
            [
                "## Motivos de bloqueio",
                "",
                "| Motivo | Qtde |",
                "|---|---:|",
            ],
        )
        for reason, count in blocked_reasons.most_common():
            lines.append(f"| {reason} | {count} |")
        lines.append("")

    if blocked_details:
        lines.extend(["## Detalhes (amostra)", ""])
        for detail in blocked_details[:max_error_lines]:
            lines.append(f"- {detail}")
        hidden = len(blocked_details) - max_error_lines
        if hidden > 0:
            lines.append(f"- ... {hidden} bloqueio(s) adicional(is) omitido(s)")
        lines.append("")

    summary_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    args = parse_args()
    try:
        ensure_range("--similarity-threshold", args.similarity_threshold)
        ensure_range("--jaccard-threshold", args.jaccard_threshold)
    except ValueError as exc:
        print(f"[erro] {exc}")
        return 2

    try:
        source_files = iter_jsonl_files(args.input)
    except FileNotFoundError as exc:
        print(f"[erro] {exc}")
        return 2
    if not source_files:
        print("[erro] nenhum arquivo .jsonl encontrado para publicar.")
        return 2

    output_dir = args.out_jsonl.parent.resolve()
    if args.input.is_dir():
        source_files = [path for path in source_files if not is_relative_to(path, output_dir)]
        if not source_files:
            print("[erro] arquivos fonte ficaram vazios apos filtro do diretorio de saida.")
            return 2

    real_snippets = []
    if not args.skip_similarity_check:
        try:
            real_snippets = load_real_question_snippets(args.real_questions_csv, args.max_real_snippets)
        except FileNotFoundError as exc:
            print(f"[erro] {exc}")
            return 2
        if not real_snippets:
            print("[erro] nenhum snippet real carregado para detector de similaridade.")
            return 2

    published_records: list[dict[str, object]] = []
    blocked_reasons: Counter[str] = Counter()
    blocked_details: list[str] = []
    seen_ids: set[str] = set()
    total_records = 0

    for source_path in source_files:
        lines = source_path.read_text(encoding="utf-8").splitlines()
        for line_number, raw_line in enumerate(lines, start=1):
            if not raw_line.strip():
                continue
            total_records += 1
            entry_ref = f"{source_path}:{line_number}"
            try:
                record = json.loads(raw_line)
            except json.JSONDecodeError as exc:
                blocked_reasons["json_invalido"] += 1
                blocked_details.append(f"{entry_ref}: JSON invalido ({exc.msg})")
                continue

            errors = validate_record(record, require_approved=True)
            if isinstance(record, dict):
                record_id = str(record.get("id", "")).strip()
                if record_id and record_id in seen_ids:
                    errors.append("id duplicado no lote publicado")
                similarity_match = None
                if not args.skip_similarity_check:
                    similarity_match = detect_similarity_match(
                        enunciado=str(record.get("enunciado", "")),
                        area=str(record.get("area", "")),
                        disciplina=str(record.get("disciplina", "")),
                        snippets=real_snippets,
                        similarity_threshold=args.similarity_threshold,
                        jaccard_threshold=args.jaccard_threshold,
                    )
                if similarity_match is not None:
                    errors.append(
                        (
                            "similaridade suspeita com base real "
                            f"(id={similarity_match.id_questao}, "
                            f"seq={similarity_match.sequence_ratio:.3f}, "
                            f"jaccard={similarity_match.jaccard:.3f})"
                        ),
                    )

                if errors:
                    blocked_reasons["falha_validacao"] += 1
                    blocked_details.append(f"{entry_ref}: {'; '.join(errors)}")
                    continue

                seen_ids.add(record_id)
                published_records.append(record)
                continue

            blocked_reasons["json_objeto_esperado"] += 1
            blocked_details.append(f"{entry_ref}: linha nao contem JSON objeto")

    write_jsonl(args.out_jsonl, published_records)
    write_summary_markdown(
        summary_path=args.summary_md,
        input_path=args.input,
        output_path=args.out_jsonl,
        source_files=len(source_files),
        total_records=total_records,
        published_records=len(published_records),
        blocked_records=sum(blocked_reasons.values()),
        blocked_reasons=blocked_reasons,
        blocked_details=blocked_details,
        max_error_lines=args.max_error_lines,
    )

    print(
        "[resumo] fontes={} processados={} publicados={} bloqueados={}".format(
            len(source_files),
            total_records,
            len(published_records),
            sum(blocked_reasons.values()),
        ),
    )
    print(f"[ok] saida publicada em {args.out_jsonl}")
    print(f"[ok] resumo salvo em {args.summary_md}")

    if args.fail_on_blocked and blocked_reasons:
        return 1
    if not published_records:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
