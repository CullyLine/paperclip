--!strict
--[[
	Items Panel -- placeholder for future item inventory.
	Shows a "Coming Soon..." message.
]]

local Players = game:GetService("Players")

local ItemsPanel = {}

local player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local function getPanel(): Frame?
	local sg = playerGui:FindFirstChild("DACMain")
	if not sg then return nil end
	local panels = sg:FindFirstChild("Panels")
	if not panels then return nil end
	return panels:FindFirstChild("Items") :: Frame?
end

function ItemsPanel.init()
	local panel = getPanel()
	if not panel then return end

	local main = panel:FindFirstChild("Main")
	if not main then return end

	local label = main:FindFirstChild("ComingSoon")
	if not label then
		local lbl = Instance.new("TextLabel")
		lbl.Name = "ComingSoon"
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 24
		lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
		lbl.Text = "Coming Soon..."
		lbl.Parent = main
	end
end

return ItemsPanel
