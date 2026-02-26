"""Tests for Monopoly board rules registry."""

from server.games.monopoly.board_rules_registry import (
    get_rule_pack,
    supports_capability,
)


def test_wave1_mario_packs_are_registered():
    assert get_rule_pack("mario_kart") is not None
    assert get_rule_pack("mario_movie") is not None


def test_capability_lookup_handles_missing_pack():
    assert supports_capability("missing", "pass_go_credit") is False
