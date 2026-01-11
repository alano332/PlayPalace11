"""
Player dataclass for Pirates of the Lost Seas.

Contains player state including position, score, gems, and references to
the leveling system and skill manager.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import TYPE_CHECKING

from ..base import Player
from .leveling import LevelingSystem

if TYPE_CHECKING:
    from .skills import SkillManager


@dataclass
class PiratesPlayer(Player):
    """
    Player state for Pirates of the Lost Seas.

    Skills are managed via the skill_manager, not as individual variables.
    Leveling is managed via the leveling property tied to this player.
    """

    position: int = 0
    score: int = 0
    gems: list[int] = field(default_factory=list)

    # Leveling system (serialized)
    _leveling: LevelingSystem = field(default=None)  # type: ignore

    # Skill manager (not serialized - rebuilt on load)
    # Note: skill_manager is set after creation since it needs the game reference

    def __post_init__(self):
        """Initialize the leveling system if not set."""
        if self._leveling is None:
            self._leveling = LevelingSystem(user_id=self.id)

    @property
    def leveling(self) -> LevelingSystem:
        """Get the leveling system for this player."""
        return self._leveling

    @property
    def level(self) -> int:
        """Shortcut to get the player's level."""
        return self._leveling.level

    @property
    def xp(self) -> int:
        """Shortcut to get the player's XP."""
        return self._leveling.xp

    def add_gem(self, gem_type: int, gem_value: int) -> None:
        """Add a gem to the player's collection and update score."""
        self.gems.append(gem_type)
        self.score += gem_value

    def remove_gem(self, gem_index: int) -> int | None:
        """Remove and return a gem at the given index, or None if invalid."""
        if 0 <= gem_index < len(self.gems):
            return self.gems.pop(gem_index)
        return None

    def has_gems(self) -> bool:
        """Check if the player has any gems."""
        return len(self.gems) > 0

    def recalculate_score(self, get_gem_value: callable) -> None:
        """Recalculate score from current gems using the provided value function."""
        self.score = sum(get_gem_value(gem) for gem in self.gems)
