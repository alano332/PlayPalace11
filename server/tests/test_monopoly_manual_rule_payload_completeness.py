"""Completeness checks for all special-board manual rule payloads."""

import pytest

from server.games.monopoly.board_profile import BOARD_PROFILES, DEFAULT_BOARD_ID
from server.games.monopoly.game import CHANCE_CARD_IDS, COMMUNITY_CHEST_CARD_IDS
from server.games.monopoly.manual_rules.loader import load_manual_rule_set


ALL_SPECIAL_BOARD_IDS = sorted(
    board_id for board_id in BOARD_PROFILES if board_id != DEFAULT_BOARD_ID
)


@pytest.mark.parametrize("board_id", ALL_SPECIAL_BOARD_IDS)
def test_all_special_boards_have_executable_manual_payload(board_id: str):
    rule_set = load_manual_rule_set(board_id)

    spaces = rule_set.board.get("spaces", [])
    chance_rows = rule_set.cards.get("chance", [])
    chest_rows = rule_set.cards.get("community_chest", [])
    mechanics = rule_set.mechanics
    citation_paths = {citation.rule_path for citation in rule_set.citations}

    assert isinstance(spaces, list)
    assert len(spaces) == 40
    assert [row.get("id") for row in chance_rows] == CHANCE_CARD_IDS
    assert [row.get("id") for row in chest_rows] == COMMUNITY_CHEST_CARD_IDS

    assert mechanics.get("mode") != "manual_core_candidate"
    source = mechanics.get("manual_source", {})
    assert isinstance(source, dict)
    assert isinstance(source.get("instruction_url"), str)
    assert source.get("instruction_url")
    assert isinstance(source.get("pdf_url"), str)
    assert source.get("pdf_url")

    assert "mechanics.manual_source" in citation_paths
