#!/usr/bin/env python3
"""Gera metadados consolidados por questão para consulta rápida de agente."""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


VALID_DIFFICULTIES = {"facil", "media", "dificil"}
COMPETENCY_RE = re.compile(r"^C\d+$")
SKILL_RE = re.compile(r"^H\d+$")


@dataclass(frozen=True)
class ConsolidatedQuestion:
    id_questao: str
    ano: int
    dia: int
    numero: int
    variacao: int
    area: str
    disciplina: str
    competencia: str
    habilidade: str
    dificuldade: str
    tem_imagem: bool
    texto_vazio: bool
    confianca_mapeamento: str
    tema_estimado: str
    motivo_mapeamento: str
    fallback_image_paths: str
    gabarito: str
    preview: str
    source_csv: str

    def as_csv_row(self) -> dict[str, str]:
        return {
            "id_questao": self.id_questao,
            "ano": str(self.ano),
            "dia": str(self.dia),
            "numero": str(self.numero),
            "variacao": str(self.variacao),
            "area": self.area,
            "disciplina": self.disciplina,
            "competencia": self.competencia,
            "habilidade": self.habilidade,
            "dificuldade": self.dificuldade,
            "tem_imagem": "true" if self.tem_imagem else "false",
            "texto_vazio": "true" if self.texto_vazio else "false",
            "confianca_mapeamento": self.confianca_mapeamento,
            "tema_estimado": self.tema_estimado,
            "motivo_mapeamento": self.motivo_mapeamento,
            "fallback_image_paths": self.fallback_image_paths,
            "gabarito": self.gabarito,
            "preview": self.preview,
            "source_csv": self.source_csv,
        }

    def as_json_row(self) -> dict[str, object]:
        return {
            "id_questao": self.id_questao,
            "ano": self.ano,
            "dia": self.dia,
            "numero": self.numero,
            "variacao": self.variacao,
            "area": self.area,
            "disciplina": self.disciplina,
            "competencia": self.competencia,
            "habilidade": self.habilidade,
            "dificuldade": self.dificuldade,
            "tem_imagem": self.tem_imagem,
            "texto_vazio": self.texto_vazio,
            "confianca_mapeamento": self.confianca_mapeamento,
            "tema_estimado": self.tema_estimado,
            "motivo_mapeamento": self.motivo_mapeamento,
            "fallback_image_paths": [
                item
                for item in self.fallback_image_paths.split(";")
                if item.strip()
            ],
            "gabarito": self.gabarito,
            "preview": self.preview,
            "source_csv": self.source_csv,
        }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Consolida metadados em esquema padrão (ano/dia/numero/area/"
            "disciplina/competencia/habilidade/dificuldade/tem_imagem)."
        )
    )
    parser.add_argument(
        "--mapped-csv",
        type=Path,
        default=Path("questoes/mapeamento_habilidades/questoes_mapeadas.csv"),
        help="CSV fonte com mapeamento automático.",
    )
    parser.add_argument(
        "--out-csv",
        type=Path,
        default=Path(
            "questoes/mapeamento_habilidades/questoes_metadados_consolidados.csv"
        ),
        help="CSV de saída consolidado.",
    )
    parser.add_argument(
        "--out-jsonl",
        type=Path,
        default=Path(
            "questoes/mapeamento_habilidades/questoes_metadados_consolidados.jsonl"
        ),
        help="JSONL de saída consolidado.",
    )
    parser.add_argument(
        "--out-summary",
        type=Path,
        default=Path(
            "questoes/mapeamento_habilidades/resumo_metadados_consolidados.md"
        ),
        help="Resumo markdown do consolidado.",
    )
    return parser.parse_args()


def normalize_competencia(raw_value: str) -> str:
    value = raw_value.strip().upper().replace(" ", "")
    if COMPETENCY_RE.fullmatch(value):
        return value
    return ""


def normalize_habilidade(raw_value: str) -> str:
    value = raw_value.strip().upper().replace(" ", "")
    if SKILL_RE.fullmatch(value):
        return value
    return ""


def normalize_dificuldade(raw_value: str) -> str:
    value = (
        raw_value.strip()
        .lower()
        .replace("á", "a")
        .replace("é", "e")
        .replace("í", "i")
        .replace("ó", "o")
        .replace("ú", "u")
    )
    if value in VALID_DIFFICULTIES:
        return value
    return "nao_classificada"


def parse_bool(raw_value: str) -> bool:
    value = raw_value.strip().lower()
    return value in {"1", "true", "sim", "yes", "y"}


def make_question_id(ano: int, dia: int, numero: int, variacao: int) -> str:
    return f"enem_{ano}_d{dia}_q{numero:03d}_v{variacao}"


def load_consolidated(mapped_csv: Path) -> list[ConsolidatedQuestion]:
    if not mapped_csv.exists():
        raise FileNotFoundError(f"CSV não encontrado: {mapped_csv}")

    rows: list[ConsolidatedQuestion] = []
    with mapped_csv.open("r", encoding="utf-8", newline="") as file_obj:
        reader = csv.DictReader(file_obj)
        for row in reader:
            try:
                ano = int((row.get("ano") or "0").strip() or 0)
                dia = int((row.get("dia") or "0").strip() or 0)
                numero = int((row.get("numero") or "0").strip() or 0)
                variacao = int((row.get("variacao") or "1").strip() or 1)
            except ValueError:
                continue

            if ano <= 0 or dia <= 0 or numero <= 0 or variacao <= 0:
                continue

            competencia = normalize_competencia(row.get("competencia_estimada", ""))
            habilidade = normalize_habilidade(row.get("habilidade_estimada", ""))
            dificuldade = normalize_dificuldade(
                row.get("dificuldade", "") or row.get("dificuldade_estimada", "")
            )

            rows.append(
                ConsolidatedQuestion(
                    id_questao=make_question_id(ano, dia, numero, variacao),
                    ano=ano,
                    dia=dia,
                    numero=numero,
                    variacao=variacao,
                    area=(row.get("area") or "").strip(),
                    disciplina=(row.get("disciplina") or "").strip(),
                    competencia=competencia,
                    habilidade=habilidade,
                    dificuldade=dificuldade,
                    tem_imagem=parse_bool(row.get("tem_imagem", "")),
                    texto_vazio=parse_bool(row.get("texto_vazio", "")),
                    confianca_mapeamento=(row.get("confianca") or "").strip(),
                    tema_estimado=(row.get("tema_estimado") or "").strip(),
                    motivo_mapeamento=(row.get("motivo") or "").strip(),
                    fallback_image_paths=(row.get("fallback_image_paths") or "").strip(),
                    gabarito=(row.get("gabarito") or "").strip(),
                    preview=(row.get("preview") or "").strip(),
                    source_csv=str(mapped_csv),
                )
            )
    rows.sort(key=lambda item: (item.ano, item.dia, item.numero, item.variacao))
    return rows


def write_csv(path: Path, rows: list[ConsolidatedQuestion]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "id_questao",
        "ano",
        "dia",
        "numero",
        "variacao",
        "area",
        "disciplina",
        "competencia",
        "habilidade",
        "dificuldade",
        "tem_imagem",
        "texto_vazio",
        "confianca_mapeamento",
        "tema_estimado",
        "motivo_mapeamento",
        "fallback_image_paths",
        "gabarito",
        "preview",
        "source_csv",
    ]
    with path.open("w", encoding="utf-8", newline="") as file_obj:
        writer = csv.DictWriter(file_obj, fieldnames=fieldnames)
        writer.writeheader()
        for item in rows:
            writer.writerow(item.as_csv_row())


def write_jsonl(path: Path, rows: list[ConsolidatedQuestion]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as file_obj:
        for item in rows:
            file_obj.write(json.dumps(item.as_json_row(), ensure_ascii=False) + "\n")


def write_summary(path: Path, rows: list[ConsolidatedQuestion]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    by_area = Counter(item.area for item in rows)
    by_difficulty = Counter(item.dificuldade for item in rows)
    by_competencia = Counter(item.competencia for item in rows)
    by_habilidade = Counter(item.habilidade for item in rows)
    with_image = sum(1 for item in rows if item.tem_imagem)
    without_image = len(rows) - with_image
    missing_comp = sum(1 for item in rows if not item.competencia)
    missing_skill = sum(1 for item in rows if not item.habilidade)
    text_empty = sum(1 for item in rows if item.texto_vazio)

    lines: list[str] = []
    lines.append("# Resumo de Metadados Consolidados")
    lines.append("")
    lines.append(f"- Total de questões: **{len(rows)}**")
    lines.append(f"- Com imagem: **{with_image}**")
    lines.append(f"- Sem imagem: **{without_image}**")
    lines.append(f"- Texto vazio (OCR): **{text_empty}**")
    lines.append(f"- Competência ausente: **{missing_comp}**")
    lines.append(f"- Habilidade ausente: **{missing_skill}**")
    lines.append("")
    lines.append("## Distribuição por área")
    lines.append("")
    lines.append("| Área | Questões |")
    lines.append("|---|---:|")
    for area, count in by_area.most_common():
        lines.append(f"| {area} | {count} |")
    lines.append("")
    lines.append("## Distribuição por dificuldade")
    lines.append("")
    lines.append("| Dificuldade | Questões |")
    lines.append("|---|---:|")
    for difficulty, count in by_difficulty.most_common():
        lines.append(f"| {difficulty} | {count} |")
    lines.append("")
    lines.append("## Top competências")
    lines.append("")
    lines.append("| Competência | Questões |")
    lines.append("|---|---:|")
    for comp, count in by_competencia.most_common(12):
        lines.append(f"| {comp} | {count} |")
    lines.append("")
    lines.append("## Top habilidades")
    lines.append("")
    lines.append("| Habilidade | Questões |")
    lines.append("|---|---:|")
    for skill, count in by_habilidade.most_common(20):
        lines.append(f"| {skill} | {count} |")
    lines.append("")
    lines.append("## Observação")
    lines.append("")
    lines.append(
        "- `dificuldade=nao_classificada` indica ausência de classificação calibrada no mapeamento atual."
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    args = parse_args()
    rows = load_consolidated(args.mapped_csv)
    write_csv(args.out_csv, rows)
    write_jsonl(args.out_jsonl, rows)
    write_summary(args.out_summary, rows)

    print(f"[ok] questões consolidadas: {len(rows)}")
    print(f"[ok] csv: {args.out_csv}")
    print(f"[ok] jsonl: {args.out_jsonl}")
    print(f"[ok] resumo: {args.out_summary}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
