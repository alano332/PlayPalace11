"""Tests for manual-rule deck initialization and fallback behavior."""

from server.games.monopoly.game import CHANCE_CARD_IDS, MonopolyGame, MonopolyOptions
from server.games.monopoly.manual_rules.models import ManualRuleSet
from server.users.test_user import MockUser


def _manual_rules_with_decks(board_id: str) -> ManualRuleSet:
    return ManualRuleSet.from_dict(
        {
            "board_id": board_id,
            "anchor_edition_id": "monopoly-e1870",
            "board": {"spaces": [{"position": 0, "space_id": "go", "name": "GO", "kind": "start"}]},
            "economy": {"properties": {}},
            "cards": {
                "chance": [{"id": "mk_card_1"}, {"id": "mk_card_2"}],
                "community_chest": [{"id": "mk_cc_1"}],
            },
            "mechanics": {},
            "win_condition": {"type": "bankruptcy"},
            "citations": [
                {
                    "rule_path": "cards.chance",
                    "edition_id": "monopoly-e1870",
                    "page_ref": "p.7",
                    "confidence": "high",
                }
            ],
        }
    )


def _start_game(board_id: str) -> MonopolyGame:
    game = MonopolyGame(
        options=MonopolyOptions(
            preset_id="classic_standard",
            board_id=board_id,
            board_rules_mode="auto",
        )
    )
    game.add_player("Host", MockUser("Host"))
    game.add_player("Guest", MockUser("Guest"))
    game.host = "Host"
    game.on_start()
    return game


def test_manual_rule_decks_replace_classic_deck_ids(monkeypatch):
    monkeypatch.setattr(
        "server.games.monopoly.game.load_manual_rule_set",
        lambda board_id: _manual_rules_with_decks(board_id),
    )

    game = _start_game("mario_kart")

    assert game.chance_deck_order == ["mk_card_1", "mk_card_2"]
    assert game.community_chest_deck_order == ["mk_cc_1"]


def test_missing_manual_rule_decks_fall_back_to_classic_ids():
    game = _start_game("mario_kart")

    assert sorted(game.chance_deck_order) == sorted(CHANCE_CARD_IDS)
