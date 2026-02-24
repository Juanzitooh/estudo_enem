"""Motor determinístico de priorização e geração de plano."""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from datetime import date, timedelta

from .models import AttemptRecord, PlanBuildResult, PlannerConfig, PriorityItem, SkillRef, StudyBlock


@dataclass(frozen=True)
class _SkillAggregates:
    acertos: int = 0
    total: int = 0
    questoes_7d: int = 0
    tentativas: int = 0
    ultimo_estudo: date | None = None

    @property
    def acuracia_media(self) -> float:
        if self.total <= 0:
            return 0.0
        return self.acertos / self.total


def _normalize_day_name(raw: str) -> str:
    normalized = raw.strip().lower()
    replacements = (
        ("ç", "c"),
        ("á", "a"),
        ("à", "a"),
        ("ã", "a"),
        ("â", "a"),
        ("é", "e"),
        ("ê", "e"),
        ("í", "i"),
        ("ó", "o"),
        ("ô", "o"),
        ("õ", "o"),
        ("ú", "u"),
    )
    for source, target in replacements:
        normalized = normalized.replace(source, target)
    return normalized


def _area_weight(area: str, area_weights: dict[str, float]) -> float:
    if area in area_weights:
        return area_weights[area]
    for key, value in area_weights.items():
        if _normalize_day_name(key) == _normalize_day_name(area):
            return value
    return 1.0


def _build_aggregates(
    attempts: list[AttemptRecord],
    config: PlannerConfig,
    reference_date: date,
) -> dict[str, _SkillAggregates]:
    cutoff_accuracy = reference_date - timedelta(days=config.janela_dias_acuracia)
    cutoff_7d = reference_date - timedelta(days=7)

    grouped: dict[str, dict[str, object]] = defaultdict(
        lambda: {
            "acertos": 0,
            "total": 0,
            "questoes_7d": 0,
            "tentativas": 0,
            "ultimo_estudo": None,
        }
    )

    for record in attempts:
        skill_key = record.skill.key
        bucket = grouped[skill_key]

        if record.data >= cutoff_accuracy:
            bucket["acertos"] = int(bucket["acertos"]) + record.acertos
            bucket["total"] = int(bucket["total"]) + record.total

        if record.data >= cutoff_7d:
            bucket["questoes_7d"] = int(bucket["questoes_7d"]) + record.total

        bucket["tentativas"] = int(bucket["tentativas"]) + 1

        last_date = bucket["ultimo_estudo"]
        if last_date is None or record.data > last_date:
            bucket["ultimo_estudo"] = record.data

    result: dict[str, _SkillAggregates] = {}
    for skill_key, bucket in grouped.items():
        result[skill_key] = _SkillAggregates(
            acertos=int(bucket["acertos"]),
            total=int(bucket["total"]),
            questoes_7d=int(bucket["questoes_7d"]),
            tentativas=int(bucket["tentativas"]),
            ultimo_estudo=bucket["ultimo_estudo"],
        )
    return result


def _focus_from_accuracy(accuracy: float) -> tuple[str, int]:
    if accuracy < 0.55:
        return ("base teórica + exemplos guiados", 8)
    if accuracy < 0.75:
        return ("questões guiadas + correção ativa", 10)
    return ("simulado curto + revisão de erros", 12)


def _compute_priorities(
    attempts: list[AttemptRecord],
    config: PlannerConfig,
    reference_date: date,
) -> list[PriorityItem]:
    aggregates = _build_aggregates(attempts, config, reference_date)

    skill_catalog: dict[str, SkillRef] = {}
    for fixed_skill in config.habilidades_fixas:
        skill_catalog[fixed_skill.key] = fixed_skill
    for record in attempts:
        skill_catalog[record.skill.key] = record.skill

    if not skill_catalog:
        return []

    priorities: list[PriorityItem] = []
    fixed_skill_keys = {item.key for item in config.habilidades_fixas}
    for key, skill in skill_catalog.items():
        stats = aggregates.get(key, _SkillAggregates())
        area_weight = _area_weight(skill.area, config.prioridade_areas)

        acuracia_media = stats.acuracia_media
        componente_erro = 1.0 - acuracia_media if stats.total > 0 else 1.0
        componente_cobertura = max(
            0.0,
            (config.meta_questoes_semana_por_habilidade - stats.questoes_7d)
            / max(config.meta_questoes_semana_por_habilidade, 1),
        )
        dias_sem_estudar = 30
        if stats.ultimo_estudo is not None:
            dias_sem_estudar = (reference_date - stats.ultimo_estudo).days
        componente_recencia = min(max(dias_sem_estudar, 0) / 14.0, 1.0)

        fixed_bonus = 0.15 if key in fixed_skill_keys else 0.0
        prioridade = area_weight * (
            0.60 * componente_erro
            + 0.25 * componente_cobertura
            + 0.15 * componente_recencia
        ) + fixed_bonus

        foco, _ = _focus_from_accuracy(acuracia_media)
        priorities.append(
            PriorityItem(
                skill=skill,
                prioridade=round(prioridade, 4),
                acuracia_media=round(acuracia_media, 4),
                questoes_7d=stats.questoes_7d,
                dias_desde_ultimo_estudo=dias_sem_estudar,
                tentativas_registradas=stats.tentativas,
                sugestao_foco=foco,
            )
        )

    priorities.sort(key=lambda item: item.prioridade, reverse=True)
    return priorities


def _build_study_days(config: PlannerConfig, reference_date: date) -> list[tuple[date, str]]:
    normalized_no_study = {_normalize_day_name(day) for day in config.dias_sem_estudo}
    normalized_days = {_normalize_day_name(day) for day in config.dias_estudo}
    index_to_day = {
        0: "segunda",
        1: "terca",
        2: "quarta",
        3: "quinta",
        4: "sexta",
        5: "sabado",
        6: "domingo",
    }

    study_days: list[tuple[date, str]] = []
    for offset in range(0, 7):
        candidate_date = reference_date + timedelta(days=offset)
        weekday_name = index_to_day[candidate_date.weekday()]
        if weekday_name not in normalized_days:
            continue
        if weekday_name in normalized_no_study:
            continue
        study_days.append((candidate_date, weekday_name))
    return study_days


def _generate_blocks(
    priorities: list[PriorityItem],
    config: PlannerConfig,
    reference_date: date,
) -> list[StudyBlock]:
    if not priorities:
        return []

    study_days = _build_study_days(config, reference_date)
    if not study_days:
        return []

    blocks: list[StudyBlock] = []
    skill_index = 0
    total_skills = len(priorities)
    last_skill_key_by_day: dict[date, str] = {}

    for current_date, day_name in study_days:
        for block_number in range(1, config.blocos_por_dia + 1):
            candidate = priorities[skill_index % total_skills]
            skill_index += 1

            # Evita repetir a mesma habilidade em blocos seguidos no mesmo dia
            if (
                total_skills > 1
                and last_skill_key_by_day.get(current_date) == candidate.skill.key
            ):
                candidate = priorities[skill_index % total_skills]
                skill_index += 1

            foco, alvo_questoes = _focus_from_accuracy(candidate.acuracia_media)
            if block_number == config.blocos_por_dia:
                foco = f"{foco} + revisão dos erros do dia"

            blocks.append(
                StudyBlock(
                    data=current_date,
                    dia_semana=day_name,
                    bloco=block_number,
                    skill=candidate.skill,
                    foco=foco,
                    alvo_questoes=alvo_questoes,
                )
            )
            last_skill_key_by_day[current_date] = candidate.skill.key

    return blocks


def build_plan(
    attempts: list[AttemptRecord],
    config: PlannerConfig,
    reference_date: date | None = None,
) -> PlanBuildResult:
    today = reference_date or date.today()
    priorities = _compute_priorities(attempts=attempts, config=config, reference_date=today)
    blocks = _generate_blocks(priorities=priorities, config=config, reference_date=today)
    return PlanBuildResult(data_geracao=today, prioridades=priorities, blocos=blocks)
