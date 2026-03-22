--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Utils = require(DAC:WaitForChild("Utils"))
local RebirthConfig = require(DAC:WaitForChild("Config"):WaitForChild("RebirthConfig"))
local RebirthMilestoneConfig = require(DAC:WaitForChild("Config"):WaitForChild("RebirthMilestoneConfig"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local SocialFeedConfig = require(DAC:WaitForChild("Config"):WaitForChild("SocialFeedConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))

local RebirthPanel = {}

function RebirthPanel.init()
	local sg = MenuHub.getScreenGui()
	local root = UIHelpers.panel(sg, "RebirthRoot")
	MenuHub.registerPanel("rebirth", root)
	UIHelpers.titleBar(root, "Rebirth", function()
		root.Visible = false
	end)

	local info = Instance.new("TextLabel")
	info.Name = "Info"
	info.Size = UDim2.new(1, -24, 0, 120)
	info.Position = UDim2.new(0, 12, 0, 52)
	info.BackgroundTransparency = 1
	info.Font = Enum.Font.Gotham
	info.TextSize = 15
	info.TextColor3 = Color3.fromRGB(240, 240, 240)
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.TextYAlignment = Enum.TextYAlignment.Top
	info.TextWrapped = true
	info.Parent = root

	local almostTier = Instance.new("TextLabel")
	almostTier.Name = "AlmostNextTier"
	almostTier.Size = UDim2.new(1, -24, 0, 36)
	almostTier.Position = UDim2.new(0, 12, 0, 172)
	almostTier.BackgroundTransparency = 1
	almostTier.Font = Enum.Font.GothamBold
	almostTier.TextSize = 12
	almostTier.TextColor3 = Color3.fromRGB(255, 200, 120)
	almostTier.TextXAlignment = Enum.TextXAlignment.Left
	almostTier.TextYAlignment = Enum.TextYAlignment.Top
	almostTier.TextWrapped = true
	almostTier.Visible = false
	almostTier.Text = ""
	almostTier.ZIndex = 4
	almostTier.Parent = root

	local celebrate = Instance.new("TextLabel")
	celebrate.Name = "RebirthCelebrate"
	celebrate.Size = UDim2.new(1, -24, 0, 44)
	celebrate.Position = UDim2.new(0, 12, 0, 218)
	celebrate.BackgroundTransparency = 1
	celebrate.Font = Enum.Font.GothamBlack
	celebrate.TextSize = 26
	celebrate.TextColor3 = Color3.fromRGB(255, 220, 90)
	celebrate.TextStrokeTransparency = 0.35
	celebrate.TextStrokeColor3 = Color3.fromRGB(80, 40, 0)
	celebrate.TextXAlignment = Enum.TextXAlignment.Left
	celebrate.TextWrapped = true
	celebrate.Visible = false
	celebrate.Text = ""
	celebrate.ZIndex = 5
	celebrate.Parent = root
	local celebrateScale = Instance.new("UIScale")
	celebrateScale.Scale = 1
	celebrateScale.Parent = celebrate

	local statPreview = Instance.new("TextLabel")
	statPreview.Name = "RebirthStatPreview"
	statPreview.Size = UDim2.new(1, -24, 0, 96)
	statPreview.Position = UDim2.new(0, 12, 0, 268)
	statPreview.BackgroundTransparency = 1
	statPreview.Font = Enum.Font.Gotham
	statPreview.TextSize = 14
	statPreview.TextColor3 = Color3.fromRGB(200, 210, 230)
	statPreview.TextXAlignment = Enum.TextXAlignment.Left
	statPreview.TextYAlignment = Enum.TextYAlignment.Top
	statPreview.TextWrapped = true
	statPreview.Visible = false
	statPreview.Text = ""
	statPreview.ZIndex = 5
	statPreview.Parent = root

	local prevRebirths: number? = nil

	local teaser = Instance.new("TextLabel")
	teaser.Name = "RebirthTeaser"
	teaser.Size = UDim2.new(1, -24, 0, 40)
	teaser.Position = UDim2.new(0, 12, 0, 318)
	teaser.BackgroundTransparency = 1
	teaser.Font = Enum.Font.Gotham
	teaser.TextSize = 13
	teaser.TextColor3 = Color3.fromRGB(200, 210, 230)
	teaser.TextXAlignment = Enum.TextXAlignment.Left
	teaser.TextYAlignment = Enum.TextYAlignment.Top
	teaser.TextWrapped = true
	teaser.Visible = false
	teaser.Text = ""
	teaser.Parent = root

	local teaserIdx = 1
	local lastRebirthForTeaser = 0
	local teaserTask: thread? = nil

	local function stopTeaserCycle()
		if teaserTask then
			task.cancel(teaserTask)
			teaserTask = nil
		end
	end

	local function tryStartTeaserCycle()
		if #MicrocopyConfig.RebirthTeaser == 0 then
			return
		end
		if lastRebirthForTeaser ~= 0 or not root.Visible then
			return
		end
		if teaserTask then
			return
		end
		teaser.Visible = true
		teaserIdx = math.random(1, #MicrocopyConfig.RebirthTeaser)
		teaser.Text = MicrocopyConfig.RebirthTeaser[teaserIdx]
		teaser.TextTransparency = 0
		teaserTask = task.spawn(function()
			while root.Parent and lastRebirthForTeaser == 0 do
				task.wait(4)
				if lastRebirthForTeaser > 0 or not root.Visible then
					break
				end
				local nextIdx = (teaserIdx % #MicrocopyConfig.RebirthTeaser) + 1
				local out = TweenService:Create(teaser, TweenInfo.new(0.35), { TextTransparency = 1 })
				out:Play()
				out.Completed:Wait()
				if lastRebirthForTeaser > 0 then
					break
				end
				teaserIdx = nextIdx
				teaser.Text = MicrocopyConfig.RebirthTeaser[teaserIdx]
				local inn = TweenService:Create(teaser, TweenInfo.new(0.35), { TextTransparency = 0 })
				inn:Play()
			end
			teaserTask = nil
		end)
	end

	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible then
			tryStartTeaserCycle()
		else
			stopTeaserCycle()
		end
	end)

	-- World / screen juice: must run even when the rebirth menu is closed.
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
		if RebirthConfig.ResetOnRebirth.coins then
			table.insert(resetBits, "coins")
		end
		if RebirthConfig.ResetOnRebirth.eggs then
			table.insert(resetBits, "eggs")
		end
		if RebirthConfig.ResetOnRebirth.carUpgrades then
			table.insert(resetBits, "car upgrade levels")
		end
		local resetStr = if #resetBits > 0 then table.concat(resetBits, ", ") else "—"
		statPreview.Text = `Gained: +{RebirthConfig.Rewards.gasBoost} Gas, +{RebirthConfig.Rewards.powerBoost} Power, +{RebirthConfig.Rewards.speedBoost} Speed, +{RebirthConfig.Rewards.crystals} Crystals.\nReset: {resetStr}.`
		celebrateScale.Scale = 0.2
		TweenService:Create(celebrateScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(5, function()
			if celebrate.Parent then
				celebrate.Visible = false
				statPreview.Visible = false
			end
		end)
	end

	local function refresh()
		local data = Remotes.getFunction("GetPlayerData"):InvokeServer()
		if not data then
			return
		end
		local r = math.floor(tonumber(data.rebirths) or 0)
		if prevRebirths ~= nil and r > prevRebirths then
			playRebirthCelebrationGlobal(r)
			if root.Visible then
				showRebirthCelebrationUI(r)
			end
		end
		prevRebirths = r
		lastRebirthForTeaser = r
		local cost = Utils.calculateRebirthCost(data.rebirths, RebirthConfig.BaseCost, RebirthConfig.CostMultiplier)
		info.Text = `Rebirths: {data.rebirths}\nCost: {Utils.formatNumber(cost)} coins (must have at least this many; coins reset on rebirth)\n\nRewards: +{RebirthConfig.Rewards.gasBoost} Gas, +{RebirthConfig.Rewards.powerBoost} Power, +{RebirthConfig.Rewards.speedBoost} Speed, +{RebirthConfig.Rewards.crystals} Crystals\n\nWARNING: Resets coins, eggs, and car upgrade levels per config.`
		local coins = math.floor(tonumber(data.coins) or 0)
		local pctToward = if cost > 0 then math.clamp(coins / cost, 0, 1) else 0
		local nearRebirth = cost > 0 and coins < cost and coins >= cost * 0.8
		if nearRebirth then
			local tpl = SocialFeedConfig.pickLine("AlmostNextTier")
			almostTier.Text = tpl
				:gsub("{PERCENT}", tostring(math.floor(pctToward * 100)))
				:gsub("{TARGET}", "your next Rebirth")
			almostTier.Visible = true
		else
			almostTier.Visible = false
			almostTier.Text = ""
		end
		if r > 0 then
			stopTeaserCycle()
			teaser.Visible = false
		else
			tryStartTeaserCycle()
		end
	end

	local go = UIHelpers.textButton(root, "REBIRTH NOW", Color3.fromRGB(230, 100, 60), 1, function()
		SoundFacade.playOneShot("rebirth")
		Remotes.getEvent("Rebirth"):FireServer()
		task.wait(0.1)
		refresh()
	end)
	go.Position = UDim2.new(0.5, 0, 1, -56)
	go.AnchorPoint = Vector2.new(0.5, 0)
	go.Size = UDim2.new(0.5, 0, 0, 44)

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(_data: any)
		refresh()
	end)

	refresh()
end

return RebirthPanel
