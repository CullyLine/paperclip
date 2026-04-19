--[[
	SubdivisionEngine
	Pure math for triangle subdivision.

	Given a triangle (A, B, C) and an increment K (>= 1), splits each edge
	into K+1 segments, producing a triangular grid of (K+2)*(K+1)/2 vertices
	and (K+1)^2 sub-triangles.

	Increment | segments/edge | sub-triangles
	    1     |       2       |       4
	    2     |       3       |       9
	    3     |       4       |      16
	    5     |       6       |      36
	   50     |      51       |    2601

	Returns:
		vertices: { Vector3 } -- 1-indexed list of new vertex positions
		triangles: { { number, number, number } } -- triples of indices into `vertices`,
			wound consistently with the parent triangle (A, B, C order)
]]

local SubdivisionEngine = {}

function SubdivisionEngine.subdivide(A: Vector3, B: Vector3, C: Vector3, increment: number)
	local K = math.max(1, math.floor(increment))
	local S = K + 1

	local vertices: { Vector3 } = {}
	local indexAt: { [number]: { [number]: number } } = {}

	for r = 0, S do
		indexAt[r] = {}
		for c = 0, r do
			local aA = (S - r) / S
			local aB = (r - c) / S
			local aC = c / S
			local pos = A * aA + B * aB + C * aC
			table.insert(vertices, pos)
			indexAt[r][c] = #vertices
		end
	end

	local triangles: { { number } } = {}
	for r = 0, S - 1 do
		for c = 0, r do
			-- "Up" triangle (always present) — same winding as parent
			table.insert(triangles, { indexAt[r][c], indexAt[r + 1][c], indexAt[r + 1][c + 1] })
			-- "Down" triangle (only when c < r) — also same winding as parent
			if c < r then
				table.insert(triangles, { indexAt[r][c], indexAt[r + 1][c + 1], indexAt[r][c + 1] })
			end
		end
	end

	-- Edge node lists, ordered from first corner -> second corner. Each list
	-- contains S+1 vertex indices, including both endpoints. Used by callers
	-- to re-fan neighboring triangles so they share edge nodes (no T-junctions).
	local edges = { AB = {}, BC = {}, CA = {} }
	for r = 0, S do
		table.insert(edges.AB, indexAt[r][0])  -- A -> B: column 0 walking down
	end
	for c = 0, S do
		table.insert(edges.BC, indexAt[S][c])  -- B -> C: bottom row walking right
	end
	for r = S, 0, -1 do
		table.insert(edges.CA, indexAt[r][r])  -- C -> A: diagonal walking up
	end

	return vertices, triangles, edges
end

-- Helper: returns a table of corner-vertex indices in the returned vertex array.
-- Useful for callers that want to reuse the original triangle's three corner nodeIds.
function SubdivisionEngine.cornerIndices(increment: number)
	local K = math.max(1, math.floor(increment))
	local S = K + 1
	-- Index of (r, c) in the 1-indexed flat array equals: 1 + sum_{r'=0..r-1}(r'+1) + c
	-- = 1 + r*(r+1)/2 + c
	local function idx(r: number, c: number): number
		return 1 + r * (r + 1) / 2 + c
	end
	return {
		A = idx(0, 0),
		B = idx(S, 0),
		C = idx(S, S),
	}
end

return SubdivisionEngine
