---
sidebar_position: 1
---

# Getting Started

Leyr is a self-contained spatial raycasting library for Roblox: shape constructors, a broadphase AABB tree, and analytic narrow-phase ray tests, bundled into one require.

## Installation

Drop the `Leyr` folder into `ReplicatedStorage` and require it.

```lua
local Leyr = require(ReplicatedStorage.Leyr)
```

## Your First Query

```lua
local Leyr = require(ReplicatedStorage.Leyr)

local RC = Leyr.RaycastDynamic.new()

RC:Insert(workspace.Wall)
RC:Insert(workspace.Floor)

local hit = RC:Raycast(Vector3.new(0, 10, 0), Vector3.new(0, -20, 0))
if hit then
    print(hit.Instance.Name, hit.Position, hit.Normal, hit.Distance)
end
```

`Insert` reads the shape and CFrame directly from the part — no separate registration step. `Raycast` returns a Roblox-shaped result table, or `nil` if nothing was hit.

## Dynamic or Static?

- **`RaycastDynamic`** — proxies can `Move` or `UpdateTransform` after insertion. Use this for anything that changes position or size during play.
- **`RaycastStatic`** — insert once, then query. The tree is rebuilt lazily on the first query after any change, which is cheaper than incremental refitting for a world that doesn't move.

```lua
local Static = Leyr.RaycastStatic.new()
Static:Insert(workspace.Terrain1)
Static:Insert(workspace.Terrain2)
-- first Raycast() call builds the tree; subsequent calls reuse it
```

## Custom Shapes

Every `Insert` call accepts an optional shape override, so you can raycast against geometry that has no backing part at all:

```lua
local Shape = Leyr.capsule(2, 6) -- radius, height
RC:Insert(someInstance, Shape)
```

See [Shapes](./guides/shapes) for the full constructor list and axis conventions.

## Next Steps

- [Shapes](./guides/shapes) — every shape constructor and how axes map to CFrame
- [Trees](./guides/trees) — dynamic vs static, rebuilds, and when to call each
- [Performance](./guides/performance) — how the fused traversal prunes the tree, and what changes query cost
