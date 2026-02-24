"""I/O do planejador offline."""

from __future__ import annotations

import csv
import json
from datetime import date, datetime
from pathlib import Path

from .models import AttemptRecord, PlanBuildResult, PlannerConfig, SkillRef

ATTEMPTS_HEADER = (
    "data",
    "area",
    "habilidade",
    "acertos",
    "total",
    "tempo_min",
    "fonte",
    "observacoes",
)


def _parse_date(value: str) -> date:
    return datetime.strptime(value, "%Y-%m-%d").date()


def _build_skill_ref_list(raw_items: list[dict[str, str]]) -> list[SkillRef]:
    result: list[SkillRef] = []
    for item in raw_items:
        area = str(item.get("area", "")).strip()
        habilidade = str(item.get("habilidade", "")).strip().upper()
        if not area or not habilidade:
            continue
        result.append(SkillRef(area=area, habilidade=habilidade))
    return result


def load_planner_config(path: Path) -> PlannerConfig:
    payload = json.loads(path.read_text(encoding="utf-8"))

    return PlannerConfig(
        data_alvo_enem=_parse_date(str(payload["data_alvo_enem"])),
        dias_estudo=list(payload.get("dias_estudo", [])),
        dias_sem_estudo=list(payload.get("dias_sem_estudo", [])),
        blocos_por_dia=int(payload.get("blocos_por_dia", 3)),
        duracao_bloco_min=int(payload.get("duracao_bloco_min", 50)),
        meta_acerto_global=float(payload.get("meta_acerto_global", 0.9)),
        meta_questoes_semana_por_habilidade=int(
            payload.get("meta_questoes_semana_por_habilidade", 20)
        ),
        prioridade_areas=dict(payload.get("prioridade_areas", {})),
        habilidades_fixas=_build_skill_ref_list(payload.get("habilidades_fixas", [])),
        janela_dias_acuracia=int(payload.get("janela_dias_acuracia", 60)),
    )


def ensure_attempts_csv(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        return
    with path.open("w", encoding="utf-8", newline="") as file_obj:
        writer = csv.DictWriter(file_obj, fieldnames=ATTEMPTS_HEADER)
        writer.writeheader()


def load_attempts_csv(path: Path) -> list[AttemptRecord]:
    if not path.exists():
        return []

    records: list[AttemptRecord] = []
    with path.open("r", encoding="utf-8", newline="") as file_obj:
        reader = csv.DictReader(file_obj)
        for row in reader:
            try:
                record = AttemptRecord(
                    data=_parse_date(str(row.get("data", "")).strip()),
                    area=str(row.get("area", "")).strip(),
                    habilidade=str(row.get("habilidade", "")).strip().upper(),
                    acertos=int(row.get("acertos", 0)),
                    total=int(row.get("total", 0)),
                    tempo_min=int(row.get("tempo_min", 0)),
                    fonte=str(row.get("fonte", "simulado_offline")).strip() or "simulado_offline",
                    observacoes=str(row.get("observacoes", "")).strip(),
                )
            except (ValueError, TypeError):
                continue
            if not record.area or not record.habilidade or record.total <= 0:
                continue
            records.append(record)
    return records


def append_attempt_record(path: Path, record: AttemptRecord) -> None:
    ensure_attempts_csv(path)
    with path.open("a", encoding="utf-8", newline="") as file_obj:
        writer = csv.DictWriter(file_obj, fieldnames=ATTEMPTS_HEADER)
        writer.writerow(
            {
                "data": record.data.isoformat(),
                "area": record.area,
                "habilidade": record.habilidade.upper(),
                "acertos": record.acertos,
                "total": record.total,
                "tempo_min": record.tempo_min,
                "fonte": record.fonte,
                "observacoes": record.observacoes,
            }
        )


def write_priority_csv(path: Path, plan: PlanBuildResult) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as file_obj:
        writer = csv.writer(file_obj)
        writer.writerow(
            [
                "area",
                "habilidade",
                "prioridade",
                "acuracia_media",
                "questoes_7d",
                "dias_desde_ultimo_estudo",
                "tentativas_registradas",
                "sugestao_foco",
            ]
        )
        for item in plan.prioridades:
            writer.writerow(
                [
                    item.skill.area,
                    item.skill.habilidade,
                    f"{item.prioridade:.4f}",
                    f"{item.acuracia_media:.4f}",
                    item.questoes_7d,
                    item.dias_desde_ultimo_estudo,
                    item.tentativas_registradas,
                    item.sugestao_foco,
                ]
            )


def write_plan_markdown(path: Path, plan: PlanBuildResult) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

    lines: list[str] = []
    lines.append("# Plano Semanal Gerado (Offline)")
    lines.append("")
    lines.append(f"- Data de geração: **{plan.data_geracao.isoformat()}**")
    lines.append("")

    lines.append("## Ranking de prioridades (top 12)")
    lines.append("")
    lines.append("| # | Área | Habilidade | Prioridade | Acurácia média | Qtd 7d | Último estudo (dias) |")
    lines.append("|---:|---|---|---:|---:|---:|---:|")

    for index, item in enumerate(plan.prioridades[:12], start=1):
        lines.append(
            "| {idx} | {area} | {hab} | {prio:.4f} | {acc:.2%} | {q7d} | {last} |".format(
                idx=index,
                area=item.skill.area,
                hab=item.skill.habilidade,
                prio=item.prioridade,
                acc=item.acuracia_media,
                q7d=item.questoes_7d,
                last=item.dias_desde_ultimo_estudo,
            )
        )
    lines.append("")

    lines.append("## Cronograma de blocos")
    lines.append("")
    lines.append("| Data | Dia | Bloco | Área | Habilidade | Foco | Alvo de questões |")
    lines.append("|---|---|---:|---|---|---|---:|")
    for block in plan.blocos:
        lines.append(
            "| {data} | {dia} | {bloco} | {area} | {hab} | {foco} | {alvo} |".format(
                data=block.data.isoformat(),
                dia=block.dia_semana,
                bloco=block.bloco,
                area=block.skill.area,
                hab=block.skill.habilidade,
                foco=block.foco,
                alvo=block.alvo_questoes,
            )
        )
    lines.append("")

    lines.append("## Como usar hoje")
    lines.append("")
    lines.append("1. Execute os blocos na ordem e registre o resultado em `plano/desempenho_habilidades.csv`.")
    lines.append("2. Recalcule o plano no fim do dia para o motor reagir ao seu feedback real.")
    lines.append("3. Se travar em uma habilidade, marque observação e aumente o tempo de revisão no próximo ciclo.")
    lines.append("")

    path.write_text("\n".join(lines), encoding="utf-8")
