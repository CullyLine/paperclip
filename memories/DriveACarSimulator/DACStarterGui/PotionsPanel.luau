--!strict
--[[
	Potions Inventory Panel.
	Shows stackable consumable boosts the player owns.
	Potions are stored in data.potions as { [potionId]: count }.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local Utils = require(DAC:WaitForChild("Utils"))

local PotionsPanel = {}

local player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local function getPanel(): Frame?
	local sg = playerGui:FindFirstChild("DACMain")
	if not sg then return nil end
	local panels = sg:FindFirstChild("Panels")
	if not panels then return nil end
	return panels:FindFirstChild("Potions") :: Frame?
end

function PotionsPanel.populate(data: any)
	local panel = getPanel()
	if not panel then return end
	local main = panel:FindFirstChild("Main") :: ScrollingFrame?
	if not main then return end

	local scroll = main:FindFirstChild("Inventory") or main :: ScrollingFrame
	if not scroll then return end

	local template = scroll:FindFirstChild("PotionTemplate")
	if template then
		template.Visible = false
	end

	for _, ch in scroll:GetChildren() do
		if ch:IsA("GuiObject") and ch.Name ~= "PotionTemplate" and not ch:IsA("UIGridLayout") and not ch:IsA("UIListLayout") then
			ch:Destroy()
		end
	end

	if type(data) ~= "table" or type(data.potions) ~= "table" then
		return
	end

	local emptyLabel = scroll:FindFirstChild("EmptyLabel") :: TextLabel?
	local hasAny = false

	for potionId, count in data.potions do
		if type(count) ~= "number" or count <= 0 then
			continue
		end
		hasAny = true

		if template then
			local item = template:Clone()
			item.Name = potionId
			item.Visible = true

			local nameLabel = item:FindFirstChild("Name")
			if nameLabel and nameLabel:IsA("TextLabel") then
				nameLabel.Text = potionId .. " x" .. tostring(count)
			end

			item.Parent = scroll
		end
	end

	if emptyLabel then
		emptyLabel.Visible = not hasAny
	end
end

function PotionsPanel.init()
	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(data)
		local panel = getPanel()
		if panel and panel.Visible then
			PotionsPanel.populate(data)
		end
	end)
end

return PotionsPanel
