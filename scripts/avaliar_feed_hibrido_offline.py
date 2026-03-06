#!/usr/bin/env python3
"""Avalia offline baseline por skill vs feed hibrido por conceito.

Metodologia resumida:
- carrega questoes reais do bundle de release local;
- cruza com Q-matrix piloto de Humanas;
- simula sessoes por usuario com modelo probabilistico de acerto/tempo;
- compara politicas de selecao de proxima questao;
- gera artefatos CSV/JSON/Markdown para decisao de rollout.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import random
import statistics
import zipfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, List, Tuple


@dataclass(frozen=True)
class Question:
    question_id: str
    skill: str
    difficulty: str
    concept_weights: Dict[str, float]


@dataclass
class RunMetrics:
    policy: str
    user_index: int
    main_questions: int
    accuracy: float
    avg_seconds: float
    retention: float


@dataclass
class PolicyResult:
    policy: str
    metrics: List[RunMetrics]

    @property
    def mean_accuracy(self) -> float:
        return statistics.fmean(item.accuracy for item in self.metrics)

    @property
    def mean_seconds(self) -> float:
        return statistics.fmean(item.avg_seconds for item in self.metrics)

    @property
    def mean_retention(self) -> float:
        return statistics.fmean(item.retention for item in self.metrics)

    @property
    def stdev_accuracy(self) -> float:
        return _safe_stdev([item.accuracy for item in self.metrics])

    @property
    def stdev_seconds(self) -> float:
        return _safe_stdev([item.avg_seconds for item in self.metrics])

    @property
    def stdev_retention(self) -> float:
        return _safe_stdev([item.retention for item in self.metrics])


def _safe_stdev(values: List[float]) -> float:
    if len(values) < 2:
        return 0.0
    return statistics.stdev(values)


def _normalize_skill(token: str) -> str:
    compact = token.strip().upper().replace(" ", "")
    if not compact:
        return ""
    if compact.startswith("H") and compact[1:].isdigit():
        return f"H{int(compact[1:])}"
    if "-H" in compact:
        suffix = compact.split("-H")[-1]
        digits = "".join(ch for ch in suffix if ch.isdigit())
        if digits:
            return f"H{int(digits)}"
    return ""


def _normalize_difficulty(token: str) -> str:
    compact = "".join(ch for ch in token.lower().strip() if ch.isalnum())
    if compact in {"facil", "easy", "f"}:
        return "facil"
    if compact in {"media", "medio", "medium", "m"}:
        return "media"
    if compact in {"dificil", "hard", "d"}:
        return "dificil"
    return "media"


def load_bundle_questions(release_zip: Path, bundle_file: str) -> Dict[str, Dict[str, str]]:
    with zipfile.ZipFile(release_zip) as archive:
        raw_bundle = archive.read(bundle_file)
    payload = json.loads(raw_bundle)

    questions = {}
    for item in payload.get("questions", []):
        if not isinstance(item, dict):
            continue
        question_id = str(item.get("id", "")).strip()
        if not question_id:
            continue
        questions[question_id] = {
            "skill": _normalize_skill(str(item.get("skill", ""))),
            "difficulty": _normalize_difficulty(str(item.get("difficulty", ""))),
        }
    return questions


def load_concept_pilot(concept_bundle_path: Path) -> Tuple[Dict[str, float], Dict[str, Dict[str, float]]]:
    payload = json.loads(concept_bundle_path.read_text(encoding="utf-8"))

    concept_base_weights: Dict[str, float] = {}
    for item in payload.get("concept_priority_weights", []):
        if not isinstance(item, dict):
            continue
        concept_id = str(item.get("concept_id", "")).strip()
        if not concept_id:
            continue
        base_weight = float(item.get("base_weight", 1.0))
        concept_base_weights[concept_id] = max(0.1, min(5.0, base_weight))

    question_concepts: Dict[str, Dict[str, float]] = {}
    for item in payload.get("question_concepts", []):
        if not isinstance(item, dict):
            continue
        question_id = str(item.get("question_id", "")).strip()
        concept_id = str(item.get("concept_id", "")).strip()
        if not question_id or not concept_id:
            continue
        weight = float(item.get("weight", 0.0))
        if weight <= 0:
            continue
        bucket = question_concepts.setdefault(question_id, {})
        bucket[concept_id] = max(bucket.get(concept_id, 0.0), weight)

    return concept_base_weights, question_concepts


def build_question_pool(
    bundle_questions: Dict[str, Dict[str, str]],
    question_concepts: Dict[str, Dict[str, float]],
) -> List[Question]:
    pool: List[Question] = []
    for question_id, concepts in question_concepts.items():
        question_meta = bundle_questions.get(question_id)
        if question_meta is None:
            continue
        skill = question_meta.get("skill", "")
        if not skill:
            continue

        total = sum(concepts.values())
        if total <= 0:
            continue
        normalized = {concept_id: weight / total for concept_id, weight in concepts.items()}
        pool.append(
            Question(
                question_id=question_id,
                skill=skill,
                difficulty=question_meta.get("difficulty", "media"),
                concept_weights=normalized,
            )
        )

    pool.sort(key=lambda item: item.question_id)
    return pool


def _initial_mastery(concepts: Iterable[str], rng: random.Random) -> Dict[str, float]:
    concept_ids = list(concepts)
    weak_concepts = set(rng.sample(concept_ids, k=max(1, len(concept_ids) // 4)))
    mastery = {}
    for concept_id in concept_ids:
        base = min(0.95, max(0.05, rng.gauss(0.54, 0.16)))
        if concept_id in weak_concepts:
            base = max(0.05, base - rng.uniform(0.12, 0.28))
        mastery[concept_id] = base
    return mastery


def _question_success_probability(question: Question, mastery: Dict[str, float]) -> float:
    concept_component = 0.0
    for concept_id, weight in question.concept_weights.items():
        concept_component += mastery.get(concept_id, 0.5) * weight

    diff_delta = {
        "facil": 0.06,
        "media": 0.00,
        "dificil": -0.08,
    }.get(question.difficulty, 0.0)

    probability = concept_component + diff_delta
    return min(0.96, max(0.04, probability))


def _question_elapsed_seconds(question: Question, success_probability: float, rng: random.Random) -> float:
    diff_penalty = {
        "facil": -8.0,
        "media": 0.0,
        "dificil": 18.0,
    }.get(question.difficulty, 0.0)
    base = 85.0 + diff_penalty + (1.0 - success_probability) * 52.0
    noisy = base + rng.gauss(0.0, 9.0)
    return min(220.0, max(35.0, noisy))


def _apply_learning(
    mastery: Dict[str, float],
    question: Question,
    correct: bool,
    decay: float,
) -> None:
    touched = set(question.concept_weights)
    for concept_id in mastery:
        if concept_id not in touched:
            mastery[concept_id] = max(0.02, mastery[concept_id] * (1.0 - decay))

    learn_rate = 0.045 if correct else 0.015
    for concept_id, weight in question.concept_weights.items():
        current = mastery.get(concept_id, 0.5)
        mastery[concept_id] = min(0.98, current + learn_rate * weight * (1.0 - current))


def _choose_question_skill_only(
    remaining: List[Question],
    skill_posterior: Dict[str, Tuple[float, float]],
    rng: random.Random,
) -> Question:
    if not remaining:
        raise ValueError("pool vazio")

    by_skill: Dict[str, List[Question]] = {}
    for question in remaining:
        by_skill.setdefault(question.skill, []).append(question)

    skill_scores: List[Tuple[float, str]] = []
    for skill, questions in by_skill.items():
        alpha, beta = skill_posterior.get(skill, (1.0, 1.0))
        mean = alpha / (alpha + beta)
        exploration = 1.0 / math.sqrt(alpha + beta)
        score = mean - (0.22 * exploration)
        score += 0.015 * math.log(1 + len(questions))
        skill_scores.append((score, skill))

    skill_scores.sort(key=lambda item: item[0])
    target_skill = skill_scores[0][1]
    candidates = by_skill[target_skill]
    return rng.choice(candidates)


def _choose_question_hybrid(
    remaining: List[Question],
    concept_posterior: Dict[str, Tuple[float, float]],
    concept_base_weights: Dict[str, float],
    rng: random.Random,
) -> Question:
    if not remaining:
        raise ValueError("pool vazio")

    best_score = None
    best_questions: List[Question] = []

    for question in remaining:
        weakness_score = 0.0
        novelty_score = 0.0
        for concept_id, weight in question.concept_weights.items():
            alpha, beta = concept_posterior.get(concept_id, (1.0, 1.0))
            mastery_mean = alpha / (alpha + beta)
            weakness = 1.0 - mastery_mean
            base_weight = concept_base_weights.get(concept_id, 1.0)
            weakness_score += weight * weakness * base_weight
            novelty_score += weight / (1.0 + alpha + beta)

        score = weakness_score + (0.15 * novelty_score)
        score += rng.random() * 0.0005  # desempate estavel com jitter minimo

        if best_score is None or score > best_score:
            best_score = score
            best_questions = [question]
        elif abs(score - best_score) <= 1e-9:
            best_questions.append(question)

    return rng.choice(best_questions)


def simulate_policy(
    *,
    policy: str,
    user_index: int,
    question_pool: List[Question],
    concept_base_weights: Dict[str, float],
    initial_mastery: Dict[str, float],
    session_questions: int,
    probe_questions: int,
    cooldown_steps: int,
    seed: int,
) -> RunMetrics:
    rng = random.Random(seed)
    mastery = dict(initial_mastery)

    remaining = list(question_pool)
    asked_ids: set[str] = set()
    trajectory: List[Tuple[int, Question]] = []
    main_correct = 0
    total_seconds = 0.0

    skill_posterior: Dict[str, Tuple[float, float]] = {}
    concept_posterior: Dict[str, Tuple[float, float]] = {}

    max_questions = min(session_questions, len(remaining))

    for step in range(max_questions):
        if policy == "skill_only":
            question = _choose_question_skill_only(remaining, skill_posterior, rng)
        elif policy == "hybrid":
            question = _choose_question_hybrid(
                remaining,
                concept_posterior,
                concept_base_weights,
                rng,
            )
        else:
            raise ValueError(f"politica nao suportada: {policy}")

        success_probability = _question_success_probability(question, mastery)
        correct = rng.random() < success_probability
        elapsed = _question_elapsed_seconds(question, success_probability, rng)

        main_correct += int(correct)
        total_seconds += elapsed
        asked_ids.add(question.question_id)
        trajectory.append((step, question))

        alpha, beta = skill_posterior.get(question.skill, (1.0, 1.0))
        if correct:
            alpha += 1.0
        else:
            beta += 1.0
        skill_posterior[question.skill] = (alpha, beta)

        for concept_id, weight in question.concept_weights.items():
            c_alpha, c_beta = concept_posterior.get(concept_id, (1.0, 1.0))
            if correct:
                c_alpha += weight
            else:
                c_beta += weight
            concept_posterior[concept_id] = (c_alpha, c_beta)

        _apply_learning(mastery, question, correct, decay=0.0018)

        remaining = [item for item in remaining if item.question_id != question.question_id]

    for _ in range(cooldown_steps):
        for concept_id in mastery:
            mastery[concept_id] = max(0.02, mastery[concept_id] * (1.0 - 0.0032))

    early_steps = {question.question_id for step, question in trajectory if step < max(0, max_questions - 8)}
    probe_candidates = [
        question
        for question in question_pool
        if question.question_id not in asked_ids and question.question_id in early_steps
    ]
    if len(probe_candidates) < probe_questions:
        probe_candidates = [
            question
            for question in question_pool
            if question.question_id not in asked_ids
        ]

    if not probe_candidates:
        retention = 0.0
    else:
        selected_probe = rng.sample(
            probe_candidates,
            k=min(probe_questions, len(probe_candidates)),
        )
        probe_correct = 0
        for question in selected_probe:
            success_probability = _question_success_probability(question, mastery)
            probe_correct += int(rng.random() < success_probability)
        retention = probe_correct / len(selected_probe)

    answered = max(1, max_questions)
    accuracy = main_correct / answered
    avg_seconds = total_seconds / answered

    return RunMetrics(
        policy=policy,
        user_index=user_index,
        main_questions=max_questions,
        accuracy=accuracy,
        avg_seconds=avg_seconds,
        retention=retention,
    )


def run_experiment(
    *,
    question_pool: List[Question],
    concept_base_weights: Dict[str, float],
    users: int,
    session_questions: int,
    probe_questions: int,
    cooldown_steps: int,
    seed: int,
) -> Tuple[PolicyResult, PolicyResult]:
    all_concepts = sorted({c for question in question_pool for c in question.concept_weights})

    baseline_metrics: List[RunMetrics] = []
    hybrid_metrics: List[RunMetrics] = []

    for user_index in range(users):
        user_rng = random.Random(seed + user_index * 9973)
        initial_mastery = _initial_mastery(all_concepts, user_rng)

        baseline = simulate_policy(
            policy="skill_only",
            user_index=user_index,
            question_pool=question_pool,
            concept_base_weights=concept_base_weights,
            initial_mastery=initial_mastery,
            session_questions=session_questions,
            probe_questions=probe_questions,
            cooldown_steps=cooldown_steps,
            seed=seed + user_index * 37 + 11,
        )
        hybrid = simulate_policy(
            policy="hybrid",
            user_index=user_index,
            question_pool=question_pool,
            concept_base_weights=concept_base_weights,
            initial_mastery=initial_mastery,
            session_questions=session_questions,
            probe_questions=probe_questions,
            cooldown_steps=cooldown_steps,
            seed=seed + user_index * 37 + 29,
        )

        baseline_metrics.append(baseline)
        hybrid_metrics.append(hybrid)

    return (
        PolicyResult(policy="skill_only", metrics=baseline_metrics),
        PolicyResult(policy="hybrid", metrics=hybrid_metrics),
    )


def build_rollout_decision(baseline: PolicyResult, hybrid: PolicyResult) -> Dict[str, object]:
    delta_accuracy_pp = (hybrid.mean_accuracy - baseline.mean_accuracy) * 100.0
    delta_retention_pp = (hybrid.mean_retention - baseline.mean_retention) * 100.0
    delta_seconds = hybrid.mean_seconds - baseline.mean_seconds

    recommend = (
        delta_retention_pp >= 2.0
        and delta_accuracy_pp >= -1.0
        and delta_seconds <= 8.0
    )

    if recommend:
        decision = "rollout_controlado"
        rationale = (
            "híbrido supera baseline em retenção com impacto aceitável em "
            "acurácia/tempo; recomendado ativar em rollout incremental."
        )
    else:
        decision = "manter_piloto"
        rationale = (
            "ganho insuficiente para rollout amplo; manter coleta adicional e "
            "recalibrar pesos/diagnóstico."
        )

    return {
        "decision": decision,
        "rationale": rationale,
        "delta_accuracy_pp": round(delta_accuracy_pp, 3),
        "delta_retention_pp": round(delta_retention_pp, 3),
        "delta_seconds": round(delta_seconds, 3),
        "thresholds": {
            "retention_pp_min": 2.0,
            "accuracy_pp_min": -1.0,
            "seconds_max": 8.0,
        },
    }


def write_outputs(
    *,
    baseline: PolicyResult,
    hybrid: PolicyResult,
    decision: Dict[str, object],
    question_pool: List[Question],
    output_prefix: Path,
    metadata: Dict[str, object],
) -> Dict[str, Path]:
    output_prefix.parent.mkdir(parents=True, exist_ok=True)

    summary_json_path = output_prefix.with_suffix(".summary.json")
    per_user_csv_path = output_prefix.with_suffix(".per_user.csv")
    report_md_path = output_prefix.with_suffix(".report.md")

    summary_payload = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "metadata": metadata,
        "dataset": {
            "questions_evaluated": len(question_pool),
            "skills": len({item.skill for item in question_pool}),
            "concepts": len({c for q in question_pool for c in q.concept_weights}),
        },
        "policies": {
            "skill_only": {
                "mean_accuracy": baseline.mean_accuracy,
                "mean_seconds": baseline.mean_seconds,
                "mean_retention": baseline.mean_retention,
                "stdev_accuracy": baseline.stdev_accuracy,
                "stdev_seconds": baseline.stdev_seconds,
                "stdev_retention": baseline.stdev_retention,
            },
            "hybrid": {
                "mean_accuracy": hybrid.mean_accuracy,
                "mean_seconds": hybrid.mean_seconds,
                "mean_retention": hybrid.mean_retention,
                "stdev_accuracy": hybrid.stdev_accuracy,
                "stdev_seconds": hybrid.stdev_seconds,
                "stdev_retention": hybrid.stdev_retention,
            },
        },
        "decision": decision,
    }
    summary_json_path.write_text(
        json.dumps(summary_payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    with per_user_csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            [
                "policy",
                "user_index",
                "main_questions",
                "accuracy",
                "avg_seconds",
                "retention",
            ]
        )
        for row in baseline.metrics + hybrid.metrics:
            writer.writerow(
                [
                    row.policy,
                    row.user_index,
                    row.main_questions,
                    f"{row.accuracy:.6f}",
                    f"{row.avg_seconds:.6f}",
                    f"{row.retention:.6f}",
                ]
            )

    accuracy_delta = (hybrid.mean_accuracy - baseline.mean_accuracy) * 100.0
    retention_delta = (hybrid.mean_retention - baseline.mean_retention) * 100.0
    seconds_delta = hybrid.mean_seconds - baseline.mean_seconds

    report_md_path.write_text(
        "\n".join(
            [
                "# T2.8 - Avaliação comparativa offline (feed skill-only vs híbrido)",
                "",
                f"- Gerado em: {summary_payload['generated_at_utc']}",
                f"- Bundle de questões: `{metadata['release_zip']}`",
                f"- Bundle conceitual piloto: `{metadata['concept_bundle']}`",
                f"- Questões avaliadas (com Q-matrix): **{len(question_pool)}**",
                "",
                "## Configuração da simulação",
                f"- Usuários simulados: **{metadata['users']}**",
                f"- Questões principais por sessão: **{metadata['session_questions']}**",
                f"- Questões de retenção (delay): **{metadata['probe_questions']}**",
                f"- Passos de cooldown (esquecimento): **{metadata['cooldown_steps']}**",
                f"- Seed: **{metadata['seed']}**",
                "",
                "## Métricas (média)",
                "",
                "| Política | Acurácia | Tempo médio (s) | Retenção |",
                "|---|---:|---:|---:|",
                f"| Skill-only | {(baseline.mean_accuracy * 100):.2f}% | {baseline.mean_seconds:.2f} | {(baseline.mean_retention * 100):.2f}% |",
                f"| Híbrido | {(hybrid.mean_accuracy * 100):.2f}% | {hybrid.mean_seconds:.2f} | {(hybrid.mean_retention * 100):.2f}% |",
                "",
                "## Delta (Híbrido - Skill-only)",
                f"- Acurácia: **{accuracy_delta:+.2f} pp**",
                f"- Tempo: **{seconds_delta:+.2f} s**",
                f"- Retenção: **{retention_delta:+.2f} pp**",
                "",
                "## Decisão de rollout",
                f"- Decisão: **{decision['decision']}**",
                f"- Justificativa: {decision['rationale']}",
                "",
                "## Critério objetivo usado",
                "- `retenção >= +2.0 pp`",
                "- `acurácia >= -1.0 pp`",
                "- `tempo <= +8.0 s`",
                "",
                "## Observações",
                "- Avaliação offline por simulação com modelo probabilístico de aprendizagem/esquecimento.",
                "- Resultado é válido para o piloto atual (Q-matrix de Humanas); reavaliar ao expandir catalogação.",
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    return {
        "summary_json": summary_json_path,
        "per_user_csv": per_user_csv_path,
        "report_md": report_md_path,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--release-zip",
        default="app_flutter/releases/local.20260305173642/assets_local.20260305173642.zip",
        help="ZIP de release contendo content_bundle.json",
    )
    parser.add_argument(
        "--bundle-file",
        default="content_bundle.json",
        help="Nome do JSON de bundle dentro do ZIP",
    )
    parser.add_argument(
        "--concept-bundle",
        default="questoes/mapeamento_habilidades/conceitos_piloto_humanas/concepts_bundle_piloto_humanas.json",
        help="JSON do piloto conceitual",
    )
    parser.add_argument("--users", type=int, default=320)
    parser.add_argument("--session-questions", type=int, default=30)
    parser.add_argument("--probe-questions", type=int, default=6)
    parser.add_argument("--cooldown-steps", type=int, default=10)
    parser.add_argument("--seed", type=int, default=20260306)
    parser.add_argument(
        "--output-prefix",
        default="docs/roadmap/references/t2_8_feed_comparativo",
        help="Prefixo de saida sem extensao",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    release_zip = Path(args.release_zip)
    concept_bundle = Path(args.concept_bundle)
    output_prefix = Path(args.output_prefix)

    if not release_zip.exists():
        raise FileNotFoundError(f"ZIP de release nao encontrado: {release_zip}")
    if not concept_bundle.exists():
        raise FileNotFoundError(f"Bundle conceitual nao encontrado: {concept_bundle}")

    bundle_questions = load_bundle_questions(release_zip, args.bundle_file)
    concept_base_weights, question_concepts = load_concept_pilot(concept_bundle)
    question_pool = build_question_pool(bundle_questions, question_concepts)
    if not question_pool:
        raise RuntimeError(
            "Nao foi possivel montar pool de questoes com cruzamento bundle + Q-matrix"
        )

    baseline, hybrid = run_experiment(
        question_pool=question_pool,
        concept_base_weights=concept_base_weights,
        users=max(20, args.users),
        session_questions=max(10, args.session_questions),
        probe_questions=max(3, args.probe_questions),
        cooldown_steps=max(1, args.cooldown_steps),
        seed=args.seed,
    )

    decision = build_rollout_decision(baseline, hybrid)

    outputs = write_outputs(
        baseline=baseline,
        hybrid=hybrid,
        decision=decision,
        question_pool=question_pool,
        output_prefix=output_prefix,
        metadata={
            "release_zip": str(release_zip),
            "concept_bundle": str(concept_bundle),
            "bundle_file": args.bundle_file,
            "users": max(20, args.users),
            "session_questions": max(10, args.session_questions),
            "probe_questions": max(3, args.probe_questions),
            "cooldown_steps": max(1, args.cooldown_steps),
            "seed": args.seed,
        },
    )

    print("Avaliacao concluida.")
    for label, path in outputs.items():
        print(f"- {label}: {path}")


if __name__ == "__main__":
    main()
