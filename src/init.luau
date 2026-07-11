--!strict
--!native
--!optimize 2

-- Raycast: a self-contained spatial raycasting library.
--
-- It bundles three pieces into one unit:
--   * shape constructors (box, sphere, capsule, cylinder, wedge, corner_wedge)
--   * an AABB tree, dynamic and static (broadphase)
--   * analytic per-shape ray tests (narrow-phase, validated against Roblox)
--
-- Two flavors are exported:
--   RaycastDynamic - proxies can Move / UpdateTransform after insertion. Use for
--                    things that move around each frame.
--   RaycastStatic  - insert once, then query. No per-proxy movement; the tree is
--                    (re)built lazily on the first query after any change. Faster
--                    queries for a world that doesn't move.
--
-- Both return Roblox-style results with the inserted Instance in place of a
-- datamodel raycast:
--   local rc = Raycast.RaycastDynamic.new()
--   rc:Insert(part)                            -- shape + CFrame read from the part
--   rc:Move(part)                              -- re-sync to part.CFrame
--   rc:UpdateTransform(part)                   -- re-sync to part.Size + part.CFrame
--   local hit = rc:Raycast(origin, direction)  -- {Instance, Position, Normal, Distance} | nil

local types = require("@self/types")
local shape_map = require("@self/shape_map")
local ray = require("@self/ray")
local aabb_tree = require("@self/aabb_tree")

local UP = Vector3.yAxis
local RIGHT = Vector3.xAxis
local LOOK = Vector3.zAxis

local DEFAULT_CONVEX_RADIUS = .05
local DEFAULT_AABB_PADDING = .05

export type Shape = types.Shape
export type BoxShape = types.BoxShape
export type SphereShape = types.SphereShape
export type CapsuleShape = types.CapsuleShape
export type CylinderShape = types.CylinderShape
export type WedgeShape = types.WedgeShape
export type CornerWedgeShape = types.CornerWedgeShape

export type RaycastResult = {
	Instance: Instance,
	Position: Vector3,
	Normal: Vector3,
	Distance: number,
}

export type FilterFn = (instance: Instance) -> boolean

-------------------------------------------------------------------------------
-- shape constructors
-------------------------------------------------------------------------------
local function create_box(size: Vector3, convex_radius: number?): types.BoxShape
	return {
		type = shape_map.BOX,
		half_extents = size / 2,
		convex_radius = convex_radius or DEFAULT_CONVEX_RADIUS
	}
end

local function create_sphere(radius: number, convex_radius: number?): types.SphereShape
	return {
		type = shape_map.SPHERE,
		radius = radius,
		convex_radius = convex_radius or DEFAULT_CONVEX_RADIUS
	}
end

local function create_capsule(radius: number, height: number, convex_radius: number?): types.CapsuleShape
	return {
		type = shape_map.CAPSULE,
		radius = radius,
		half_height = height / 2,
		convex_radius = convex_radius or DEFAULT_CONVEX_RADIUS
	}
end

local function create_cylinder(radius: number, height: number, convex_radius: number?): types.CylinderShape
	return {
		type = shape_map.CYLINDER,
		radius = radius,
		half_height = height / 2,
		convex_radius = convex_radius or DEFAULT_CONVEX_RADIUS
	}
end

local function create_wedge(size: Vector3, convex_radius: number?): types.WedgeShape
	local half_extents = size / 2

	local hx, hy, hz = half_extents.X, half_extents.Y, half_extents.Z

	local sr = hx * RIGHT
	local su = hy * UP
	local sl = hz * LOOK

	local v1 = sr + sl - su
	local v2 = sr - sl - su
	local v3 = sr + sl + su

	-- precomputed local face half-spaces for raycasting (dot(p, n) <= d).
	-- the sloped top rises toward +Z (matching Roblox's wedge part) and passes
	-- through the local origin; the other faces are the two X ends, the bottom,
	-- and the tall back wall at +Z.
	local ray_slope = vector.normalize(vector.create(0, hz, hy))
	local ray_normals = {
		vector.create( 1,  0,  0) :: any,
		vector.create(-1,  0,  0) :: any,
		vector.create( 0, -1,  0) :: any,
		vector.create( 0,  0, -1) :: any,
		ray_slope :: any,
	}
	local ray_offsets = { hx, hx, hy, hz, 0 }

	return {
		type = shape_map.WEDGE,
		vertices = {v1, v2, v3},
		local_slope = vector.normalize(vector.create(0, hz, -hy)) :: any,
		local_edge = vector.normalize(vector.create(0, hy, hz)) :: any,
		half_extents = half_extents,
		ray_normals = ray_normals,
		ray_offsets = ray_offsets,
		convex_radius = convex_radius or DEFAULT_CONVEX_RADIUS
	}
end

local function create_corner_wedge(size: Vector3, convex_radius: number?): types.CornerWedgeShape
	local half_extents = size / 2

	local hx, hy, hz = half_extents.X, half_extents.Y, half_extents.Z

	local sr = hx * RIGHT
	local su = hy * UP
	local sl = hz * LOOK

	local v1 = sr + sl - su
	local v2 = sr - sl - su
	local v3 = sr - sl + su
	local v4 = -sr - sl - su
	local v5 = -sr + sl - su

	-- precomputed local face half-spaces for raycasting (dot(p, n) <= d).
	-- five faces: the +X end, the bottom, the +Z wall, and the two slanted
	-- faces (both pass through the local origin). orientation matches Roblox's
	-- corner-wedge part, and the diagonal planes hold for any aspect ratio.
	local ray_slope1 = vector.normalize(vector.create(0, hz, -hy))
	local ray_slope2 = vector.normalize(vector.create(-hy, hx, 0))
	local ray_normals = {
		vector.create( 1,  0,  0) :: any,
		vector.create( 0, -1,  0) :: any,
		vector.create( 0,  0,  1) :: any,
		ray_slope1 :: any,
		ray_slope2 :: any,
	}
	local ray_offsets = { hx, hy, hz, 0, 0 }

	return {
		type = shape_map.CORNER_WEDGE,
		vertices = {v1, v2, v3, v4, v5},
		local_slope1 = vector.normalize(vector.create(0, hz, hy)) :: any,
		local_slope2 = vector.normalize(vector.create(-hy, hx, 0)) :: any,
		local_edge1 = vector.normalize(vector.create(0, hy, -hz)) :: any,
		local_edge2 = vector.normalize(vector.create(hx, hy, 0)) :: any,
		local_edge3 = vector.normalize(vector.create(hx, hy, -hz)) :: any,
		half_extents = half_extents,
		ray_normals = ray_normals,
		ray_offsets = ray_offsets,
		convex_radius = convex_radius or DEFAULT_CONVEX_RADIUS
	}
end

-- rebuild a shape at a new world size, preserving its type. used by
-- UpdateTransform to change scale. axis conventions match from_part:
-- cylinder/capsule use size.X as the length along the local X axis.
local function resize_shape(shape: types.Shape, size: Vector3): types.Shape
	local t = shape.type
	local cr = shape.convex_radius
	if t == shape_map.BOX then
		return create_box(size, cr)
	elseif t == shape_map.SPHERE then
		return create_sphere(size.X / 2, cr)
	elseif t == shape_map.CAPSULE then
		return create_capsule(size.Y / 2, size.X, cr)
	elseif t == shape_map.CYLINDER then
		return create_cylinder(size.Y / 2, size.X, cr)
	elseif t == shape_map.WEDGE then
		return create_wedge(size, cr)
	elseif t == shape_map.CORNER_WEDGE then
		return create_corner_wedge(size, cr)
	end
	error("resize_shape: unsupported shape type")
end

local function create_from_part(part: BasePart, convex_radius: number?): types.Shape
	if not part:IsA("Part") then
		error("Raycast only supports primitive Parts (got " .. part.ClassName .. ")")
	end

	local shape = (part :: Part).Shape
	local size = part.Size

	if shape == Enum.PartType.Block then
		return create_box(size, convex_radius)
	elseif shape == Enum.PartType.Ball then
		return create_sphere(size.X / 2, convex_radius)
	elseif shape == Enum.PartType.Cylinder then
		if size.Y ~= size.Z then
			error("cylinder does not have a consistent radius")
		end
		return create_cylinder(size.Y / 2, size.X, convex_radius)
	elseif shape == Enum.PartType.Wedge then
		return create_wedge(size, convex_radius)
	elseif shape == Enum.PartType.CornerWedge then
		return create_corner_wedge(size, convex_radius)
	end
	error("unsupported part shape")
end

-------------------------------------------------------------------------------
-- narrow-phase dispatch by shape type
-------------------------------------------------------------------------------
local ray_box = ray.ray_box
local ray_sphere = ray.ray_sphere
local ray_capsule = ray.ray_capsule
local ray_cylinder = ray.ray_cylinder
local ray_wedge = ray.ray_wedge
local ray_corner_wedge = ray.ray_corner_wedge

local BOX = shape_map.BOX
local SPHERE = shape_map.SPHERE
local CAPSULE = shape_map.CAPSULE
local CYLINDER = shape_map.CYLINDER
local WEDGE = shape_map.WEDGE
local CORNER_WEDGE = shape_map.CORNER_WEDGE

local function cast_shape(
	origin: Vector3,
	direction: Vector3,
	cf: CFrame,
	shape: types.Shape
): (Vector3?, number?, Vector3?, boolean?)
	local t = shape.type
	if t == BOX then
		return ray_box(origin, direction, cf, shape :: any)
	elseif t == SPHERE then
		return ray_sphere(origin, direction, cf, shape :: any)
	elseif t == CYLINDER then
		return ray_cylinder(origin, direction, cf, shape :: any)
	elseif t == CAPSULE then
		return ray_capsule(origin, direction, cf, shape :: any)
	elseif t == WEDGE then
		return ray_wedge(origin, direction, cf, shape :: any)
	elseif t == CORNER_WEDGE then
		return ray_corner_wedge(origin, direction, cf, shape :: any)
	end
	return nil, nil, nil, nil
end

-- fused broadphase + narrow-phase: a single distance-ordered traversal of the
-- AABB tree. children are visited nearest-entry-first, and any subtree whose
-- AABB entry lies beyond the best confirmed surface hit is pruned. profiling
-- showed the flat collect-then-test query visited 120+ nodes per ray to find
-- ~1.6 candidates on dense scenes; ordering + pruning cuts the visits to the
-- near end of the ray. written closure-free with module-level stacks -- the
-- per-call closure and duplicated AABB tests were what sank the first attempt.
--
-- pruning is conservative: a shape lies inside its AABB, so its surface hit t
-- is always >= the AABB entry t. padding only enlarges AABBs, which shrinks
-- entry t -- we may prune less, never wrongly.
--
-- the stack holds node INDICES, and slab tests read the child AABBs cached on
-- the parent node (c1_min..c2_max) -- so each visited node costs one table load
-- instead of three, and entries pruned by a later best_t are never loaded at all.
local traverse_indices = table.create(128) :: {number}
local traverse_ts = table.create(128) :: {number}

local NULL = 0

-- profiling: nodes popped by the last query_nearest call
local debug_visited = 0

local function query_nearest(
	tree: types.Tree,
	instance_of: { [number]: Instance },
	origin: Vector3,
	direction: Vector3,
	filter: FilterFn?
): RaycastResult?
	local root = tree.root
	if root == NULL then
		return nil
	end

	local dir_len = vector.magnitude(direction :: any)
	if dir_len <= 0 then
		return nil
	end
	local inv_len = 1 / dir_len
	local inv_dir = 1 / direction

	local nodes = tree.nodes

	local best_t = 1 -- parametric; hits past the segment end never count
	local best_dist = 0
	local best_hit: Vector3? = nil
	local best_normal: Vector3? = nil
	local best_instance: Instance? = nil

	-- seed with the root's entry distance (the root is the only node slab-tested
	-- via its own aabb; every other node's box is tested from its parent's cache)
	local top = 0
	do
		local node = nodes[root]
		local t1 = (node.aabb_min - origin :: any) * inv_dir
		local t2 = (node.aabb_max - origin :: any) * inv_dir
		local vmin = vector.min(t1 :: any, t2 :: any)
		local vmax = vector.max(t1 :: any, t2 :: any)
		local tmin = math.max(vmin.x, vmin.y, vmin.z, 0)
		local tmax = math.min(vmax.x, vmax.y, vmax.z)
		if tmax >= tmin and tmin < best_t then
			top = 1
			traverse_indices[1] = root
			traverse_ts[1] = tmin
		end
	end

	local visited = 0
	while top > 0 do
		local entry_t = traverse_ts[top]
		local index = traverse_indices[top]
		top -= 1
		visited += 1

		-- a closer confirmed hit landed after this node was pushed
		if entry_t >= best_t then
			continue
		end

		local node = nodes[index]
		local c1 = node.child1
		if c1 == NULL then
			-- leaf: exact narrow-phase test. inside-origin hits (the ray starts
			-- inside the shape and the test reports the exit point) are discarded
			-- to match native workspace:Raycast, which ignores parts the ray
			-- originates in -- the traversal then continues to farther proxies.
			local instance = instance_of[node.id]
			if not filter or filter(instance) then
				local hit, dist, normal, is_inside = cast_shape(origin, direction, node.cf, node.shape)
				if hit and not is_inside then
					local t = (dist :: number) * inv_len
					if t < best_t then
						best_t = t
						best_dist = dist :: number
						best_hit = hit
						best_normal = normal
						best_instance = instance
					end
				end
			end
		else
			local a1 = (node.c1_min - origin :: any) * inv_dir
			local a2 = (node.c1_max - origin :: any) * inv_dir
			local vmin = vector.min(a1 :: any, a2 :: any)
			local vmax = vector.max(a1 :: any, a2 :: any)
			local tmin1 = math.max(vmin.x, vmin.y, vmin.z, 0)
			local tmax1 = math.min(vmax.x, vmax.y, vmax.z)

			local b1 = (node.c2_min - origin :: any) * inv_dir
			local b2 = (node.c2_max - origin :: any) * inv_dir
			vmin = vector.min(b1 :: any, b2 :: any)
			vmax = vector.max(b1 :: any, b2 :: any)
			local tmin2 = math.max(vmin.x, vmin.y, vmin.z, 0)
			local tmax2 = math.min(vmax.x, vmax.y, vmax.z)

			local hit1 = tmax1 >= tmin1 and tmin1 < best_t
			local hit2 = tmax2 >= tmin2 and tmin2 < best_t

			-- push the farther child first so the nearer pops next
			if hit1 and hit2 then
				local c2 = node.child2
				if tmin1 <= tmin2 then
					top += 1
					traverse_indices[top] = c2
					traverse_ts[top] = tmin2
					top += 1
					traverse_indices[top] = c1
					traverse_ts[top] = tmin1
				else
					top += 1
					traverse_indices[top] = c1
					traverse_ts[top] = tmin1
					top += 1
					traverse_indices[top] = c2
					traverse_ts[top] = tmin2
				end
			elseif hit1 then
				top += 1
				traverse_indices[top] = c1
				traverse_ts[top] = tmin1
			elseif hit2 then
				top += 1
				traverse_indices[top] = node.child2
				traverse_ts[top] = tmin2
			end
		end
	end

	debug_visited = visited

	if not best_instance then
		return nil
	end

	return {
		Instance = best_instance :: Instance,
		Position = best_hit :: Vector3,
		Normal = best_normal :: Vector3,
		Distance = best_dist,
	}
end

type Config = { aabb_padding: number? }

-------------------------------------------------------------------------------
-- RaycastDynamic: movable proxies
-------------------------------------------------------------------------------
local RaycastDynamic = {}
RaycastDynamic.__index = RaycastDynamic

export type RaycastDynamic = typeof(setmetatable(
	{} :: {
		_tree: types.DynamicTree,
		_next_id: number,
		_id_of: { [Instance]: number },
		_instance_of: { [number]: Instance },
	},
	RaycastDynamic
))

function RaycastDynamic.new(config: Config?): RaycastDynamic
	local padding = config and config.aabb_padding or DEFAULT_AABB_PADDING
	return setmetatable({
		_tree = aabb_tree.new_dynamic({ aabb_padding = padding }),
		_next_id = 0,
		_id_of = {},
		_instance_of = {},
	}, RaycastDynamic)
end

-- the shape and transform are derived from the part itself (part.Shape/.Size
-- and part.CFrame). pass a shape override to reuse a prebuilt shape.
function RaycastDynamic.Insert(self: RaycastDynamic, part: BasePart, shape: types.Shape?)
	if self._id_of[part] then
		error("instance already inserted")
	end
	local id = self._next_id + 1
	self._next_id = id
	self._id_of[part] = id
	self._instance_of[id] = part
	self._tree:insert(id, part.CFrame, shape or create_from_part(part))
end

function RaycastDynamic.Remove(self: RaycastDynamic, instance: Instance)
	local id = self._id_of[instance]
	if not id then
		return
	end
	self._id_of[instance] = nil
	self._instance_of[id] = nil
	self._tree:remove(id)
end

-- re-sync the proxy to the part's current CFrame (shape unchanged). pass an
-- explicit cframe to move it somewhere other than the part's live transform.
function RaycastDynamic.Move(self: RaycastDynamic, part: BasePart, cframe: CFrame?)
	local id = self._id_of[part]
	if not id then
		error("instance not inserted")
	end
	self._tree:move(id, cframe or part.CFrame)
end

-- re-sync the proxy to the part's current size and CFrame (rebuilds the shape
-- at the new scale, then repositions). pass explicit cframe/size to override.
function RaycastDynamic.UpdateTransform(self: RaycastDynamic, part: BasePart, cframe: CFrame?, size: Vector3?)
	local id = self._id_of[part]
	if not id then
		error("instance not inserted")
	end
	local tree = self._tree
	local node = tree.nodes[tree.leaf_map[id]]
	tree:resize(id, resize_shape(node.shape, size or part.Size))
	tree:move(id, cframe or part.CFrame)
end

-- rebuild the tree bottom-up (SAH) to restore query quality. incremental
-- inserts and lots of movement loosen the hierarchy over time, which makes
-- every Raycast visit more nodes; call this after bulk-inserting or
-- periodically (e.g. once per frame/second) in scenes with heavy churn.
function RaycastDynamic.Rebuild(self: RaycastDynamic)
	if self._tree.proxy_count > 0 then
		self._tree:full_rebuild()
	end
end

function RaycastDynamic.Clear(self: RaycastDynamic)
	self._tree:clear()
	self._next_id = 0
	self._id_of = {}
	self._instance_of = {}
end

-- nearest hit along the segment origin -> origin + direction, or nil. an
-- optional filter(instance) -> boolean may exclude proxies (return false to
-- skip). matches native semantics: proxies the ray starts inside are ignored.
function RaycastDynamic.Raycast(self: RaycastDynamic, origin: Vector3, direction: Vector3, filter: FilterFn?): RaycastResult?
	return query_nearest(self._tree, self._instance_of, origin, direction, filter)
end

-------------------------------------------------------------------------------
-- RaycastStatic: insert once, query many. rebuilt lazily when dirty.
-------------------------------------------------------------------------------
local RaycastStatic = {}
RaycastStatic.__index = RaycastStatic

export type RaycastStatic = typeof(setmetatable(
	{} :: {
		_tree: types.StaticTree,
		_next_id: number,
		_id_of: { [Instance]: number },
		_instance_of: { [number]: Instance },
		_dirty: boolean,
	},
	RaycastStatic
))

function RaycastStatic.new(): RaycastStatic
	return setmetatable({
		_tree = aabb_tree.new_static(),
		_next_id = 0,
		_id_of = {},
		_instance_of = {},
		_dirty = false,
	}, RaycastStatic)
end

-- the shape and transform are derived from the part itself (part.Shape/.Size
-- and part.CFrame). pass a shape override to reuse a prebuilt shape.
function RaycastStatic.Insert(self: RaycastStatic, part: BasePart, shape: types.Shape?)
	if self._id_of[part] then
		error("instance already inserted")
	end
	local id = self._next_id + 1
	self._next_id = id
	self._id_of[part] = id
	self._instance_of[id] = part
	self._tree:insert(id, part.CFrame, shape or create_from_part(part))
	self._dirty = true
end

function RaycastStatic.Remove(self: RaycastStatic, instance: Instance)
	local id = self._id_of[instance]
	if not id then
		return
	end
	self._id_of[instance] = nil
	self._instance_of[id] = nil
	self._tree:remove(id)
	self._dirty = true
end

-- force a rebuild now. optional: the first Raycast after a change rebuilds
-- automatically, so calling this is only needed to control *when* the cost is paid.
function RaycastStatic.Build(self: RaycastStatic)
	if self._tree.proxy_count > 0 then
		self._tree:full_rebuild()
	end
	self._dirty = false
end

function RaycastStatic.Clear(self: RaycastStatic)
	self._tree:clear()
	self._next_id = 0
	self._id_of = {}
	self._instance_of = {}
	self._dirty = false
end

function RaycastStatic.Raycast(self: RaycastStatic, origin: Vector3, direction: Vector3, filter: FilterFn?): RaycastResult?
	if self._dirty then
		if self._tree.proxy_count > 0 then
			self._tree:full_rebuild()
		end
		self._dirty = false
	end
	return query_nearest(self._tree, self._instance_of, origin, direction, filter)
end

-------------------------------------------------------------------------------
-- module
-------------------------------------------------------------------------------
return {
	RaycastDynamic = RaycastDynamic,
	RaycastStatic = RaycastStatic,

	-- shape constructors, also available module-level
	box = create_box,
	sphere = create_sphere,
	capsule = create_capsule,
	cylinder = create_cylinder,
	wedge = create_wedge,
	corner_wedge = create_corner_wedge,
	from_part = create_from_part,

	-- profiling only
	_debug_nodes_visited = aabb_tree.debug_get_nodes_visited,
	_debug_fused_visited = function(): number
		return debug_visited
	end,
}
