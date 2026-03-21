--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Constants = require(DAC:WaitForChild("Constants"))
local Remotes = require(DAC:WaitForChild("Remotes"))

local PlaytimeGemHUD = {}

function PlaytimeGemHUD.init()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "DACPlaytimeGem"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 280, 0, 28)
	label.Position = UDim2.new(1, -290, 0, 88)
	label.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	label.BackgroundTransparency = 0.2
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(200, 120, 255)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.Parent = label

	local function update(data: any)
		if not data then
			return
		end
		local p = data.playtimeSecondsSinceGem or 0
		local need = Constants.PLAYTIME_GEM_INTERVAL or 300
		local left = math.max(0, need - p)
		local m = math.floor(left / 60)
		local s = math.floor(left % 60)
		label.Text = ` Playtime gem in {m}:{string.format("%02d", s)} `
	end

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(update)
	local d = Remotes.getFunction("GetPlayerData"):InvokeServer()
	update(d)
end

return PlaytimeGemHUD
