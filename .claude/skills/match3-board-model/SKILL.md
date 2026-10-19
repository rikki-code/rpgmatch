---
name: match3-board-model
description: >
  Board model of the match-3 engine: BoardGraph/GridCell/CellKind as a graph,
  not an array, and the gravity rule around pits. Use when touching board
  generation, gravity, or cell adjacency in this match-3 project.
---

## Board is a graph, not an array

`BoardGraph` stores cells (`GridCell`) by coordinate, but adjacency is explicit
`GridCell.neighbors[direction]` refs, not index arithmetic on an array. The default generator builds
a rectangular 4-neighbor grid (UP/DOWN/LEFT/RIGHT, `core/board/grid_direction.gd`), but links can be
rewritten at runtime — the future basis for portals (a non-adjacent cell as "neighbor"), segment
rotation, conveyors. Algorithms (`MatchFinder`, gravity) only ever walk `neighbors` and know nothing
about geometry.

Runtime topology changes already happen — the in-game world editor
(`.claude/skills/match3-world-editor/SKILL.md`) adds/removes cells via `BoardGraph.add_cell`/
`remove_cell` and re-calls `link_grid_neighbors()`. Because of that, `link_grid_neighbors()`
unconditionally overwrites `cell.neighbors[dir]` (even to `null`), not only when a neighbor exists —
otherwise a removed cell's neighbor would keep a dangling ref to it. `remove_cell(pos)` is a full
removal from the graph (a hole, like a board edge — not `PitCellKind`, see below), taking its occupant
with it.

## CellKind — polymorphism, not enum

`CellKind` is a base class with virtual hooks, not an enum with `if`.
- `NormalCellKind` — ordinary cell.
- `PitCellKind` (pit) — just `can_hold_tile() -> false`, nothing else.

## Pit rule (simple: a pit is just an ordinary segment boundary)

A pit splits a physical column into independent segments exactly like a board edge or a hole in a
non-rectangular board — **it has no other special behavior**, no cell anywhere gets "pinned".

- The segment **above** a pit falls and rests on it like a floor — exactly as if the board edge were
  right below. If a tile directly above a pit is destroyed, the whole segment above compacts down to
  it as usual, nothing is fixed in place.
- The segment **below** a pit spawns new tiles from the top exactly like a segment resting against the
  board's top edge — its spawn source is just the pit instead of the sky above the board.

`EffectGravityColumn`'s implementation is identical to any other segment — no separate "pinned"
mechanism exists:
1. A column is cut into segments (`_segments`) at boundaries: a pit or a hole in a non-rectangular
   board. Both sides of a pit are ordinary segments, indistinguishable from any other.
2. Each segment compacts independently (tiles fall to the segment's bottom, `EffectSpawnTile` fills
   remaining gaps at the top) — segments don't affect each other.

(An earlier version tried to "pin"/freeze the cell above a pit — turned out unnecessary and buggy: a
cell directly above a pit shouldn't differ from any other cell in its segment.)

## Generation

`WorldGenParams` — params (Resource): size, color count, pit count/density, seed, `allow_enemies`,
`allow_penalties`, `difficulty`. `BoardGenerator` builds the graph and places tiles avoiding any
starting matches ≥3. Details — `.claude/skills/match3-worldgen/SKILL.md`.
