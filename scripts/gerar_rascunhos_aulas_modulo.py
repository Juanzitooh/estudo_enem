#!/usr/bin/env python3
"""Gera rascunhos de aulas por modulo a partir do indice dos 6 volumes.

Objetivo:
- produzir arquivos em `aulas/{area}/modulos/V{volume}_M{modulo}_{slug}.md`;
- excluir `tipo_modulo=exercicios`;
- pre-preencher metadados editoriais e ficha do modulo.
"""

from __future__ import annotations

import argparse
import csv
import re
import unicodedata
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable

DEFAULT_INDEX_CSV = Path("plano/indice_livros_6_volumes.csv")
DEFAULT_TEMPLATE = Path("templates/aula_modulo_enem.md")
DEFAULT_OUT_ROOT = Path("aulas")


@dataclass(frozen=True)
class ModuleRow:
    volume: int
    modulo: int
    area: str
    materia: str
    titulo: str
    expectativas: list[str]
    competencias_habilidades: list[str]
    tipo_modulo: str


@dataclass
class GenerationStats:
    created: int = 0
    skipped_existing: int = 0
    skipped_tipo: int = 0
    skipped_invalid: int = 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Gera rascunhos de aulas por modulo com base no CSV de indice."
    )
    parser.add_argument(
        "--index-csv",
        type=Path,
        default=DEFAULT_INDEX_CSV,
        help="CSV com indice de modulos.",
    )
    parser.add_argument(
        "--template",
        type=Path,
        default=DEFAULT_TEMPLATE,
        help="Template markdown de aula por modulo.",
    )
    parser.add_argument(
        "--out-root",
        type=Path,
        default=DEFAULT_OUT_ROOT,
        help="Diretorio raiz de saida.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Limite maximo de aulas geradas.",
    )
    parser.add_argument(
        "--only-area",
        default="",
        help="Filtro opcional por nome de area (comparacao sem acento).",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Sobrescreve arquivos de aula ja existentes.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Nao grava arquivo, apenas mostra o que seria gerado.",
    )
    parser.add_argument(
        "--generated-by",
        default="codex",
        help="Valor para metadados editoriais do rascunho.",
    )
    return parser.parse_args()


def normalize_text(value: str) -> str:
    ascii_value = (
        unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    )
    return re.sub(r"\s+", " ", ascii_value).strip().lower()


def area_folder_name(area_name: str) -> str:
    normalized = normalize_text(area_name)
    if "linguagens" in normalized:
        return "linguagens"
    if "humanas" in normalized:
        return "humanas"
    if "natureza" in normalized:
        return "natureza"
    if "matemat" in normalized:
        return "matematica"
    slug = slugify(area_name)
    return slug if slug else "geral"


def slugify(value: str) -> str:
    normalized = normalize_text(value)
    normalized = normalized.replace("/", " ")
    slug = re.sub(r"[^a-z0-9]+", "_", normalized)
    return slug.strip("_")


def parse_list_field(raw_text: str) -> list[str]:
    if not raw_text:
        return []
    text = raw_text.replace("\r", "\n")
    chunks = re.split(r"[;\n]+", text)
    items: list[str] = []
    for chunk in chunks:
        clean_chunk = re.sub(r"\s+", " ", chunk).strip(" .")
        if clean_chunk:
            items.append(clean_chunk)
    return items


def parse_int(raw_value: str) -> int:
    text = (raw_value or "").strip()
    if not text:
        return 0
    try:
        return int(text)
    except ValueError:
        return 0


def iter_module_rows(index_csv: Path) -> Iterable[ModuleRow]:
    with index_csv.open("r", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            volume = parse_int((row.get("volume") or "").strip())
            modulo = parse_int((row.get("modulo") or "").strip())
            area = (row.get("area") or "").strip()
            materia = (row.get("materia") or "").strip()
            titulo = (row.get("titulo") or "").strip()
            tipo_modulo = normalize_text((row.get("tipo_modulo") or "").strip())
            expectativas = parse_list_field((row.get("expectativas_aprendizagem") or "").strip())
            habilidades = parse_list_field((row.get("habilidades") or "").strip())

            yield ModuleRow(
                volume=volume,
                modulo=modulo,
                area=area,
                materia=materia,
                titulo=titulo,
                expectativas=expectativas,
                competencias_habilidades=habilidades,
                tipo_modulo=tipo_modulo,
            )


def format_list_for_line(items: list[str], fallback: str) -> str:
    if not items:
        return fallback
    return "; ".join(items)


def build_output_path(out_root: Path, module_row: ModuleRow) -> Path:
    folder = area_folder_name(module_row.area)
    safe_title = slugify(module_row.titulo) or f"modulo_{module_row.modulo}"
    file_name = f"V{module_row.volume}_M{module_row.modulo}_{safe_title}.md"
    return out_root / folder / "modulos" / file_name


def render_module_draft(template_text: str, module_row: ModuleRow, generated_by: str) -> str:
    now_local = datetime.now().astimezone()
    now_local_text = now_local.strftime("%Y-%m-%d %H:%M %Z")
    now_utc_iso = now_local.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    window_start = (now_local - timedelta(days=365)).date().isoformat()
    window_end = now_local.date().isoformat()

    checklist_items = module_row.expectativas[:3]
    while len(checklist_items) < 3:
        checklist_items.append("Completar expectativa de aprendizagem")

    content = template_text
    replacements = {
        "# Aula ENEM — Módulo {volume}.{modulo} ({área}/{matéria})": (
            f"# Aula ENEM — Módulo {module_row.volume}.{module_row.modulo} "
            f"({module_row.area}/{module_row.materia})"
        ),
        "**Status editorial:** {rascunho | revisado | aprovado | publicado}  ": "**Status editorial:** rascunho  ",
        "**Atualizado por IA em:** {AAAA-MM-DD HH:MM TZ}  ": f"**Atualizado por IA em:** {now_local_text}  ",
        "**Revisado manualmente em:** {AAAA-MM-DD HH:MM TZ | pendente}  ": "**Revisado manualmente em:** pendente  ",
        "**Revisado por:** {nome | pendente}": "**Revisado por:** pendente",
        "`ia_updated_at`: {AAAA-MM-DDTHH:MM:SSZ}  ": f"`ia_updated_at`: {now_utc_iso}  ",
        "`manual_reviewed_at`: {AAAA-MM-DDTHH:MM:SSZ | pendente}  ": "`manual_reviewed_at`: pendente  ",
        "`manual_reviewed_by`: {nome | pendente}": "`manual_reviewed_by`: pendente",
        "- **Área:** {área ENEM}": f"- **Área:** {module_row.area}",
        "- **Matéria:** {matéria}": f"- **Matéria:** {module_row.materia}",
        "- **Volume:** {número}": f"- **Volume:** {module_row.volume}",
        "- **Módulo:** {número}": f"- **Módulo:** {module_row.modulo}",
        "- **Título:** {título do módulo}": f"- **Título:** {module_row.titulo or 'Preencher título'}",
        "- **Expectativas de aprendizagem:** {lista objetiva}": (
            "- **Expectativas de aprendizagem:** "
            f"{format_list_for_line(module_row.expectativas, 'Preencher expectativas')}"
        ),
        "- **Competências e habilidades:** {competências/habilidades associadas}": (
            "- **Competências e habilidades:** "
            f"{format_list_for_line(module_row.competencias_habilidades, 'Preencher competências/habilidades')}"
        ),
        "- **Janela temporal usada:** {AAAA-MM-DD a AAAA-MM-DD}": (
            f"- **Janela temporal usada:** {window_start} a {window_end}"
        ),
        "- [ ] {aprendizado 1}": f"- [ ] {checklist_items[0]}",
        "- [ ] {aprendizado 2}": f"- [ ] {checklist_items[1]}",
        "- [ ] {aprendizado 3}": f"- [ ] {checklist_items[2]}",
    }

    for original, replacement in replacements.items():
        content = content.replace(original, replacement)

    generated_header = (
        f"<!-- rascunho_gerado_por: {generated_by}; data_geracao: {now_utc_iso} -->\n"
    )
    return generated_header + content.rstrip() + "\n"


def should_include_row(module_row: ModuleRow, only_area_filter: str) -> bool:
    if module_row.tipo_modulo == "exercicios":
        return False
    if module_row.volume <= 0 or module_row.modulo <= 0:
        return False
    if not module_row.area or not module_row.materia:
        return False
    if not only_area_filter:
        return True
    return normalize_text(only_area_filter) in normalize_text(module_row.area)


def main() -> int:
    args = parse_args()

    if not args.index_csv.exists():
        raise SystemExit(f"arquivo de indice nao encontrado: {args.index_csv}")
    if not args.template.exists():
        raise SystemExit(f"template nao encontrado: {args.template}")

    template_text = args.template.read_text(encoding="utf-8")
    stats = GenerationStats()

    generated_count = 0
    for module_row in iter_module_rows(args.index_csv):
        if module_row.tipo_modulo == "exercicios":
            stats.skipped_tipo += 1
            continue

        if not should_include_row(module_row, args.only_area):
            stats.skipped_invalid += 1
            continue

        if args.limit is not None and generated_count >= args.limit:
            break

        output_path = build_output_path(args.out_root, module_row)
        if output_path.exists() and not args.overwrite:
            stats.skipped_existing += 1
            continue

        draft_text = render_module_draft(
            template_text=template_text,
            module_row=module_row,
            generated_by=args.generated_by,
        )

        if args.dry_run:
            print(f"[dry-run] gerar {output_path}")
        else:
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(draft_text, encoding="utf-8")
            print(f"[ok] gerado {output_path}")

        generated_count += 1
        stats.created += 1

    print("\nResumo:")
    print(f"- criados: {stats.created}")
    print(f"- ignorados (ja existem): {stats.skipped_existing}")
    print(f"- ignorados (tipo exercicios): {stats.skipped_tipo}")
    print(f"- ignorados (invalidos/filtro): {stats.skipped_invalid}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
