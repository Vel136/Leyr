---
sidebar_position: 4
---

# FAQ

Answers to the questions that come up most often.

---

## General

**What is Leyr?**

Leyr is a spatial raycasting library for Roblox. It bundles shape constructors, a broadphase AABB tree (dynamic and static), and analytic per-shape narrow-phase ray tests into one self-contained module, so you can raycast against custom geometry without relying on `workspace:Raycast` or live datamodel Parts.

---

**Is Leyr free?**

Yes — MIT. Use it however you want, commercial or otherwise.

---

**Does Leyr replace `workspace:Raycast`?**

Not automatically — you choose what to insert. Leyr queries only the proxies you've explicitly added to a `RaycastDynamic` or `RaycastStatic` instance. This is what makes it possible to raycast against shapes with no backing Instance, or to build a query world that's a deliberate subset of the datamodel.

---

## Setup

**Where does the Leyr folder go?**

`ReplicatedStorage`, or anywhere reachable from wherever you require it. Leyr has no client/server split of its own — it's pure computation with no RunService connections and no networking.

---

**Do I need one tree or many?**

One per logical query domain. If you have geometry that never moves (terrain, level architecture) and geometry that moves constantly (props, characters), keeping them in separate `RaycastStatic` and `RaycastDynamic` instances avoids paying dynamic-tree refit costs for things that never change.

---

## Shapes

**What shapes are supported?**

Box, sphere, capsule, cylinder, wedge, and corner wedge — the same primitive set as Roblox's `Part.Shape` enum, plus the two wedge variants. Mesh, hull, and ellipsoid are reserved in the shape-type table but not yet implemented as ray tests.

---

**What does `convexRadius` do?**

It's stored on the shape but is not currently applied as a Minkowski-sum inflation in the ray tests — the narrow-phase tests operate on the exact shape as specified. Leave it at the default unless you have a specific reason to override it.

---

**`Leyr.from_part` throws "unsupported part shape". Why?**

`from_part` only recognizes `Enum.PartType.Block`, `Ball`, `Cylinder`, `Wedge`, and `CornerWedge` on a `Part` instance. MeshParts, unions, and other part classes aren't derivable automatically — construct a shape explicitly and pass it as the `Insert` override instead.

---

**My cylinder shape errors with "cylinder does not have a consistent radius".**

`from_part` requires `part.Size.Y == part.Size.Z` for a cylinder, since Leyr's cylinder shape has one radius, not independent Y/Z extents. If your part is scaled non-uniformly on those axes, construct the shape manually with `Leyr.cylinder(radius, height)` instead.

---

## Dynamic vs Static

**When should I use `RaycastStatic` instead of `RaycastDynamic`?**

When the geometry doesn't move. `RaycastStatic` skips the incremental insert/refit machinery entirely and rebuilds the whole tree via SAH partitioning, lazily, the next time you query after a change. For a world that's built once and queried many times, that's cheaper than paying per-move refit costs it never needs.

---

**How often should I call `RaycastDynamic:Rebuild()`?**

Depends on how much movement and insertion churn your scene has. Frequent moves loosen the tree's hierarchy over time, which increases the number of nodes each query visits. If you're inserting many proxies at once, or moving a large fraction of them every frame, calling `Rebuild()` once per frame (or once per second, for lighter churn) restores query quality. It's unnecessary for a mostly-static scene with occasional single moves.

---

**Does `RaycastStatic:Build()` do anything I need to call manually?**

Not strictly — the first `Raycast()` call after any `Insert`/`Remove` rebuilds automatically. Call `Build()` yourself only if you want to control exactly when that cost is paid, e.g. during a loading screen rather than on the first query of gameplay.

---

## Queries

**What does `Raycast` return?**

`{ Instance, Position, Normal, Distance } | nil` — the same shape as a Roblox `RaycastResult`, with `Instance` set to whatever you passed to `Insert` for that proxy.

---

**Why did my ray pass through something it should have hit?**

Check whether the ray originates inside that shape. Leyr discards inside-origin hits to match native `workspace:Raycast` semantics — the ray continues past that proxy to the next candidate rather than reporting the exit point.

---

**Can I filter which proxies are considered?**

Yes — pass a third argument to `Raycast`, a function `(instance: Instance) -> boolean`. Return `false` to exclude that proxy from the result; the query moves on to the next candidate.

```lua
RC:Raycast(origin, direction, function(instance)
    return not instance:HasTag("Ignored")
end)
```

---

**Is `Raycast` allocation-free?**

The fused broadphase + narrow-phase traversal (`query_nearest`) uses module-level scratch arrays for its traversal stack rather than allocating a new table per call, and the individual shape ray tests carry no shared mutable state, so they're safe to call from multiple threads under Parallel Luau / `task.desynchronize()`. The result table itself is allocated per hit.

---

## Comparisons

**How is this different from `workspace:Raycast`?**

`workspace:Raycast` queries the live datamodel and only sees Parts that actually exist in `workspace`. Leyr queries an explicit proxy set you build yourself, which can include shapes with no backing Instance, shapes positioned independently of any part's actual CFrame, or a deliberately restricted subset of the world — at the cost of having to keep that proxy set in sync yourself.
