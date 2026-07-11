<div align="center">

**Custom, Fast, Accurate**

[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

</div>

---

Leyr is a self-contained spatial raycasting library for Roblox. It bundles primitive shape support, a broadphase AABB tree, and analytic narrow-phase ray tests into a single module - no dependency on `workspace:Raycast`, no `RaycastParams`, no datamodel Parts required to query against.

## Features

- **Custom** - insert any primitive shape (box, sphere, capsule, cylinder, wedge, corner wedge) at any CFrame, independent of whether an Instance exists in the datamodel
- **Fast** - a fused broadphase + narrow-phase traversal visits the AABB tree in distance order and prunes subtrees beyond the closest confirmed hit; SAH-built static trees and incrementally-refit dynamic trees
- **Accurate** - analytic per-shape ray tests validated against Roblox's own `workspace:Raycast`, with convex-radius support and correct inside-origin handling
- **Two tree flavors** - `RaycastDynamic` for proxies that move every frame (incremental insert/remove/move with lazy partial rebuilds), and `RaycastStatic` for a world that doesn't move (lazy full rebuild on first query after a change)
- **Roblox-shaped results** - every hit returns `{ Instance, Position, Normal, Distance }`, so it drops into existing raycast-based code with minimal changes
- **`--!strict` throughout** - fully typed, no `--!nocheck` escape hatches

## Installation

Drop the `Leyr` folder into `ReplicatedStorage` (or anywhere reachable by your scripts) and require it.

```lua
local Leyr = require(ReplicatedStorage.Leyr)
```

## Quick Start

```lua
local Leyr = require(ReplicatedStorage.Leyr)

local RC = Leyr.RaycastDynamic.new()

-- shape + CFrame read directly from the part
RC:Insert(workspace.Wall)

local hit = RC:Raycast(origin, direction)
if hit then
    print("Hit", hit.Instance.Name, "at", hit.Position, "normal", hit.Normal)
end
```

## Dynamic vs Static

```lua
-- Dynamic: proxies can move after insertion
local Dynamic = Leyr.RaycastDynamic.new()
Dynamic:Insert(part)
Dynamic:Move(part)             -- re-sync to part.CFrame
Dynamic:UpdateTransform(part)  -- re-sync to part.Size and part.CFrame

-- Static: insert once, query many. Rebuilt lazily on first query after a change.
local Static = Leyr.RaycastStatic.new()
Static:Insert(part)
Static:Build() -- optional: control exactly when the rebuild cost is paid
```

## Custom Shapes

Insert a shape without any backing Instance, or override the shape derived from a part:

```lua
local Shape = Leyr.capsule(2, 6) -- radius, height

RC:Insert(someInstance, Shape)
```

Shape constructors: `Leyr.box`, `Leyr.sphere`, `Leyr.capsule`, `Leyr.cylinder`, `Leyr.wedge`, `Leyr.corner_wedge`, `Leyr.from_part`.

## License

MIT License - Copyright (c) 2026 VeDevelopment
