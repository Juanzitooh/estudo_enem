#!/usr/bin/env python3
"""Editor visual simples para o índice dos 6 volumes em CSV."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path
import re
import tkinter as tk
from tkinter import messagebox, ttk

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CSV_PATH = REPO_ROOT / "plano/indice_livros_6_volumes.csv"
REQUIRED_FIELDNAMES = (
    "volume",
    "area",
    "materia",
    "modulo",
    "titulo",
    "pagina",
    "habilidades",
)
EXPECTATIONS_FIELDNAME = "expectativas_aprendizagem"
OUTPUT_FIELDNAMES = REQUIRED_FIELDNAMES + (EXPECTATIONS_FIELDNAME,)


@dataclass
class ModuleRow:
    """Linha editável do índice de módulos."""

    volume: str
    area: str
    materia: str
    modulo: str
    titulo: str
    pagina: str
    habilidades: str
    expectativas_aprendizagem: str

    @classmethod
    def from_dict(cls, row: dict[str, str]) -> ModuleRow:
        return cls(
            volume=row.get("volume", "").strip(),
            area=row.get("area", "").strip(),
            materia=row.get("materia", "").strip(),
            modulo=row.get("modulo", "").strip(),
            titulo=row.get("titulo", "").strip(),
            pagina=row.get("pagina", "").strip(),
            habilidades=row.get("habilidades", "").strip(),
            expectativas_aprendizagem=(
                row.get(EXPECTATIONS_FIELDNAME)
                or row.get("expectativas")
                or row.get("descricao")
                or row.get("descrição")
                or ""
            ).strip(),
        )

    def as_dict(self) -> dict[str, str]:
        return {
            "volume": self.volume,
            "area": self.area,
            "materia": self.materia,
            "modulo": self.modulo,
            "titulo": self.titulo,
            "pagina": self.pagina,
            "habilidades": self.habilidades,
            EXPECTATIONS_FIELDNAME: self.expectativas_aprendizagem,
        }


def normalize_habilidades(text: str) -> str:
    """Normaliza lista de habilidades aceitando vírgula ou ponto e vírgula."""
    parts = [item.strip() for item in re.split(r"[;,]+", text) if item.strip()]
    return "; ".join(parts)


def normalize_expectativas_aprendizagem(text: str) -> str:
    """Normaliza expectativas aceitando uma por linha ou separadas por ';'."""
    parts: list[str] = []
    for chunk in re.split(r"[;\n\r]+", text):
        cleaned = re.sub(r"^\s*(?:[-*•]+|\d+[.)])\s*", "", chunk.strip())
        if cleaned:
            parts.append(cleaned)
    return "; ".join(parts)


def load_rows(csv_path: Path) -> list[ModuleRow]:
    """Carrega linhas do CSV preservando a ordem existente."""
    with csv_path.open("r", encoding="utf-8", newline="") as file_obj:
        reader = csv.DictReader(file_obj)
        if reader.fieldnames is None:
            raise ValueError("CSV sem cabeçalho.")
        missing = [field for field in REQUIRED_FIELDNAMES if field not in reader.fieldnames]
        if missing:
            raise ValueError(f"CSV sem colunas obrigatórias: {', '.join(missing)}")
        return [ModuleRow.from_dict(row) for row in reader]


def save_rows(csv_path: Path, rows: list[ModuleRow]) -> None:
    """Escreve linhas no CSV com o mesmo esquema usado pelo projeto."""
    with csv_path.open("w", encoding="utf-8", newline="") as file_obj:
        writer = csv.DictWriter(
            file_obj,
            fieldnames=list(OUTPUT_FIELDNAMES),
            quoting=csv.QUOTE_ALL,
        )
        writer.writeheader()
        for row in rows:
            writer.writerow(row.as_dict())


class IndiceLivrosEditor:
    """Aplicação GUI para editar título/página/habilidades/expectativas por módulo."""

    def __init__(self, root: tk.Tk, csv_path: Path) -> None:
        self.root = root
        self.csv_path = csv_path
        self.rows = load_rows(csv_path)
        if not self.rows:
            raise ValueError("CSV sem registros para editar.")

        self.current_index = 0
        self.dirty = False

        self.var_volume = tk.StringVar()
        self.var_area = tk.StringVar()
        self.var_materia = tk.StringVar()
        self.var_modulo = tk.StringVar()
        self.var_titulo = tk.StringVar()
        self.var_pagina = tk.StringVar()
        self.var_habilidades = tk.StringVar()
        self.var_status = tk.StringVar(value="Pronto.")
        self.var_progress = tk.StringVar()
        self.expectativas_text: tk.Text | None = None

        self._build_ui()
        self._show_row(0)

    def _build_ui(self) -> None:
        self.root.title("Editor CSV - Índice dos 6 Volumes")
        self.root.geometry("980x540")
        self.root.minsize(920, 500)

        main_frame = ttk.Frame(self.root, padding=12)
        main_frame.pack(fill="both", expand=True)

        ttk.Label(
            main_frame,
            text=f"Arquivo: {self.csv_path}",
        ).pack(anchor="w")
        ttk.Label(
            main_frame,
            textvariable=self.var_progress,
            font=("TkDefaultFont", 10, "bold"),
        ).pack(anchor="w", pady=(4, 8))

        form_frame = ttk.Frame(main_frame)
        form_frame.pack(fill="x")

        self._readonly_entry(form_frame, 0, "Volume", self.var_volume)
        self._readonly_entry(form_frame, 1, "Área", self.var_area)
        self._readonly_entry(form_frame, 2, "Matéria", self.var_materia)
        self._readonly_entry(form_frame, 3, "Módulo", self.var_modulo)

        ttk.Label(form_frame, text="Título").grid(row=4, column=0, sticky="w", pady=(10, 4))
        ttk.Entry(form_frame, textvariable=self.var_titulo, width=94).grid(
            row=4, column=1, sticky="we", pady=(10, 4)
        )

        ttk.Label(form_frame, text="Página").grid(row=5, column=0, sticky="w", pady=4)
        ttk.Entry(form_frame, textvariable=self.var_pagina, width=25).grid(
            row=5, column=1, sticky="w", pady=4
        )

        ttk.Label(form_frame, text="Habilidades/Competências").grid(
            row=6, column=0, sticky="w", pady=4
        )
        ttk.Entry(form_frame, textvariable=self.var_habilidades, width=94).grid(
            row=6, column=1, sticky="we", pady=4
        )

        ttk.Label(
            form_frame,
            text=(
                "Use vírgula ou ';' para múltiplos itens. "
                "Aceita c2, h19 ou c2-h19."
            ),
        ).grid(row=7, column=1, sticky="w", pady=(2, 0))

        ttk.Label(form_frame, text="Expectativas de aprendizagem").grid(
            row=8, column=0, sticky="nw", pady=(8, 4)
        )
        self.expectativas_text = tk.Text(form_frame, width=94, height=4, wrap="word")
        self.expectativas_text.grid(row=8, column=1, sticky="we", pady=(8, 4))
        ttk.Label(
            form_frame,
            text=(
                "Liste 2-4 expectativas curtas (uma por linha ou separadas por ';')."
            ),
        ).grid(row=9, column=1, sticky="w", pady=(2, 0))

        form_frame.columnconfigure(1, weight=1)

        buttons_frame = ttk.Frame(main_frame)
        buttons_frame.pack(fill="x", pady=(14, 8))

        ttk.Button(buttons_frame, text="Primeiro", command=self.go_first).pack(side="left")
        ttk.Button(buttons_frame, text="Anterior", command=self.go_previous).pack(side="left", padx=6)
        ttk.Button(buttons_frame, text="Próximo", command=self.go_next).pack(side="left", padx=6)
        ttk.Button(buttons_frame, text="Último", command=self.go_last).pack(side="left", padx=6)

        ttk.Button(buttons_frame, text="Salvar linha", command=self.save_current_row).pack(
            side="right"
        )
        ttk.Button(buttons_frame, text="Salvar arquivo", command=self.save_file).pack(
            side="right", padx=(0, 6)
        )

        ttk.Label(main_frame, textvariable=self.var_status).pack(anchor="w")

        self.root.bind("<Control-s>", self._on_shortcut_save)
        self.root.protocol("WM_DELETE_WINDOW", self.on_close)

    def _readonly_entry(
        self,
        parent: ttk.Frame,
        row: int,
        label: str,
        variable: tk.StringVar,
    ) -> None:
        ttk.Label(parent, text=label).grid(row=row, column=0, sticky="w", pady=2)
        entry = ttk.Entry(parent, textvariable=variable, width=94, state="readonly")
        entry.grid(row=row, column=1, sticky="we", pady=2)

    def _on_shortcut_save(self, _event: tk.Event[tk.Misc]) -> None:
        self.save_file()

    def _show_row(self, index: int) -> None:
        self.current_index = index
        row = self.rows[index]

        self.var_volume.set(row.volume)
        self.var_area.set(row.area)
        self.var_materia.set(row.materia)
        self.var_modulo.set(row.modulo)
        self.var_titulo.set(row.titulo)
        self.var_pagina.set(row.pagina)
        self.var_habilidades.set(row.habilidades)
        if self.expectativas_text is not None:
            self.expectativas_text.delete("1.0", tk.END)
            self.expectativas_text.insert("1.0", row.expectativas_aprendizagem)

        self.var_progress.set(
            f"Registro {index + 1}/{len(self.rows)} "
            f"| Volume {row.volume} | {row.materia} | Módulo {row.modulo}"
        )

    def _persist_current(self) -> None:
        row = self.rows[self.current_index]
        new_titulo = self.var_titulo.get().strip()
        new_pagina = self.var_pagina.get().strip()
        new_habilidades = normalize_habilidades(self.var_habilidades.get().strip())
        new_expectativas = ""
        if self.expectativas_text is not None:
            new_expectativas = normalize_expectativas_aprendizagem(
                self.expectativas_text.get("1.0", tk.END).strip()
            )

        changed = (
            row.titulo != new_titulo
            or row.pagina != new_pagina
            or row.habilidades != new_habilidades
            or row.expectativas_aprendizagem != new_expectativas
        )
        if changed:
            row.titulo = new_titulo
            row.pagina = new_pagina
            row.habilidades = new_habilidades
            row.expectativas_aprendizagem = new_expectativas
            self.var_habilidades.set(new_habilidades)
            if self.expectativas_text is not None:
                self.expectativas_text.delete("1.0", tk.END)
                self.expectativas_text.insert("1.0", new_expectativas)
            self.dirty = True
            self.var_status.set("Alterações pendentes. Clique em 'Salvar arquivo' para gravar.")

    def _navigate(self, target_index: int) -> None:
        self._persist_current()
        self._show_row(target_index)

    def go_first(self) -> None:
        self._navigate(0)

    def go_previous(self) -> None:
        if self.current_index > 0:
            self._navigate(self.current_index - 1)

    def go_next(self) -> None:
        if self.current_index < len(self.rows) - 1:
            self._navigate(self.current_index + 1)

    def go_last(self) -> None:
        self._navigate(len(self.rows) - 1)

    def save_current_row(self) -> None:
        self._persist_current()
        row = self.rows[self.current_index]
        self.var_status.set(
            f"Linha atual atualizada em memória: Volume {row.volume} | "
            f"{row.materia} | Módulo {row.modulo}."
        )

    def save_file(self) -> None:
        self._persist_current()
        save_rows(self.csv_path, self.rows)
        self.dirty = False
        self.var_status.set(f"Arquivo salvo: {self.csv_path}")

    def on_close(self) -> None:
        self._persist_current()
        if not self.dirty:
            self.root.destroy()
            return

        decision = messagebox.askyesnocancel(
            "Salvar antes de sair?",
            "Há alterações não salvas. Deseja salvar antes de fechar?",
        )
        if decision is None:
            return
        if decision:
            self.save_file()
        self.root.destroy()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Editor visual para plano/indice_livros_6_volumes.csv.",
    )
    parser.add_argument(
        "--csv",
        type=Path,
        default=DEFAULT_CSV_PATH,
        help="Caminho para o CSV a ser editado.",
    )
    return parser.parse_args()


def resolve_csv_path(path: Path) -> Path:
    if path.is_absolute():
        return path
    return (REPO_ROOT / path).resolve()


def main() -> int:
    args = parse_args()
    csv_path = resolve_csv_path(args.csv)

    if not csv_path.exists():
        print(f"Arquivo não encontrado: {csv_path}")
        return 1

    try:
        root = tk.Tk()
        IndiceLivrosEditor(root, csv_path)
        root.mainloop()
    except ValueError as exc:
        print(f"Erro ao abrir CSV: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
