"""SQLite storage for inverter readings."""

import sqlite3
from datetime import date
from pathlib import Path

from grostat.models import InverterReading

# All columns except 'id' (auto-increment)
_COLUMNS = InverterReading.__dataclass_fields__.keys()

_CREATE_TABLE = """
CREATE TABLE IF NOT EXISTS readings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    vpv1 REAL, vpv2 REAL, ipv1 REAL, ipv2 REAL,
    ppv1 REAL, ppv2 REAL, ppv REAL,
    epv1_today REAL, epv2_today REAL, epv1_total REAL, epv2_total REAL,
    vacr REAL, vacs REAL, vact REAL,
    vacr_phase REAL, vacs_phase REAL, vact_phase REAL,
    iacr REAL, iacs REAL, iact REAL,
    pacr REAL, pacs REAL, pact REAL,
    pac REAL, rac REAL, pf REAL, fac REAL,
    temperature REAL, ipm_temperature REAL,
    power_today REAL, power_total REAL, time_total REAL,
    status INTEGER, fault_type INTEGER,
    p_bus_voltage REAL, n_bus_voltage REAL,
    warn_code INTEGER, warning_value1 INTEGER, warning_value2 INTEGER,
    real_op_percent REAL,
    vmax_phase REAL, alert TEXT
)
"""

_CREATE_INDEXES = [
    "CREATE INDEX IF NOT EXISTS idx_readings_timestamp ON readings(timestamp)",
    "CREATE INDEX IF NOT EXISTS idx_readings_alert ON readings(alert) WHERE alert != ''",
]


class Database:
    def __init__(self, db_path: Path) -> None:
        self.db_path = db_path
        self.conn = sqlite3.connect(str(db_path))
        self.conn.row_factory = sqlite3.Row
        self.conn.execute("PRAGMA journal_mode=WAL")
        self._init_schema()

    def _init_schema(self) -> None:
        self.conn.execute(_CREATE_TABLE)
        for idx in _CREATE_INDEXES:
            self.conn.execute(idx)
        self.conn.commit()

    def insert_reading(self, reading: InverterReading) -> None:
        cols = list(_COLUMNS)
        placeholders = ", ".join("?" for _ in cols)
        col_names = ", ".join(cols)
        self.conn.execute(
            f"INSERT INTO readings ({col_names}) VALUES ({placeholders})",
            reading.values(),
        )
        self.conn.commit()

    def get_latest(self) -> dict | None:
        row = self.conn.execute("SELECT * FROM readings ORDER BY id DESC LIMIT 1").fetchone()
        return dict(row) if row else None

    def get_readings_for_date(self, target: date) -> list[dict]:
        target_str = target.strftime("%Y-%m-%d")
        rows = self.conn.execute(
            "SELECT * FROM readings WHERE timestamp LIKE ? ORDER BY timestamp",
            (f"{target_str}%",),
        ).fetchall()
        return [dict(r) for r in rows]

    def get_date_range(self) -> tuple[str | None, str | None]:
        row = self.conn.execute("SELECT MIN(timestamp), MAX(timestamp) FROM readings").fetchone()
        return (row[0], row[1]) if row else (None, None)

    def get_row_count(self) -> int:
        row = self.conn.execute("SELECT COUNT(*) FROM readings").fetchone()
        return row[0] if row else 0

    def export_readings(
        self, from_date: date | None = None, to_date: date | None = None
    ) -> list[dict]:
        query = "SELECT * FROM readings"
        params: list[str] = []
        conditions: list[str] = []

        if from_date:
            conditions.append("timestamp >= ?")
            params.append(from_date.strftime("%Y-%m-%d"))
        if to_date:
            conditions.append("timestamp < ?")
            # Next day to include full to_date
            params.append(f"{to_date.strftime('%Y-%m-%d')} 99")

        if conditions:
            query += " WHERE " + " AND ".join(conditions)
        query += " ORDER BY timestamp"

        rows = self.conn.execute(query, params).fetchall()
        return [dict(r) for r in rows]

    def close(self) -> None:
        self.conn.close()
