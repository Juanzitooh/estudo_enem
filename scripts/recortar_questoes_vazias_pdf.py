#!/usr/bin/env python3
"""Recorta imagens de fallback para questões vazias no banco real."""

from __future__ import annotations

import argparse
import csv
import re
import subprocess
import tempfile
import unicodedata
import xml.etree.ElementTree as ET
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


QUESTION_HEADER_RE = re.compile(r"^## Questão\s+(\d{3})(?:\s+\(variação\s+(\d+)\))?\s*$", re.MULTILINE)
INVALID_XML_CHAR_RE = re.compile(r"[^\x09\x0A\x0D\x20-\uD7FF\uE000-\uFFFD]")

XHTML_NS = {"x": "http://www.w3.org/1999/xhtml"}
ANCHOR_TOKEN = "QUESTAO"
MIN_QUESTION = 1
MAX_QUESTION = 180

START_MARGIN_PT = 8.0
END_MARGIN_PT = 6.0
MIN_CROP_HEIGHT_PT = 20.0
TOP_STRIP_TOP_TOLERANCE_PT = 2.0
TOP_STRIP_MAX_HEIGHT_PT = 120.0
CADERNO_CODE_RE = re.compile(r"^(?:AZUL|AMARELO|AMARELA|ROSA|BRANCO|BRANCA)\d")
HEADER_NOISE_TOKENS = {
    "ENEM",
    "QUESTOES",
    "QUESTAO",
    "TECNOLOGIAS",
    "LINGUAGENS",
    "CODIGOS",
    "SUAS",
    "HUMANAS",
    "NATUREZA",
    "MATEMATICA",
    "CIENCIAS",
    "DIA",
    "SAB",
    "DOM",
    "PROVA",
    "CADERNO",
    "OPCAO",
    "INGLES",
    "ESPANHOL",
}


@dataclass(frozen=True)
class MarkdownQuestion:
    numero: int
    variacao: int
    vazio: bool


@dataclass(frozen=True)
class QuestionAnchor:
    numero: int
    variacao: int
    page: int
    x_pt: float
    y_pt: float


@dataclass(frozen=True)
class PageInfo:
    width_pt: float
    height_pt: float


@dataclass(frozen=True)
class CropRect:
    page: int
    x_pt: float
    y_pt: float
    w_pt: float
    h_pt: float


@dataclass(frozen=True)
class WordBox:
    x_min: float
    y_min: float
    x_max: float
    y_max: float
    token: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Gera recortes de imagem para questões vazias no markdown extraído."
    )
    parser.add_argument("--ano", type=int, required=True)
    parser.add_argument("--dia", type=int, choices=[1, 2], required=True)
    parser.add_argument(
        "--prova-pdf",
        type=Path,
        help="PDF de prova. Padrão: questoes/provas_anteriores/{ano}_dia{dia}_prova.pdf",
    )
    parser.add_argument(
        "--questoes-md",
        type=Path,
        help="Markdown com questões extraídas. Padrão: questoes/banco_reais/enem_{ano}/dia{dia}_questoes_reais.md",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        help="Diretório de saída das imagens e manifest.",
    )
    parser.add_argument("--dpi", type=int, default=160, help="DPI dos recortes PNG.")
    parser.add_argument(
        "--somente-vazias",
        action="store_true",
        help="Recorta apenas as questões vazias.",
    )
    parser.add_argument(
        "--todas",
        action="store_true",
        help="Recorta todas as questões do markdown (ignora filtro de vazias).",
    )
    return parser.parse_args()


def normalize_token(text: str) -> str:
    lowered = text.lower()
    normalized = unicodedata.normalize("NFD", lowered)
    normalized = "".join(ch for ch in normalized if unicodedata.category(ch) != "Mn")
    normalized = re.sub(r"[^a-z0-9]+", "", normalized)
    return normalized.upper()


def parse_markdown_questions(path: Path) -> list[MarkdownQuestion]:
    content = path.read_text(encoding="utf-8")
    matches = list(QUESTION_HEADER_RE.finditer(content))
    result: list[MarkdownQuestion] = []

    for index, match in enumerate(matches):
        numero = int(match.group(1))
        variacao = int(match.group(2)) if match.group(2) else 1
        start = match.end()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(content)
        block = content[start:end].strip()

        has_body = False
        for line in block.splitlines():
            stripped = line.strip()
            if not stripped:
                continue
            if stripped.startswith("- Área:"):
                continue
            if stripped.startswith("- Gabarito:"):
                continue
            has_body = True
            break

        result.append(
            MarkdownQuestion(
                numero=numero,
                variacao=variacao,
                vazio=(not has_body),
            )
        )

    return result


def read_bbox_xml(pdf_path: Path) -> ET.Element:
    with tempfile.NamedTemporaryFile(suffix=".html", delete=False) as temp_file:
        bbox_path = Path(temp_file.name)

    try:
        subprocess.run(
            ["pdftotext", "-bbox-layout", str(pdf_path), str(bbox_path)],
            check=True,
            capture_output=True,
            text=True,
        )
        try:
            tree = ET.parse(bbox_path)
            return tree.getroot()
        except ET.ParseError:
            raw_text = bbox_path.read_text(encoding="utf-8", errors="ignore")
            sanitized = INVALID_XML_CHAR_RE.sub("", raw_text)
            return ET.fromstring(sanitized)
    finally:
        if bbox_path.exists():
            bbox_path.unlink()


def collect_page_info(root: ET.Element) -> dict[int, PageInfo]:
    pages = root.findall(".//x:page", XHTML_NS)
    info: dict[int, PageInfo] = {}
    for index, page in enumerate(pages, start=1):
        info[index] = PageInfo(
            width_pt=float(page.attrib["width"]),
            height_pt=float(page.attrib["height"]),
        )
    return info


def collect_question_anchors(root: ET.Element, pages_info: dict[int, PageInfo]) -> list[QuestionAnchor]:
    anchors_by_page: dict[int, list[tuple[int, float, float]]] = defaultdict(list)
    pages = root.findall(".//x:page", XHTML_NS)

    for page_index, page in enumerate(pages, start=1):
        words = page.findall(".//x:word", XHTML_NS)
        words_data: list[tuple[float, float, str]] = []
        for word in words:
            text = (word.text or "").strip()
            if not text:
                continue
            words_data.append(
                (
                    float(word.attrib["xMin"]),
                    float(word.attrib["yMin"]),
                    text,
                )
            )

        words_data.sort(key=lambda item: (item[1], item[0]))
        total = len(words_data)
        for idx, (x_pt, y_pt, text) in enumerate(words_data):
            if normalize_token(text) != ANCHOR_TOKEN:
                continue
            for next_idx in range(idx + 1, min(idx + 7, total)):
                next_x, next_y, next_text = words_data[next_idx]
                number_token = normalize_token(next_text)
                if not number_token.isdigit():
                    continue
                numero = int(number_token)
                if not (MIN_QUESTION <= numero <= MAX_QUESTION):
                    continue
                anchors_by_page[page_index].append((numero, min(x_pt, next_x), min(y_pt, next_y)))
                break

    ordered_raw: list[tuple[int, int, float, float]] = []
    for page_index in sorted(anchors_by_page):
        page_width = pages_info[page_index].width_pt
        split_x = page_width * 0.5
        page_anchors = anchors_by_page[page_index]
        page_anchors.sort(
            key=lambda item: (
                0 if item[1] < split_x else 1,  # coluna esquerda antes da direita
                item[2],
                item[1],
            )
        )
        for numero, x_pt, y_pt in page_anchors:
            ordered_raw.append((numero, page_index, x_pt, y_pt))

    variation_counter: defaultdict[int, int] = defaultdict(int)
    anchors: list[QuestionAnchor] = []
    for numero, page, x_pt, y_pt in ordered_raw:
        variation_counter[numero] += 1
        anchors.append(
            QuestionAnchor(
                numero=numero,
                variacao=variation_counter[numero],
                page=page,
                x_pt=x_pt,
                y_pt=y_pt,
            )
        )
    return anchors


def collect_words_by_page(root: ET.Element) -> dict[int, list[WordBox]]:
    pages = root.findall(".//x:page", XHTML_NS)
    words_by_page: dict[int, list[WordBox]] = {}

    for page_index, page in enumerate(pages, start=1):
        page_words: list[WordBox] = []
        for word in page.findall(".//x:word", XHTML_NS):
            text = (word.text or "").strip()
            if not text:
                continue
            token = normalize_token(text)
            if not token:
                continue
            page_words.append(
                WordBox(
                    x_min=float(word.attrib["xMin"]),
                    y_min=float(word.attrib["yMin"]),
                    x_max=float(word.attrib["xMax"]),
                    y_max=float(word.attrib["yMax"]),
                    token=token,
                )
            )
        words_by_page[page_index] = page_words

    return words_by_page


def tokens_in_crop(crop: CropRect, words_by_page: dict[int, list[WordBox]]) -> list[str]:
    page_words = words_by_page.get(crop.page, [])
    if not page_words:
        return []

    x2 = crop.x_pt + crop.w_pt
    y2 = crop.y_pt + crop.h_pt
    tokens: list[str] = []

    for word in page_words:
        if word.x_max < crop.x_pt or word.x_min > x2:
            continue
        if word.y_max < crop.y_pt or word.y_min > y2:
            continue
        tokens.append(word.token)

    return tokens


def is_header_noise_token(token: str) -> bool:
    if not token:
        return True
    if token in HEADER_NOISE_TOKENS:
        return True
    if token.isdigit():
        return True
    if len(token) <= 2:
        return True
    if CADERNO_CODE_RE.match(token):
        return True
    if "SAB" in token and any(ch.isdigit() for ch in token):
        return True
    if token.startswith(("AZUL", "AMARELO", "AMARELA", "ROSA", "BRANCO", "BRANCA")) and any(
        ch.isdigit() for ch in token
    ):
        return True
    if token[0].isdigit() and any(ch.isdigit() for ch in token) and any(
        tag in token for tag in ("AZ", "AM", "RS", "BR")
    ):
        return True
    return False


def should_skip_top_strip_crop(crop: CropRect, words_by_page: dict[int, list[WordBox]]) -> bool:
    is_top_strip = crop.y_pt <= TOP_STRIP_TOP_TOLERANCE_PT and crop.h_pt <= TOP_STRIP_MAX_HEIGHT_PT
    if not is_top_strip:
        return False

    tokens = tokens_in_crop(crop, words_by_page)
    if not tokens:
        return True

    alpha_tokens = [token for token in tokens if any(ch.isalpha() for ch in token)]
    if not alpha_tokens:
        return True

    meaningful_alpha = [token for token in alpha_tokens if not is_header_noise_token(token)]
    if not meaningful_alpha:
        return True
    if len(meaningful_alpha) == 1 and len(alpha_tokens) <= 3:
        return True

    return False


def resolve_targets(
    markdown_questions: list[MarkdownQuestion],
    only_empty: bool,
) -> list[MarkdownQuestion]:
    if only_empty:
        return [item for item in markdown_questions if item.vazio]
    return markdown_questions


def find_anchor(
    anchors: list[QuestionAnchor],
    numero: int,
    variacao: int,
) -> int | None:
    for index, anchor in enumerate(anchors):
        if anchor.numero == numero and anchor.variacao == variacao:
            return index

    same_number = [idx for idx, anchor in enumerate(anchors) if anchor.numero == numero]
    if not same_number:
        return None

    if variacao <= len(same_number):
        return same_number[variacao - 1]
    return same_number[0]


def column_index(anchor: QuestionAnchor, pages: dict[int, PageInfo]) -> int:
    page_info = pages[anchor.page]
    split_x = page_info.width_pt * 0.5
    return 0 if anchor.x_pt < split_x else 1


def column_bounds(page_info: PageInfo, col: int) -> tuple[float, float]:
    split_x = page_info.width_pt * 0.5
    if col == 0:
        return 0.0, split_x
    return split_x, page_info.width_pt - split_x


def build_crops_for_anchor(
    anchors: list[QuestionAnchor],
    anchor_index: int,
    pages: dict[int, PageInfo],
) -> list[CropRect]:
    current = anchors[anchor_index]
    current_col = column_index(current, pages)
    next_anchor: QuestionAnchor | None = None
    for candidate in anchors[anchor_index + 1 :]:
        if column_index(candidate, pages) == current_col:
            next_anchor = candidate
            break

    if next_anchor is None:
        end_page = max(pages)
        end_y = pages[end_page].height_pt
    else:
        end_page = next_anchor.page
        end_y = next_anchor.y_pt

    start_page = current.page
    start_y = max(0.0, current.y_pt - START_MARGIN_PT)

    crops: list[CropRect] = []
    if start_page == end_page:
        page_info = pages[start_page]
        x_pt, w_pt = column_bounds(page_info, current_col)
        y2 = min(page_info.height_pt, max(start_y + MIN_CROP_HEIGHT_PT, end_y - END_MARGIN_PT))
        if y2 - start_y < MIN_CROP_HEIGHT_PT:
            y2 = page_info.height_pt
        crops.append(
            CropRect(
                page=start_page,
                x_pt=x_pt,
                y_pt=start_y,
                w_pt=w_pt,
                h_pt=max(MIN_CROP_HEIGHT_PT, y2 - start_y),
            )
        )
        return crops

    # Primeira página (do início da questão até fim da página)
    first_page = pages[start_page]
    first_x, first_w = column_bounds(first_page, current_col)
    first_h = max(MIN_CROP_HEIGHT_PT, first_page.height_pt - start_y)
    crops.append(
        CropRect(
            page=start_page,
            x_pt=first_x,
            y_pt=start_y,
            w_pt=first_w,
            h_pt=first_h,
        )
    )

    # Páginas intermediárias inteiras
    for page_num in range(start_page + 1, end_page):
        page_info = pages[page_num]
        mid_x, mid_w = column_bounds(page_info, current_col)
        crops.append(
            CropRect(
                page=page_num,
                x_pt=mid_x,
                y_pt=0.0,
                w_pt=mid_w,
                h_pt=page_info.height_pt,
            )
        )

    # Última página (do topo até o início da próxima questão)
    last_page = pages[end_page]
    last_x, last_w = column_bounds(last_page, current_col)
    last_h = max(MIN_CROP_HEIGHT_PT, min(last_page.height_pt, end_y - END_MARGIN_PT))
    crops.append(
        CropRect(
            page=end_page,
            x_pt=last_x,
            y_pt=0.0,
            w_pt=last_w,
            h_pt=last_h,
        )
    )

    return crops


def pt_to_px(value_pt: float, dpi: int) -> int:
    return max(1, int(round(value_pt * dpi / 72.0)))


def render_crop(pdf_path: Path, out_png: Path, crop: CropRect, dpi: int) -> None:
    out_png.parent.mkdir(parents=True, exist_ok=True)
    out_prefix = out_png.with_suffix("")

    x_px = pt_to_px(crop.x_pt, dpi)
    y_px = pt_to_px(crop.y_pt, dpi)
    w_px = pt_to_px(crop.w_pt, dpi)
    h_px = pt_to_px(crop.h_pt, dpi)

    subprocess.run(
        [
            "pdftoppm",
            "-f",
            str(crop.page),
            "-l",
            str(crop.page),
            "-r",
            str(dpi),
            "-x",
            str(x_px),
            "-y",
            str(y_px),
            "-W",
            str(w_px),
            "-H",
            str(h_px),
            "-singlefile",
            "-png",
            str(pdf_path),
            str(out_prefix),
        ],
        check=True,
        capture_output=True,
        text=True,
    )


def default_paths(args: argparse.Namespace) -> tuple[Path, Path, Path]:
    prova_pdf = args.prova_pdf or Path(f"questoes/provas_anteriores/{args.ano}_dia{args.dia}_prova.pdf")
    questoes_md = args.questoes_md or Path(
        f"questoes/banco_reais/enem_{args.ano}/dia{args.dia}_questoes_reais.md"
    )
    out_dir = args.out_dir or Path(
        f"questoes/banco_reais/enem_{args.ano}/dia{args.dia}_questoes_vazias_imagens"
    )
    return prova_pdf, questoes_md, out_dir


def write_manifest(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "ano",
        "dia",
        "numero",
        "variacao",
        "parte",
        "page",
        "x_pt",
        "y_pt",
        "w_pt",
        "h_pt",
        "image_path",
    ]
    with path.open("w", encoding="utf-8", newline="") as file_obj:
        writer = csv.DictWriter(file_obj, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def write_summary(
    path: Path,
    ano: int,
    dia: int,
    total_targets: int,
    anchors_found: int,
    missing_targets: list[MarkdownQuestion],
    skipped_header_crops: int,
    rows: list[dict[str, str]],
) -> None:
    lines: list[str] = []
    lines.append(f"# Recorte de Questões Vazias — ENEM {ano} Dia {dia}")
    lines.append("")
    lines.append(f"- Questões alvo: **{total_targets}**")
    lines.append(f"- Questões com âncora encontrada: **{anchors_found}**")
    lines.append(f"- Questões sem âncora: **{len(missing_targets)}**")
    lines.append(f"- Recortes descartados (topo/header): **{skipped_header_crops}**")
    lines.append(f"- Imagens geradas: **{len(rows)}**")
    lines.append("")

    if missing_targets:
        lines.append("## Sem âncora no PDF")
        lines.append("")
        lines.append("| Questão | Variação |")
        lines.append("|---:|---:|")
        for item in missing_targets:
            lines.append(f"| {item.numero:03d} | {item.variacao} |")
        lines.append("")

    lines.append("## Recortes gerados")
    lines.append("")
    lines.append("| Questão | Variação | Parte | Página | Arquivo |")
    lines.append("|---:|---:|---:|---:|---|")
    for row in rows:
        lines.append(
            f"| {int(row['numero']):03d} | {row['variacao']} | {row['parte']} | {row['page']} | `{row['image_path']}` |"
        )
    lines.append("")

    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    args = parse_args()
    if not args.somente_vazias and not args.todas:
        args.somente_vazias = True
    if args.todas:
        args.somente_vazias = False

    prova_pdf, questoes_md, out_dir = default_paths(args)

    if not prova_pdf.exists():
        raise FileNotFoundError(f"PDF não encontrado: {prova_pdf}")
    if not questoes_md.exists():
        raise FileNotFoundError(f"Markdown de questões não encontrado: {questoes_md}")

    markdown_questions = parse_markdown_questions(questoes_md)
    targets = resolve_targets(markdown_questions, only_empty=args.somente_vazias)

    root = read_bbox_xml(prova_pdf)
    pages = collect_page_info(root)
    anchors = collect_question_anchors(root, pages)
    words_by_page = collect_words_by_page(root)

    manifest_rows: list[dict[str, str]] = []
    missing_targets: list[MarkdownQuestion] = []
    anchored_count = 0
    skipped_header_crops = 0

    images_dir = out_dir / "images"
    if images_dir.exists():
        for stale_png in images_dir.glob("*.png"):
            stale_png.unlink()
    images_dir.mkdir(parents=True, exist_ok=True)

    for target in targets:
        anchor_index = find_anchor(anchors, target.numero, target.variacao)
        if anchor_index is None:
            missing_targets.append(target)
            continue
        anchored_count += 1
        crops = build_crops_for_anchor(anchors, anchor_index, pages)
        output_part = 0

        for crop in crops:
            if should_skip_top_strip_crop(crop, words_by_page):
                skipped_header_crops += 1
                continue

            output_part += 1
            file_name = (
                f"q{target.numero:03d}_v{target.variacao:02d}_p{crop.page:02d}_part{output_part:02d}.png"
            )
            image_path = images_dir / file_name
            render_crop(prova_pdf, image_path, crop, args.dpi)

            manifest_rows.append(
                {
                    "ano": str(args.ano),
                    "dia": str(args.dia),
                    "numero": str(target.numero),
                    "variacao": str(target.variacao),
                    "parte": str(output_part),
                    "page": str(crop.page),
                    "x_pt": f"{crop.x_pt:.2f}",
                    "y_pt": f"{crop.y_pt:.2f}",
                    "w_pt": f"{crop.w_pt:.2f}",
                    "h_pt": f"{crop.h_pt:.2f}",
                    "image_path": str(image_path),
                }
            )

    manifest_path = out_dir / "manifest.csv"
    summary_path = out_dir / "resumo.md"
    write_manifest(manifest_path, manifest_rows)
    write_summary(
        path=summary_path,
        ano=args.ano,
        dia=args.dia,
        total_targets=len(targets),
        anchors_found=anchored_count,
        missing_targets=missing_targets,
        skipped_header_crops=skipped_header_crops,
        rows=manifest_rows,
    )

    print(f"[ok] questões analisadas: {len(markdown_questions)}")
    print(f"[ok] alvos: {len(targets)}")
    print(f"[ok] com âncora: {anchored_count}")
    print(f"[ok] sem âncora: {len(missing_targets)}")
    print(f"[ok] recortes descartados (topo/header): {skipped_header_crops}")
    print(f"[ok] recortes gerados: {len(manifest_rows)}")
    print(f"[ok] saída: {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
