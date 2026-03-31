## ADDED Requirements

### Requirement: Fetch full inverter data from Growatt API
The system SHALL fetch all available parameters from the Growatt API v4 `queryLastData` endpoint for device NFB8922074. The response SHALL be parsed into a typed `InverterReading` model containing the following field groups:

**DC Input (panels):** vpv1, vpv2, ipv1, ipv2, ppv1, ppv2, ppv, epv1Today, epv2Today, epv1Total, epv2Total
**AC Output (grid):** vacr, vacs, vact, iacr, iacs, iact, pacr, pacs, pact, pac, rac, pf, fac
**Temperature:** temperature, ipmTemperature
**Energy:** powerToday, powerTotal, timeTotal
**Diagnostics:** status, faultType, pBusVoltage, nBusVoltage, warnCode, warningValue1, warningValue2, realOPPercent

#### Scenario: Successful data fetch
- **WHEN** the API returns a valid response with `code: 0`
- **THEN** the system SHALL parse all fields into an `InverterReading` with correct types (float for measurements, int for status/codes)

#### Scenario: Missing fields in API response
- **WHEN** the API response omits some fields (e.g., falownik in standby returns zeros)
- **THEN** the system SHALL use 0.0 for missing float fields and 0 for missing int fields

#### Scenario: API error
- **WHEN** the API returns a non-zero code or HTTP error
- **THEN** the system SHALL retry up to 2 times with 10s delay, then log the error and exit with non-zero code

### Requirement: Compute phase voltages from line-to-line
The system SHALL compute phase voltages (V_LN) from line-to-line voltages (V_LL) using the formula `V_phase = V_LL / √3` for all three phases (R, S, T).

#### Scenario: Voltage conversion
- **WHEN** API returns vacr=432.5 (line-to-line)
- **THEN** the system SHALL store both vacr=432.5 and vacr_phase=249.7 (rounded to 1 decimal)

### Requirement: Store readings in SQLite
The system SHALL store each reading as a row in a `readings` table in a SQLite database. The table SHALL have columns for all fields from `InverterReading` plus computed phase voltages, a max phase voltage (`vmax_phase`), and an alert level column.

#### Scenario: First run creates database
- **WHEN** the database file does not exist
- **THEN** the system SHALL create it with the `readings` table and indexes on `timestamp` and `alert`

#### Scenario: Append reading
- **WHEN** a new reading is collected
- **THEN** the system SHALL INSERT a new row with ISO 8601 timestamp and all field values

### Requirement: Single collection invocation for cron
The system SHALL support a single `grostat collect` command suitable for cron execution (*/5 6-20 * * *). Each invocation SHALL fetch one reading, store it, check alerts, and exit.

#### Scenario: Cron invocation
- **WHEN** `grostat collect` is executed
- **THEN** the system SHALL perform exactly one API call, store the result, evaluate alert thresholds, and exit with code 0 on success
