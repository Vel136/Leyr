---
sidebar_position: 2
sidebar_label: "Documentation"
---

# Custom, Fast, Accurate

Leyr is a spatial raycasting library for Roblox. It replaces `workspace:Raycast` with a self-contained AABB tree and a set of analytic per-shape ray tests, so you can raycast against custom geometry — shapes with no backing Instance, shapes at arbitrary CFrames, shapes that don't match any live part — with the same result shape Roblox gives you.

---

## One Folder. One Require.

Drop the `Leyr` folder into `ReplicatedStorage` and require it.

```lua
local Leyr = require(ReplicatedStorage.Leyr)
```

---

## Insert. Query. Done.

```lua
local RC = Leyr.RaycastDynamic.new()

RC:Insert(workspace.Wall)
RC:Insert(workspace.Crate)

local hit = RC:Raycast(origin, direction)
if hit then
    print(hit.Instance.Name, "at", hit.Position)
end
```

`direction` is the raw displacement vector for the segment, not a unit vector — its magnitude is the cast distance, matching `workspace:Raycast`.

---

## Dynamic: Things That Move

`RaycastDynamic` proxies can be repositioned or resized after insertion. Movement is incremental — the tree refits along the path from the moved leaf to the root, and a bounded padding on each AABB absorbs small movements without a refit at all:

```lua
local RC = Leyr.RaycastDynamic.new()

RC:Insert(part)
RC:Move(part)             -- re-sync to part.CFrame
RC:UpdateTransform(part)  -- re-sync to part.Size and part.CFrame (rebuilds the shape)
```

Heavy churn loosens the tree's hierarchy over time, which makes every query visit more nodes. Call `Rebuild()` periodically (once per frame or once per second, depending on how much movement your scene has) to restore query quality via a full SAH rebuild:

```lua
RC:Rebuild()
```

---

## Static: A World That Doesn't Move

`RaycastStatic` trades incremental refitting for a lazy full rebuild. Insert and remove freely; the tree stays dirty until the next query, at which point it rebuilds once via SAH partitioning:

```lua
local RC = Leyr.RaycastStatic.new()

RC:Insert(workspace.Terrain1)
RC:Insert(workspace.Terrain2)

RC:Build() -- optional: control exactly when the rebuild cost is paid
local hit = RC:Raycast(origin, direction)
```

If you don't call `Build()` explicitly, the first `Raycast()` after a change pays the rebuild cost instead.

---

## Custom Shapes, No Instance Required

Every `Insert` accepts an optional shape override. The `Instance` you pass is only used as the map key and the value returned on a hit — the shape and CFrame used for the actual query come from the override:

```lua
local Shape = Leyr.capsule(2, 6) -- radius, height
RC:Insert(someInstance, Shape, someCFrame)
```

Shape constructors, also available module-level:

```lua
Leyr.box(size, convexRadius?)
Leyr.sphere(radius, convexRadius?)
Leyr.capsule(radius, height, convexRadius?)
Leyr.cylinder(radius, height, convexRadius?)
Leyr.wedge(size, convexRadius?)
Leyr.corner_wedge(size, convexRadius?)
Leyr.from_part(part, convexRadius?)
```

See [Shapes](./guides/shapes) for axis conventions on wedge and corner-wedge, and how `convexRadius` affects the ray test.

---

## Filtering Hits

`Raycast` accepts an optional filter callback, checked per candidate before the narrow-phase test runs:

```lua
local hit = RC:Raycast(origin, direction, function(instance)
    return not instance:HasTag("Ignored")
end)
```

Return `false` to skip a proxy entirely.

---

## Removing and Clearing

```lua
RC:Remove(instance)
RC:Clear() -- drops every proxy and resets internal state
```

---

## Origin-Inside Hits

If the ray starts inside a shape, the narrow-phase test reports the exit point but the traversal discards it — matching native `workspace:Raycast`, which ignores parts the ray originates in. The query continues to the next candidate along the ray instead of returning that exit point.
