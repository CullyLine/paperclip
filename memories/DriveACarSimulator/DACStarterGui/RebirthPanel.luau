--!strict
--[[
	Rebirth panel.
	UI is pre-built in DACMain.Panels.Rebirth; this script only wires behavior.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Utils = require(DAC:WaitForChild("Utils"))
local RebirthConfig = require(DAC:WaitForChild("Config"):WaitForChild("RebirthConfig"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local SocialFeedConfig = require(DAC:WaitForChild("Config"):WaitForChild("SocialFeedConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local RemoteFailSafe = require(DAC:WaitForChild("RemoteFailSafe"))
local RebirthClientState = require(DAC:WaitForChild("RebirthClientState"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local ClientRemoteDebounce = require(DAC:WaitForChild("ClientRemoteDebounce"))

local RebirthPanel = {}

local lastRebirthFire = { 0 }

function RebirthPanel.init()
	local sg = MenuHub.getScreenGui()
	local root = sg:WaitForChild("Rebirth") :: Frame

	local info = root:WaitForChild("Info") :: TextLabel
	local almostTier = root:WaitForChild("AlmostNextTier") :: TextLabel
	local celebrate = root:WaitForChild("RebirthCelebrate") :: TextLabel
	local celebrateScale = celebrate:WaitForChild("UIScale") :: UIScale
	local statPreview = root:WaitForChild("RebirthStatPreview") :: TextLabel
	local teaser = root:WaitForChild("RebirthTeaser") :: TextLabel
	local goBtn = root:WaitForChild("RebirthBtn") :: TextButton

	local prevRebirths: number? = nil
	local teaserIdx = 1
	local lastRebirthForTeaser = 0
	local teaserTask: thread? = nil

	local function stopTeaserCycle()
		if teaserTask then task.cancel(teaserTask); teaserTask = nil end
	end

	local function tryStartTeaserCycle()
		if #MicrocopyConfig.RebirthTeaser == 0 then return end
		if lastRebirthForTeaser ~= 0 or not root.Visible then return end
		if teaserTask then return end
		teaser.Visible = true
		teaserIdx = math.random(1, #MicrocopyConfig.RebirthTeaser)
		teaser.Text = MicrocopyConfig.RebirthTeaser[teaserIdx]
		teaser.TextTransparency = 0
		teaserTask = task.spawn(function()
			while root.Parent and lastRebirthForTeaser == 0 do
				task.wait(4)
				if lastRebirthForTeaser > 0 or not root.Visible then break end
				local nextIdx = (teaserIdx % #MicrocopyConfig.RebirthTeaser) + 1
				local out = TweenService:Create(teaser, TweenInfo.new(0.35), { TextTransparency = 1 })
				out:Play(); out.Completed:Wait()
				if lastRebirthForTeaser > 0 then break end
				teaserIdx = nextIdx
				teaser.Text = MicrocopyConfig.RebirthTeaser[teaserIdx]
				TweenService:Create(teaser, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()
			end
			teaserTask = nil
		end)
	end

	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible then tryStartTeaserCycle() else stopTeaserCycle() end
	end)

	-- Global VFX + audio payoff: VFXController.onPlayerDataUpdate → rebirthFlash (deduped).
	-- Panel-only: staged stat reveal + count-up when Rebirth menu is open.

	local statPreviewScale = statPreview:FindFirstChildOfClass("UIScale") :: UIScale?
	local CEREMONY_HIDE_SEC = 5.5

	local function showRebirthCelebrationUI(newCount: number)
		celebrate.Visible = true
		statPreview.Visible = true
		local cel = MicrocopyConfig.RebirthCelebration[math.random(1, #MicrocopyConfig.RebirthCelebration)]
		celebrate.Text = cel:gsub("{COUNT}", tostring(newCount))
		local resetBits = {}
		if RebirthConfig.ResetOnRebirth.coins then table.insert(resetBits, "coins") end
		if RebirthConfig.ResetOnRebirth.eggs then table.insert(resetBits, "eggs") end
		if RebirthConfig.ResetOnRebirth.carUpgrades then table.insert(resetBits, "car upgrade levels") end
		local resetStr = if #resetBits > 0 then table.concat(resetBits, ", ") else "\u{2014}"

		local rGas = RebirthConfig.Rewards.gasBoost
		local rPow = RebirthConfig.Rewards.powerBoost
		local rSpd = RebirthConfig.Rewards.speedBoost

		statPreview.TextTransparency = 1
		if statPreviewScale then
			statPreviewScale.Scale = 0.92
		end
		statPreview.Text = "Gained: +0 Gas, +0 Power, +0 Speed.\nReset: " .. resetStr .. "."

		celebrateScale.Scale = 0.2
		TweenService:Create(celebrateScale, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

		task.delay(0.22, function()
			if not statPreview.Parent then
				return
			end
			local steps = 7
			for s = 0, steps do
				if not statPreview.Parent then
					return
				end
				local t = s / steps
				local g = math.floor(rGas * t + 0.5)
				local p = math.floor(rPow * t + 0.5)
				local sp = math.floor(rSpd * t + 0.5)
				statPreview.Text = "Gained: +"
					.. tostring(g)
					.. " Gas, +"
					.. tostring(p)
					.. " Power, +"
					.. tostring(sp)
					.. " Speed.\nReset: "
					.. resetStr
					.. "."
				statPreview.TextTransparency = 1 - t
				if statPreviewScale then
					statPreviewScale.Scale = 0.92 + 0.08 * t
				end
				task.wait(0.038)
			end
			if statPreview.Parent then
				statPreview.TextTransparency = 0
				if statPreviewScale then
					TweenService:Create(statPreviewScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				end
			end
		end)

		task.delay(CEREMONY_HIDE_SEC, function()
			if celebrate.Parent then
				celebrate.Visible = false
				statPreview.Visible = false
			end
		end)
	end

	local function refresh()
		local data = Remotes.getFunction("GetPlayerData"):InvokeServer()
		if not data then return end
		local r = math.floor(tonumber(data.rebirths) or 0)
		RebirthClientState.clearIfRebirthAdvanced(r)
		if prevRebirths ~= nil and r > prevRebirths then
			if root.Visible then
				showRebirthCelebrationUI(r)
			end
		end
		prevRebirths = r
		lastRebirthForTeaser = r
		local cost = Utils.calculateRebirthCost(data.rebirths, RebirthConfig.BaseCost, RebirthConfig.CostMultiplier)
		local rGas = RebirthConfig.Rewards.gasBoost
		local rPow = RebirthConfig.Rewards.powerBoost
		local rSpd = RebirthConfig.Rewards.speedBoost
		local rebirthN = math.floor(tonumber(data.rebirths) or 0)
		local firstTimeHint = if rebirthN == 0
			then "First rebirth: spend your coin bank once to unlock permanent bonuses.\n\n"
			else ""
		info.Text = "Rebirths: "
			.. tostring(rebirthN)
			.. "\nCost: "
			.. Utils.formatNumber(cost)
			.. " coins (need at least this many; your coins go to 0 after rebirth)\n\n"
			.. firstTimeHint
			.. "Each rebirth: +"
			.. tostring(rGas)
			.. " Gas, +"
			.. tostring(rPow)
			.. " Power, +"
			.. tostring(rSpd)
			.. " Speed — permanent (stack forever)\n\n"
			.. "Resets: coins, egg inventory, all car upgrade levels\n"
			.. "Keeps: owned cars, pets, other world currencies"
		local coins = math.floor(tonumber(data.coins) or 0)
		local pctToward = if cost > 0 then math.clamp(coins / cost, 0, 1) else 0
		local nearRebirth = cost > 0 and coins < cost and coins >= cost * 0.8
		if nearRebirth then
			local tpl = SocialFeedConfig.pickLine("AlmostNextTier")
			almostTier.Text = tpl:gsub("{PERCENT}", tostring(math.floor(pctToward * 100))):gsub("{TARGET}", "your next Rebirth")
			almostTier.Visible = true
		else
			almostTier.Visible = false; almostTier.Text = ""
		end
		if r > 0 then stopTeaserCycle(); teaser.Visible = false
		else tryStartTeaserCycle() end
	end

	goBtn.MouseButton1Click:Connect(function()
		if not ClientRemoteDebounce.allow(lastRebirthFire) then
			return
		end
		local exp = if prevRebirths ~= nil then prevRebirths else 0
		if not RebirthClientState.begin(exp) then
			return
		end
		-- Staged ceremony: confirm / anticipation (riser), then server request after ~0.3s (matches debounce window).
		SoundFacade.playOneShot("rebirth_riser")
		task.delay(0.3, function()
			if not goBtn.Parent then
				return
			end
			if not RemoteFailSafe.fireEvent("REBIRTH", "Rebirth", exp) then
				RebirthClientState.forceRelease()
			end
		end)
	end)

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(_data: any)
		refresh()
	end)

	RebirthClientState.registerPrimaryButton(goBtn)
	refresh()
end

return RebirthPanel
