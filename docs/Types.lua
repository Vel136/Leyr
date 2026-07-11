--[=[
	@class Types

	Shape constructors and result types shared by [RaycastDynamic] and
	[RaycastStatic].

	Shape constructors are also available module-level on the required
	`Leyr` table:

	```lua
	local Leyr = require(ReplicatedStorage.Leyr)

	Leyr.box(size, convexRadius)
	Leyr.sphere(radius, convexRadius)
	Leyr.capsule(radius, height, convexRadius)
	Leyr.cylinder(radius, height, convexRadius)
	Leyr.wedge(size, convexRadius)
	Leyr.corner_wedge(size, convexRadius)
	Leyr.from_part(part, convexRadius)
	```
]=]
local Types = {}

--[=[
	Builds a box shape from a full size (not half-extents).

	@param size Vector3
	@param convexRadius number? -- Defaults to `0.05`.
	@return Shape
]=]
function Types.box(size: Vector3, convexRadius: number?): any end

--[=[
	Builds a sphere shape.

	@param radius number
	@param convexRadius number? -- Defaults to `0.05`.
	@return Shape
]=]
function Types.sphere(radius: number, convexRadius: number?): any end

--[=[
	Builds a capsule shape. Oriented along the CFrame's `RightVector`.

	@param radius number
	@param height number
	@param convexRadius number? -- Defaults to `0.05`.
	@return Shape
]=]
function Types.capsule(radius: number, height: number, convexRadius: number?): any end

--[=[
	Builds a cylinder shape. Oriented along the CFrame's `RightVector`.

	@param radius number
	@param height number
	@param convexRadius number? -- Defaults to `0.05`.
	@return Shape
]=]
function Types.cylinder(radius: number, height: number, convexRadius: number?): any end

--[=[
	Builds a wedge shape from a full size (not half-extents). Orientation
	matches Roblox's wedge part - the sloped face rises toward `+Z`.

	@param size Vector3
	@param convexRadius number? -- Defaults to `0.05`.
	@return Shape
]=]
function Types.wedge(size: Vector3, convexRadius: number?): any end

--[=[
	Builds a corner-wedge shape from a full size (not half-extents).
	Orientation matches Roblox's corner-wedge part.

	@param size Vector3
	@param convexRadius number? -- Defaults to `0.05`.
	@return Shape
]=]
function Types.corner_wedge(size: Vector3, convexRadius: number?): any end

--[=[
	Derives a shape from a `Part`'s `Shape` and `Size` properties.

	Only `Enum.PartType.Block`, `Ball`, `Cylinder`, `Wedge`, and `CornerWedge`
	are supported. Cylinders require `Size.Y == Size.Z`. Only `Part` instances
	are accepted - errors on any other `BasePart` subclass.

	@param part BasePart
	@param convexRadius number? -- Defaults to `0.05`.
	@return Shape
]=]
function Types.from_part(part: BasePart, convexRadius: number?): any end

--[=[
	@interface RaycastResult
	@within Types
	.Instance Instance
	.Position Vector3
	.Normal Vector3
	.Distance number

	The value returned by `Raycast` on a hit - matches the shape of a native
	Roblox `RaycastResult`.
]=]

--[=[
	@interface Shape
	@within Types
	.type number
	.convex_radius number

	Base fields present on every shape table. Shape-specific dimensions
	(`half_extents`, `radius`, `half_height`, etc.) are added by the
	individual constructors.
]=]

return Types
