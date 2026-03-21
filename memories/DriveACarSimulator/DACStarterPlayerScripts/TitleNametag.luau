--!strict
--[[
	Shows DAC_PlayerTitle attribute above characters (e.g. Early Driver).
]]

local Players = game:GetService("Players")

local TitleNametag = {}

local function attachTitle(character: Model, titleText: string?)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local existing = root:FindFirstChild("DAC_TitleNametag")
	if existing then
		existing:Destroy()
	end
	if not titleText or titleText == "" then
		return
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "DAC_TitleNametag"
	bb.Adornee = root
	bb.Size = UDim2.fromOffset(200, 28)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 2.35, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 120
	bb.Parent = root

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = titleText
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 200, 80)
	label.Parent = bb

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(120, 80, 20)
	stroke.Parent = label
end

local function hookPlayer(target: Player)
	local function refresh()
		local char = target.Character
		if not char then
			return
		end
		local t = target:GetAttribute("DAC_PlayerTitle")
		attachTitle(char, if type(t) == "string" then t else nil)
	end

	target.CharacterAdded:Connect(refresh)
	target:GetAttributeChangedSignal("DAC_PlayerTitle"):Connect(refresh)
	if target.Character then
		refresh()
	end
end

function TitleNametag.init()
	for _, p in Players:GetPlayers() do
		hookPlayer(p)
	end
	Players.PlayerAdded:Connect(hookPlayer)
end

return TitleNametag
