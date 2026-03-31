"""CLI interface using Typer."""

import csv
import io
import logging
import sys
import time
from datetime import date, datetime
from pathlib import Path
from typing import Annotated

import typer
from rich.console import Console
from rich.table import Table

from grostat.alerts import AlertChecker
from grostat.api import GrowattClient
from grostat.config import CONFIG_FILE, Settings, init_config
from grostat.db import Database

app = typer.Typer(help="grostat — Growatt inverter data collector")
console = Console()
logger = logging.getLogger("grostat")


def _setup_logging(db_path: Path) -> None:
    """Configure logging to stderr and a file next to the database."""
    root = logging.getLogger("grostat")
    root.setLevel(logging.INFO)
    root.handlers.clear()

    fmt = logging.Formatter("%(asctime)s %(levelname)-8s %(message)s", datefmt="%H:%M:%S")

    stderr_handler = logging.StreamHandler(sys.stderr)
    stderr_handler.setFormatter(fmt)
    root.addHandler(stderr_handler)

    log_file = db_path.parent / "grostat.log"
    file_handler = logging.FileHandler(log_file, encoding="utf-8")
    file_handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)-8s %(message)s"))
    root.addHandler(file_handler)


def _get_deps() -> tuple[Settings, Database, GrowattClient, AlertChecker]:
    """Initialize all dependencies."""
    settings = Settings()
    if not settings.token:
        console.print("[red]Token not set. Run 'grostat init' or set GROSTAT_TOKEN.[/red]")
        raise typer.Exit(1)

    db_path = settings.resolved_db_path()
    _setup_logging(db_path)
    db = Database(db_path)
    client = GrowattClient(settings)
    alerts = AlertChecker(settings)
    return settings, db, client, alerts


def _collect_once(client: GrowattClient, db: Database, alerts: AlertChecker) -> bool:
    """Fetch one reading, store it, check alerts. Returns True on success."""
    try:
        reading = client.fetch_last_data()
    except Exception as e:
        logger.error("Failed to fetch data: %s", e)
        return False

    level = alerts.evaluate(reading)
    reading.alert = level
    db.insert_reading(reading)

    status_txt = {0: "WAIT", 1: "OK", 3: "FAULT"}.get(reading.status, f"?{reading.status}")
    logger.info(
        "%s | R:%.1fV S:%.1fV T:%.1fV (max=%.1fV) | PAC=%sW | DC=%sW | E=%.1fkWh%s",
        status_txt,
        reading.vacr_phase,
        reading.vacs_phase,
        reading.vact_phase,
        reading.vmax_phase,
        reading.pac,
        reading.ppv,
        reading.power_today,
        f" [{level}]" if level else "",
    )
    return True


@app.command()
def init() -> None:
    """Create config file at ~/.config/grostat/config.json."""
    if CONFIG_FILE.exists():
        console.print(f"Config already exists: {CONFIG_FILE}")
        console.print("Edit it directly or delete it to recreate.")
        return
    path = init_config()
    console.print(f"Created config: [bold]{path}[/bold]")
    console.print("Edit it and set your [bold]token[/bold] before running 'grostat collect'.")


@app.command()
def collect(
    loop: Annotated[bool, typer.Option(help="Continuous collection mode")] = False,
) -> None:
    """Fetch one reading from the inverter and store it."""
    settings, db, client, alerts = _get_deps()

    if not loop:
        success = _collect_once(client, db, alerts)
        db.close()
        if not success:
            raise typer.Exit(1)
        return

    interval = settings.loop_interval_s
    logger.info("Starting continuous collection (every %ds). Ctrl+C to stop.", interval)
    try:
        while True:
            _collect_once(client, db, alerts)
            time.sleep(settings.loop_interval_s)
    except KeyboardInterrupt:
        logger.info("Stopped by user.")
    finally:
        db.close()


@app.command()
def summary(
    target_date: Annotated[
        str | None, typer.Argument(help="Date YYYY-MM-DD (default: today)")
    ] = None,
) -> None:
    """Display daily summary of collected data."""
    _, db, _, _ = _get_deps()

    target = date.today()
    if target_date:
        target = datetime.strptime(target_date, "%Y-%m-%d").date()

    rows = db.get_readings_for_date(target)
    db.close()

    if not rows:
        console.print(f"No data for {target}")
        return

    vmax_all = max(r["vmax_phase"] for r in rows)
    active = [r["vmax_phase"] for r in rows if r["vmax_phase"] > 0]
    vmin_all = min(active) if active else 0
    pac_max = max(r["pac"] for r in rows)
    ppv_max = max(r["ppv"] for r in rows)
    e_today_vals = [r["power_today"] for r in rows if r["power_today"]]
    e_today = max(e_today_vals) if e_today_vals else 0
    alert_count = sum(1 for r in rows if r["alert"])
    fault_count = sum(1 for r in rows if r["status"] == 3)
    temp_vals = [r["temperature"] for r in rows if r["temperature"] > 0]
    temp_range = f"{min(temp_vals):.1f}-{max(temp_vals):.1f}" if temp_vals else "n/a"

    # Average phase S voltage (historically highest)
    vacs_vals = [r["vacs_phase"] for r in rows if r["vacs_phase"] > 0]
    vacs_avg = sum(vacs_vals) / len(vacs_vals) if vacs_vals else 0

    table = Table(title=f"Summary {target} ({len(rows)} readings)")
    table.add_column("Metric", style="bold")
    table.add_column("Value", justify="right")

    table.add_row("Vmax phase", f"{vmax_all:.1f} V")
    table.add_row("Vmin phase", f"{vmin_all:.1f} V")
    table.add_row("Vacs (S) avg", f"{vacs_avg:.1f} V")
    table.add_row("PAC max", f"{pac_max:.0f} W")
    table.add_row("PPV max (DC)", f"{ppv_max:.0f} W")
    table.add_row("Energy today", f"{e_today:.1f} kWh")
    table.add_row("Alerts", str(alert_count))
    table.add_row("Faults", str(fault_count))
    table.add_row("Temp range", f"{temp_range} °C")

    console.print(table)


@app.command()
def status() -> None:
    """Display the most recent reading."""
    _, db, _, _ = _get_deps()
    row = db.get_latest()
    db.close()

    if not row:
        console.print("No readings yet. Run 'grostat collect' first.")
        return

    groups = {
        "DC Input": [
            ("vpv1", "V"),
            ("vpv2", "V"),
            ("ipv1", "A"),
            ("ipv2", "A"),
            ("ppv1", "W"),
            ("ppv2", "W"),
            ("ppv", "W"),
            ("epv1_today", "kWh"),
            ("epv2_today", "kWh"),
        ],
        "AC Grid": [
            ("vacr_phase", "V"),
            ("vacs_phase", "V"),
            ("vact_phase", "V"),
            ("vmax_phase", "V"),
            ("iacr", "A"),
            ("iacs", "A"),
            ("iact", "A"),
            ("pacr", "W"),
            ("pacs", "W"),
            ("pact", "W"),
            ("pac", "W"),
            ("rac", "W"),
            ("pf", ""),
            ("fac", "Hz"),
        ],
        "Temperature": [
            ("temperature", "°C"),
            ("ipm_temperature", "°C"),
        ],
        "Energy": [
            ("power_today", "kWh"),
            ("power_total", "kWh"),
            ("time_total", "h"),
        ],
        "Diagnostics": [
            ("status", ""),
            ("fault_type", ""),
            ("warn_code", ""),
            ("p_bus_voltage", "V"),
            ("n_bus_voltage", "V"),
            ("real_op_percent", "%"),
        ],
    }

    console.print(
        f"\n[bold]Last reading:[/bold] {row['timestamp']}  "
        f"[{'red' if row['alert'] else 'green'}]{row['alert'] or 'OK'}[/]"
    )

    for group_name, fields in groups.items():
        table = Table(title=group_name, show_header=True)
        table.add_column("Field")
        table.add_column("Value", justify="right")
        for field, unit in fields:
            val = row.get(field, "")
            table.add_row(field, f"{val} {unit}".strip())
        console.print(table)


@app.command()
def export(
    from_date: Annotated[str | None, typer.Option("--from", help="Start date YYYY-MM-DD")] = None,
    to_date: Annotated[str | None, typer.Option("--to", help="End date YYYY-MM-DD")] = None,
    output: Annotated[Path | None, typer.Option("--output", "-o", help="Output file")] = None,
) -> None:
    """Export readings to CSV."""
    _, db, _, _ = _get_deps()

    fd = datetime.strptime(from_date, "%Y-%m-%d").date() if from_date else None
    td = datetime.strptime(to_date, "%Y-%m-%d").date() if to_date else None
    rows = db.export_readings(fd, td)
    db.close()

    if not rows:
        console.print("No data to export.")
        return

    fieldnames = list(rows[0].keys())

    if output:
        with open(output, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)
        console.print(f"Exported {len(rows)} rows → {output}")
    else:
        buf = io.StringIO()
        writer = csv.DictWriter(buf, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
        sys.stdout.write(buf.getvalue())


@app.command()
def db_info() -> None:
    """Show database info: path, size, row count, date range."""
    settings = Settings()
    db_path = settings.resolved_db_path()
    db = Database(db_path)

    row_count = db.get_row_count()
    first, last = db.get_date_range()
    db.close()

    size_mb = db_path.stat().st_size / (1024 * 1024) if db_path.exists() else 0

    table = Table(title="Database Info")
    table.add_column("Property", style="bold")
    table.add_column("Value")
    table.add_row("Path", str(db_path))
    table.add_row("Size", f"{size_mb:.2f} MB")
    table.add_row("Rows", str(row_count))
    table.add_row("First reading", first or "—")
    table.add_row("Last reading", last or "—")

    console.print(table)
