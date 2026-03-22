--!strict
--[[
	Headless egg-hatch handler: pity streak tracking + hatch VFX.
	No UI is created here — the Egg Shop UI lives in DACMain.Panels.EggStore
	and is wired by UIController.wireEggStorePanel().
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Constants = require(DAC:WaitForChild("Constants"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))

local EggShopPanel = {}

local pityNoRareStreak = 0

local function onHatchResultForPity(result: any)
	if type(result) ~= "table" then
		return
	end
	local r = result.rarity
	local order = Constants.RARITY_ORDER
	local tier = 1
	if type(r) == "string" then
		tier = order[string.lower(r)] or 1
	end
	local rareMin = order.rare or 3
	if tier >= rareMin then
		pityNoRareStreak = 0
	else
		pityNoRareStreak += 1
	end
end

function EggShopPanel.getNoRareStreak(): number
	return pityNoRareStreak
end

function EggShopPanel.init()
	Remotes.getEvent("HatchEgg").OnClientEvent:Connect(function(result)
		onHatchResultForPity(result)
		VFXFacade.hatchReveal(result)
	end)
end

return EggShopPanel
