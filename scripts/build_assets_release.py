#!/usr/bin/env python3
"""Gera pacote de conteúdo (zip) + manifest com SHA256 para cliente Flutter."""

from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import zipfile


DEFAULT_QUESTIONS_CSV = Path("questoes/mapeamento_habilidades/questoes_mapeadas.csv")
DEFAULT_MODULES_CSV = Path("plano/indice_livros_6_volumes.csv")
DEFAULT_OUTPUT_DIR = Path("app_flutter/releases")
BUNDLE_FILE_NAME = "content_bundle.json"


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
        help="CSV de módulos/livros com habilidades.",
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


def normalize_skill_token(raw_value: str) -> str:
    token = raw_value.strip().upper().replace(" ", "")
    if not token:
        return ""

    if token.startswith("H") and token[1:].isdigit():
        return f"H{int(token[1:])}"

    if "-H" in token:
        tail = token.split("-H", maxsplit=1)[1]
        digits = "".join(ch for ch in tail if ch.isdigit())
        if digits:
            return f"H{int(digits)}"

    return token


def parse_skill_list(raw_skills: str) -> list[str]:
    if not raw_skills.strip():
        return []

    parts = [item.strip() for item in raw_skills.replace(";", ",").split(",")]
    result: list[str] = []
    seen: set[str] = set()

    for item in parts:
        normalized = normalize_skill_token(item)
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        result.append(normalized)

    return result


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

            question = {
                "id": f"{year}_{day}_{number}_{variation}",
                "year": year,
                "day": day,
                "number": number,
                "variation": variation,
                "area": (row.get("area") or "").strip(),
                "discipline": (row.get("disciplina") or "").strip(),
                "theme": (row.get("tema_estimado") or "").strip(),
                "skill": normalize_skill_token((row.get("habilidade_estimada") or "").strip()),
                "confidence": (row.get("confianca") or "").strip(),
                "statement": (row.get("preview") or "").strip(),
                "answer": (row.get("gabarito") or "").strip(),
                "source": str(questions_csv),
            }
            if not question["statement"]:
                continue
            rows.append(question)

            if limit > 0 and len(rows) >= limit:
                break

    return rows


def read_book_modules(modules_csv: Path) -> list[dict[str, object]]:
    if not modules_csv.exists():
        return []

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
            raw_skills = (row.get("habilidades") or "").strip()
            skills = parse_skill_list(raw_skills)

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
                    "skills": skills,
                    "skills_raw": raw_skills,
                    "source": str(modules_csv),
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

    book_modules = read_book_modules(modules_csv=args.modules_csv)
    if not book_modules:
        print(f"[warn] sem módulos/livros no bundle: {args.modules_csv}")

    out_root = args.out_dir / version
    out_root.mkdir(parents=True, exist_ok=True)

    bundle = {
        "schema": "2",
        "version": version,
        "generated_at": generated_at,
        "question_count": len(questions),
        "book_module_count": len(book_modules),
        "questions": questions,
        "book_modules": book_modules,
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
    print(f"[ok] zip: {archive_path}")
    print(f"[ok] manifest: {manifest_path}")
    print(f"[ok] latest manifest: {latest_manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
