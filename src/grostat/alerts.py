"""Two-tier voltage alert system with macOS notifications."""

import logging
import platform
import subprocess

from grostat.config import Settings
from grostat.models import InverterReading

logger = logging.getLogger("grostat")


class AlertChecker:
    def __init__(self, settings: Settings) -> None:
        self.warning_v = settings.alert_warning_v
        self.critical_v = settings.alert_critical_v
        self._is_macos = platform.system() == "Darwin"

    def evaluate(self, reading: InverterReading) -> str:
        """Evaluate reading and return alert level: '', 'WARNING', or 'CRITICAL'."""
        v = reading.vmax_phase

        if v >= self.critical_v:
            level = "CRITICAL"
            logger.critical(
                "CRITICAL: vmax_phase=%.1fV (>= %.1fV) on phases R:%.1f S:%.1f T:%.1f",
                v,
                self.critical_v,
                reading.vacr_phase,
                reading.vacs_phase,
                reading.vact_phase,
            )
            self._notify(
                f"CRITICAL: {v:.1f}V (grid voltage exceeded!)",
                f"R:{reading.vacr_phase}V S:{reading.vacs_phase}V T:{reading.vact_phase}V",
                title="grostat CRITICAL",
            )
        elif v >= self.warning_v:
            level = "WARNING"
            logger.warning(
                "WARNING: vmax_phase=%.1fV (>= %.1fV) on phases R:%.1f S:%.1f T:%.1f",
                v,
                self.warning_v,
                reading.vacr_phase,
                reading.vacs_phase,
                reading.vact_phase,
            )
            self._notify(
                f"WARNING: {v:.1f}V (approaching grid limit)",
                f"R:{reading.vacr_phase}V S:{reading.vacs_phase}V T:{reading.vact_phase}V",
                title="grostat",
            )
        else:
            level = ""

        return level

    def _notify(self, message: str, subtitle: str, title: str = "grostat") -> None:
        if not self._is_macos:
            return
        try:
            script = f'display notification "{message}" with title "{title}" subtitle "{subtitle}"'
            subprocess.run(
                ["osascript", "-e", script],
                capture_output=True,
                timeout=5,
            )
        except Exception:
            pass  # notification is best-effort
