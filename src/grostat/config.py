"""Configuration via environment variables and .env file."""

from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="GROSTAT_",
        env_file=".env",
        env_file_encoding="utf-8",
    )

    token: str = ""
    device_sn: str = "NFB8922074"
    db_path: Path = Path("~/.local/share/grostat/grostat.db")
    alert_warning_v: float = 250.0
    alert_critical_v: float = 253.0
    api_base: str = "https://openapi.growatt.com/v4/new-api"
    loop_interval_s: int = 300

    def resolved_db_path(self) -> Path:
        """Return expanded db_path, creating parent directories if needed."""
        path = self.db_path.expanduser()
        path.parent.mkdir(parents=True, exist_ok=True)
        return path
