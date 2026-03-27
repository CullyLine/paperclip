--!strict
--[[
	Headless egg-hatch handler: pity streak tracking + first-session onboarding.
	Egg Shop panel UI lives in DACMain.Panels.EggStore (wired by UIController.wireEggStorePanel).
	Shop afford states + spotlight / breathe juice are driven from UIController (Egg Buy popup + slots).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Constants = require(DAC:WaitForChild("Constants"))
local Remotes = require(DAC:WaitForChild("Remotes"))

local EggShopPanel = {}

local function showFirstSessionNotification(msg: string)
	task.defer(function()
		local ps = Players.LocalPlayer:FindFirstChild("PlayerScripts")
		if not ps then
			return
		end
		local dac = ps:FindFirstChild("DAC")
		local ctrls = dac and dac:FindFirstChild("Controllers")
		local mod = ctrls and ctrls:FindFirstChild("UIController")
		if not mod or not mod:IsA("ModuleScript") then
			return
		end
		local ok, uc = pcall(require, mod)
		if ok and type(uc) == "table" then
			if type((uc :: any).showToast) == "function" then
				(uc :: any).showToast({ type = "success", message = msg })
			elseif uc.showNotification then
				uc.showNotification({ type = "success", message = msg })
			end
		end
	end)
end

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
		task.defer(function()
			local ok, r = pcall(function()
				return Remotes.getFunction("FirstSessionOnboarding"):InvokeServer({ kind = "prepareFirstHatch" })
			end)
			if ok and type(r) == "table" and r.applied == true then
				local msg = r.mainLine
				if type(r.hookLine) == "string" and r.hookLine ~= "" then
					msg = msg .. "\n" .. r.hookLine
				end
				showFirstSessionNotification(msg)
			end
		end)
	end)
end

return EggShopPanel
