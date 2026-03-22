--!strict
--[[
	Centralized failure UX: copy from MicrocopyConfig, SFX via SoundFacade,
	VFX via VFXFacade (shake, toast). UI panels pass optional GuiButton to pulse.
]]

local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))

local FailureFeedback = {}

local POOLS: { [string]: { string } } = {
	purchase_fail = MicrocopyConfig.PurchaseFail,
	equip_fail = MicrocopyConfig.EquipLocked,
	egg_fail = MicrocopyConfig.EggFail,
	fuel_empty = MicrocopyConfig.FuelEmpty,
	quest_fail = MicrocopyConfig.QuestFail,
}

local function pickLine(pool: { string }): string
	if #pool == 0 then
		return "Something went wrong."
	end
	return pool[math.random(1, #pool)]
end

local function pulseButton(btn: GuiButton)
	local orig = btn.BackgroundColor3
	TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = Color3.fromRGB(230, 60, 60),
	}):Play()
	task.delay(0.15, function()
		if btn.Parent then
			TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = orig,
			}):Play()
		end
	end)
end

local SHOW_ALIASES: { [string]: string } = {
	fuelEmpty = "fuel_empty",
	purchaseFail = "purchase_fail",
	equipFail = "equip_fail",
	eggFail = "egg_fail",
	questFail = "quest_fail",
}

function FailureFeedback.show(kind: string, context: { [string]: any }?)
	local key = SHOW_ALIASES[kind] or kind
	FailureFeedback.fire(key, context)
end

function FailureFeedback.fire(feedbackType: string, context: { [string]: any }?)
	local pool = POOLS[feedbackType]
	if not pool then
		pool = MicrocopyConfig.PurchaseFail
	end
	local line = pickLine(pool)

	local skipSound = type(context) == "table" and context.skipSound == true
	if not skipSound then
		if feedbackType == "purchase_fail" then
			SoundFacade.playOneShot("purchase_fail")
		elseif feedbackType == "fuel_empty" then
			SoundFacade.playOneShot("fuel_empty")
		elseif feedbackType == "quest_fail" then
			SoundFacade.playOneShot("notification")
		else
			SoundFacade.playOneShot("error")
		end
	end

	VFXFacade.failureFeedback(line, feedbackType)

	if type(context) == "table" then
		local btn = context.button
		if btn and btn:IsA("GuiButton") then
			pulseButton(btn)
		end
	end
end

return FailureFeedback
