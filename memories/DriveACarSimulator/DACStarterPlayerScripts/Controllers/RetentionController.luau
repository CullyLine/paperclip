--!strict
--[[
	Idle session retention popup: after prolonged AFK, one dismissible reminder per session.
	Does not show while the player is in an active driving run.

	Daily streak FOMO: timed toasts at 6h / 2h / 30m before streak loss (48h claim window),
	StreakLost commiseration, and periodic PlayStreak celebration while streak is active.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local Constants = require(DAC:WaitForChild("Constants"))
local SocialFeedConfig = require(DAC:WaitForChild("Config"):WaitForChild("SocialFeedConfig"))
local BattlePassConfig = require(DAC:WaitForChild("Config"):WaitForChild("BattlePassConfig"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local DailyRewardConfig = require(DAC:WaitForChild("Config"):WaitForChild("DailyRewardConfig"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

local DrivingController = require(script.Parent:WaitForChild("DrivingController"))
local UIController = require(script.Parent:WaitForChild("UIController"))

local player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local IDLE_SECONDS = 15 * 60
local MOUSE_MOVE_THRESHOLD = 6

local STREAK_RESET_SEC = DailyRewardConfig.STREAK_RESET_SECONDS
local STREAK_WARN_6H = 6 * 3600
local STREAK_WARN_2H = 2 * 3600
local STREAK_WARN_30M = 30 * 60
local PLAY_STREAK_INTERVAL_SEC = 5 * 60

local RetentionController = {}

local lastActivityClock = os.clock()
local lastMousePos: Vector2? = nil
local shownThisSession = false
local gui: ScreenGui? = nil
local inputConns: { RBXScriptConnection } = {}

-- Daily streak nudges (session-local)
local streakFired6h = false
local streakFired2h = false
local streakFired30m = false
local streakShownLostToast = false
local streakPrevTimeLeft: number? = nil
local streakLastClaimSeen: number? = nil
local lastPlayStreakToastClock = 0.0

local function formatDuration(sec: number): string
	if sec <= 0 then
		return "soon"
	end
	if sec < 60 then
		return string.format("%ds", math.floor(sec + 0.5))
	end
	local m = math.floor(sec / 60)
	local s = math.floor(sec % 60)
	if m < 60 then
		return string.format("%dm %ds", m, s)
	end
	local h = math.floor(m / 60)
	m = m % 60
	return string.format("%dh %dm", h, m)
end

local function xpIntoCurrentTier(totalXp: number): (number, number, number)
	local remaining = totalXp
	for tier = 1, BattlePassConfig.TIER_COUNT do
		local need = BattlePassConfig.xpPerTier[tier]
		if remaining < need then
			return tier, need - remaining, need
		end
		remaining -= need
	end
	return BattlePassConfig.TIER_COUNT, 0, BattlePassConfig.xpPerTier[BattlePassConfig.TIER_COUNT]
end

local function getEggPityStreak(): number?
	local dac = playerGui:FindFirstChild("DAC")
	if not dac then
		return nil
	end
	local m = dac:FindFirstChild("EggShopPanel")
	if not m or not m:IsA("ModuleScript") then
		return nil
	end
	local ok, mod = pcall(require, m)
	if ok and type(mod) == "table" and type((mod :: any).getNoRareStreak) == "function" then
		return (mod :: any).getNoRareStreak()
	end
	return nil
end

local function buildContextLines(data: any): { string }
	local lines: { string } = {}
	if type(data) ~= "table" then
		return lines
	end

	local dr = data.dailyReward
	if type(dr) == "table" then
		local lastClaim = type(dr.lastClaim) == "number" and dr.lastClaim or 0
		local elapsed = os.time() - lastClaim
		if elapsed >= Constants.DAILY_REWARD_COOLDOWN then
			table.insert(lines, "Daily reward: ready to claim!")
		else
			local left = Constants.DAILY_REWARD_COOLDOWN - elapsed
			table.insert(lines, `Next daily reward in {formatDuration(left)}`)
		end
	end

	local bp = data.battlePass
	if type(bp) == "table" and type(bp.xp) == "number" then
		local tier, need, _cap = xpIntoCurrentTier(bp.xp)
		if need > 0 then
			table.insert(lines, `Battle Pass: {need} XP to tier {tier}`)
		else
			table.insert(lines, "Battle Pass: max tier reached this season")
		end
	end

	local pity = getEggPityStreak()
	if type(pity) == "number" and pity > 0 then
		table.insert(lines, `Egg pity: {pity} hatch(es) since last rare+`)
	end

	return lines
end

local function touchActivity()
	lastActivityClock = os.clock()
end

local function streakSubstitute(line: string, streak: number): string
	return line:gsub("{STREAK}", tostring(streak))
end

local function streakTick()
	if DrivingController.isInRun() then
		return
	end
	local data = UIController.getData()
	if type(data) ~= "table" or type(data.dailyReward) ~= "table" then
		return
	end
	local dr = data.dailyReward
	local streak = math.floor(tonumber(dr.streak) or 0)
	local lastClaim = math.floor(tonumber(dr.lastClaim) or 0)
	local lostStreak = math.floor(tonumber(dr.lastClaimLostStreak) or 0)

	if streakLastClaimSeen ~= lastClaim then
		streakLastClaimSeen = lastClaim
		streakPrevTimeLeft = nil
		streakFired6h = false
		streakFired2h = false
		streakFired30m = false
	end

	local now = os.time()
	local elapsed = now - lastClaim
	local inClaimWindow = streak >= 1 and elapsed <= STREAK_RESET_SEC

	if not streakShownLostToast then
		if streak >= 1 and elapsed > STREAK_RESET_SEC then
			streakShownLostToast = true
			local line = streakSubstitute(MicrocopyConfig.pickVariant(MicrocopyConfig.StreakLost), streak)
			UIController.showNotification({ type = "streak_nudge", message = line })
		elseif lostStreak > 0 then
			streakShownLostToast = true
			local line = streakSubstitute(MicrocopyConfig.pickVariant(MicrocopyConfig.StreakLost), lostStreak)
			UIController.showNotification({ type = "streak_nudge", message = line })
		end
	end

	if streak >= 2 and inClaimWindow then
		if os.clock() - lastPlayStreakToastClock >= PLAY_STREAK_INTERVAL_SEC then
			lastPlayStreakToastClock = os.clock()
			local line = streakSubstitute(MicrocopyConfig.pickVariant(MicrocopyConfig.PlayStreak), streak)
			UIController.showNotification({ type = "streak_celebrate", message = line })
		end
	end

	if not inClaimWindow or streak < 1 then
		return
	end

	local timeLeft = lastClaim + STREAK_RESET_SEC - now
	if timeLeft <= 0 then
		streakPrevTimeLeft = timeLeft
		return
	end

	if streakPrevTimeLeft == nil then
		streakPrevTimeLeft = timeLeft
		return
	end

	local prev = streakPrevTimeLeft
	streakPrevTimeLeft = timeLeft

	if not streakFired6h and prev > STREAK_WARN_6H and timeLeft <= STREAK_WARN_6H then
		streakFired6h = true
		local line = streakSubstitute(MicrocopyConfig.pickVariant(MicrocopyConfig.StreakWarning6h), streak)
		UIController.showNotification({ type = "streak_nudge", message = line })
	elseif not streakFired2h and prev > STREAK_WARN_2H and timeLeft <= STREAK_WARN_2H then
		streakFired2h = true
		local line = streakSubstitute(MicrocopyConfig.pickVariant(MicrocopyConfig.StreakWarning2h), streak)
		UIController.showNotification({ type = "streak_urgent", message = line })
	elseif not streakFired30m and prev > STREAK_WARN_30M and timeLeft <= STREAK_WARN_30M then
		streakFired30m = true
		local line = streakSubstitute(MicrocopyConfig.pickVariant(MicrocopyConfig.StreakWarning30m), streak)
		UIController.showNotification({ type = "streak_critical", message = line })
	end
end

local function hidePopup()
	if gui then
		gui.Enabled = false
	end
end

local function showPopup()
	if shownThisSession or gui == nil then
		return
	end
	if DrivingController.isInRun() then
		return
	end

	local ok, data = pcall(function()
		return Remotes.getFunction("GetPlayerData"):InvokeServer()
	end)
	if not ok then
		data = nil
	end

	local headline = SocialFeedConfig.pickLine("SessionEndRetention")
	local lines = buildContextLines(data)

	local card = gui:FindFirstChild("RetentionCard") :: Frame?
	local body = gui and gui:FindFirstChild("BodyText", true) :: TextLabel?
	local rowsFrame = gui and gui:FindFirstChild("ContextRows", true) :: Frame?
	if not card or not body or not rowsFrame then
		return
	end

	body.Text = headline
	for _, c in rowsFrame:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local layout = rowsFrame:FindFirstChildOfClass("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 8)
		layout.Parent = rowsFrame
	end
	for i, line in lines do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 36)
		row.BackgroundColor3 = Color3.fromRGB(240, 195, 220)
		row.BackgroundTransparency = 0.3
		row.LayoutOrder = i
		row.Parent = rowsFrame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = row
		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, -16, 1, -8)
		t.Position = UDim2.new(0, 8, 0, 4)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.Gotham
		t.TextSize = 13
		t.TextColor3 = Color3.fromRGB(40, 40, 50)
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextWrapped = true
		t.Text = line
		t.Parent = row
	end

	gui.Enabled = true
	shownThisSession = true

	local scale = card:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Scale = 0.85
		scale.Parent = card
	end
	scale.Scale = 0.85
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function pollIdle()
	if shownThisSession or gui == nil then
		return
	end
	if gui.Enabled then
		return
	end
	if DrivingController.isInRun() then
		return
	end
	if os.clock() - lastActivityClock >= IDLE_SECONDS then
		showPopup()
	end
end

function RetentionController.init()
	if gui then
		return
	end

	local sg = Instance.new("ScreenGui")
	sg.Name = "DACRetentionPopup"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = 550
	sg.Enabled = false
	sg.Parent = playerGui
	gui = sg

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.55
	backdrop.Text = ""
	backdrop.ZIndex = 1
	backdrop.Parent = sg
	backdrop.MouseButton1Click:Connect(function()
		touchActivity()
		hidePopup()
	end)

	local card = Instance.new("Frame")
	card.Name = "RetentionCard"
	card.Size = UDim2.fromOffset(340, 320)
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = Color3.fromRGB(255, 214, 238)
	card.BackgroundTransparency = 0.02
	card.ZIndex = 2
	card.Parent = sg
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 14)
	cardCorner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(42, 42, 64)
	stroke.Parent = card

	local header = Instance.new("TextLabel")
	header.Name = "HeaderLabel"
	header.Size = UDim2.new(1, -40, 0, 28)
	header.Position = UDim2.new(0.5, 0, 0, 16)
	header.AnchorPoint = Vector2.new(0.5, 0)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.TextSize = 22
	header.TextColor3 = Color3.fromRGB(30, 30, 30)
	header.Text = "Don't go yet!"
	header.ZIndex = 3
	header.Parent = card

	local dismiss = Instance.new("TextButton")
	dismiss.Name = "DismissBtn"
	dismiss.Size = UDim2.fromOffset(32, 32)
	dismiss.Position = UDim2.new(1, -6, 0, 4)
	dismiss.AnchorPoint = Vector2.new(1, 0)
	dismiss.BackgroundColor3 = Color3.fromRGB(255, 34, 34)
	dismiss.Text = "X"
	dismiss.Font = Enum.Font.GothamBold
	dismiss.TextSize = 18
	dismiss.TextColor3 = Color3.new(1, 1, 1)
	dismiss.ZIndex = 4
	dismiss.Parent = card
	Instance.new("UICorner", dismiss).CornerRadius = UDim.new(0, 8)
	dismiss.MouseButton1Click:Connect(function()
		touchActivity()
		hidePopup()
	end)

	local body = Instance.new("TextLabel")
	body.Name = "BodyText"
	body.Size = UDim2.new(1, -32, 0, 72)
	body.Position = UDim2.new(0, 16, 0, 52)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextSize = 15
	body.TextColor3 = Color3.fromRGB(50, 50, 50)
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.ZIndex = 3
	body.Parent = card

	local rowsFrame = Instance.new("Frame")
	rowsFrame.Name = "ContextRows"
	rowsFrame.Size = UDim2.new(1, -32, 0, 120)
	rowsFrame.Position = UDim2.new(0, 16, 0, 128)
	rowsFrame.BackgroundTransparency = 1
	rowsFrame.ZIndex = 3
	rowsFrame.Parent = card
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = rowsFrame

	local cta = Instance.new("TextButton")
	cta.Name = "KeepPlaying"
	cta.Size = UDim2.new(1, -32, 0, 44)
	cta.Position = UDim2.new(0.5, 0, 1, -16)
	cta.AnchorPoint = Vector2.new(0.5, 1)
	cta.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	cta.TextColor3 = Color3.new(1, 1, 1)
	cta.Font = Enum.Font.GothamBold
	cta.TextSize = 16
	cta.Text = "Keep Playing"
	cta.ZIndex = 3
	cta.Parent = card
	local ctaC = Instance.new("UICorner")
	ctaC.CornerRadius = UDim.new(0, 10)
	ctaC.Parent = cta
	cta.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("level_up")
		touchActivity()
		hidePopup()
	end)

	table.insert(inputConns, UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		touchActivity()
	end))

	table.insert(
		inputConns,
		Remotes.getEvent("StartRun").OnClientEvent:Connect(function()
			touchActivity()
		end)
	)
	table.insert(
		inputConns,
		Remotes.getEvent("EndRun").OnClientEvent:Connect(function()
			touchActivity()
		end)
	)

	table.insert(inputConns, UserInputService.InputChanged:Connect(function(input, gp)
		if gp then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local pos = input.Position
			if lastMousePos then
				local d = (Vector2.new(pos.X, pos.Y) - lastMousePos).Magnitude
				if d >= MOUSE_MOVE_THRESHOLD then
					touchActivity()
				end
			end
			lastMousePos = Vector2.new(pos.X, pos.Y)
		end
	end))

	task.spawn(function()
		while gui and gui.Parent do
			task.wait(1)
			pollIdle()
		end
	end)

	task.spawn(function()
		while gui and gui.Parent do
			task.wait(12)
			pcall(streakTick)
		end
	end)
end

return RetentionController
