--[=[
	@class RaycastDynamic

	Broadphase + narrow-phase raycasting against proxies that can move after
	insertion.

	Insertion picks the sibling that minimizes surface-area cost. Movement is
	incremental: a small move is absorbed into the leaf's padded AABB with no
	tree change, and a move outside that padding triggers a remove/reinsert.
	Heavy churn loosens the tree's balance over time - call [RaycastDynamic:Rebuild]
	periodically to restore query quality.

	```lua
	local Leyr = require(ReplicatedStorage.Leyr)

	local RC = Leyr.RaycastDynamic.new()
	RC:Insert(workspace.Wall)

	local hit = RC:Raycast(origin, direction)
	if hit then
	    print(hit.Instance.Name, hit.Position)
	end
	```
]=]
local RaycastDynamic = {}

--[=[
	Creates a new dynamic raycast tree.

	@param config { aabb_padding: number? }? -- `aabb_padding` defaults to `0.05`. Larger padding absorbs more movement without a refit, at the cost of looser queries.
	@return RaycastDynamic
]=]
function RaycastDynamic.new(config: { aabb_padding: number? }?): RaycastDynamic end

--[=[
	Inserts a proxy into the tree. The shape and CFrame are read from the part
	unless an explicit shape is given.

	Errors if `instance` is already inserted.

	@param instance BasePart
	@param shape Shape? -- Overrides the shape derived from `instance`.
	@param cframe CFrame? -- Overrides `instance.CFrame` as the initial transform.
]=]
function RaycastDynamic:Insert(instance: BasePart, shape: any?, cframe: CFrame?) end

--[=[
	Removes a proxy from the tree. No-ops if `instance` was never inserted.

	@param instance Instance
]=]
function RaycastDynamic:Remove(instance: Instance) end

--[=[
	Re-syncs a proxy to its part's current CFrame (shape unchanged). Pass an
	explicit CFrame to move it somewhere other than the part's live transform.

	If the new position still fits inside the leaf's padded AABB, this is an
	O(1) update. Otherwise the leaf is removed and reinserted.

	@param instance BasePart
	@param cframe CFrame?
]=]
function RaycastDynamic:Move(instance: BasePart, cframe: CFrame?) end

--[=[
	Re-syncs a proxy to its part's current size and CFrame, rebuilding the
	shape at the new scale using the same axis conventions as `from_part`.
	Pass explicit `cframe`/`size` to override.

	@param instance BasePart
	@param cframe CFrame?
	@param size Vector3?
]=]
function RaycastDynamic:UpdateTransform(instance: BasePart, cframe: CFrame?, size: Vector3?) end

--[=[
	Forces a full SAH rebuild of the tree, restoring query quality after
	heavy movement or insertion churn.

	```lua
	RC:Rebuild()
	```
]=]
function RaycastDynamic:Rebuild() end

--[=[
	Removes every proxy and resets internal state.
]=]
function RaycastDynamic:Clear() end

--[=[
	Returns the nearest hit along the segment `origin -> origin + direction`,
	or `nil` if nothing was hit.

	`direction` is the raw displacement vector, not a unit vector - its
	magnitude is the cast distance, matching `workspace:Raycast`.

	Proxies the ray originates inside are ignored, matching native
	`workspace:Raycast` semantics.

	@param origin Vector3
	@param direction Vector3
	@param filter ((instance: Instance) -> boolean)? -- Return `false` to exclude a proxy from consideration.
	@return RaycastResult?
]=]
function RaycastDynamic:Raycast(origin: Vector3, direction: Vector3, filter: any?): any end

return RaycastDynamic
