---
sidebar_position: 3
---

# Performance

## The Fused Traversal

`Raycast` doesn't collect broadphase candidates and then narrow-phase test them as a separate pass. It runs a single distance-ordered traversal: children are visited nearest-entry-first, and any subtree whose AABB entry point lies beyond the closest confirmed surface hit is pruned without ever being loaded.

This matters because a shape always lies inside its own AABB — so its surface hit distance is always greater than or equal to its AABB's entry distance. Once a real hit is found at distance `t`, every unvisited node whose AABB entry is farther than `t` can be safely skipped; it cannot contain anything closer. On dense scenes, this cuts node visits substantially compared to a flat collect-then-test query.

Padding (from `RaycastDynamic`'s `aabb_padding`) only ever enlarges AABBs, which can only shrink their entry distance — so pruning under padding is conservative. It may prune less than it could, but it never prunes a closer hit by mistake.

## Cached Child AABBs

Internal tree nodes cache copies of both children's AABBs (`c1_min`/`c1_max`/`c2_min`/`c2_max`) directly on the parent, rather than requiring the traversal to load each child node just to read its bounds. A visited internal node costs one table read to slab-test both children, instead of three separate node loads. Only nodes that pass their parent's cached test are ever pushed onto the traversal stack.

## Allocation-Free Traversal

The traversal stack for `Raycast` (`query_nearest`) is a pair of module-level scratch arrays, reused across calls instead of allocated per query. The individual per-shape ray tests (`ray_box`, `ray_sphere`, etc.) hold no shared mutable state, so they're safe to call concurrently — including from multiple threads under Parallel Luau / `task.desynchronize()`. Only the final result table, on an actual hit, is a fresh allocation.

## Dynamic Tree Quality Over Time

`RaycastDynamic` inserts and moves are incremental — cheap individually, but they loosen the tree's balance over time. A loosened tree means looser AABBs at every level, which means more nodes get visited (and fewer get pruned) per query. If your scene has heavy movement or insertion churn, call `Rebuild()` periodically:

```lua
RC:Rebuild()
```

This performs a full SAH rebuild — the same binned partition used to build a fresh `RaycastStatic` tree — restoring tight bounds and query quality. There's no single right interval; profile your own scene. A scene with occasional single-object movement rarely needs it, while one with hundreds of proxies moving every frame likely benefits from a rebuild once per second or once per frame during heavy movement.

## Static Trees Avoid the Problem Entirely

`RaycastStatic` sidesteps refit degradation by never refitting — it rebuilds from scratch, lazily, on the first query after any change. For geometry that's inserted once and never moves, this is strictly cheaper than paying incremental-refit overhead it doesn't need.

## Benchmark Numbers

Measured in Roblox Studio (not a live server — real numbers will vary by device and load). Single-shape microbenchmark, `engine:Raycast(origin, direction)` vs native `workspace:Raycast`, averaged in microseconds per ray:

| Shape | Static (µs) | Dynamic (µs) | Native (µs) | Static speedup | Dynamic speedup |
|---|---:|---:|---:|---:|---:|
| Ball | 0.546 | 0.502 | 3.720 | 6.8× | 7.4× |
| Block | 0.794 | 0.815 | 2.983 | 3.8× | 3.7× |
| Cylinder | 0.732 | 0.726 | 3.054 | 4.2× | 4.2× |
| Wedge | 0.986 | 0.867 | 3.411 | 3.5× | 3.9× |
| CornerWedge | 0.757 | 0.808 | 3.004 | 4.0× | 3.7× |

Scaling test — N parts inserted, rays cast across the crowd, average cost per ray:

| N | Static (µs) | Dynamic (µs) | Native (µs) | Static speedup |
|---:|---:|---:|---:|---:|
| 100 | 2.460 | 2.517 | 3.936 | 1.6× |
| 1,000 | 7.117 | 7.515 | 10.221 | 1.4× |
| 5,000 | 13.654 | 15.894 | 22.079 | 1.6× |
| 10,000 | 18.344 | 21.448 | 26.611 | 1.5× |

Static and dynamic trees track each other closely at every scale — the dynamic tree's incremental-insert overhead doesn't show up as a meaningful query-time cost in these runs. The margin over native narrows as scene size grows (more candidate proxies per ray means more narrow-phase tests regardless of tree implementation), but Leyr stays faster than native at every size tested.

## Query Cost Scales With What You Insert

Leyr only queries proxies you've explicitly inserted. Keeping a `RaycastStatic` tree for immobile geometry and a separate `RaycastDynamic` tree for moving proxies means static queries never pay dynamic-tree refit costs, and dynamic-tree rebuilds never have to repartition geometry that was never going to move in the first place.
