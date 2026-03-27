--!strict
--[[
	Small group badge beside the player name when DAC_GroupMember is true (server attribute).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local GroupRewardConfig = require(DAC:WaitForChild("Config"):WaitForChild("GroupRewardConfig"))

local function attachBadge(character: Model, show: boolean)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local existing = root:FindFirstChild("DAC_GroupMemberBadge") :: BillboardGui?
	if existing then
		existing:Destroy()
	end

	if not show then
		return
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "DAC_GroupMemberBadge"
	bb.Adornee = root
	bb.Size = UDim2.fromOffset(28, 28)
	bb.StudsOffsetWorldSpace = Vector3.new(1.85, 3.35, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 120
	bb.Parent = root

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.Text = "👥"
	icon.TextSize = 22
	icon.Font = Enum.Font.GothamBold
	icon.Parent = bb

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(42, 42, 64)
	stroke.Parent = icon
end

local hookCleanups: { [number]: () -> () } = {}

local function hookPlayer(target: Player)
	local conns: { RBXScriptConnection } = {}

	local function refresh()
		if type(GroupRewardConfig.groupId) ~= "number" or GroupRewardConfig.groupId <= 0 then
			return
		end
		local char = target.Character
		if not char then
			return
		end
		local show = target:GetAttribute("DAC_GroupMember") == true
		attachBadge(char, show)
	end

	local function cleanup()
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
		if hookCleanups[target.UserId] == cleanup then
			hookCleanups[target.UserId] = nil
		end
	end

	table.insert(conns, target.CharacterAdded:Connect(refresh))
	table.insert(conns, target:GetAttributeChangedSignal("DAC_GroupMember"):Connect(refresh))
	hookCleanups[target.UserId] = cleanup
	if target.Character then
		refresh()
	end
end

Players.PlayerRemoving:Connect(function(player)
	local fn = hookCleanups[player.UserId]
	if fn then
		fn()
	end
end)

for _, p in Players:GetPlayers() do
	hookPlayer(p)
end
Players.PlayerAdded:Connect(hookPlayer)
