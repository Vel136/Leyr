---
sidebar_position: 1
---

# Shapes

Every shape is a plain table with a `type` field and shape-specific dimensions. Constructors build these tables for you and precompute anything the ray test needs.

## Constructors

```lua
Leyr.box(size: Vector3, convexRadius: number?)
Leyr.sphere(radius: number, convexRadius: number?)
Leyr.capsule(radius: number, height: number, convexRadius: number?)
Leyr.cylinder(radius: number, height: number, convexRadius: number?)
Leyr.wedge(size: Vector3, convexRadius: number?)
Leyr.corner_wedge(size: Vector3, convexRadius: number?)
Leyr.from_part(part: BasePart, convexRadius: number?)
```

`convexRadius` defaults to `0.05` if omitted.

## Axis Conventions

Box, wedge, and corner wedge take a `Vector3` size and store half-extents. Wedge and corner-wedge orientation matches Roblox's own wedge and corner-wedge parts:

- **Wedge** - the sloped face rises toward `+Z`. Half-extents map to CFrame axes as `X = Right`, `Y = Up`, `Z = Look`.
- **Corner wedge** - five faces: `+X` end, bottom, `+Z` wall, and two slanted faces through the local origin. Same axis mapping as wedge.

Capsule and cylinder take `radius` and `height` (not half-height) and are oriented along the CFrame's **`RightVector`** - i.e. the local X axis, not Y as you might expect from a vertical capsule intuition. A capsule standing upright needs a CFrame rotated so `RightVector` points up.

```lua
local upright = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
RC:Insert(instance, Leyr.capsule(1, 4), upright)
```

## `from_part`

Derives a shape directly from a `Part`'s `Shape` and `Size` properties:

| `Part.Shape` | Resulting shape |
|---|---|
| `Enum.PartType.Block` | box |
| `Enum.PartType.Ball` | sphere, radius `= Size.X / 2` |
| `Enum.PartType.Cylinder` | cylinder, radius `= Size.Y / 2`, height `= Size.X`. Requires `Size.Y == Size.Z`. |
| `Enum.PartType.Wedge` | wedge |
| `Enum.PartType.CornerWedge` | corner wedge |

Only `Part` instances are accepted - MeshParts, unions, and other classes raise an error. Build a shape explicitly for those instead.

`from_part` is called automatically by `Insert` when no shape override is given, so most call sites never need to call it directly.

## Resizing

`RaycastDynamic.UpdateTransform` rebuilds a proxy's shape at a new size while preserving its type, using the same axis conventions as `from_part`:

```lua
RC:UpdateTransform(part) -- reads part.Size and part.CFrame
```

## Mesh, Hull, Ellipsoid

These type bits are reserved in the shape-type table for future use but have no constructor or ray test yet. Attempting to raycast against a shape with one of these types returns no hit.

## Known Limitation: MeshParts

`Leyr.from_part` (and therefore the default, no-override path of `Insert`) only accepts `Part` instances. Passing a `MeshPart` raises `"Raycast only supports primitive Parts (got MeshPart)"` - there is no analytic ray test for arbitrary mesh geometry, and no automatic fallback to `workspace:Raycast` for it.

If you need to include MeshParts in your query world, either:

- Approximate the mesh with one of the supported primitives and pass it as the `Insert` shape override, or
- Keep MeshParts out of the tree entirely and query them separately with `workspace:Raycast`, then compare the two results by `Distance` yourself.
