"""Integration tests for Monopoly cheaters preset behavior."""

from server.games.monopoly.game import MonopolyGame, MonopolyOptions
from server.users.test_user import MockUser


def _create_two_player_game(options: MonopolyOptions | None = None) -> MonopolyGame:
    game = MonopolyGame(options=options or MonopolyOptions())
    host_user = MockUser("Host")
    guest_user = MockUser("Guest")
    game.add_player("Host", host_user)
    game.add_player("Guest", guest_user)
    game.host = "Host"
    return game


def _start_two_player_game(options: MonopolyOptions | None = None) -> MonopolyGame:
    game = _create_two_player_game(options)
    game.on_start()
    return game


def test_cheaters_on_start_initializes_profile_and_engine():
    game = _start_two_player_game(MonopolyOptions(preset_id="cheaters"))
    assert game.cheaters_profile is not None
    assert game.cheaters_engine is not None
    assert game.cheaters_profile.anchor_edition_id == "monopoly-e4888"


def test_cheaters_blocks_end_turn_before_roll_and_applies_penalty():
    game = _start_two_player_game(MonopolyOptions(preset_id="cheaters"))
    host = game.current_player
    assert host is not None
    starting = host.cash

    game.execute_action(host, "end_turn")

    assert game.current_player is host
    assert host.cash < starting
