"""Inverter reading data model."""

import math
from dataclasses import dataclass, fields
from datetime import datetime

SQRT3 = math.sqrt(3)


def _float(data: dict, key: str) -> float:
    try:
        return float(data.get(key, 0))
    except (TypeError, ValueError):
        return 0.0


def _int(data: dict, key: str) -> int:
    try:
        return int(data.get(key, 0))
    except (TypeError, ValueError):
        return 0


def _ll_to_phase(v_ll: float) -> float:
    """Convert line-to-line voltage to phase voltage (V_LN = V_LL / sqrt(3))."""
    return round(v_ll / SQRT3, 1) if v_ll else 0.0


@dataclass
class InverterReading:
    timestamp: str

    # DC input (panels)
    vpv1: float = 0.0
    vpv2: float = 0.0
    ipv1: float = 0.0
    ipv2: float = 0.0
    ppv1: float = 0.0
    ppv2: float = 0.0
    ppv: float = 0.0
    epv1_today: float = 0.0
    epv2_today: float = 0.0
    epv1_total: float = 0.0
    epv2_total: float = 0.0

    # AC output — line-to-line
    vacr: float = 0.0
    vacs: float = 0.0
    vact: float = 0.0
    # AC output — phase (computed)
    vacr_phase: float = 0.0
    vacs_phase: float = 0.0
    vact_phase: float = 0.0
    # AC output — current
    iacr: float = 0.0
    iacs: float = 0.0
    iact: float = 0.0
    # AC output — power per phase
    pacr: float = 0.0
    pacs: float = 0.0
    pact: float = 0.0
    # AC output — totals
    pac: float = 0.0
    rac: float = 0.0
    pf: float = 0.0
    fac: float = 0.0

    # Temperature
    temperature: float = 0.0
    ipm_temperature: float = 0.0

    # Energy
    power_today: float = 0.0
    power_total: float = 0.0
    time_total: float = 0.0

    # Diagnostics
    status: int = 0
    fault_type: int = 0
    p_bus_voltage: float = 0.0
    n_bus_voltage: float = 0.0
    warn_code: int = 0
    warning_value1: int = 0
    warning_value2: int = 0
    real_op_percent: float = 0.0

    # Computed
    vmax_phase: float = 0.0
    alert: str = ""

    @classmethod
    def from_api_response(cls, data: dict) -> "InverterReading":
        ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        vacr = _float(data, "vacr")
        vacs = _float(data, "vacs")
        vact = _float(data, "vact")
        vacr_phase = _ll_to_phase(vacr)
        vacs_phase = _ll_to_phase(vacs)
        vact_phase = _ll_to_phase(vact)
        vmax_phase = max(vacr_phase, vacs_phase, vact_phase)

        return cls(
            timestamp=ts,
            # DC
            vpv1=_float(data, "vpv1"),
            vpv2=_float(data, "vpv2"),
            ipv1=_float(data, "ipv1"),
            ipv2=_float(data, "ipv2"),
            ppv1=_float(data, "ppv1"),
            ppv2=_float(data, "ppv2"),
            ppv=_float(data, "ppv"),
            epv1_today=_float(data, "epv1Today"),
            epv2_today=_float(data, "epv2Today"),
            epv1_total=_float(data, "epv1Total"),
            epv2_total=_float(data, "epv2Total"),
            # AC — line-to-line
            vacr=vacr,
            vacs=vacs,
            vact=vact,
            # AC — phase
            vacr_phase=vacr_phase,
            vacs_phase=vacs_phase,
            vact_phase=vact_phase,
            # AC — current
            iacr=_float(data, "iacr"),
            iacs=_float(data, "iacs"),
            iact=_float(data, "iact"),
            # AC — power per phase
            pacr=_float(data, "pacr"),
            pacs=_float(data, "pacs"),
            pact=_float(data, "pact"),
            # AC — totals
            pac=_float(data, "pac"),
            rac=_float(data, "rac"),
            pf=_float(data, "pf"),
            fac=_float(data, "fac"),
            # Temperature
            temperature=_float(data, "temperature"),
            ipm_temperature=_float(data, "ipmTemperature"),
            # Energy
            power_today=_float(data, "powerToday"),
            power_total=_float(data, "powerTotal"),
            time_total=_float(data, "timeTotal"),
            # Diagnostics
            status=_int(data, "status"),
            fault_type=_int(data, "faultType"),
            p_bus_voltage=_float(data, "pBusVoltage"),
            n_bus_voltage=_float(data, "nBusVoltage"),
            warn_code=_int(data, "warnCode"),
            warning_value1=_int(data, "warningValue1"),
            warning_value2=_int(data, "warningValue2"),
            real_op_percent=_float(data, "realOPPercent"),
            # Computed
            vmax_phase=vmax_phase,
        )

    def column_names(self) -> list[str]:
        return [f.name for f in fields(self)]

    def values(self) -> list[object]:
        return [getattr(self, f.name) for f in fields(self)]
