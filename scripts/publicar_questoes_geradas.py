#!/usr/bin/env python3
"""Publica somente questoes geradas aprovadas por revisao humana."""

from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
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
    parser.add_argument(
        "--publish-mode",
        choices=("merge-id", "append", "overwrite"),
        default="merge-id",
        help=(
            "Modo de escrita da saida: merge-id (incremental sem duplicar id), "
            "append (concatena) ou overwrite (substitui)."
        ),
    )
    parser.add_argument(
        "--release-version",
        type=str,
        default="",
        help="Versao da publicacao incremental (ex.: qgen.2026.02.27.1).",
    )
    parser.add_argument(
        "--manifest-json",
        type=Path,
        default=Path("questoes/generateds/published/manifest_publicacao.json"),
        help="Manifest json da publicacao incremental.",
    )
    parser.add_argument(
        "--history-jsonl",
        type=Path,
        default=Path("questoes/generateds/published/historico_publicacao.jsonl"),
        help="Historico append-only das publicacoes incrementais.",
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


def read_jsonl(path: Path) -> list[dict[str, object]]:
    if not path.exists():
        return []
    records: list[dict[str, object]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        record = json.loads(line)
        if isinstance(record, dict):
            records.append(record)
    return records


def apply_publish_mode(
    *,
    publish_mode: str,
    existing_records: list[dict[str, object]],
    new_records: list[dict[str, object]],
) -> tuple[list[dict[str, object]], int]:
    if publish_mode == "overwrite":
        return list(new_records), len(new_records)

    if publish_mode == "append":
        return existing_records + new_records, len(new_records)

    merged: list[dict[str, object]] = []
    id_to_index: dict[str, int] = {}
    for record in existing_records:
        record_id = str(record.get("id", "")).strip()
        if record_id:
            id_to_index[record_id] = len(merged)
        merged.append(record)

    new_items = 0
    for record in new_records:
        record_id = str(record.get("id", "")).strip()
        if record_id and record_id in id_to_index:
            merged[id_to_index[record_id]] = record
            continue
        if record_id:
            id_to_index[record_id] = len(merged)
        merged.append(record)
        new_items += 1
    return merged, new_items


def write_summary_markdown(
    summary_path: Path,
    *,
    input_path: Path,
    output_path: Path,
    source_files: int,
    total_records: int,
    published_records: int,
    blocked_records: int,
    existing_records: int,
    output_total_records: int,
    new_records_added: int,
    publish_mode: str,
    release_version: str,
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
        f"- Release: `{release_version}`",
        f"- Modo de publicacao: `{publish_mode}`",
        f"- Arquivos fonte: **{source_files}**",
        f"- Registros processados: **{total_records}**",
        f"- Registros publicados: **{published_records}**",
        f"- Registros bloqueados: **{blocked_records}**",
        f"- Registros existentes na saida antes da rodada: **{existing_records}**",
        f"- Novos registros adicionados nessa rodada: **{new_records_added}**",
        f"- Total final na saida: **{output_total_records}**",
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

    release_version = args.release_version.strip()
    if not release_version:
        release_version = "qgen." + datetime.now(timezone.utc).strftime("%Y.%m.%d.%H%M%S")

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

    existing_records = read_jsonl(args.out_jsonl)
    final_records, new_records_added = apply_publish_mode(
        publish_mode=args.publish_mode,
        existing_records=existing_records,
        new_records=published_records,
    )

    write_jsonl(args.out_jsonl, final_records)

    created_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    manifest_data = {
        "release_version": release_version,
        "created_at": created_at,
        "input": str(args.input),
        "output_jsonl": str(args.out_jsonl),
        "summary_md": str(args.summary_md),
        "publish_mode": args.publish_mode,
        "source_files": len(source_files),
        "processed_records": total_records,
        "approved_records_in_run": len(published_records),
        "blocked_records_in_run": sum(blocked_reasons.values()),
        "existing_records_before_run": len(existing_records),
        "new_records_added_in_run": new_records_added,
        "final_records_in_output": len(final_records),
        "similarity_check_enabled": not args.skip_similarity_check,
        "similarity_threshold": args.similarity_threshold,
        "jaccard_threshold": args.jaccard_threshold,
    }
    args.manifest_json.parent.mkdir(parents=True, exist_ok=True)
    args.manifest_json.write_text(json.dumps(manifest_data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    args.history_jsonl.parent.mkdir(parents=True, exist_ok=True)
    with args.history_jsonl.open("a", encoding="utf-8") as history:
        history.write(json.dumps(manifest_data, ensure_ascii=False) + "\n")

    write_summary_markdown(
        summary_path=args.summary_md,
        input_path=args.input,
        output_path=args.out_jsonl,
        source_files=len(source_files),
        total_records=total_records,
        published_records=len(published_records),
        blocked_records=sum(blocked_reasons.values()),
        existing_records=len(existing_records),
        output_total_records=len(final_records),
        new_records_added=new_records_added,
        publish_mode=args.publish_mode,
        release_version=release_version,
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
    print(f"[ok] manifest salvo em {args.manifest_json}")

    if args.fail_on_blocked and blocked_reasons:
        return 1
    if not published_records:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
