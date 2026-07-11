--[=[
	@class RaycastStatic

	Broadphase + narrow-phase raycasting against proxies that don't move
	after insertion.

	Insert and remove are cheap - they don't refit anything. The tree is
	marked dirty on any change and rebuilt lazily, in full, the next time
	[RaycastStatic:Raycast] is called.

	```lua
	local Leyr = require(ReplicatedStorage.Leyr)

	local RC = Leyr.RaycastStatic.new()
	RC:Insert(workspace.Terrain1)
	RC:Insert(workspace.Terrain2)

	local hit = RC:Raycast(origin, direction) -- rebuilds on first call
	```
]=]
local RaycastStatic = {}

--[=[
	Creates a new static raycast tree.

	@return RaycastStatic
]=]
function RaycastStatic.new(): RaycastStatic end

--[=[
	Inserts a proxy into the tree. The shape and CFrame are read from the part
	unless an explicit shape is given. Marks the tree dirty.

	Errors if `instance` is already inserted.

	@param instance BasePart
	@param shape Shape? -- Overrides the shape derived from `instance`.
	@param cframe CFrame? -- Overrides `instance.CFrame` as the initial transform.
]=]
function RaycastStatic:Insert(instance: BasePart, shape: any?, cframe: CFrame?) end

--[=[
	Removes a proxy from the tree. Marks the tree dirty. No-ops if `instance`
	was never inserted.

	@param instance Instance
]=]
function RaycastStatic:Remove(instance: Instance) end

--[=[
	Forces a full SAH rebuild now. Calling this is only needed to control
	*when* the rebuild cost is paid - the first `Raycast()` after any change
	rebuilds automatically if this was never called.

	```lua
	RC:Build() -- e.g. during a loading screen
	```
]=]
function RaycastStatic:Build() end

--[=[
	Removes every proxy and resets internal state.
]=]
function RaycastStatic:Clear() end

--[=[
	Returns the nearest hit along the segment `origin -> origin + direction`,
	or `nil` if nothing was hit. Rebuilds the tree first if it's dirty.

	`direction` is the raw displacement vector, not a unit vector - its
	magnitude is the cast distance, matching `workspace:Raycast`.

	Proxies the ray originates inside are ignored, matching native
	`workspace:Raycast` semantics.

	@param origin Vector3
	@param direction Vector3
	@param filter ((instance: Instance) -> boolean)? -- Return `false` to exclude a proxy from consideration.
	@return RaycastResult?
]=]
function RaycastStatic:Raycast(origin: Vector3, direction: Vector3, filter: any?): any end

return RaycastStatic
