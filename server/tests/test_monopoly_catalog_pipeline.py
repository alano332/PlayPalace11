"""Tests for Monopoly catalog ingestion and normalization pipeline."""

from server.games.monopoly.catalog.models import RawInstructionRecord, CanonicalEdition


def test_model_defaults_are_serializable():
    """Raw records can be transformed into canonical editions."""
    raw = RawInstructionRecord(
        locale="en-us",
        instruction_url=(
            "https://instructions.hasbro.com/en-us/instruction/"
            "monopoly-game-cheaters-edition"
        ),
        sku="E1871",
        slug="monopoly-game-cheaters-edition",
        name="Monopoly Game: Cheaters Edition",
        brand="Monopoly",
        manuals=[],
    )

    edition = CanonicalEdition.from_raw(raw)

    assert edition.sku == "E1871"
    assert edition.edition_id.startswith("monopoly-")
