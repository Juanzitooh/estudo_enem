"""Modelos de dados do planejador offline."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date


PT_BR_WEEKDAYS = (
    "segunda",
    "terca",
    "quarta",
    "quinta",
    "sexta",
    "sabado",
    "domingo",
)


@dataclass(frozen=True)
class SkillRef:
    area: str
    habilidade: str

    @property
    def key(self) -> str:
        return f"{self.area}:{self.habilidade.upper()}"


@dataclass(frozen=True)
class AttemptRecord:
    data: date
    area: str
    habilidade: str
    acertos: int
    total: int
    tempo_min: int
    fonte: str = "simulado_offline"
    observacoes: str = ""

    @property
    def skill(self) -> SkillRef:
        return SkillRef(area=self.area, habilidade=self.habilidade.upper())

    @property
    def acuracia(self) -> float:
        if self.total <= 0:
            return 0.0
        return self.acertos / self.total


@dataclass(frozen=True)
class PriorityItem:
    skill: SkillRef
    prioridade: float
    acuracia_media: float
    questoes_7d: int
    dias_desde_ultimo_estudo: int
    tentativas_registradas: int
    sugestao_foco: str


@dataclass(frozen=True)
class StudyBlock:
    data: date
    dia_semana: str
    bloco: int
    skill: SkillRef
    foco: str
    alvo_questoes: int


@dataclass(frozen=True)
class PlanBuildResult:
    data_geracao: date
    prioridades: list[PriorityItem]
    blocos: list[StudyBlock]


@dataclass
class PlannerConfig:
    data_alvo_enem: date
    dias_estudo: list[str] = field(default_factory=lambda: list(PT_BR_WEEKDAYS[:-1]))
    dias_sem_estudo: list[str] = field(default_factory=lambda: ["domingo"])
    blocos_por_dia: int = 3
    duracao_bloco_min: int = 50
    meta_acerto_global: float = 0.9
    meta_questoes_semana_por_habilidade: int = 20
    prioridade_areas: dict[str, float] = field(default_factory=dict)
    habilidades_fixas: list[SkillRef] = field(default_factory=list)
    janela_dias_acuracia: int = 60
