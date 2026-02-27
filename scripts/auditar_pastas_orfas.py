#!/usr/bin/env python3
"""Audita pastas/arquivos orfaos e executa limpeza segura de temporarios."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
import re
import shutil
import subprocess


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REFERENCE_FILES = (
    Path("plano/roadmap_geral.md"),
    Path("plano/roadmap_proximos_passos.md"),
    Path("plano/arquitetura_conteudo_offline.md"),
    Path("plano/politica_retencao_repositorio.md"),
    Path("README.md"),
    Path("dist.sh"),
    Path("deploy.sh"),
    Path("scripts/build_assets_release.py"),
    Path("scripts/package_linux_artifacts.sh"),
)
DEFAULT_REPORT_FILE = Path("plano/relatorio_limpeza_repositorio.md")
FORCED_KEEP_TOP_LEVEL = {
    "app_flutter",
    "assets",
    "aulas",
    "matriz",
    "notes",
    "planner",
    "plano",
    "prompts",
    "questoes",
    "scripts",
    "sources",
    "templates",
    "README.md",
    "CHANGELOG.md",
    "LICENSE",
    ".gitignore",
    "agents.global.md",
    "dist.sh",
    "deploy.sh",
    "install_linux.sh",
    "dist_windows.bat",
    "deploy.bat",
    "edital.pdf",
}
KNOWN_ARCHIVE_HINTS = {
    "teste_aula_habilidade_base_h18.md",
    "teste_aula_habilidade_base_h18.pdf",
}
SAFE_REMOVE_GLOB_PATTERNS = (
    "**/__pycache__",
    "**/*.pyc",
    "**/.DS_Store",
    "**/*.tmp",
    "**/*.temp",
    "**/.pytest_cache",
)
SAFE_REMOVE_SKIP_PREFIXES = (
    ".git/",
    ".venv_mdpdf/",
    ".vscode/",
)
CODE_BLOCK_PATH_RE = re.compile(r"`([^`]+)`")
PATH_LIKE_SUFFIXES = (
    ".md",
    ".py",
    ".sh",
    ".bat",
    ".json",
    ".csv",
    ".zip",
    ".db",
    ".pdf",
    ".yaml",
    ".yml",
)


@dataclass(frozen=True)
class ClassifiedPath:
    relative_path: str
    action: str
    reason: str


@dataclass(frozen=True)
class SafeArtifact:
    relative_path: str
    pattern: str
    tracked: bool


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Audita estruturas nao referenciadas pelo roadmap/pipeline e "
            "remove artefatos temporarios seguros."
        ),
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=PROJECT_ROOT,
        help="Raiz do repositorio (padrao: raiz deste projeto).",
    )
    parser.add_argument(
        "--reference-file",
        action="append",
        type=Path,
        default=[],
        help="Arquivo adicional para extrair referencias de caminhos.",
    )
    parser.add_argument(
        "--report-out",
        type=Path,
        default=DEFAULT_REPORT_FILE,
        help="Caminho do relatorio markdown de auditoria.",
    )
    parser.add_argument(
        "--apply-safe-clean",
        action="store_true",
        help="Executa remocao segura para artefatos temporarios detectados.",
    )
    return parser.parse_args()


def load_git_tracked_paths(repo_root: Path) -> set[str]:
    command = ["git", "-C", str(repo_root), "ls-files", "-z"]
    result = subprocess.run(command, capture_output=True, check=False)
    if result.returncode != 0:
        return set()
    tracked: set[str] = set()
    for item in result.stdout.split(b"\x00"):
        if not item:
            continue
        tracked.add(item.decode("utf-8"))
    return tracked


def normalize_token(raw_token: str) -> str:
    cleaned = raw_token.strip().strip("()[]{}<>.,;:")
    cleaned = cleaned.replace("\\", "/")
    if cleaned.startswith("./"):
        cleaned = cleaned[2:]
    if "://" in cleaned:
        return ""
    if "{" in cleaned or "}" in cleaned:
        return ""
    return cleaned


def split_pipeline_token(token: str) -> list[str]:
    pieces = [token]
    for separator in ("->", "|", ",", ";"):
        expanded: list[str] = []
        for piece in pieces:
            expanded.extend(piece.split(separator))
        pieces = expanded
    return [piece.strip() for piece in pieces if piece.strip()]


def token_looks_like_path(token: str) -> bool:
    if "/" in token:
        return True
    return token.endswith(PATH_LIKE_SUFFIXES)


def resolve_token_paths(repo_root: Path, token: str) -> list[Path]:
    if "*" in token:
        matches: list[Path] = []
        for path in sorted(repo_root.glob(token)):
            if path.exists():
                matches.append(path)
        return matches
    candidate = repo_root / token
    if candidate.exists():
        return [candidate]
    return []


def extract_referenced_paths(repo_root: Path, reference_files: list[Path]) -> set[str]:
    referenced_paths: set[str] = set()
    for reference_file in reference_files:
        full_path = repo_root / reference_file
        if not full_path.exists():
            continue
        referenced_paths.add(reference_file.as_posix())
        text = full_path.read_text(encoding="utf-8")
        for raw_token in CODE_BLOCK_PATH_RE.findall(text):
            for token_piece in split_pipeline_token(raw_token):
                token = normalize_token(token_piece)
                if not token or not token_looks_like_path(token):
                    continue
                for resolved in resolve_token_paths(repo_root, token):
                    resolved_absolute = resolved.resolve()
                    try:
                        relative = resolved_absolute.relative_to(repo_root)
                    except ValueError:
                        continue
                    if relative.as_posix() == ".":
                        continue
                    referenced_paths.add(relative.as_posix())
    return referenced_paths


def top_level_from_paths(relative_paths: set[str]) -> set[str]:
    top_levels: set[str] = set()
    for relative_path in relative_paths:
        top_levels.add(relative_path.split("/", maxsplit=1)[0])
    return top_levels


def classify_top_level_entries(repo_root: Path, referenced_top_levels: set[str]) -> list[ClassifiedPath]:
    classified: list[ClassifiedPath] = []
    for entry in sorted(repo_root.iterdir(), key=lambda item: item.name.lower()):
        name = entry.name
        if name == ".git":
            continue
        if name in referenced_top_levels:
            classified.append(
                ClassifiedPath(
                    relative_path=name,
                    action="manter",
                    reason="referenciado no roadmap/build",
                )
            )
            continue
        if name in FORCED_KEEP_TOP_LEVEL:
            classified.append(
                ClassifiedPath(
                    relative_path=name,
                    action="manter",
                    reason="pasta/arquivo essencial por politica",
                )
            )
            continue
        if name.startswith("."):
            classified.append(
                ClassifiedPath(
                    relative_path=name,
                    action="manter",
                    reason="configuracao local/oculta",
                )
            )
            continue
        if name in KNOWN_ARCHIVE_HINTS:
            classified.append(
                ClassifiedPath(
                    relative_path=name,
                    action="mover para archive",
                    reason="artefato de teste fora da arvore principal",
                )
            )
            continue
        classified.append(
            ClassifiedPath(
                relative_path=name,
                action="mover para archive",
                reason="nao referenciado explicitamente no roadmap/build",
            )
        )
    return classified


def should_skip_safe_artifact(relative_path: str) -> bool:
    return any(relative_path.startswith(prefix) for prefix in SAFE_REMOVE_SKIP_PREFIXES)


def find_safe_artifacts(repo_root: Path, tracked_paths: set[str]) -> list[SafeArtifact]:
    seen_paths: set[str] = set()
    selected_dirs: set[str] = set()
    artifacts: list[SafeArtifact] = []
    for pattern in SAFE_REMOVE_GLOB_PATTERNS:
        for path in sorted(repo_root.glob(pattern)):
            if not path.exists():
                continue
            relative_path = path.relative_to(repo_root).as_posix()
            if should_skip_safe_artifact(relative_path):
                continue
            if any(relative_path.startswith(f"{selected_dir}/") for selected_dir in selected_dirs):
                continue
            if relative_path in seen_paths:
                continue
            seen_paths.add(relative_path)
            artifacts.append(
                SafeArtifact(
                    relative_path=relative_path,
                    pattern=pattern,
                    tracked=relative_path in tracked_paths,
                )
            )
            if path.is_dir():
                selected_dirs.add(relative_path)
    return artifacts


def apply_safe_cleanup(repo_root: Path, artifacts: list[SafeArtifact]) -> tuple[list[str], list[str]]:
    removed_paths: list[str] = []
    skipped_paths: list[str] = []
    for artifact in artifacts:
        full_path = repo_root / artifact.relative_path
        if artifact.tracked:
            skipped_paths.append(f"{artifact.relative_path} (tracked)")
            continue
        if not full_path.exists():
            continue
        if full_path.is_dir():
            shutil.rmtree(full_path)
        else:
            full_path.unlink()
        removed_paths.append(artifact.relative_path)
    return removed_paths, skipped_paths


def render_markdown_report(
    generated_at: str,
    reference_files: list[Path],
    classified_entries: list[ClassifiedPath],
    artifacts: list[SafeArtifact],
    removed_paths: list[str],
    skipped_paths: list[str],
) -> str:
    kept = [entry for entry in classified_entries if entry.action == "manter"]
    archive = [entry for entry in classified_entries if entry.action == "mover para archive"]

    lines: list[str] = []
    lines.append("# Relatório de Limpeza do Repositório")
    lines.append("")
    lines.append(f"- Gerado em (UTC): **{generated_at}**")
    lines.append(f"- Arquivos de referência analisados: **{len(reference_files)}**")
    lines.append(f"- Entradas top-level classificadas: **{len(classified_entries)}**")
    lines.append(f"- Temporários seguros detectados: **{len(artifacts)}**")
    lines.append(f"- Remoções seguras aplicadas: **{len(removed_paths)}**")
    lines.append("")
    lines.append("## Arquivos-base usados na auditoria")
    for reference_file in reference_files:
        lines.append(f"- `{reference_file.as_posix()}`")
    lines.append("")
    lines.append("## Classificação top-level")
    lines.append("")
    lines.append("| Caminho | Ação | Motivo |")
    lines.append("|---|---|---|")
    for entry in sorted(classified_entries, key=lambda item: item.relative_path.lower()):
        lines.append(f"| `{entry.relative_path}` | {entry.action} | {entry.reason} |")
    lines.append("")
    lines.append("## Pendências para decisão manual")
    if not archive:
        lines.append("- Nenhuma pendência top-level de archive nesta execução.")
    else:
        for entry in archive:
            lines.append(f"- `{entry.relative_path}` -> {entry.reason}")
    lines.append("")
    lines.append("## Limpeza segura (fase 1)")
    if not artifacts:
        lines.append("- Nenhum artefato temporário detectado.")
    else:
        lines.append("| Caminho | Pattern | Status |")
        lines.append("|---|---|---|")
        removed_set = set(removed_paths)
        skipped_set = {item.split(" ", maxsplit=1)[0] for item in skipped_paths}
        for artifact in artifacts:
            status = "detectado"
            if artifact.relative_path in removed_set:
                status = "removido"
            elif artifact.relative_path in skipped_set:
                status = "ignorado (tracked)"
            lines.append(
                f"| `{artifact.relative_path}` | `{artifact.pattern}` | {status} |"
            )
    lines.append("")
    if skipped_paths:
        lines.append("## Itens pulados na limpeza segura")
        for skipped_path in skipped_paths:
            lines.append(f"- `{skipped_path}`")
        lines.append("")
    lines.append("## Resumo operacional")
    lines.append(f"- `manter`: {len(kept)}")
    lines.append(f"- `mover para archive`: {len(archive)}")
    lines.append(f"- `remover` aplicado na fase 1: {len(removed_paths)}")
    return "\n".join(lines) + "\n"


def resolve_reference_files(arguments: argparse.Namespace) -> list[Path]:
    references: list[Path] = list(DEFAULT_REFERENCE_FILES)
    for extra in arguments.reference_file:
        references.append(extra)
    unique_references: list[Path] = []
    seen: set[str] = set()
    for reference in references:
        posix_path = reference.as_posix()
        if posix_path in seen:
            continue
        seen.add(posix_path)
        unique_references.append(reference)
    return unique_references


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.resolve()
    reference_files = resolve_reference_files(args)
    report_out = (repo_root / args.report_out).resolve()
    report_out.parent.mkdir(parents=True, exist_ok=True)

    tracked_paths = load_git_tracked_paths(repo_root)
    referenced_paths = extract_referenced_paths(repo_root, reference_files)
    referenced_top_levels = top_level_from_paths(referenced_paths)

    classified_entries = classify_top_level_entries(repo_root, referenced_top_levels)
    safe_artifacts = find_safe_artifacts(repo_root, tracked_paths)

    removed_paths: list[str] = []
    skipped_paths: list[str] = []
    if args.apply_safe_clean:
        removed_paths, skipped_paths = apply_safe_cleanup(repo_root, safe_artifacts)

    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    report = render_markdown_report(
        generated_at=generated_at,
        reference_files=reference_files,
        classified_entries=classified_entries,
        artifacts=safe_artifacts,
        removed_paths=removed_paths,
        skipped_paths=skipped_paths,
    )
    report_out.write_text(report, encoding="utf-8")

    print(f"[ok] Relatorio salvo em: {report_out}")
    print(f"[ok] Top-level classificados: {len(classified_entries)}")
    print(f"[ok] Temporarios detectados: {len(safe_artifacts)}")
    if args.apply_safe_clean:
        print(f"[ok] Removidos na fase 1: {len(removed_paths)}")
        if skipped_paths:
            print(f"[ok] Itens pulados: {len(skipped_paths)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
