"""Hardware/sound emulation helpers for special board features."""

from __future__ import annotations

from dataclasses import dataclass

SUPPORTED_EVENT_IDS = {
    "play_theme",
    "star_wars_theme",
    "junior_coin_sound_powerup",
}

HARDWARE_EVENT_SOUND_ASSETS = {
    "play_theme": "game_monopoly_hardware/play_theme_placeholder.ogg",
    "star_wars_theme": "game_monopoly_hardware/star_wars_theme_placeholder.ogg",
    "junior_coin_sound_powerup": "game_monopoly_hardware/junior_coin_sound_placeholder.ogg",
}


@dataclass(frozen=True)
class HardwareEvent:
    """Normalized hardware event emitted by board runtime."""

    board_id: str
    event_id: str
    payload: dict[str, object]


@dataclass(frozen=True)
class HardwareResult:
    """Resolution result for one hardware event."""

    status: str
    details: str = ""
    sound_asset: str = ""


def resolve_hardware_event(event: HardwareEvent, sound_mode: str) -> HardwareResult:
    """Resolve one hardware event according to active sound mode."""
    if sound_mode != "emulated":
        return HardwareResult(status="ignored", details="sound_mode_disabled")

    # Explicit product-scope exclusion: Pac-Man game-unit behavior is out-of-scope.
    if event.board_id == "pacman":
        return HardwareResult(status="ignored", details="pacman_excluded")

    if event.event_id not in SUPPORTED_EVENT_IDS:
        return HardwareResult(status="ignored", details="unsupported_event")

    return HardwareResult(
        status="emulated",
        details=event.event_id,
        sound_asset=HARDWARE_EVENT_SOUND_ASSETS.get(event.event_id, ""),
    )
