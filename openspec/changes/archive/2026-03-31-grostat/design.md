## Context

Istniejący `growatt_monitor.py` to jednofilowy skrypt zbierający dane z falownika Growatt 10000 TL3-S (S/N: NFB8922074) przez API v4. Token jest hardcoded, dane trafiają do CSV, zbierany jest ograniczony podzbiór parametrów. Skrypt działa z crona co 5 minut w godzinach 6–20.

Falownik to 3-fazowy inwerter z 2 stringami MPPT, podłączony do sieci Energa-Operator. Znany problem: napięcie na fazie S przekracza 250–253V, powodując wyłączenia. Monitoring napięć jest kluczowy dla dokumentacji problemu wobec operatora sieci.

## Goals / Non-Goals

**Goals:**
- Instalowalny pakiet Python z pełnym zestawem ~35 parametrów falownika
- SQLite jako storage (query-friendly, zero maintenance)
- Konfiguracja przez `.env` (bezpieczne przechowywanie tokena)
- Dwupoziomowe alerty napięciowe z macOS notifications
- CLI via Typer z komendami: collect, summary, status, export, db-info
- Dystrybucja przez Homebrew tap
- Tooling: uv, ruff, ty

**Non-Goals:**
- Migracja starych danych CSV
- Dashboard / web UI
- Wsparcie wielu falowników jednocześnie
- Integracja z Home Assistant / MQTT
- Automatyczne reakcje na alerty (np. wyłączenie falownika)

## Decisions

### 1. SQLite jako jedyny storage (nie CSV)

**Wybór**: SQLite z jedną tabelą `readings`.

**Alternatywy rozważone**:
- CSV: prostsze, ale trudne query, brak indeksów, ~35 kolumn to za dużo
- PostgreSQL/TimescaleDB: overkill dla jednego urządzenia, wymaga serwera
- InfluxDB: idealny do time-series, ale dodatkowa infrastruktura

**Uzasadnienie**: SQLite jest w stdlib, zero konfiguracji, obsługuje terabajty. ~35 MB/rok to nic. Analityka przez zwykłe SQL.

### 2. pydantic-settings do konfiguracji

**Wybór**: `pydantic-settings` z `SettingsConfigDict(env_file=".env")`.

**Alternatywy rozważone**:
- `python-dotenv` + ręczna walidacja: mniej kodu, ale brak type safety
- `dynaconf`: zbyt rozbudowane
- Czyste `os.environ`: brak walidacji, brak defaults

**Uzasadnienie**: Walidacja typów, `.env` support, defaults, env prefix (`GROSTAT_`) — wszystko out of the box. Jedna zależność, mały footprint.

### 3. Typer + Rich do CLI

**Wybór**: Typer jako CLI framework, Rich do formatowania tabel w `summary` i `status`.

**Uzasadnienie**: Typer daje auto-help, type hints jako parametry, subkomendy. Rich daje ładne tabelki bez wysiłku. Oba to standardowy stack z ekosystemu Astral/modern Python.

### 4. Struktura pakietu — src layout

```
grostat/
├── pyproject.toml
├── .env.example
├── src/
│   └── grostat/
│       ├── __init__.py
│       ├── config.py       # Settings (pydantic-settings)
│       ├── api.py          # GrowattClient — komunikacja z API
│       ├── models.py       # InverterReading dataclass
│       ├── db.py           # Database — SQLite operations
│       ├── alerts.py       # AlertChecker — progi, notifications
│       └── cli.py          # Typer app — entry point
```

**Uzasadnienie**: src layout to standard PEP 621. Podział na moduły: API, modele, storage, alerty, CLI — każdy z jedną odpowiedzialnością.

### 5. Mapowanie pól API → SQLite

Pola z API (`queryLastData`) mapowane bezpośrednio na kolumny SQLite. Nazwy kolumn w snake_case, oryginalne nazwy API jako mapping w `models.py`.

Napięcia przechowywane w obu formach: line-to-line (surowe z API) i fazowe (przeliczone ÷√3). Koszt: 6 dodatkowych REAL — znikomy.

### 6. Alerty — dwa progi

| Próg | Poziom | Akcja |
|------|--------|-------|
| ≥ 250V fazowe | WARNING | log + macOS notification (pierwsze wystąpienie) |
| ≥ 253V fazowe | CRITICAL | log + macOS notification (pierwsze wystąpienie) |

macOS notification: `osascript -e 'display notification "..." with title "grostat"'`. Zero zależności. Na Linux/headless — graceful skip (tylko log).

### 7. Homebrew tap

- Repo: `zalun/homebrew-grostat`
- Formula: Python formula wskazująca na tarball z GitHub release
- Instalacja: `brew tap zalun/grostat && brew install grostat`
- Wymaga: główne repo `zalun/grostat` na GitHubie z tagowanymi releases

## Risks / Trade-offs

**[API rate limiting]** → Growatt API v4 nie dokumentuje limitów. Mitigacja: jedno wywołanie co 5 min to bezpieczny interwał, retry z backoff już zaimplementowany w istniejącym kodzie.

**[Token expiry]** → Nie wiadomo czy token API wygasa. Mitigacja: jasny error message przy 401/403 z instrukcją wygenerowania nowego tokena.

**[macOS notifications z crona]** → Cron może nie mieć uprawnień do wyświetlania notyfikacji. Mitigacja: graceful fallback do samego loga. Użytkownik musi dodać Terminal/cron do System Settings → Notifications.

**[SQLite concurrent writes]** → Przy jednym writerze (cron co 5 min) nie ma problemu. Gdyby ktoś odpytywał DB podczas zapisu — SQLite WAL mode rozwiązuje to automatycznie.

**[Homebrew formula maintenance]** → Przy każdym release trzeba zaktualizować hash w formule. Mitigacja: prosty skrypt release lub GitHub Action.
