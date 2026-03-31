## Why

Istniejący `growatt_monitor.py` jest jednofilowym skryptem z hardcoded tokenem API i ograniczonym zestawem zbieranych danych (tylko napięcia AC i energia). Brakuje danych DC z paneli (vpv, ipv, ppv per string), mocy per faza (pacr/pacs/pact), temperatur, diagnostyki i wielu pól energetycznych. Dane trafiają do CSV, co utrudnia query i analizy. Skrypt nie jest instalowalny — trzeba go kopiować ręcznie.

Potrzebny jest porządny, instalowalny pakiet Python (`grostat`) zbierający pełny zestaw ~35 parametrów falownika Growatt 10000 TL3-S do SQLite, z konfiguracją przez `.env`, dwupoziomowymi alertami napięciowymi (WARNING ≥250V, CRITICAL ≥253V) i powiadomieniami macOS. Dystrybucja przez Homebrew tap.

## What Changes

- **Nowy pakiet Python** `grostat` z `pyproject.toml` (uv, ruff, ty)
- **SQLite storage** zamiast CSV (~35 MB/rok przy */5 min 6-20)
- **Pełny zestaw danych**: DC input (vpv1/2, ipv1/2, ppv1/2, ppv, epv*), AC output (vac*, iac*, pac* per faza), temperatura (temperature, ipmTemperature), energia (powerToday/Total, timeTotal), diagnostyka (pBusVoltage, nBusVoltage, warnCode, warningValue*, faultType, realOPPercent)
- **Konfiguracja** przez `.env` + `pydantic-settings` (token, device SN, db path, alert thresholds)
- **CLI via Typer**: `grostat collect`, `grostat summary [DATE]`, `grostat status`, `grostat export`, `grostat db-info`
- **Dwupoziomowe alerty**: WARNING ≥250V fazowe, CRITICAL ≥253V fazowe (norma polska)
- **macOS notifications** przy pierwszym alercie w sesji (`osascript`)
- **Homebrew tap** (`zalun/homebrew-grostat`) do instalacji na dowolnej maszynie
- **BREAKING**: stary `growatt_monitor.py` zastąpiony nowym pakietem; stare CSV nie są migrowane

## Capabilities

### New Capabilities
- `data-collection`: Pobieranie pełnego zestawu ~35 parametrów z Growatt API v4 (queryLastData) i zapis do SQLite
- `alert-system`: Dwupoziomowe alerty napięciowe (WARNING ≥250V, CRITICAL ≥253V) z logowaniem i macOS notifications
- `cli`: Interfejs Typer z komendami collect, summary, status, export, db-info
- `configuration`: Zarządzanie konfiguracją przez .env + pydantic-settings z walidacją
- `distribution`: Pakowanie jako instalowany pakiet Python z Homebrew tap

### Modified Capabilities
<!-- brak istniejących specs -->

## Impact

- **Nowe zależności**: requests, typer, pydantic-settings, rich (opcjonalnie do tabel w CLI)
- **Tooling**: uv (package manager), ruff (linter/formatter), ty (type checker)
- **Zewnętrzne repo**: `zalun/homebrew-grostat` (Homebrew tap formula)
- **Cron**: zmiana wywołania z `python3 growatt_monitor.py` na `grostat collect`
- **Stare dane**: CSV zostają nietknięte, nowy system zaczyna od zera w SQLite
