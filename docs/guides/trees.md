---
sidebar_position: 2
---

# Trees

Leyr keeps every inserted proxy in an AABB tree used as the broadphase for queries. Two flavors trade off differently depending on how much your geometry moves.

## RaycastDynamic

Built for proxies that move. Insertion picks the sibling that minimizes surface-area cost (the classic dynamic-BVH insertion heuristic), and every `Move` either absorbs the movement into the existing AABB's padding (if the new position still fits inside the padded box) or removes and reinserts the leaf.

```lua
local RC = Leyr.RaycastDynamic.new({ aabb_padding = 0.05 })

RC:Insert(part)
RC:Move(part)             -- re-sync to part.CFrame; cheap if the move is small
RC:UpdateTransform(part)  -- re-sync to part.Size and part.CFrame
```

`aabb_padding` controls how much slack each leaf's AABB carries beyond its tight-fit bounds. Larger padding absorbs more movement without triggering a remove/reinsert, at the cost of looser (and therefore slower) queries.

Each refit optionally runs a local tree rotation (ported from Box2D's dynamic tree) to keep the hierarchy balanced as it changes shape. Over time, heavy churn still degrades query quality — call `Rebuild()` periodically to force a full SAH rebuild:

```lua
RC:Rebuild()
```

## RaycastStatic

Built for a world that doesn't move. `Insert` and `Remove` are cheap — they don't refit anything — but the tree is marked dirty, and the next `Raycast()` call pays for a full rebuild before querying:

```lua
local RC = Leyr.RaycastStatic.new()

RC:Insert(workspace.Terrain1)
RC:Insert(workspace.Terrain2)

RC:Build() -- optional: pay the rebuild cost now instead of on first query
local hit = RC:Raycast(origin, direction)
```

There's no padding and no incremental refit machinery — every rebuild is a from-scratch SAH partition over every leaf currently in the tree.

## Rebuild Strategy

Both flavors use the same surface-area-heuristic (SAH) binned build: leaves are split along the axis with the widest centroid spread, binned into 16 buckets, and partitioned at whichever bucket boundary minimizes total child surface area. This produces a tighter, shallower tree than incremental insertion alone, which is why periodic rebuilds pay for themselves once a dynamic tree has churned enough.

`RaycastDynamic:Rebuild()` performs a **full** rebuild — every leaf is repartitioned. There is no partial-rebuild entry point exposed publicly; `should_rebuild` and `partial_rebuild` exist on the underlying tree object for internal heuristics but aren't part of the public `RaycastDynamic`/`RaycastStatic` surface.

## Choosing Between Them

| | `RaycastDynamic` | `RaycastStatic` |
|---|---|---|
| Proxies move after insert | Yes, incrementally | No — treat as insert-once |
| Rebuild trigger | Manual (`Rebuild()`) | Automatic, lazy, on next query after a change |
| Per-move cost | O(log n) refit, occasional remove/reinsert | N/A |
| Best for | Characters, projectiles, moving props | Terrain, level geometry, anything built once |

Mixed scenes typically want one of each — a `RaycastStatic` tree for the level, and a `RaycastDynamic` tree for everything that moves.
