"""
Poker hand evaluator for standard 52-card decks.

Provides helpers for scoring a 5-card hand and selecting the best 5-card hand
from a larger set (e.g., 7 cards in Hold'em).
"""

from __future__ import annotations

from collections import Counter
from itertools import combinations
from typing import Iterable

from .cards import Card, SUIT_NONE

# Hand category ranks (higher is better)
HIGH_CARD = 0
ONE_PAIR = 1
TWO_PAIR = 2
THREE_OF_A_KIND = 3
STRAIGHT = 4
FLUSH = 5
FULL_HOUSE = 6
FOUR_OF_A_KIND = 7
STRAIGHT_FLUSH = 8


def best_hand(cards: list[Card]) -> tuple[tuple[int, tuple[int, ...]], list[Card]]:
    """Return the best 5-card hand score and the chosen 5 cards."""
    if len(cards) < 5:
        raise ValueError("best_hand requires at least 5 cards")

    best_score: tuple[int, tuple[int, ...]] | None = None
    best_five: list[Card] | None = None

    for hand in combinations(cards, 5):
        score = score_5_cards(list(hand))
        if best_score is None or score > best_score:
            best_score = score
            best_five = list(hand)

    # best_score and best_five are always set because len(cards) >= 5
    return best_score, best_five  # type: ignore[return-value]


def score_5_cards(cards: list[Card]) -> tuple[int, tuple[int, ...]]:
    """Score exactly 5 cards. Higher tuples compare as better hands."""
    if len(cards) != 5:
        raise ValueError("score_5_cards requires exactly 5 cards")

    ranks = [_rank_value(card.rank) for card in cards]
    suits = [card.suit for card in cards]

    rank_counts = Counter(ranks)
    counts_sorted = sorted(
        ((count, rank) for rank, count in rank_counts.items()),
        key=lambda x: (x[0], x[1]),
        reverse=True,
    )

    is_flush = _is_flush(suits)
    is_straight, straight_high = _is_straight(ranks)

    if is_straight and is_flush:
        return (STRAIGHT_FLUSH, (straight_high,))

    if counts_sorted[0][0] == 4:
        quad_rank = counts_sorted[0][1]
        kicker = _highest_of_excluding(ranks, {quad_rank})[0]
        return (FOUR_OF_A_KIND, (quad_rank, kicker))

    if counts_sorted[0][0] == 3 and counts_sorted[1][0] == 2:
        trip_rank = counts_sorted[0][1]
        pair_rank = counts_sorted[1][1]
        return (FULL_HOUSE, (trip_rank, pair_rank))

    if is_flush:
        return (FLUSH, tuple(sorted(ranks, reverse=True)))

    if is_straight:
        return (STRAIGHT, (straight_high,))

    if counts_sorted[0][0] == 3:
        trip_rank = counts_sorted[0][1]
        kickers = _highest_of_excluding(ranks, {trip_rank})
        return (THREE_OF_A_KIND, (trip_rank, *kickers))

    if counts_sorted[0][0] == 2 and counts_sorted[1][0] == 2:
        high_pair = max(counts_sorted[0][1], counts_sorted[1][1])
        low_pair = min(counts_sorted[0][1], counts_sorted[1][1])
        kicker = _highest_of_excluding(ranks, {high_pair, low_pair})[0]
        return (TWO_PAIR, (high_pair, low_pair, kicker))

    if counts_sorted[0][0] == 2:
        pair_rank = counts_sorted[0][1]
        kickers = _highest_of_excluding(ranks, {pair_rank})
        return (ONE_PAIR, (pair_rank, *kickers))

    return (HIGH_CARD, tuple(sorted(ranks, reverse=True)))


def _rank_value(rank: int) -> int:
    """Convert Card.rank to standard poker rank (Ace high)."""
    return 14 if rank == 1 else rank


def _is_flush(suits: Iterable[int]) -> bool:
    suit_set = set(suits)
    return len(suit_set) == 1 and next(iter(suit_set)) != SUIT_NONE


def _is_straight(ranks: list[int]) -> tuple[bool, int]:
    unique = sorted(set(ranks), reverse=True)
    if len(unique) != 5:
        return False, 0

    high = unique[0]
    low = unique[-1]
    if high - low == 4:
        return True, high

    # Wheel: A-2-3-4-5 (A counted as 14)
    if unique == [14, 5, 4, 3, 2]:
        return True, 5

    return False, 0


def _highest_of_excluding(ranks: list[int], excluded: set[int]) -> list[int]:
    remaining = [r for r in ranks if r not in excluded]
    return sorted(remaining, reverse=True)
