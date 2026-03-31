# grostat

Growatt inverter data collector. Fetches ~35 telemetry parameters from Growatt inverters via API v4 and stores them in SQLite.

Built for **Growatt 10000 TL3-S** (3-phase, 2 MPPT strings) but should work with other Growatt inverters.

## Install

```bash
brew tap zalun/grostat
brew install grostat
```

## Setup

```bash
grostat init
```

This creates `~/.config/grostat/config.json` and asks for your API token and device serial number.

You can also set them individually:

```bash
grostat token <your-api-token>
grostat device <serial-number>
```

Get your API token from [server.growatt.com](https://server.growatt.com) → Settings → API Management.

## Usage

```bash
grostat collect              # fetch one reading
grostat collect --loop       # continuous collection (every 5 min)
grostat status               # show latest reading
grostat summary              # today's summary
grostat summary 2026-03-21   # specific date
grostat export               # CSV to stdout
grostat export --from 2026-03-01 --to 2026-03-31 --output march.csv
grostat db-info              # database stats
```

## Scheduling

```bash
grostat schedule             # install launchd agent (every 5 min, 6:00-20:00)
grostat schedule --interval 10 --start-hour 5 --end-hour 22
grostat unschedule           # remove launchd agent
```

This installs a macOS launchd agent that survives reboots.

## Collected data

| Category | Fields |
|----------|--------|
| DC Input (panels) | vpv1/2, ipv1/2, ppv1/2, ppv, epv1/2 today/total |
| AC Grid (3-phase) | vacr/s/t (LL + phase), iacr/s/t, pacr/s/t, pac, rac, pf, fac |
| Temperature | inverter, IPM module |
| Energy | today, total, operating hours |
| Diagnostics | status, faults, bus voltages, warnings, power limit % |

## Alerts

Two-tier voltage monitoring:

- **WARNING** ≥ 250V phase voltage
- **CRITICAL** ≥ 253V phase voltage (Polish grid norm exceeded)

Alerts trigger macOS desktop notifications and are logged.

Thresholds are configurable in `~/.config/grostat/config.json`.

## Configuration

`~/.config/grostat/config.json`:

```json
{
  "token": "",
  "device_sn": "",
  "db_path": "~/.local/share/grostat/grostat.db",
  "alert_warning_v": 250.0,
  "alert_critical_v": 253.0,
  "api_base": "https://openapi.growatt.com/v4/new-api",
  "loop_interval_s": 300
}
```

Environment variables (`GROSTAT_TOKEN`, `GROSTAT_DEVICE_SN`, etc.) override config file values.

## Storage

SQLite database at `~/.local/share/grostat/grostat.db` (~35 MB/year at 5-min intervals).

Logs at `~/.local/share/grostat/grostat.log` with automatic rotation (5 MB, 3 rotations).

## License

MIT
