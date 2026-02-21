#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/md_to_pdf_prince.sh <input.md> [output.pdf]

Examples:
  scripts/md_to_pdf_prince.sh teste_aula_habilidade_base_h18.md
  scripts/md_to_pdf_prince.sh teste_aula_habilidade_base_h18.md aula_h18.pdf
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 1 ]]; then
  usage
  exit 0
fi

INPUT_MD="$1"
if [[ ! -f "$INPUT_MD" ]]; then
  echo "Erro: arquivo nao encontrado: $INPUT_MD" >&2
  exit 1
fi

if [[ $# -ge 2 ]]; then
  OUTPUT_PDF="$2"
else
  OUTPUT_PDF="${INPUT_MD%.md}.pdf"
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="${MDTO_PDF_VENV:-$REPO_ROOT/.venv_mdpdf}"
PY_BIN="$VENV_DIR/bin/python"
PIP_BIN="$VENV_DIR/bin/pip"

if command -v prince >/dev/null 2>&1; then
  PRINCE_BIN="$(command -v prince)"
elif [[ -x "$HOME/.local/bin/prince" ]]; then
  PRINCE_BIN="$HOME/.local/bin/prince"
else
  echo "Erro: prince nao encontrado. Instale PrinceXML antes de converter." >&2
  exit 1
fi

if [[ ! -x "$PY_BIN" ]]; then
  python3 -m venv "$VENV_DIR"
  "$PIP_BIN" install markdown >/dev/null
fi

if ! "$PY_BIN" - <<'PY' >/dev/null 2>&1
import markdown  # noqa: F401
PY
then
  "$PIP_BIN" install markdown >/dev/null
fi

TMP_HTML="$(mktemp --suffix=.html)"
trap 'rm -f "$TMP_HTML"' EXIT

"$PY_BIN" - "$INPUT_MD" "$TMP_HTML" <<'PY'
import pathlib
import sys

import markdown

input_md = pathlib.Path(sys.argv[1])
output_html = pathlib.Path(sys.argv[2])
text = input_md.read_text(encoding="utf-8")

html_body = markdown.markdown(
    text,
    extensions=[
        "extra",
        "sane_lists",
        "toc",
    ],
)

title = input_md.stem.replace("_", " ")

html_doc = f"""<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{title}</title>
  <style>
    @page {{ size: A4; margin: 16mm; }}
    html, body {{ margin: 0; padding: 0; }}
    body {{
      font-family: "Segoe UI", Arial, sans-serif;
      font-size: 11pt;
      line-height: 1.5;
      color: #1f1f1f;
    }}
    h1, h2, h3 {{ line-height: 1.2; margin: 1.2em 0 0.5em; }}
    h1 {{ font-size: 24pt; }}
    h2 {{ font-size: 17pt; border-bottom: 1px solid #ddd; padding-bottom: 0.2em; }}
    h3 {{ font-size: 13pt; }}
    p {{ margin: 0.6em 0; }}
    ul, ol {{ margin: 0.4em 0 0.8em 1.2em; padding: 0; }}
    li {{ margin: 0.2em 0; }}
    code {{
      font-family: "JetBrains Mono", "Cascadia Code", monospace;
      background: #f4f4f4;
      border-radius: 4px;
      padding: 0.1em 0.3em;
      font-size: 0.92em;
    }}
    pre {{
      background: #f4f4f4;
      border: 1px solid #e5e5e5;
      border-radius: 8px;
      padding: 0.8em;
      overflow: auto;
    }}
    pre code {{ background: transparent; padding: 0; }}
    table {{
      border-collapse: collapse;
      width: 100%;
      margin: 0.8em 0;
      font-size: 10.5pt;
    }}
    th, td {{
      border: 1px solid #d9d9d9;
      padding: 0.45em 0.55em;
      vertical-align: top;
    }}
    th {{
      background: #f7f7f7;
      text-align: left;
    }}
    blockquote {{
      border-left: 4px solid #cfcfcf;
      padding: 0.3em 0.8em;
      margin: 0.9em 0;
      color: #444;
      background: #fafafa;
    }}
    hr {{
      border: 0;
      border-top: 1px solid #ddd;
      margin: 1.2em 0;
    }}
  </style>
</head>
<body>
{html_body}
</body>
</html>
"""

output_html.write_text(html_doc, encoding="utf-8")
PY

"$PRINCE_BIN" "$TMP_HTML" --javascript -o "$OUTPUT_PDF"

echo "PDF gerado: $OUTPUT_PDF"
