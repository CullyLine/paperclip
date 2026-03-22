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
local RebirthMilestoneConfig = require(DAC:WaitForChild("Config"):WaitForChild("RebirthMilestoneConfig"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local SocialFeedConfig = require(DAC:WaitForChild("Config"):WaitForChild("SocialFeedConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))

local RebirthPanel = {}

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

	local function playRebirthCelebrationGlobal(newCount: number)
		SoundFacade.playOneShot("rebirth_confetti")
		local milestone = RebirthMilestoneConfig.getHighestMilestoneCrossed(prevRebirths or 0, newCount)
		VFXFacade.rebirthFlash(newCount, milestone)
	end

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
		statPreview.Text = "Gained: +" .. tostring(RebirthConfig.Rewards.gasBoost) .. " Gas, +" .. tostring(RebirthConfig.Rewards.powerBoost) .. " Power, +" .. tostring(RebirthConfig.Rewards.speedBoost) .. " Speed, +" .. tostring(RebirthConfig.Rewards.crystals) .. " Crystals.\nReset: " .. resetStr .. "."
		celebrateScale.Scale = 0.2
		TweenService:Create(celebrateScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(5, function()
			if celebrate.Parent then celebrate.Visible = false; statPreview.Visible = false end
		end)
	end

	local function refresh()
		local data = Remotes.getFunction("GetPlayerData"):InvokeServer()
		if not data then return end
		local r = math.floor(tonumber(data.rebirths) or 0)
		if prevRebirths ~= nil and r > prevRebirths then
			playRebirthCelebrationGlobal(r)
			if root.Visible then showRebirthCelebrationUI(r) end
		end
		prevRebirths = r
		lastRebirthForTeaser = r
		local cost = Utils.calculateRebirthCost(data.rebirths, RebirthConfig.BaseCost, RebirthConfig.CostMultiplier)
		info.Text = "Rebirths: " .. tostring(data.rebirths) .. "\nCost: " .. Utils.formatNumber(cost) .. " coins (must have at least this many; coins reset on rebirth)\n\nRewards: +" .. tostring(RebirthConfig.Rewards.gasBoost) .. " Gas, +" .. tostring(RebirthConfig.Rewards.powerBoost) .. " Power, +" .. tostring(RebirthConfig.Rewards.speedBoost) .. " Speed, +" .. tostring(RebirthConfig.Rewards.crystals) .. " Crystals\n\nWARNING: Resets coins, eggs, and car upgrade levels per config."
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
		SoundFacade.playOneShot("rebirth")
		Remotes.getEvent("Rebirth"):FireServer()
		task.wait(0.1)
		refresh()
	end)

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(_data: any)
		refresh()
	end)

	refresh()
end

return RebirthPanel
