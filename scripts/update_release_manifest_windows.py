#!/usr/bin/env python3
"""Atualiza release_manifest.json para builds Windows preservando outros artefatos."""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Atualiza release_manifest.json com artefatos de conteúdo e Windows. "
            "Outros artefatos existentes (linux/android/web) são preservados."
        )
    )
    parser.add_argument("--release-manifest", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--channel", required=True)
    parser.add_argument("--manifest-file", required=True)
    parser.add_argument("--assets-file", required=True)
    parser.add_argument("--windows-file", required=True)
    parser.add_argument("--manifest-tag-file")
    parser.add_argument("--assets-tag-file")
    parser.add_argument("--windows-tag-file")
    return parser.parse_args()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _artifact_entry(path: Path) -> dict[str, Any]:
    return {
        "file": path.name,
        "sha256": _sha256_file(path),
        "size": path.stat().st_size,
    }


def _load_existing_manifest(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    content = path.read_text(encoding="utf-8-sig").strip()
    if not content:
        return {}
    data = json.loads(content)
    if not isinstance(data, dict):
        return {}
    return data


def _require_file(path_str: str, label: str) -> Path:
    path = Path(path_str)
    if not path.exists():
        raise FileNotFoundError(f"{label} nao encontrado: {path}")
    if not path.is_file():
        raise FileNotFoundError(f"{label} invalido (nao e arquivo): {path}")
    return path


def _optional_file(path_str: str | None, label: str) -> Path | None:
    if not path_str:
        return None
    return _require_file(path_str, label)


def _read_artifacts(existing: dict[str, Any]) -> dict[str, Any]:
    artifacts = existing.get("artifacts")
    if not isinstance(artifacts, dict):
        return {}
    return dict(artifacts)


def _remove_missing_optional(
    artifacts: dict[str, Any],
    key: str,
    value: Path | None,
) -> None:
    if value is None:
        artifacts.pop(key, None)


def main() -> int:
    args = _parse_args()

    release_manifest = Path(args.release_manifest)
    manifest_file = _require_file(args.manifest_file, "manifest")
    assets_file = _require_file(args.assets_file, "assets zip")
    windows_file = _require_file(args.windows_file, "windows zip")
    manifest_tag_file = _optional_file(args.manifest_tag_file, "manifest tag")
    assets_tag_file = _optional_file(args.assets_tag_file, "assets tag")
    windows_tag_file = _optional_file(args.windows_tag_file, "windows tag zip")

    data = _load_existing_manifest(release_manifest)
    artifacts = _read_artifacts(data)

    artifacts["manifest_json"] = _artifact_entry(manifest_file)
    artifacts["assets_zip"] = _artifact_entry(assets_file)
    artifacts["windows_zip"] = _artifact_entry(windows_file)

    if manifest_tag_file is not None:
        artifacts["manifest_tag"] = _artifact_entry(manifest_tag_file)
    if assets_tag_file is not None:
        artifacts["assets_tag"] = _artifact_entry(assets_tag_file)
    if windows_tag_file is not None:
        artifacts["windows_tag_zip"] = _artifact_entry(windows_tag_file)

    _remove_missing_optional(artifacts, "manifest_tag", manifest_tag_file)
    _remove_missing_optional(artifacts, "assets_tag", assets_tag_file)
    _remove_missing_optional(artifacts, "windows_tag_zip", windows_tag_file)

    data["version"] = args.version
    data["channel"] = args.channel
    data["generated_at_utc"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    data["artifacts"] = artifacts

    release_manifest.parent.mkdir(parents=True, exist_ok=True)
    release_manifest.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
