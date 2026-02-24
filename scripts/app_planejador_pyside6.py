#!/usr/bin/env python3
"""Interface PySide6 para o planejador offline ENEM."""

from __future__ import annotations

from datetime import date
from pathlib import Path
import sys

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

try:
    from PySide6.QtCore import QDate
    from PySide6.QtWidgets import (
        QApplication,
        QComboBox,
        QDateEdit,
        QFormLayout,
        QGroupBox,
        QHBoxLayout,
        QLabel,
        QLineEdit,
        QMainWindow,
        QMessageBox,
        QPushButton,
        QSpinBox,
        QTableWidget,
        QTableWidgetItem,
        QVBoxLayout,
        QWidget,
    )
except ImportError as exc:
    raise SystemExit(
        "PySide6 não encontrado. Instale com: pip install PySide6"
    ) from exc

from planner import (
    AttemptRecord,
    append_attempt_record,
    build_plan,
    ensure_attempts_csv,
    load_attempts_csv,
    load_planner_config,
    write_plan_markdown,
    write_priority_csv,
)


class PlannerWindow(QMainWindow):
    """Janela principal para coletar feedback e recalcular plano."""

    def __init__(self, repo_root: Path) -> None:
        super().__init__()
        self.repo_root = repo_root
        self.config_path = self.repo_root / "prompts/contexto_planejador.json"
        self.config_fallback = self.repo_root / "prompts/contexto_planejador.example.json"
        self.attempts_path = self.repo_root / "plano/desempenho_habilidades.csv"
        self.plan_md_path = self.repo_root / "plano/plano_semanal_gerado.md"
        self.priority_csv_path = self.repo_root / "plano/prioridades_habilidades.csv"

        self.config = None
        self.attempts: list[AttemptRecord] = []
        self.plan = None

        self._build_ui()
        self._load_data()
        self._recalculate_plan()

    def _build_ui(self) -> None:
        self.setWindowTitle("ENEM Planner Offline (sem IA)")
        self.resize(1200, 820)

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        root_layout = QVBoxLayout(central_widget)

        info_label = QLabel(
            "Fluxo: registrar resultado por habilidade -> recalcular plano -> estudar -> registrar novamente."
        )
        root_layout.addWidget(info_label)

        root_layout.addWidget(self._build_input_group())
        root_layout.addWidget(self._build_priority_group())
        root_layout.addWidget(self._build_attempts_group())

        self.status_label = QLabel("")
        root_layout.addWidget(self.status_label)

    def _build_input_group(self) -> QGroupBox:
        group = QGroupBox("Registrar feedback da sessão")
        layout = QFormLayout(group)

        self.input_date = QDateEdit()
        self.input_date.setCalendarPopup(True)
        self.input_date.setDate(QDate.currentDate())

        self.input_area = QComboBox()
        self.input_area.setEditable(True)
        self.input_area.addItems(
            [
                "Matemática",
                "Ciências da Natureza",
                "Linguagens",
                "Ciências Humanas",
                "Redação",
            ]
        )

        self.input_habilidade = QLineEdit()
        self.input_habilidade.setPlaceholderText("Ex.: H16")

        self.input_acertos = QSpinBox()
        self.input_acertos.setRange(0, 200)
        self.input_acertos.setValue(7)

        self.input_total = QSpinBox()
        self.input_total.setRange(1, 200)
        self.input_total.setValue(10)

        self.input_tempo = QSpinBox()
        self.input_tempo.setRange(1, 360)
        self.input_tempo.setValue(50)

        self.input_fonte = QComboBox()
        self.input_fonte.setEditable(True)
        self.input_fonte.addItems(["simulado_offline", "lista_exercicios", "revisao"])

        self.input_obs = QLineEdit()
        self.input_obs.setPlaceholderText("erro principal, dificuldade, etc.")

        button_row = QHBoxLayout()
        save_button = QPushButton("Salvar feedback")
        save_button.clicked.connect(self._save_attempt)
        recalc_button = QPushButton("Recalcular plano agora")
        recalc_button.clicked.connect(self._recalculate_plan)
        button_row.addWidget(save_button)
        button_row.addWidget(recalc_button)

        layout.addRow("Data:", self.input_date)
        layout.addRow("Área:", self.input_area)
        layout.addRow("Habilidade:", self.input_habilidade)
        layout.addRow("Acertos:", self.input_acertos)
        layout.addRow("Total:", self.input_total)
        layout.addRow("Tempo (min):", self.input_tempo)
        layout.addRow("Fonte:", self.input_fonte)
        layout.addRow("Observações:", self.input_obs)
        layout.addRow(button_row)
        return group

    def _build_priority_group(self) -> QGroupBox:
        group = QGroupBox("Prioridades de habilidade")
        layout = QVBoxLayout(group)

        self.priority_table = QTableWidget(0, 7)
        self.priority_table.setHorizontalHeaderLabels(
            [
                "Área",
                "Habilidade",
                "Prioridade",
                "Acurácia média",
                "Questões 7d",
                "Dias sem estudar",
                "Foco sugerido",
            ]
        )
        self.priority_table.horizontalHeader().setStretchLastSection(True)
        layout.addWidget(self.priority_table)
        return group

    def _build_attempts_group(self) -> QGroupBox:
        group = QGroupBox("Últimos feedbacks")
        layout = QVBoxLayout(group)

        self.attempts_table = QTableWidget(0, 8)
        self.attempts_table.setHorizontalHeaderLabels(
            [
                "Data",
                "Área",
                "Habilidade",
                "Acertos",
                "Total",
                "Acurácia",
                "Tempo (min)",
                "Fonte",
            ]
        )
        self.attempts_table.horizontalHeader().setStretchLastSection(True)
        layout.addWidget(self.attempts_table)
        return group

    def _resolve_config_path(self) -> Path:
        if self.config_path.exists():
            return self.config_path
        return self.config_fallback

    def _load_data(self) -> None:
        ensure_attempts_csv(self.attempts_path)
        self.attempts = load_attempts_csv(self.attempts_path)

        chosen_config_path = self._resolve_config_path()
        if not chosen_config_path.exists():
            QMessageBox.critical(
                self,
                "Configuração ausente",
                "Nenhum contexto encontrado em prompts/contexto_planejador.json "
                "ou prompts/contexto_planejador.example.json.",
            )
            return
        self.config = load_planner_config(chosen_config_path)
        self._refresh_attempts_table()

    def _refresh_attempts_table(self) -> None:
        records = sorted(self.attempts, key=lambda item: item.data, reverse=True)[:80]
        self.attempts_table.setRowCount(len(records))
        for row_index, record in enumerate(records):
            self.attempts_table.setItem(row_index, 0, QTableWidgetItem(record.data.isoformat()))
            self.attempts_table.setItem(row_index, 1, QTableWidgetItem(record.area))
            self.attempts_table.setItem(row_index, 2, QTableWidgetItem(record.habilidade))
            self.attempts_table.setItem(row_index, 3, QTableWidgetItem(str(record.acertos)))
            self.attempts_table.setItem(row_index, 4, QTableWidgetItem(str(record.total)))
            self.attempts_table.setItem(row_index, 5, QTableWidgetItem(f"{record.acuracia:.0%}"))
            self.attempts_table.setItem(row_index, 6, QTableWidgetItem(str(record.tempo_min)))
            self.attempts_table.setItem(row_index, 7, QTableWidgetItem(record.fonte))

    def _refresh_priority_table(self) -> None:
        if self.plan is None:
            self.priority_table.setRowCount(0)
            return
        top_items = self.plan.prioridades[:20]
        self.priority_table.setRowCount(len(top_items))
        for row_index, item in enumerate(top_items):
            self.priority_table.setItem(row_index, 0, QTableWidgetItem(item.skill.area))
            self.priority_table.setItem(row_index, 1, QTableWidgetItem(item.skill.habilidade))
            self.priority_table.setItem(row_index, 2, QTableWidgetItem(f"{item.prioridade:.4f}"))
            self.priority_table.setItem(row_index, 3, QTableWidgetItem(f"{item.acuracia_media:.0%}"))
            self.priority_table.setItem(row_index, 4, QTableWidgetItem(str(item.questoes_7d)))
            self.priority_table.setItem(
                row_index,
                5,
                QTableWidgetItem(str(item.dias_desde_ultimo_estudo)),
            )
            self.priority_table.setItem(row_index, 6, QTableWidgetItem(item.sugestao_foco))

    def _save_attempt(self) -> None:
        if self.config is None:
            QMessageBox.warning(self, "Configuração", "Configuração de planejador não carregada.")
            return

        habilidade = self.input_habilidade.text().strip().upper()
        area = self.input_area.currentText().strip()
        if not habilidade or not area:
            QMessageBox.warning(self, "Dados inválidos", "Área e habilidade são obrigatórias.")
            return

        acertos = int(self.input_acertos.value())
        total = int(self.input_total.value())
        if acertos > total:
            QMessageBox.warning(self, "Dados inválidos", "Acertos não pode ser maior que total.")
            return

        qt_date = self.input_date.date()
        record = AttemptRecord(
            data=date(qt_date.year(), qt_date.month(), qt_date.day()),
            area=area,
            habilidade=habilidade,
            acertos=acertos,
            total=total,
            tempo_min=int(self.input_tempo.value()),
            fonte=self.input_fonte.currentText().strip() or "simulado_offline",
            observacoes=self.input_obs.text().strip(),
        )
        append_attempt_record(self.attempts_path, record)
        self.attempts = load_attempts_csv(self.attempts_path)
        self._refresh_attempts_table()
        self._recalculate_plan()
        self.status_label.setText(
            f"Feedback salvo: {record.area} {record.habilidade} ({record.acertos}/{record.total})"
        )

    def _recalculate_plan(self) -> None:
        if self.config is None:
            return
        self.plan = build_plan(attempts=self.attempts, config=self.config)
        write_plan_markdown(self.plan_md_path, self.plan)
        write_priority_csv(self.priority_csv_path, self.plan)
        self._refresh_priority_table()
        self.status_label.setText(
            "Plano recalculado. Arquivos atualizados: "
            f"{self.plan_md_path} e {self.priority_csv_path}"
        )


def main() -> int:
    app = QApplication([])
    window = PlannerWindow(repo_root=REPO_ROOT)
    window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
