#!/usr/bin/env python3
"""Gera pacote de conteúdo (zip) + manifest com SHA256 para cliente Flutter."""

from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import tempfile
import unicodedata
import zipfile


DEFAULT_QUESTIONS_CSV = Path("questoes/mapeamento_habilidades/questoes_mapeadas.csv")
DEFAULT_MODULES_CSV = Path("plano/indice_livros_6_volumes.csv")
DEFAULT_MODULE_QUESTION_MATCHES_CSV = Path(
    "questoes/mapeamento_habilidades/intercorrelacao/modulo_questao_matches.csv"
)
DEFAULT_OUTPUT_DIR = Path("app_flutter/releases")
BUNDLE_FILE_NAME = "content_bundle.json"
COMPETENCE_HEADER_RE = re.compile(r"^###\s+Competência de área\s+(\d+)\b", re.IGNORECASE)
SKILL_LINE_RE = re.compile(r"^\s*-\s+\*\*H(\d+)\*\*")
COMPETENCY_TOKEN_RE = re.compile(r"^C(\d+)$")
SKILL_TOKEN_RE = re.compile(r"^H(\d+)$")
COMPOSITE_TOKEN_RE = re.compile(r"^C(\d+)-H(\d+)$")
MATRIX_SKILL_FILES = {
    "HUMANAS": Path("matriz/habilidades_por_area/humanas.md"),
    "LINGUAGENS": Path("matriz/habilidades_por_area/linguagens.md"),
    "MATEMATICA": Path("matriz/habilidades_por_area/matematica.md"),
    "NATUREZA": Path("matriz/habilidades_por_area/natureza.md"),
}
PROJECT_ROOT = Path(__file__).resolve().parents[1]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Empacota conteúdo para update offline (manifest + SHA256).",
    )
    parser.add_argument(
        "--questions-csv",
        "--input-csv",
        dest="questions_csv",
        type=Path,
        default=DEFAULT_QUESTIONS_CSV,
        help="CSV de questões mapeadas.",
    )
    parser.add_argument(
        "--modules-csv",
        type=Path,
        default=DEFAULT_MODULES_CSV,
        help="CSV de módulos/livros com habilidades/competências e expectativas.",
    )
    parser.add_argument(
        "--module-question-matches-csv",
        type=Path,
        default=DEFAULT_MODULE_QUESTION_MATCHES_CSV,
        help="CSV de intercorrelação módulo x questão (opcional).",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Diretório de saída de releases.",
    )
    parser.add_argument(
        "--version",
        type=str,
        default="",
        help="Versão do conteúdo (ex.: 2026.02.24.1). Se vazio, usa UTC atual.",
    )
    parser.add_argument(
        "--base-url",
        type=str,
        default="",
        help="Base URL para montar download_url no manifest (opcional).",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Limita quantidade de questões no bundle (0 = todas).",
    )
    return parser.parse_args()


def make_version(raw: str) -> str:
    if raw.strip():
        return raw.strip()
    now = datetime.now(timezone.utc)
    return now.strftime("%Y.%m.%d.%H%M%S")


def dedupe_preserve_order(values: list[str]) -> list[str]:
    result: list[str] = []
    seen: set[str] = set()
    for value in values:
        if not value or value in seen:
            continue
        seen.add(value)
        result.append(value)
    return result


def strip_diacritics(raw_text: str) -> str:
    normalized = unicodedata.normalize("NFKD", raw_text)
    return "".join(ch for ch in normalized if not unicodedata.combining(ch))


def normalize_area_key(raw_area: str) -> str:
    normalized = strip_diacritics(raw_area).casefold()
    if "human" in normalized:
        return "HUMANAS"
    if "linguagens" in normalized:
        return "LINGUAGENS"
    if "matematica" in normalized:
        return "MATEMATICA"
    if "natureza" in normalized:
        return "NATUREZA"
    return ""


def load_competency_skill_catalog() -> dict[str, dict[str, list[str]]]:
    catalog: dict[str, dict[str, list[str]]] = {}

    for area_key, matrix_path in MATRIX_SKILL_FILES.items():
        if not matrix_path.exists():
            continue

        competency_map: dict[str, list[str]] = {}
        current_competency = ""
        for raw_line in matrix_path.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            competency_match = COMPETENCE_HEADER_RE.match(line)
            if competency_match:
                current_competency = f"C{int(competency_match.group(1))}"
                competency_map.setdefault(current_competency, [])
                continue

            if not current_competency:
                continue

            skill_match = SKILL_LINE_RE.match(line)
            if not skill_match:
                continue
            competency_map[current_competency].append(f"H{int(skill_match.group(1))}")

        if competency_map:
            catalog[area_key] = competency_map

    return catalog


def normalize_skill_token(raw_value: str) -> str:
    token = raw_value.strip().upper().replace(" ", "")
    if not token:
        return ""

    composite_match = COMPOSITE_TOKEN_RE.fullmatch(token)
    if composite_match:
        return f"H{int(composite_match.group(2))}"

    skill_match = SKILL_TOKEN_RE.fullmatch(token)
    if skill_match:
        return f"H{int(skill_match.group(1))}"

    if token.startswith("H") and token[1:].isdigit():
        return f"H{int(token[1:])}"

    if "-H" in token:
        tail = token.split("-H", maxsplit=1)[1]
        digits = "".join(ch for ch in tail if ch.isdigit())
        if digits:
            return f"H{int(digits)}"

    return ""


def normalize_competency_token(raw_value: str) -> str:
    token = raw_value.strip().upper().replace(" ", "")
    if not token:
        return ""

    composite_match = COMPOSITE_TOKEN_RE.fullmatch(token)
    if composite_match:
        return f"C{int(composite_match.group(1))}"

    competency_match = COMPETENCY_TOKEN_RE.fullmatch(token)
    if competency_match:
        return f"C{int(competency_match.group(1))}"

    prefixed_match = re.match(r"^C(\d+)(?:[-:.].*)?$", token)
    if prefixed_match:
        return f"C{int(prefixed_match.group(1))}"

    return ""


def parse_module_tags(raw_tags: str) -> tuple[list[str], list[str]]:
    if not raw_tags.strip():
        return [], []

    parts = [item.strip() for item in raw_tags.replace(";", ",").split(",") if item.strip()]
    skills: list[str] = []
    competencies: list[str] = []
    seen_skills: set[str] = set()
    seen_competencies: set[str] = set()

    for item in parts:
        skill = normalize_skill_token(item)
        competency = normalize_competency_token(item)

        if skill and skill not in seen_skills:
            seen_skills.add(skill)
            skills.append(skill)
        if competency and competency not in seen_competencies:
            seen_competencies.add(competency)
            competencies.append(competency)

    return skills, competencies


def parse_learning_expectations(raw_value: str) -> list[str]:
    if not raw_value.strip():
        return []

    expectations: list[str] = []
    seen: set[str] = set()
    normalized_text = raw_value.replace("\\n", "\n")
    chunks = re.split(r"[;\n\r]+", normalized_text)
    for chunk in chunks:
        cleaned = re.sub(r"^\s*(?:[-*•]+|\d+[.)])\s*", "", chunk.strip())
        if not cleaned:
            continue
        normalized_key = cleaned.casefold()
        if normalized_key in seen:
            continue
        seen.add(normalized_key)
        expectations.append(cleaned)

    return expectations


def parse_fallback_image_paths(raw_value: str) -> list[str]:
    if not raw_value.strip():
        return []

    parts = [chunk.strip().replace("\\", "/") for chunk in raw_value.split(";")]
    cleaned: list[str] = []
    seen: set[str] = set()
    for part in parts:
        if not part:
            continue
        normalized = part.lstrip("./")
        if (
            not normalized
            or normalized.startswith("/")
            or normalized.startswith("../")
            or "/../" in normalized
        ):
            continue
        if normalized in seen:
            continue
        seen.add(normalized)
        cleaned.append(normalized)
    return cleaned


def parse_bool_flag(raw_value: str) -> bool:
    normalized = raw_value.strip().casefold()
    return normalized in {"1", "true", "sim", "yes", "y", "s"}


def parse_score(raw_value: str) -> float:
    normalized = raw_value.strip().replace(",", ".")
    if not normalized:
        return 0.0
    try:
        score = float(normalized)
    except ValueError:
        return 0.0
    if score < 0:
        return 0.0
    if score > 1:
        return 1.0
    return score


def collect_fallback_assets(
    questions: list[dict[str, object]],
    project_root: Path,
) -> list[tuple[Path, str]]:
    assets: list[tuple[Path, str]] = []
    seen: set[str] = set()
    root = project_root.resolve()

    for question in questions:
        paths = question.get("fallback_image_paths")
        if not isinstance(paths, list):
            continue
        for raw_path in paths:
            if not isinstance(raw_path, str):
                continue
            rel_path = raw_path.strip().replace("\\", "/").lstrip("./")
            if (
                not rel_path
                or rel_path in seen
                or rel_path.startswith("/")
                or rel_path.startswith("../")
                or "/../" in rel_path
            ):
                continue

            source_path = (project_root / rel_path).resolve()
            try:
                source_path.relative_to(root)
            except ValueError:
                continue
            if not source_path.exists():
                print(f"[warn] fallback image ausente: {rel_path}")
                continue

            seen.add(rel_path)
            assets.append((source_path, rel_path))

    return assets


def skills_from_competencies(
    area: str,
    competencies: list[str],
    catalog: dict[str, dict[str, list[str]]],
) -> list[str]:
    area_key = normalize_area_key(area)
    if not area_key:
        return []

    competency_map = catalog.get(area_key, {})
    resolved: list[str] = []
    for competency in competencies:
        resolved.extend(competency_map.get(competency, []))
    return dedupe_preserve_order(resolved)


def read_questions(questions_csv: Path, limit: int = 0) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []

    with questions_csv.open("r", encoding="utf-8", newline="") as file_obj:
        reader = csv.DictReader(file_obj)
        for row in reader:
            try:
                year = int(row.get("ano", "0") or 0)
                day = int(row.get("dia", "0") or 0)
                number = int(row.get("numero", "0") or 0)
                variation = int(row.get("variacao", "1") or 1)
            except ValueError:
                continue

            if year <= 0 or day <= 0 or number <= 0:
                continue

            fallback_image_paths = parse_fallback_image_paths(
                (row.get("fallback_image_paths") or "").strip()
            )
            has_image = parse_bool_flag((row.get("tem_imagem") or "").strip())
            if fallback_image_paths:
                has_image = True

            question = {
                "id": f"{year}_{day}_{number}_{variation}",
                "year": year,
                "day": day,
                "number": number,
                "variation": variation,
                "area": (row.get("area") or "").strip(),
                "discipline": (row.get("disciplina") or "").strip(),
                "materia": (row.get("materia") or row.get("disciplina") or "").strip(),
                "theme": (row.get("tema_estimado") or "").strip(),
                "competency": normalize_competency_token(
                    (row.get("competencia_estimada") or "").strip()
                ),
                "skill": normalize_skill_token((row.get("habilidade_estimada") or "").strip()),
                "confidence": (row.get("confianca") or "").strip(),
                "has_image": has_image,
                "text_empty": parse_bool_flag((row.get("texto_vazio") or "").strip()),
                "statement": (row.get("preview") or "").strip(),
                "answer": (row.get("gabarito") or "").strip(),
                "fallback_image_paths": fallback_image_paths,
                "source": str(questions_csv),
            }
            if not question["statement"] and question["fallback_image_paths"]:
                question["statement"] = "Texto OCR indisponível (usar imagem fallback)."
                question["statement_is_fallback"] = True
            else:
                question["statement_is_fallback"] = False
            if not question["statement"]:
                continue
            rows.append(question)

            if limit > 0 and len(rows) >= limit:
                break

    return rows


def read_book_modules(modules_csv: Path) -> list[dict[str, object]]:
    if not modules_csv.exists():
        return []

    catalog = load_competency_skill_catalog()
    rows: list[dict[str, object]] = []
    with modules_csv.open("r", encoding="utf-8", newline="") as file_obj:
        reader = csv.DictReader(file_obj)
        for row in reader:
            volume = int(str(row.get("volume", "0") or "0") or 0)
            modulo = int(str(row.get("modulo", "0") or "0") or 0)
            area = (row.get("area") or "").strip()
            materia = (row.get("materia") or "").strip()
            title = (row.get("titulo") or "").strip()
            page = (row.get("pagina") or "").strip()
            raw_tags = (row.get("habilidades") or "").strip()
            raw_expectations = (
                row.get("expectativas_aprendizagem")
                or row.get("expectativas")
                or row.get("descricao")
                or row.get("descrição")
                or ""
            ).strip()

            explicit_skills, competencies = parse_module_tags(raw_tags)
            expanded_skills = skills_from_competencies(area=area, competencies=competencies, catalog=catalog)
            skills = dedupe_preserve_order(explicit_skills + expanded_skills)
            learning_expectations = parse_learning_expectations(raw_expectations)
            learning_expectations_raw = "; ".join(learning_expectations)

            module_id = f"v{volume}_{materia.lower().replace(' ', '_')}_m{modulo}"
            rows.append(
                {
                    "id": module_id,
                    "volume": volume,
                    "area": area,
                    "materia": materia,
                    "modulo": modulo,
                    "title": title,
                    "page": page,
                    "learning_expectations": learning_expectations,
                    "learning_expectations_raw": learning_expectations_raw,
                    "description": learning_expectations_raw,
                    "skills": skills,
                    "skills_raw": raw_tags,
                    "competencies": competencies,
                    "competencies_raw": "; ".join(competencies),
                    "source": str(modules_csv),
                }
            )

    return rows


def read_module_question_matches(matches_csv: Path) -> list[dict[str, object]]:
    if not matches_csv.exists():
        print(f"[warn] sem intercorrelação no bundle: {matches_csv}")
        return []

    rows: list[dict[str, object]] = []
    seen: set[tuple[object, ...]] = set()
    with matches_csv.open("r", encoding="utf-8", newline="") as file_obj:
        reader = csv.DictReader(file_obj)
        for row in reader:
            try:
                year = int(str(row.get("ano", "0") or "0"))
                day = int(str(row.get("dia", "0") or "0"))
                number = int(str(row.get("numero", "0") or "0"))
                variation = int(str(row.get("variacao", "1") or "1"))
                volume = int(str(row.get("volume", "0") or "0"))
                modulo = int(str(row.get("modulo", "0") or "0"))
            except ValueError:
                continue

            if year <= 0 or day <= 0 or number <= 0 or volume <= 0 or modulo <= 0:
                continue

            question_id = f"{year}_{day}_{number}_{variation}"
            score_match = parse_score((row.get("score_match") or "").strip())
            assunto_match = (row.get("assuntos_match") or "").strip()
            tipo_match = (row.get("tipo_match") or "").strip()
            materia = (row.get("materia") or "").strip()

            dedupe_key = (
                question_id,
                materia.casefold(),
                volume,
                modulo,
                assunto_match.casefold(),
                tipo_match.casefold(),
                score_match,
            )
            if dedupe_key in seen:
                continue
            seen.add(dedupe_key)

            rows.append(
                {
                    "question_id": question_id,
                    "year": year,
                    "day": day,
                    "number": number,
                    "variation": variation,
                    "area": (row.get("area") or "").strip(),
                    "discipline": (row.get("disciplina") or "").strip(),
                    "materia": materia,
                    "volume": volume,
                    "modulo": modulo,
                    "competencias": (row.get("competencias") or "").strip(),
                    "habilidades": (row.get("habilidades") or "").strip(),
                    "assuntos_match": assunto_match,
                    "score_match": score_match,
                    "tipo_match": tipo_match,
                    "confianca": (row.get("confianca") or "").strip(),
                    "revisado_manual": parse_bool_flag(
                        (row.get("revisado_manual") or "").strip()
                    ),
                    "source": str(matches_csv),
                }
            )

    return rows


def sha256_file(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as file_obj:
        for chunk in iter(lambda: file_obj.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def join_url(base: str, name: str) -> str:
    normalized = base.rstrip("/")
    return f"{normalized}/{name}" if normalized else ""


def main() -> int:
    args = parse_args()

    questions_csv = args.questions_csv
    if not questions_csv.exists():
        raise FileNotFoundError(f"CSV de questões não encontrado: {questions_csv}")

    version = make_version(args.version)
    generated_at = datetime.now(timezone.utc).isoformat()

    questions = read_questions(questions_csv=questions_csv, limit=max(args.limit, 0))
    if not questions:
        raise RuntimeError("Nenhuma questão válida encontrada para empacotar.")
    fallback_assets = collect_fallback_assets(questions, project_root=PROJECT_ROOT)

    book_modules = read_book_modules(modules_csv=args.modules_csv)
    if not book_modules:
        print(f"[warn] sem módulos/livros no bundle: {args.modules_csv}")
    module_question_matches = read_module_question_matches(
        matches_csv=args.module_question_matches_csv
    )

    out_root = args.out_dir / version
    out_root.mkdir(parents=True, exist_ok=True)

    bundle = {
        "schema": "2",
        "version": version,
        "generated_at": generated_at,
        "question_count": len(questions),
        "book_module_count": len(book_modules),
        "module_question_match_count": len(module_question_matches),
        "fallback_asset_count": len(fallback_assets),
        "questions": questions,
        "book_modules": book_modules,
        "module_question_matches": module_question_matches,
    }

    with tempfile.TemporaryDirectory(prefix="enem_bundle_") as temp_dir:
        temp_path = Path(temp_dir)
        bundle_path = temp_path / BUNDLE_FILE_NAME
        bundle_path.write_text(
            json.dumps(bundle, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

        archive_name = f"assets_{version}.zip"
        archive_path = out_root / archive_name

        with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as zip_obj:
            zip_obj.write(bundle_path, arcname=BUNDLE_FILE_NAME)
            for source_path, arcname in fallback_assets:
                zip_obj.write(source_path, arcname=arcname)

    digest = sha256_file(archive_path)
    archive_size = archive_path.stat().st_size

    manifest = {
        "version": version,
        "generated_at": generated_at,
        "archive_file": archive_name,
        "bundle_file": BUNDLE_FILE_NAME,
        "sha256": digest,
        "size": archive_size,
        "download_url": join_url(args.base_url, archive_name),
        "question_count": len(questions),
        "book_module_count": len(book_modules),
        "module_question_match_count": len(module_question_matches),
        "fallback_asset_count": len(fallback_assets),
    }

    manifest_path = out_root / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    latest_manifest_path = args.out_dir / "manifest.json"
    latest_manifest_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(manifest_path, latest_manifest_path)

    print(f"[ok] versão: {version}")
    print(f"[ok] questões: {len(questions)}")
    print(f"[ok] módulos/livro: {len(book_modules)}")
    print(f"[ok] vínculos módulo-questão: {len(module_question_matches)}")
    print(f"[ok] assets fallback: {len(fallback_assets)}")
    print(f"[ok] zip: {archive_path}")
    print(f"[ok] manifest: {manifest_path}")
    print(f"[ok] latest manifest: {latest_manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
