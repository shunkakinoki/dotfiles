import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_managed_codex_configs_disable_startup_update_prompts() -> None:
    for name in ("config.toml", "config.tpl.toml"):
        config = tomllib.loads((ROOT / "config/codex" / name).read_text())
        assert config["check_for_update_on_startup"] is False
