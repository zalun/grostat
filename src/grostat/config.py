"""Configuration via ~/.config/grostat/config.json and environment variables."""

import json
from pathlib import Path
from typing import Any

from pydantic_settings import BaseSettings, PydanticBaseSettingsSource, SettingsConfigDict
from pydantic_settings.main import JsonConfigSettingsSource

CONFIG_DIR = Path("~/.config/grostat").expanduser()
CONFIG_FILE = CONFIG_DIR / "config.json"

DEFAULT_CONFIG = {
    "token": "",
    "device_sn": "NFB8922074",
    "db_path": "~/.local/share/grostat/grostat.db",
    "alert_warning_v": 250.0,
    "alert_critical_v": 253.0,
    "api_base": "https://openapi.growatt.com/v4/new-api",
    "loop_interval_s": 300,
}


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="GROSTAT_",
        json_file=str(CONFIG_FILE),
        json_file_encoding="utf-8",
    )

    token: str = ""
    device_sn: str = "NFB8922074"
    db_path: Path = Path("~/.local/share/grostat/grostat.db")
    alert_warning_v: float = 250.0
    alert_critical_v: float = 253.0
    api_base: str = "https://openapi.growatt.com/v4/new-api"
    loop_interval_s: int = 300

    @classmethod
    def settings_customise_sources(
        cls,
        settings_cls: type["Settings"],
        init_settings: PydanticBaseSettingsSource,
        env_settings: PydanticBaseSettingsSource,
        dotenv_settings: PydanticBaseSettingsSource,
        file_secret_settings: PydanticBaseSettingsSource,
        **kwargs: Any,
    ) -> tuple[PydanticBaseSettingsSource, ...]:
        return (
            init_settings,
            env_settings,
            JsonConfigSettingsSource(settings_cls),
            file_secret_settings,
        )

    def resolved_db_path(self) -> Path:
        """Return expanded db_path, creating parent directories if needed."""
        path = self.db_path.expanduser()
        path.parent.mkdir(parents=True, exist_ok=True)
        return path


def init_config() -> Path:
    """Create default config file. Returns path to created file."""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_FILE.write_text(
        json.dumps(DEFAULT_CONFIG, indent=2) + "\n",
        encoding="utf-8",
    )
    return CONFIG_FILE
