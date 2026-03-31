"""Growatt API v4 client."""

import logging
import time

import requests

from grostat.config import Settings
from grostat.models import InverterReading

logger = logging.getLogger("grostat")


class GrowattClient:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def fetch_last_data(self) -> InverterReading:
        """Fetch latest inverter reading from Growatt API."""
        data = self._api_call("queryLastData")
        inv_list = data.get("inv", [])
        if not inv_list:
            raise ValueError("Empty inv list in API response")
        return InverterReading.from_api_response(inv_list[0])

    def _api_call(self, endpoint: str, retries: int = 2) -> dict:
        url = f"{self.settings.api_base}/{endpoint}"
        headers = {"token": self.settings.token}
        data = {"deviceType": "inv", "deviceSn": self.settings.device_sn}

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
                    logger.warning("Attempt %d failed: %s. Retrying in 10s...", attempt + 1, e)
                    time.sleep(10)
                else:
                    raise
        raise RuntimeError("Unreachable")
