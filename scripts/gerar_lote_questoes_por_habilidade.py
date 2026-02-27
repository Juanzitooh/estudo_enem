#!/usr/bin/env python3
"""Cria estrutura de lote por habilidade com prompt final e manifest auditavel."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import sys


AREA_OPTIONS = {
    "linguagens": "Linguagens, Codigos e suas Tecnologias",
    "humanas": "Ciencias Humanas e suas Tecnologias",
    "natureza": "Ciencias da Natureza e suas Tecnologias",
    "matematica": "Matematica e suas Tecnologias",
}
TYPE_OPTIONS = {"treino", "simulado", "redacao"}
COMPETENCY_RE = re.compile(r"^C[0-9]{1,2}$")
SKILL_RE = re.compile(r"^H[0-9]{1,3}$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Monta lote de questoes por habilidade com rastreabilidade de prompt.",
    )
    parser.add_argument(
        "--area-key",
        choices=sorted(AREA_OPTIONS.keys()),
        required=True,
        help="Chave da area para pasta de saida.",
    )
    parser.add_argument(
        "--tipo",
        choices=sorted(TYPE_OPTIONS),
        default="treino",
        help="Tipo de lote.",
    )
    parser.add_argument("--disciplina", type=str, required=True, help="Disciplina do lote.")
    parser.add_argument("--materia", type=str, required=True, help="Materia do lote.")
    parser.add_argument("--competencia", type=str, required=True, help="Competencia (ex.: C3).")
    parser.add_argument("--habilidade", type=str, required=True, help="Habilidade (ex.: H10).")
    parser.add_argument(
        "--total-questoes",
        type=int,
        default=10,
        help="Quantidade total de questoes no lote.",
    )
    parser.add_argument(
        "--distribution",
        type=str,
        default="5,3,2",
        help="Distribuicao facil,media,dificil (ex.: 5,3,2).",
    )
    parser.add_argument(
        "--generated-by",
        type=str,
        default="agent.questoes.v1",
        help="Identificador do agente/gerador.",
    )
    parser.add_argument(
        "--prompt-ref",
        type=str,
        default="",
        help="Referencia de prompt. Se vazio, usa o id do lote.",
    )
    parser.add_argument(
        "--prompt-template",
        type=Path,
        default=Path("prompts/gerar_questoes_habilidade_enem.md"),
        help="Template base do prompt.",
    )
    parser.add_argument(
        "--out-root",
        type=Path,
        default=Path("questoes/generateds"),
        help="Diretorio raiz de saida.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Mostra caminho/manifest sem escrever arquivos.",
    )
    return parser.parse_args()


def normalize_token(raw_value: str) -> str:
    return raw_value.strip().upper()


def parse_distribution(raw_distribution: str) -> tuple[int, int, int]:
    parts = [chunk.strip() for chunk in raw_distribution.split(",")]
    if len(parts) != 3:
        raise ValueError("distribuicao invalida; use facil,media,dificil (ex.: 5,3,2)")
    try:
        values = tuple(int(item) for item in parts)
    except ValueError as exc:
        raise ValueError("distribuicao invalida; use apenas inteiros") from exc
    if any(value < 0 for value in values):
        raise ValueError("distribuicao invalida; nao use valores negativos")
    return values


def validate_inputs(args: argparse.Namespace, distribution: tuple[int, int, int]) -> None:
    if not COMPETENCY_RE.match(args.competencia.strip().upper()):
        raise ValueError("competencia invalida; use formato Cn")
    if not SKILL_RE.match(args.habilidade.strip().upper()):
        raise ValueError("habilidade invalida; use formato Hn")
    if args.total_questoes <= 0:
        raise ValueError("total_questoes deve ser maior que zero")
    if sum(distribution) != args.total_questoes:
        raise ValueError("soma da distribuicao deve bater com total_questoes")
    if not args.prompt_template.exists():
        raise ValueError(f"template de prompt nao encontrado: {args.prompt_template}")


def build_lote_id(area_key: str, habilidade: str, timestamp_token: str) -> str:
    skill_token = habilidade.strip().lower()
    return f"lote_{area_key}_{skill_token}_{timestamp_token}"


def render_prompt(template_text: str, replacements: dict[str, str]) -> str:
    rendered = template_text
    for key, value in replacements.items():
        rendered = rendered.replace(f"{{{key}}}", value)
    return rendered


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def main() -> int:
    args = parse_args()
    try:
        distribution = parse_distribution(args.distribution)
        validate_inputs(args, distribution)
    except ValueError as exc:
        print(f"[erro] {exc}")
        return 2

    now = datetime.now(timezone.utc)
    iso_timestamp = now.isoformat(timespec="seconds").replace("+00:00", "Z")
    stamp = now.strftime("%Y%m%dT%H%M%SZ")

    competencia = normalize_token(args.competencia)
    habilidade = normalize_token(args.habilidade)
    lote_id = build_lote_id(args.area_key, habilidade, stamp)
    prompt_ref = args.prompt_ref.strip() or lote_id

    area_label = AREA_OPTIONS[args.area_key]
    qtd_facil, qtd_media, qtd_dificil = distribution

    lote_dir = args.out_root / args.area_key / args.tipo / "lotes" / lote_id
    prompt_path = lote_dir / "prompt_final.md"
    manifest_path = lote_dir / "manifest.json"
    output_jsonl_path = lote_dir / "saida_ia.jsonl"
    readme_path = lote_dir / "README.md"

    template_text = args.prompt_template.read_text(encoding="utf-8")
    prompt_text = render_prompt(
        template_text=template_text,
        replacements={
            "TOTAL_QUESTOES": str(args.total_questoes),
            "AREA": area_label,
            "DISCIPLINA": args.disciplina.strip(),
            "MATERIA": args.materia.strip(),
            "TIPO": args.tipo,
            "COMPETENCIA": competencia,
            "HABILIDADE": habilidade,
            "QTD_FACIL": str(qtd_facil),
            "QTD_MEDIA": str(qtd_media),
            "QTD_DIFICIL": str(qtd_dificil),
            "PROMPT_REF": prompt_ref,
            "GENERATED_BY": args.generated_by.strip(),
            "UPDATED_AT_ISO": iso_timestamp,
        },
    )

    manifest = {
        "lote_id": lote_id,
        "created_at": iso_timestamp,
        "area_key": args.area_key,
        "area": area_label,
        "tipo": args.tipo,
        "disciplina": args.disciplina.strip(),
        "materia": args.materia.strip(),
        "competencia": competencia,
        "habilidade": habilidade,
        "total_questoes": args.total_questoes,
        "distribution": {
            "facil": qtd_facil,
            "media": qtd_media,
            "dificil": qtd_dificil,
        },
        "generated_by": args.generated_by.strip(),
        "prompt_ref": prompt_ref,
        "prompt_template": str(args.prompt_template),
        "output_jsonl": str(output_jsonl_path),
        "review_status": "rascunho",
    }

    if args.dry_run:
        print(f"[dry-run] lote_id={lote_id}")
        print(f"[dry-run] pasta={lote_dir}")
        print(json.dumps(manifest, ensure_ascii=False, indent=2))
        return 0

    write_text(prompt_path, prompt_text)
    write_text(manifest_path, json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    write_text(output_jsonl_path, "")
    write_text(
        readme_path,
        (
            f"# {lote_id}\n\n"
            "1. Abra `prompt_final.md` e copie o prompt para IA externa.\n"
            "2. Salve a saida JSONL da IA em `saida_ia.jsonl`.\n"
            "3. Rode validacao local:\n\n"
            "```bash\n"
            f"python3 scripts/validar_questoes_geradas.py --input {output_jsonl_path} "
            f"--expected-distribution {qtd_facil},{qtd_media},{qtd_dificil}\n"
            "```\n"
        ),
    )

    print(f"[ok] lote criado em {lote_dir}")
    print(f"[ok] prompt final: {prompt_path}")
    print(f"[ok] manifest: {manifest_path}")
    print(f"[ok] saida esperada: {output_jsonl_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
