--!strict
--[[
	Rebirth Upgrades Panel.
	Opened only via zone proximity (RebirthUpgrades zone).
	Shows all 7 gem-purchasable stats with current level, bonus %, and buy button.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local Utils = require(DAC:WaitForChild("Utils"))
local RebirthUpgradeConfig = require(DAC:WaitForChild("Config"):WaitForChild("RebirthUpgradeConfig"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local RemoteFailSafe = require(DAC:WaitForChild("RemoteFailSafe"))

local RebirthUpgradesPanel = {}

local player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local function getPanel(): Frame?
	local sg = playerGui:FindFirstChild("DACMain")
	if not sg then return nil end
	local panels = sg:FindFirstChild("Panels")
	if not panels then return nil end
	return panels:FindFirstChild("RebirthUpgrades") :: Frame?
end

function RebirthUpgradesPanel.populate(data: any)
	local panel = getPanel()
	if not panel then return end
	local main = panel:FindFirstChild("Main") :: Frame?
	if not main then return end

	local gemsLabel = main:FindFirstChild("GemsBalance") :: TextLabel?
	if gemsLabel then
		gemsLabel.Text = "Gems: " .. Utils.formatNumber((data and data.gems) or 0)
	end

	local scroll = main:FindFirstChild("Stats") :: ScrollingFrame?
	if not scroll then return end

	local template = scroll:FindFirstChild("StatTemplate")
	if template then
		template.Visible = false
	end

	for _, ch in scroll:GetChildren() do
		if ch:IsA("GuiObject") and ch.Name ~= "StatTemplate" and not ch:IsA("UIListLayout") and not ch:IsA("UIGridLayout") then
			ch:Destroy()
		end
	end

	local upgrades = (data and data.rebirthUpgrades) or {}
	local sortedStats = RebirthUpgradeConfig.getSortedStats()

	for _, statDef in sortedStats do
		local currentPoints = (upgrades :: any)[statDef.id] or 0
		local maxPoints = RebirthUpgradeConfig.getMaxPoints(statDef.id)
		local currentPct = RebirthUpgradeConfig.getCurrentPercent(statDef.id, currentPoints)
		local isMaxed = currentPoints >= maxPoints
		local cost = statDef.costPerPoint

		local row: Frame
		if template then
			row = template:Clone() :: Frame
		else
			row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 48)
		end
		row.Name = statDef.id
		row.Visible = true
		row.LayoutOrder = statDef.order

		local nameLabel = row:FindFirstChild("Name") :: TextLabel?
		if nameLabel then
			nameLabel.Text = statDef.name
		end

		local valueLabel = row:FindFirstChild("Value") :: TextLabel?
		if valueLabel then
			if statDef.id == "moreEggsAtOnce" or statDef.id == "moreRebirthSkips" then
				valueLabel.Text = "+" .. tostring(currentPoints)
			else
				valueLabel.Text = "+" .. tostring(currentPct) .. "%"
			end
		end

		local buyBtn = row:FindFirstChild("Buy") :: TextButton?
		if buyBtn then
			if isMaxed then
				buyBtn.Text = "MAX"
				buyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
				buyBtn.Active = false
			else
				buyBtn.Text = tostring(cost) .. " Gems"
				local canAfford = data and (data.gems or 0) >= cost
				buyBtn.BackgroundColor3 = canAfford and Color3.fromRGB(80, 180, 80) or Color3.fromRGB(140, 140, 155)
				buyBtn.Active = canAfford or false

				local sid = statDef.id
				buyBtn.MouseButton1Click:Connect(function()
					SoundFacade.playOneShot("click")
					RemoteFailSafe.fireEvent("UPGRADE", "BuyRebirthUpgrade", sid)
				end)
			end
		end

		row.Parent = scroll
	end
end

function RebirthUpgradesPanel.init()
	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(data)
		local panel = getPanel()
		if panel and panel.Visible then
			RebirthUpgradesPanel.populate(data)
		end
	end)
end

return RebirthUpgradesPanel
