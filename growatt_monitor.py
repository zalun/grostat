#!/usr/bin/env python3
"""
Monitor napięcia i mocy falownika Growatt NFB8922074
Odpytuje API Growatt co 5 minut i loguje dane do CSV.
Flaguje gdy napięcie fazowe > 250V (zbliża się do progu wyłączenia ~253V).

Użycie:
    python growatt_monitor.py                          # pojedynczy pomiar
    python growatt_monitor.py --output-dir /dane/pv    # pomiar, zapis do podanego katalogu
    python growatt_monitor.py --loop                   # ciągły monitoring co 5 min
    python growatt_monitor.py --summary                # podsumowanie dzisiejszych danych
    python growatt_monitor.py --summary 2026-03-21     # podsumowanie wybranego dnia
    python growatt_monitor.py --faults                 # info o fault logach

Przykład cron (co 5 min, 6:00-20:00):
    */5 6-20 * * * /usr/bin/python3 /home/pi/growatt_monitor.py --output-dir /home/pi/dane_growatt
"""

import argparse
import requests
import csv
import os
import sys
import math
import json
import time
import logging
from datetime import datetime, date
from pathlib import Path

# ── Konfiguracja ──────────────────────────────────────────────────

TOKEN = "irh75uiiqlxl03j989ss3hpcz010vy14"
DEVICE_SN = "NFB8922074"
API_BASE = "https://openapi.growatt.com/v4/new-api"

ALERT_THRESHOLD_V = 250.0   # fazowe [V] — alarm powyżej tej wartości
LOOP_INTERVAL_S = 300        # 5 minut między pomiarami
SQRT3 = math.sqrt(3)

# ── Katalog danych (ustawiany przez --output-dir lub domyślnie) ──

DATA_DIR = None  # ustawiane w _init_data_dir()

def _init_data_dir(output_dir=None):
    """Ustaw katalog danych. Priorytet: --output-dir > domyślnie obok skryptu."""
    global DATA_DIR
    if output_dir:
        DATA_DIR = Path(output_dir)
    else:
        DATA_DIR = Path(__file__).parent / "dane_growatt"
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    _init_logging()

# ── Logging ───────────────────────────────────────────────────────

logger = logging.getLogger("growatt")

def _init_logging():
    """Konfiguruj logging po ustaleniu DATA_DIR."""
    logger.setLevel(logging.INFO)
    # Wyczyść stare handlery (przy ponownym wywołaniu)
    logger.handlers.clear()

    # Konsola
    ch = logging.StreamHandler()
    ch.setFormatter(logging.Formatter("%(asctime)s %(levelname)s  %(message)s", datefmt="%H:%M:%S"))
    logger.addHandler(ch)

    # Plik
    log_file = DATA_DIR / "growatt_monitor.log"
    fh = logging.FileHandler(log_file, encoding="utf-8")
    fh.setFormatter(logging.Formatter("%(asctime)s %(levelname)s  %(message)s"))
    logger.addHandler(fh)

# ── Nazwy plików CSV ─────────────────────────────────────────────

CSV_FIELDS = [
    "timestamp", "status", "faultType",
    "vacr_ll", "vacs_ll", "vact_ll",
    "vacr_phase", "vacs_phase", "vact_phase", "vmax_phase",
    "pac_W", "rac_W", "pf", "fac_Hz",
    "eToday_kWh", "eTotal_kWh",
    "alert",
]

FAULT_FIELDS = [
    "timestamp_downloaded", "fault_time", "fault_code", "fault_description",
]


def csv_path_for_month(prefix="voltages", dt=None):
    """Zwraca ścieżkę CSV: dane_growatt/voltages_2026-03.csv"""
    dt = dt or date.today()
    return DATA_DIR / f"{prefix}_{dt.strftime('%Y-%m')}.csv"


def fault_csv_path(dt=None):
    return csv_path_for_month("faults", dt)


# ── Konwersje ─────────────────────────────────────────────────────

def ll_to_phase(v_ll):
    """Przelicz napięcie między fazami na fazowe (V_LN = V_LL / √3)"""
    try:
        return round(float(v_ll) / SQRT3, 1)
    except (TypeError, ValueError):
        return 0.0


# ── API ───────────────────────────────────────────────────────────

def _api_call(endpoint, extra_data=None, retries=2):
    """Wywołaj endpoint Growatt API z obsługą retry."""
    url = f"{API_BASE}/{endpoint}"
    headers = {"token": TOKEN}
    data = {"deviceType": "inv", "deviceSn": DEVICE_SN}
    if extra_data:
        data.update(extra_data)

    for attempt in range(retries + 1):
        try:
            r = requests.post(url, headers=headers, data=data, timeout=15)
            r.raise_for_status()
            j = r.json()
            if j.get("code") != 0:
                raise ValueError(f"API error (code={j.get('code')}): {j.get('msg', j)}")
            return j.get("data", j)
        except requests.RequestException as e:
            if attempt < retries:
                logger.warning(f"  Próba {attempt+1} nie powiodła się: {e}. Ponawiam za 10s...")
                time.sleep(10)
            else:
                raise


def fetch_last_data():
    """Pobierz ostatni odczyt z falownika."""
    data = _api_call("queryLastData")
    inv_list = data.get("inv", [])
    if not inv_list:
        raise ValueError("Brak danych w odpowiedzi API (pusta lista inv)")
    return inv_list[0]


def fetch_fault_log():
    """
    Fault log NIE jest dostępny przez API v4 (endpoint queryFault nie istnieje).
    Fault logi można pobrać ręcznie z portalu: https://server.growatt.com
    lub przez starsze API (login/hasło zamiast tokena).
    """
    logger.info("Fault log nie jest dostępny przez API v4 (token).")
    logger.info("Użyj portalu server.growatt.com → Inverter → Fault Log")
    return None


# ── Zapis CSV ─────────────────────────────────────────────────────

def _append_csv(filepath, fieldnames, row):
    """Dopisz wiersz do CSV, tworząc nagłówek jeśli plik nie istnieje."""
    write_header = not filepath.exists()
    with open(filepath, "a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        if write_header:
            writer.writeheader()
        writer.writerow(row)


def log_measurement(row):
    """Zapisz pomiar do miesięcznego CSV."""
    _append_csv(csv_path_for_month(), CSV_FIELDS, row)


def log_faults(faults):
    """Zapisz fault logi do CSV."""
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    path = fault_csv_path()
    for f in faults:
        _append_csv(path, FAULT_FIELDS, {
            "timestamp_downloaded": ts,
            "fault_time": f.get("time", f.get("faultTime", "")),
            "fault_code": f.get("eventId", f.get("faultCode", "")),
            "fault_description": f.get("eventName", f.get("faultDesc", "")),
        })
    logger.info(f"Zapisano {len(faults)} fault(ów) → {path.name}")


# ── Główna logika pomiaru ────────────────────────────────────────

def run_once():
    """Wykonaj pojedynczy pomiar i zapisz."""
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    try:
        d = fetch_last_data()
    except Exception as e:
        logger.error(f"BŁĄD pobierania danych: {e}")
        return None

    # Napięcia line-to-line → fazowe
    vacr_ll = d.get("vacr", 0)
    vacs_ll = d.get("vacs", 0)
    vact_ll = d.get("vact", 0)
    vacr = ll_to_phase(vacr_ll)
    vacs = ll_to_phase(vacs_ll)
    vact = ll_to_phase(vact_ll)

    pac   = d.get("pac", 0)        # moc czynna [W]
    rac   = d.get("rac", 0)        # moc bierna [W]
    pf    = d.get("pf", 0)         # power factor
    fac   = d.get("fac", 0)        # częstotliwość [Hz]
    status = d.get("status", -1)   # 0=wait, 1=normal, 3=fault
    fault  = d.get("faultType", 0)

    # Energia
    e_today = d.get("eToday", d.get("etoday", 0))
    e_total = d.get("eTotal", d.get("etotal", 0))

    v_max = max(vacr, vacs, vact)
    alert = "ALARM" if v_max >= ALERT_THRESHOLD_V else ""

    row = {
        "timestamp": ts,
        "status": status,
        "faultType": fault,
        "vacr_ll": vacr_ll,
        "vacs_ll": vacs_ll,
        "vact_ll": vact_ll,
        "vacr_phase": vacr,
        "vacs_phase": vacs,
        "vact_phase": vact,
        "vmax_phase": v_max,
        "pac_W": pac,
        "rac_W": rac,
        "pf": pf,
        "fac_Hz": fac,
        "eToday_kWh": e_today,
        "eTotal_kWh": e_total,
        "alert": alert,
    }

    log_measurement(row)

    status_txt = {0: "WAIT", 1: "OK", 3: "FAULT"}.get(status, f"?{status}")
    msg = (
        f"{status_txt} | R:{vacr}V S:{vacs}V T:{vact}V (max={v_max}V) | "
        f"PAC={pac}W RAC={rac}W PF={pf} | E_today={e_today}kWh"
    )
    if alert:
        logger.warning(f"⚠️  {msg}")
    else:
        logger.info(msg)

    return row


# ── Podsumowanie dzienne ──────────────────────────────────────────

def daily_summary(target_date=None):
    """Wyświetl podsumowanie danych z danego dnia."""
    target = target_date or date.today()
    target_str = target.strftime("%Y-%m-%d")
    csv_file = csv_path_for_month(dt=target)

    if not csv_file.exists():
        # Sprawdź stary plik (bez rotacji)
        old_file = Path(__file__).parent / "growatt_voltage_log.csv"
        if old_file.exists():
            csv_file = old_file
        else:
            logger.info(f"Brak danych za {target_str}")
            return

    rows = []
    with open(csv_file, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for r in reader:
            if r["timestamp"].startswith(target_str):
                rows.append(r)

    if not rows:
        logger.info(f"Brak pomiarów za {target_str}")
        return

    vmax_all = max(float(r["vmax_phase"]) for r in rows)
    pac_max = max(float(r["pac_W"]) for r in rows)
    alarms = sum(1 for r in rows if r.get("alert"))
    faults = sum(1 for r in rows if str(r.get("status")) == "3")

    # Energia — ostatni odczyt dnia
    e_today_vals = [float(r.get("eToday_kWh", 0)) for r in rows if r.get("eToday_kWh")]
    e_today = max(e_today_vals) if e_today_vals else 0

    # Napięcia fazowe — statystyki fazy S (najwyższa)
    vacs_vals = [float(r["vacs_phase"]) for r in rows if float(r["vacs_phase"]) > 0]
    vacs_avg = sum(vacs_vals) / len(vacs_vals) if vacs_vals else 0

    print(f"\n{'='*55}")
    print(f"  PODSUMOWANIE  {target_str}  ({len(rows)} pomiarów)")
    print(f"{'='*55}")
    print(f"  Vmax fazowe:     {vmax_all:.1f} V")
    print(f"  Vacs (S) śred.:  {vacs_avg:.1f} V")
    print(f"  PAC max:         {pac_max:.0f} W")
    print(f"  Energia dziś:    {e_today:.1f} kWh")
    print(f"  Alarmy (>250V):  {alarms}")
    print(f"  Faults:          {faults}")
    print(f"{'='*55}\n")


# ── Tryb ciągły ───────────────────────────────────────────────────

def run_loop():
    """Ciągły monitoring co LOOP_INTERVAL_S sekund."""
    logger.info(f"Start ciągłego monitoringu (co {LOOP_INTERVAL_S//60} min). Ctrl+C aby zatrzymać.")
    while True:
        try:
            run_once()
        except KeyboardInterrupt:
            logger.info("Zatrzymano przez użytkownika.")
            break
        except Exception as e:
            logger.error(f"Nieoczekiwany błąd: {e}")

        try:
            time.sleep(LOOP_INTERVAL_S)
        except KeyboardInterrupt:
            logger.info("Zatrzymano przez użytkownika.")
            break


# ── CLI ───────────────────────────────────────────────────────────

def parse_args():
    parser = argparse.ArgumentParser(
        description="Monitor falownika Growatt NFB8922074",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Przykład cron:\n  */5 6-20 * * * python3 growatt_monitor.py --output-dir /home/pi/dane_growatt",
    )
    parser.add_argument(
        "--output-dir", "-o",
        help="Katalog zapisu danych CSV i logów (domyślnie: dane_growatt/ obok skryptu)",
    )

    sub = parser.add_subparsers(dest="command")
    sub.add_parser("loop", help="Ciągły monitoring co 5 min")
    sum_p = sub.add_parser("summary", help="Podsumowanie dnia")
    sum_p.add_argument("date", nargs="?", help="Data YYYY-MM-DD (domyślnie: dziś)")
    sub.add_parser("faults", help="Info o fault logach")

    return parser.parse_args()


def main():
    args = parse_args()
    _init_data_dir(args.output_dir)

    if args.command == "loop":
        run_loop()
    elif args.command == "summary":
        target = None
        if args.date:
            target = datetime.strptime(args.date, "%Y-%m-%d").date()
        daily_summary(target)
    elif args.command == "faults":
        fetch_fault_log()
    else:
        # Domyślnie: pojedynczy pomiar
        run_once()


if __name__ == "__main__":
    main()
