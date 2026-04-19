--[[
	AutoTriangulate
	Delaunay triangulation on the XZ plane from a set of node positions.
	Bowyer-Watson incremental insertion algorithm.

	-- Alpha-shape filtering --
	Plain Delaunay triangulates the *convex hull* of the input. When nodes
	are laid out along a non-convex shape (a curve, a C, a ring), Delaunay
	happily fills the concavities with huge "bridge" triangles — e.g. one
	triangle stretching from one tip of the curve to the other across empty
	space. This looks awful and is almost never what the user wants.

	Fix: after Delaunay, drop any triangle whose longest edge is more than
	`maxEdgeFactor` times the median nearest-neighbor distance among the
	input points. This is a simplified alpha-shape / alpha-complex filter.
	The threshold scales with point density automatically (sparse layouts
	get a sparse threshold, dense layouts get a tight one).

	Pass maxEdgeFactor = 0 (or any value <= 0) to disable filtering and
	get raw Delaunay back.
]]

local AutoTriangulate = {}

local DEFAULT_MAX_EDGE_FACTOR = 3.0

type Point = {
	x: number,
	z: number,
	nodeId: string,
}

type Triangle = {
	p1: Point,
	p2: Point,
	p3: Point,
}

local function circumcircleContains(tri: Triangle, p: Point): boolean
	local ax = tri.p1.x - p.x
	local az = tri.p1.z - p.z
	local bx = tri.p2.x - p.x
	local bz = tri.p2.z - p.z
	local cx = tri.p3.x - p.x
	local cz = tri.p3.z - p.z

	local det = (ax * ax + az * az) * (bx * cz - cx * bz)
		- (bx * bx + bz * bz) * (ax * cz - cx * az)
		+ (cx * cx + cz * cz) * (ax * bz - bx * az)

	return det > 0
end

local function edgeKey(a: Point, b: Point): string
	local idA = a.nodeId
	local idB = b.nodeId
	if idA > idB then idA, idB = idB, idA end
	return idA .. "|" .. idB
end

local function sharesEdge(t1: Triangle, t2: Triangle): boolean
	local pts1 = { t1.p1, t1.p2, t1.p3 }
	local pts2 = { t2.p1, t2.p2, t2.p3 }
	local shared = 0
	for _, a in pts1 do
		for _, b in pts2 do
			if a.nodeId == b.nodeId then
				shared += 1
			end
		end
	end
	return shared >= 2
end

local function medianNearestNeighborDistance(points: { Point }): number
	if #points < 2 then return 0 end
	local distances = table.create(#points)
	for i = 1, #points do
		local p = points[i]
		local minSq = math.huge
		for j = 1, #points do
			if i ~= j then
				local q = points[j]
				local dx = p.x - q.x
				local dz = p.z - q.z
				local dSq = dx * dx + dz * dz
				if dSq < minSq then minSq = dSq end
			end
		end
		if minSq < math.huge then
			distances[#distances + 1] = math.sqrt(minSq)
		end
	end
	if #distances == 0 then return 0 end
	table.sort(distances)
	-- True median (average of two middles for even counts) is overkill for
	-- our use case; the lower-middle index is plenty and avoids the branch.
	return distances[math.ceil(#distances / 2)]
end

function AutoTriangulate.triangulate(
	nodePositions: { { nodeId: string, position: Vector3 } },
	maxEdgeFactor: number?
): { { string } }
	if #nodePositions < 3 then return {} end
	local edgeFactor = maxEdgeFactor or DEFAULT_MAX_EDGE_FACTOR

	-- Project to XZ plane
	local points: { Point } = {}
	for _, entry in nodePositions do
		table.insert(points, {
			x = entry.position.X,
			z = entry.position.Z,
			nodeId = entry.nodeId,
		})
	end

	-- Compute bounding box for super triangle
	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge
	for _, p in points do
		minX = math.min(minX, p.x)
		maxX = math.max(maxX, p.x)
		minZ = math.min(minZ, p.z)
		maxZ = math.max(maxZ, p.z)
	end

	local dx = maxX - minX
	local dz = maxZ - minZ
	local dmax = math.max(dx, dz)
	local midX = (minX + maxX) * 0.5
	local midZ = (minZ + maxZ) * 0.5

	-- Super-triangle vertices (large enough to contain all points)
	local superA: Point = { x = midX - 2 * dmax, z = midZ - dmax, nodeId = "__super_a" }
	local superB: Point = { x = midX + 2 * dmax, z = midZ - dmax, nodeId = "__super_b" }
	local superC: Point = { x = midX, z = midZ + 2 * dmax, nodeId = "__super_c" }

	local triangles: { Triangle } = {
		{ p1 = superA, p2 = superB, p3 = superC }
	}

	-- Insert each point
	for _, point in points do
		local badTriangles: { Triangle } = {}
		for _, tri in triangles do
			if circumcircleContains(tri, point) then
				table.insert(badTriangles, tri)
			end
		end

		-- Find boundary polygon (non-shared edges)
		local edgeCounts: { [string]: { Point } } = {}
		local edgeList: { { Point } } = {}
		for _, tri in badTriangles do
			local edges = {
				{ tri.p1, tri.p2 },
				{ tri.p2, tri.p3 },
				{ tri.p3, tri.p1 },
			}
			for _, e in edges do
				local key = edgeKey(e[1], e[2])
				if edgeCounts[key] then
					edgeCounts[key] = nil -- shared edge, remove
				else
					edgeCounts[key] = e
				end
			end
		end

		-- Remove bad triangles
		for _, bad in badTriangles do
			for i = #triangles, 1, -1 do
				local t = triangles[i]
				if t.p1.nodeId == bad.p1.nodeId and t.p2.nodeId == bad.p2.nodeId and t.p3.nodeId == bad.p3.nodeId then
					table.remove(triangles, i)
					break
				end
			end
		end

		-- Create new triangles from boundary edges to new point
		for _, edge in edgeCounts do
			table.insert(triangles, { p1 = edge[1], p2 = edge[2], p3 = point })
		end
	end

	-- Remove triangles that share vertices with the super triangle, and
	-- (optionally) drop "bridge" triangles whose longest edge dwarfs the
	-- typical inter-node spacing — those are the convex-hull artifacts.
	local superIds = { __super_a = true, __super_b = true, __super_c = true }

	-- maxEdgeSq == 0 means "filter disabled". math.huge means "no edge can
	-- exceed this", which is the same thing in practice and keeps the inner
	-- loop branch-free.
	local maxEdgeSq: number
	if edgeFactor > 0 then
		local medianNN = medianNearestNeighborDistance(points)
		if medianNN > 0 then
			local maxEdge = medianNN * edgeFactor
			maxEdgeSq = maxEdge * maxEdge
		else
			maxEdgeSq = math.huge
		end
	else
		maxEdgeSq = math.huge
	end

	local result: { { string } } = {}
	for _, tri in triangles do
		if superIds[tri.p1.nodeId] or superIds[tri.p2.nodeId] or superIds[tri.p3.nodeId] then
			continue
		end
		if maxEdgeSq ~= math.huge then
			local p1, p2, p3 = tri.p1, tri.p2, tri.p3
			local d12 = (p1.x - p2.x)^2 + (p1.z - p2.z)^2
			local d23 = (p2.x - p3.x)^2 + (p2.z - p3.z)^2
			local d31 = (p3.x - p1.x)^2 + (p3.z - p1.z)^2
			if d12 > maxEdgeSq or d23 > maxEdgeSq or d31 > maxEdgeSq then
				continue
			end
		end
		table.insert(result, { tri.p1.nodeId, tri.p2.nodeId, tri.p3.nodeId })
	end

	return result
end

return AutoTriangulate
