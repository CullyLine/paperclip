--[[
	TriangleEngine
	Draws a 3D triangle from three Vector3 points using two WedgeParts.
	Based on EgoMoose's algorithm.
]]

local TriangleEngine = {}

local WEDGE_TEMPLATE = Instance.new("WedgePart")
WEDGE_TEMPLATE.Anchored = true
WEDGE_TEMPLATE.CanCollide = true
WEDGE_TEMPLATE.CastShadow = true
WEDGE_TEMPLATE.TopSurface = Enum.SurfaceType.Smooth
WEDGE_TEMPLATE.BottomSurface = Enum.SurfaceType.Smooth

function TriangleEngine.draw(a: Vector3, b: Vector3, c: Vector3, thickness: number?): (WedgePart, WedgePart)
	local t = thickness or 0.1

	local edges = {
		{ longest = c - b, other = a - b, position = b },
		{ longest = a - c, other = b - c, position = c },
		{ longest = b - a, other = c - a, position = a },
	}
	table.sort(edges, function(x, y) return x.longest.Magnitude > y.longest.Magnitude end)

	local edge = edges[1]
	local longest = edge.longest
	local other = edge.other

	local theta = math.acos(math.clamp(longest.Unit:Dot(other.Unit), -1, 1))
	local w1 = math.cos(theta) * other.Magnitude
	local w2 = longest.Magnitude - w1
	local h = math.sin(theta) * other.Magnitude

	print(string.format("[TriEngine] a=%s b=%s c=%s | h=%.2f w1=%.2f w2=%.2f", tostring(a), tostring(b), tostring(c), h, w1, w2))

	if h < 0.001 then
		warn("[TriEngine] Degenerate triangle, height near zero")
		local wedge1 = WEDGE_TEMPLATE:Clone()
		wedge1.Size = Vector3.new(t, 0.01, 0.01)
		wedge1.CFrame = CFrame.new(a)
		local wedge2 = WEDGE_TEMPLATE:Clone()
		wedge2.Size = Vector3.new(t, 0.01, 0.01)
		wedge2.CFrame = CFrame.new(a)
		return wedge1, wedge2
	end

	local right = longest:Cross(other).Unit
	local up = right:Cross(longest).Unit
	local back = longest.Unit

	local p1 = edge.position + other * 0.5
	local p2 = edge.position + longest + (other - longest) * 0.5

	local cf1 = CFrame.new(
		p1.X, p1.Y, p1.Z,
		-right.X, up.X, back.X,
		-right.Y, up.Y, back.Y,
		-right.Z, up.Z, back.Z
	)
	local cf2 = CFrame.new(
		p2.X, p2.Y, p2.Z,
		right.X, up.X, -back.X,
		right.Y, up.Y, -back.Y,
		right.Z, up.Z, -back.Z
	)

	local wedge1 = WEDGE_TEMPLATE:Clone()
	wedge1.Size = Vector3.new(t, h, w1)
	wedge1.CFrame = cf1

	local wedge2 = WEDGE_TEMPLATE:Clone()
	wedge2.Size = Vector3.new(t, h, w2)
	wedge2.CFrame = cf2

	return wedge1, wedge2
end

function TriangleEngine.updateTriangle(model: Model, a: Vector3, b: Vector3, c: Vector3, thickness: number?)
	local wedge1 = model:FindFirstChild("Wedge1")
	local wedge2 = model:FindFirstChild("Wedge2")
	if not wedge1 or not wedge2 then return end

	local t = thickness or 0.1

	local edges = {
		{ longest = c - b, other = a - b, position = b },
		{ longest = a - c, other = b - c, position = c },
		{ longest = b - a, other = c - a, position = a },
	}
	table.sort(edges, function(x, y) return x.longest.Magnitude > y.longest.Magnitude end)

	local edge = edges[1]
	local longest = edge.longest
	local other = edge.other

	local theta = math.acos(math.clamp(longest.Unit:Dot(other.Unit), -1, 1))
	local w1 = math.cos(theta) * other.Magnitude
	local w2 = longest.Magnitude - w1
	local h = math.sin(theta) * other.Magnitude

	if h < 0.001 then return end

	local right = longest:Cross(other).Unit
	local up = right:Cross(longest).Unit
	local back = longest.Unit

	local p1 = edge.position + other * 0.5
	local p2 = edge.position + longest + (other - longest) * 0.5

	wedge1.Size = Vector3.new(t, h, w1)
	wedge1.CFrame = CFrame.new(
		p1.X, p1.Y, p1.Z,
		-right.X, up.X, back.X,
		-right.Y, up.Y, back.Y,
		-right.Z, up.Z, back.Z
	)
	wedge2.Size = Vector3.new(t, h, w2)
	wedge2.CFrame = CFrame.new(
		p2.X, p2.Y, p2.Z,
		right.X, up.X, -back.X,
		right.Y, up.Y, -back.Y,
		right.Z, up.Z, -back.Z
	)
end

function TriangleEngine.setAppearance(model: Model, color: Color3, material: Enum.Material)
	for _, child in model:GetChildren() do
		if child:IsA("WedgePart") then
			child.Color = color
			child.Material = material
		end
	end
end

function TriangleEngine.getNormal(a: Vector3, b: Vector3, c: Vector3): Vector3
	local ab = b - a
	local ac = c - a
	return ab:Cross(ac).Unit
end

return TriangleEngine
