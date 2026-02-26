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
import unicodedata

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


def normalize_for_compare(text: str) -> str:
    """Normaliza texto para comparação case-insensitive sem acentos."""
    normalized = unicodedata.normalize("NFD", text.casefold().strip())
    return "".join(ch for ch in normalized if unicodedata.category(ch) != "Mn")


def unique_preserve_order(values: list[str]) -> list[str]:
    """Remove duplicados preservando a ordem de primeira ocorrência."""
    result: list[str] = []
    seen: set[str] = set()
    for value in values:
        key = value.strip()
        if not key or key in seen:
            continue
        seen.add(key)
        result.append(key)
    return result


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
        self.var_nav_volume = tk.StringVar()
        self.var_nav_area = tk.StringVar()
        self.var_nav_materia = tk.StringVar()
        self.var_nav_modulo = tk.StringVar()
        self.expectativas_text: tk.Text | None = None
        self.combo_nav_volume: ttk.Combobox | None = None
        self.combo_nav_area: ttk.Combobox | None = None
        self.combo_nav_materia: ttk.Combobox | None = None
        self.combo_nav_modulo: ttk.Combobox | None = None
        self._updating_nav_widgets = False

        self._build_ui()
        self._refresh_nav_options_from_current()
        self._show_row(0)
        self._warn_missing_linguagens_tracks()

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

        nav_frame = ttk.LabelFrame(main_frame, text="Navegação rápida", padding=8)
        nav_frame.pack(fill="x", pady=(0, 8))

        ttk.Label(nav_frame, text="Volume").grid(row=0, column=0, sticky="w")
        self.combo_nav_volume = ttk.Combobox(
            nav_frame,
            textvariable=self.var_nav_volume,
            state="readonly",
            width=8,
        )
        self.combo_nav_volume.grid(row=0, column=1, sticky="w", padx=(4, 12))
        self.combo_nav_volume.bind("<<ComboboxSelected>>", self._on_nav_volume_change)

        ttk.Label(nav_frame, text="Área").grid(row=0, column=2, sticky="w")
        self.combo_nav_area = ttk.Combobox(
            nav_frame,
            textvariable=self.var_nav_area,
            state="readonly",
            width=34,
        )
        self.combo_nav_area.grid(row=0, column=3, sticky="we", padx=(4, 12))
        self.combo_nav_area.bind("<<ComboboxSelected>>", self._on_nav_area_change)

        ttk.Label(nav_frame, text="Matéria").grid(row=0, column=4, sticky="w")
        self.combo_nav_materia = ttk.Combobox(
            nav_frame,
            textvariable=self.var_nav_materia,
            state="readonly",
            width=24,
        )
        self.combo_nav_materia.grid(row=0, column=5, sticky="we", padx=(4, 12))
        self.combo_nav_materia.bind("<<ComboboxSelected>>", self._on_nav_materia_change)

        ttk.Label(nav_frame, text="Módulo").grid(row=0, column=6, sticky="w")
        self.combo_nav_modulo = ttk.Combobox(
            nav_frame,
            textvariable=self.var_nav_modulo,
            state="readonly",
            width=8,
        )
        self.combo_nav_modulo.grid(row=0, column=7, sticky="w", padx=(4, 12))

        ttk.Button(nav_frame, text="Ir para", command=self.go_selected).grid(
            row=0, column=8, sticky="e"
        )
        ttk.Button(
            nav_frame,
            text="Próx. não preenchido",
            command=self.go_next_unfilled,
        ).grid(row=0, column=9, sticky="e", padx=(8, 0))

        nav_frame.columnconfigure(3, weight=1)
        nav_frame.columnconfigure(5, weight=1)

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
        ttk.Button(buttons_frame, text="Próx. não preenchido", command=self.go_next_unfilled).pack(
            side="left", padx=6
        )

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
        self._refresh_nav_options_from_current()

    def _warn_missing_linguagens_tracks(self) -> None:
        linguagens_rows = [
            row for row in self.rows if "linguagens" in normalize_for_compare(row.area)
        ]
        if not linguagens_rows:
            return

        normalized_materias = {
            normalize_for_compare(row.materia) for row in linguagens_rows if row.materia.strip()
        }
        missing: list[str] = []
        if "redacao" not in normalized_materias:
            missing.append("Redação")
        if "ingles" not in normalized_materias:
            missing.append("Inglês")

        if missing:
            joined = ", ".join(missing)
            self.var_status.set(
                f"Aviso: CSV sem blocos de {joined} em Linguagens. "
                "Navegação segue apenas o que existe no arquivo."
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

    def _row_matches_selection(self, row: ModuleRow) -> bool:
        return (
            row.volume.strip() == self.var_nav_volume.get().strip()
            and row.area.strip() == self.var_nav_area.get().strip()
            and row.materia.strip() == self.var_nav_materia.get().strip()
            and row.modulo.strip() == self.var_nav_modulo.get().strip()
        )

    def _rows_filtered(
        self,
        *,
        volume: str = "",
        area: str = "",
        materia: str = "",
    ) -> list[ModuleRow]:
        result = self.rows
        if volume.strip():
            result = [row for row in result if row.volume.strip() == volume.strip()]
        if area.strip():
            result = [row for row in result if row.area.strip() == area.strip()]
        if materia.strip():
            result = [row for row in result if row.materia.strip() == materia.strip()]
        return result

    def _set_combo_values(
        self,
        combo: ttk.Combobox | None,
        values: list[str],
        variable: tk.StringVar,
    ) -> None:
        if combo is None:
            return
        combo["values"] = values
        current = variable.get().strip()
        if current and current in values:
            variable.set(current)
            return
        variable.set(values[0] if values else "")

    def _refresh_nav_options_from_current(self) -> None:
        row = self.rows[self.current_index]
        self._refresh_nav_options(
            selected_volume=row.volume,
            selected_area=row.area,
            selected_materia=row.materia,
            selected_modulo=row.modulo,
        )

    def _refresh_nav_options(
        self,
        *,
        selected_volume: str = "",
        selected_area: str = "",
        selected_materia: str = "",
        selected_modulo: str = "",
    ) -> None:
        self._updating_nav_widgets = True
        try:
            current_volume = selected_volume.strip() or self.var_nav_volume.get().strip()
            volumes = unique_preserve_order([row.volume for row in self.rows])
            self._set_combo_values(self.combo_nav_volume, volumes, self.var_nav_volume)
            if current_volume and current_volume in volumes:
                self.var_nav_volume.set(current_volume)

            current_area = selected_area.strip() or self.var_nav_area.get().strip()
            rows_by_volume = self._rows_filtered(volume=self.var_nav_volume.get())
            areas = unique_preserve_order([row.area for row in rows_by_volume])
            self._set_combo_values(self.combo_nav_area, areas, self.var_nav_area)
            if current_area and current_area in areas:
                self.var_nav_area.set(current_area)

            current_materia = selected_materia.strip() or self.var_nav_materia.get().strip()
            rows_by_area = self._rows_filtered(
                volume=self.var_nav_volume.get(),
                area=self.var_nav_area.get(),
            )
            materias = unique_preserve_order([row.materia for row in rows_by_area])
            self._set_combo_values(self.combo_nav_materia, materias, self.var_nav_materia)
            if current_materia and current_materia in materias:
                self.var_nav_materia.set(current_materia)

            current_modulo = selected_modulo.strip() or self.var_nav_modulo.get().strip()
            rows_by_materia = self._rows_filtered(
                volume=self.var_nav_volume.get(),
                area=self.var_nav_area.get(),
                materia=self.var_nav_materia.get(),
            )
            modulos = unique_preserve_order([row.modulo for row in rows_by_materia])
            self._set_combo_values(self.combo_nav_modulo, modulos, self.var_nav_modulo)
            if current_modulo and current_modulo in modulos:
                self.var_nav_modulo.set(current_modulo)
        finally:
            self._updating_nav_widgets = False

    def _on_nav_volume_change(self, _event: tk.Event[tk.Misc]) -> None:
        if self._updating_nav_widgets:
            return
        self._refresh_nav_options()

    def _on_nav_area_change(self, _event: tk.Event[tk.Misc]) -> None:
        if self._updating_nav_widgets:
            return
        self._refresh_nav_options()

    def _on_nav_materia_change(self, _event: tk.Event[tk.Misc]) -> None:
        if self._updating_nav_widgets:
            return
        self._refresh_nav_options()

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

    def go_selected(self) -> None:
        self._persist_current()
        for index, row in enumerate(self.rows):
            if self._row_matches_selection(row):
                self._show_row(index)
                self.var_status.set(
                    f"Navegado para: Volume {row.volume} | {row.materia} | Módulo {row.modulo}."
                )
                return
        self.var_status.set("Combinação selecionada não encontrada no CSV.")

    def _is_row_unfilled(self, row: ModuleRow) -> bool:
        return any(
            not value.strip()
            for value in (
                row.titulo,
                row.pagina,
                row.habilidades,
                row.expectativas_aprendizagem,
            )
        )

    def go_next_unfilled(self) -> None:
        self._persist_current()
        total = len(self.rows)
        if total <= 0:
            return

        start = (self.current_index + 1) % total
        index = start
        while True:
            if self._is_row_unfilled(self.rows[index]):
                self._show_row(index)
                row = self.rows[index]
                self.var_status.set(
                    f"Próximo pendente: Registro {index + 1} | Volume {row.volume} | "
                    f"{row.materia} | Módulo {row.modulo}."
                )
                return
            index = (index + 1) % total
            if index == start:
                break

        self.var_status.set("Nenhum registro com campos pendentes encontrado.")

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
