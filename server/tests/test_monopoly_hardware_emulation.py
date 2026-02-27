"""Tests for Monopoly hardware/sound emulation framework."""

from server.games.monopoly.hardware_emulation import (
    HardwareEvent,
    resolve_hardware_event,
)


def test_hardware_event_is_inert_when_sound_mode_none():
    event = HardwareEvent(
        board_id="star_wars_mandalorian",
        event_id="play_theme",
        payload={},
    )

    result = resolve_hardware_event(event, sound_mode="none")

    assert result.status == "ignored"
    assert result.sound_asset == ""


def test_hardware_event_is_emulatable_when_sound_mode_emulated():
    event = HardwareEvent(
        board_id="star_wars_mandalorian",
        event_id="play_theme",
        payload={},
    )

    result = resolve_hardware_event(event, sound_mode="emulated")

    assert result.status == "emulated"
    assert result.sound_asset == "game_monopoly_hardware/play_theme_placeholder.ogg"


def test_junior_coin_sound_event_is_emulatable_when_sound_mode_emulated():
    event = HardwareEvent(
        board_id="junior_super_mario",
        event_id="junior_coin_sound_powerup",
        payload={"power_up_die": 4, "outcome": "collect_2"},
    )

    result = resolve_hardware_event(event, sound_mode="emulated")

    assert result.status == "emulated"
    assert result.details == "junior_coin_sound_powerup"
    assert result.sound_asset == "game_monopoly_hardware/junior_coin_sound_placeholder.ogg"


def test_hardware_event_excludes_pacman_game_unit_emulation():
    event = HardwareEvent(
        board_id="pacman",
        event_id="unit_signal",
        payload={},
    )

    result = resolve_hardware_event(event, sound_mode="emulated")

    assert result.status == "ignored"
    assert result.sound_asset == ""
