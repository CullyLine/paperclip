--!strict
--[[
	POLA-618: Single place to tear down transient PlayerGui overlays on **character respawn**
	and before **world-travel fade** so run-end UI, purchase overlays, and duplicate stacks
	do not linger across lifecycle events.
]]

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))

local ClientUiLifecycle = {}

export type TeardownReason = "character_respawn" | "world_travel_fade"

local initDone = false
local charConn: RBXScriptConnection? = nil

local function tryRequireModule(inst: Instance?): any
	if not inst or not inst:IsA("ModuleScript") then
		return nil
	end
	local ok, mod = pcall(require, inst)
	if ok then
		return mod
	end
	return nil
end

local function destroyEphemeralScreenGuis(playerGui: PlayerGui)
	for _, ch in playerGui:GetChildren() do
		if ch:IsA("ScreenGui") then
			local n = ch.Name
			if n == "DailyRewardCelebration" or n == "DACPurchaseThankYou" then
				ch:Destroy()
			end
		end
	end
end

local function tearDownStarterGuiModules(player: Player)
	local pg = player:FindFirstChild("PlayerGui") :: PlayerGui?
	if not pg then
		return
	end
	local dac = pg:FindFirstChild("DAC")
	if dac then
		local pp = dac:FindFirstChild("PayoutPanel")
		local payout = if pp and pp:IsA("ModuleScript") then tryRequireModule(pp) else nil
		if type(payout) == "table" and type((payout :: any).forceTeardown) == "function" then
			(payout :: any).forceTeardown()
		end
	end

	local ps = player:FindFirstChild("PlayerScripts")
	if not ps then
		return
	end
	local dacPs = ps:FindFirstChild("DAC")
	local ctrls = dacPs and dacPs:FindFirstChild("Controllers")
	if not ctrls then
		return
	end
	for _, name in { "PurchaseThankYouController", "VehicleEnterJuiceController", "RetentionController" } do
		local ms = ctrls:FindFirstChild(name)
		local m = if ms and ms:IsA("ModuleScript") then tryRequireModule(ms) else nil
		if type(m) == "table" and type((m :: any).tearDownForLifecycle) == "function" then
			(m :: any).tearDownForLifecycle()
		end
	end
end

function ClientUiLifecycle.tearDownTransientUi(reason: TeardownReason)
	local player = Players.LocalPlayer
	if not player then
		return
	end
	local pg = player:FindFirstChild("PlayerGui") :: PlayerGui?
	if not pg then
		return
	end

	destroyEphemeralScreenGuis(pg)
	tearDownStarterGuiModules(player)

	if reason == "character_respawn" then
		VFXFacade.resetTravelFlashState()
	end
end

function ClientUiLifecycle.init(player: Player)
	if initDone then
		return
	end
	initDone = true

	if charConn then
		charConn:Disconnect()
		charConn = nil
	end
	charConn = player.CharacterAdded:Connect(function()
		task.defer(function()
			ClientUiLifecycle.tearDownTransientUi("character_respawn")
		end)
	end)
end

return ClientUiLifecycle
