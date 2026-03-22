--!strict
--[[
	Full-screen reward chest reveal: slide-in, wobble, lid pop, flying reward labels,
	coin-rain particles, staggered cha-ching, total counter, fade out.
	Triggered when UIController receives notification.type == "reward_claim".
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))
local Utils = require(DAC:WaitForChild("Utils"))

local RewardChestAnimation = {}

local player = Players.LocalPlayer

local activeRoot: Frame? = nil

export type RewardItem = {
	label: string,
	amount: number?,
	kind: string?,
}

export type RewardPayload = {
	type: string?,
	message: string?,
	title: string?,
	subtitle: string?,
	items: { RewardItem }?,
}

local KIND_COLORS: { [string]: Color3 } = {
	coins = Color3.fromRGB(255, 210, 80),
	gems = Color3.fromRGB(120, 220, 255),
	crystals = Color3.fromRGB(200, 140, 255),
	skulls = Color3.fromRGB(220, 220, 220),
	xp = Color3.fromRGB(120, 255, 160),
	pet = Color3.fromRGB(255, 160, 220),
	egg = Color3.fromRGB(255, 200, 120),
	car = Color3.fromRGB(180, 200, 255),
	premium = Color3.fromRGB(255, 230, 150),
}

local function colorForKind(kind: string?): Color3
	if not kind then
		return Color3.fromRGB(255, 245, 200)
	end
	return KIND_COLORS[kind] or Color3.fromRGB(255, 245, 200)
end

local function normalizeItems(payload: RewardPayload): { RewardItem }
	if type(payload.items) == "table" and #payload.items > 0 then
		return payload.items :: { RewardItem }
	end
	local msg = if type(payload.message) == "string" then payload.message else "Reward"
	return { { label = msg, kind = "coins" } }
end

local function formatItemLine(it: RewardItem): string
	if it.amount and it.amount > 0 then
		return `+{Utils.formatNumber(it.amount)} {it.label}`
	end
	return it.label
end

local function estimateTotalNumber(items: { RewardItem }): number
	local sum = 0
	local any = false
	for _, it in items do
		if type(it.amount) == "number" and it.amount > 0 then
			local k = it.kind or ""
			if k == "coins" or k == "gems" or k == "crystals" or k == "skulls" or k == "xp" then
				sum += it.amount
				any = true
			end
		end
	end
	if any then
		return sum
	end
	return 0
end

local function destroyActive()
	if activeRoot and activeRoot.Parent then
		activeRoot:Destroy()
	end
	activeRoot = nil
end

function RewardChestAnimation.play(payload: RewardPayload)
	destroyActive()

	local items = normalizeItems(payload)
	local screenGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local host = screenGui:FindFirstChild("DACMain") :: ScreenGui?
	if not host then
		return
	end

	VFXFacade.rewardChestBurst()

	local root = Instance.new("Frame")
	root.Name = "RewardChestOverlay"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.new(0, 0, 0)
	root.BackgroundTransparency = 0.45
	root.BorderSizePixel = 0
	root.ZIndex = 900
	root.Active = true
	root.Parent = host
	activeRoot = root

	local titleText = if type(payload.title) == "string" and payload.title ~= "" then payload.title else "Reward"
	local subText = if type(payload.subtitle) == "string" then payload.subtitle else nil

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(0.9, 0, 0, 36)
	header.Position = UDim2.new(0.05, 0, 0.12, 0)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.TextSize = 28
	header.TextColor3 = Color3.fromRGB(255, 230, 140)
	header.TextStrokeTransparency = 0.5
	header.Text = titleText
	header.ZIndex = 902
	header.Parent = root

	if subText then
		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(0.9, 0, 0, 22)
		sub.Position = UDim2.new(0.05, 0, 0.12, 38)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.GothamMedium
		sub.TextSize = 18
		sub.TextColor3 = Color3.fromRGB(200, 200, 220)
		sub.Text = subText
		sub.ZIndex = 902
		sub.Parent = root
	end

	local chestWrap = Instance.new("Frame")
	chestWrap.Name = "ChestWrap"
	chestWrap.AnchorPoint = Vector2.new(0.5, 0.5)
	chestWrap.Position = UDim2.new(0.5, 0, 0.52, 0)
	chestWrap.Size = UDim2.new(0, 280, 0, 220)
	chestWrap.BackgroundTransparency = 1
	chestWrap.ZIndex = 901
	chestWrap.Parent = root

	local chestScale = Instance.new("UIScale")
	chestScale.Scale = 1
	chestScale.Parent = chestWrap

	local chestOuter = Instance.new("Frame")
	chestOuter.Size = UDim2.fromScale(1, 1)
	chestOuter.BackgroundColor3 = Color3.fromRGB(120, 75, 20)
	chestOuter.BorderSizePixel = 0
	chestOuter.ZIndex = 901
	chestOuter.Parent = chestWrap

	local outerCorner = Instance.new("UICorner")
	outerCorner.CornerRadius = UDim.new(0, 16)
	outerCorner.Parent = chestOuter

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Thickness = 3
	outerStroke.Color = Color3.fromRGB(255, 215, 100)
	outerStroke.Parent = chestOuter

	local gradOuter = Instance.new("UIGradient")
	gradOuter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 140, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 55, 15)),
	})
	gradOuter.Rotation = 90
	gradOuter.Parent = chestOuter

	local lid = Instance.new("Frame")
	lid.Name = "Lid"
	lid.AnchorPoint = Vector2.new(0.5, 1)
	lid.Position = UDim2.new(0.5, 0, 0.42, 0)
	lid.Size = UDim2.new(0.92, 0, 0, 52)
	lid.BackgroundColor3 = Color3.fromRGB(210, 160, 60)
	lid.BorderSizePixel = 0
	lid.ZIndex = 903
	lid.Parent = chestWrap

	local lidCorner = Instance.new("UICorner")
	lidCorner.CornerRadius = UDim.new(0, 12)
	lidCorner.Parent = lid

	local lidGrad = Instance.new("UIGradient")
	lidGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 120)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 100, 30)),
	})
	lidGrad.Rotation = 90
	lidGrad.Parent = lid

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 0)
	body.Position = UDim2.new(0.5, 0, 0.42, 0)
	body.Size = UDim2.new(0.88, 0, 0.58, 0)
	body.BackgroundColor3 = Color3.fromRGB(170, 110, 35)
	body.BorderSizePixel = 0
	body.ZIndex = 902
	body.Parent = chestWrap

	local bodyCorner = Instance.new("UICorner")
	bodyCorner.CornerRadius = UDim.new(0, 12)
	bodyCorner.Parent = body

	local bodyGrad = Instance.new("UIGradient")
	bodyGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 190, 80)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 70, 20)),
	})
	bodyGrad.Rotation = 90
	bodyGrad.Parent = body

	local lock = Instance.new("Frame")
	lock.Size = UDim2.new(0, 36, 0, 36)
	lock.Position = UDim2.new(0.5, -18, 0.55, -18)
	lock.BackgroundColor3 = Color3.fromRGB(255, 220, 80)
	lock.ZIndex = 904
	lock.Parent = chestWrap

	local lockCorner = Instance.new("UICorner")
	lockCorner.CornerRadius = UDim.new(1, 0)
	lockCorner.Parent = lock

	local rainFolder = Instance.new("Frame")
	rainFolder.Name = "CoinRain"
	rainFolder.Size = UDim2.fromScale(1, 1)
	rainFolder.BackgroundTransparency = 1
	rainFolder.ZIndex = 899
	rainFolder.Parent = root

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 240, 150)
	flash.BackgroundTransparency = 1
	flash.ZIndex = 905
	flash.Parent = root

	local totalLabel = Instance.new("TextLabel")
	totalLabel.Name = "TotalLine"
	totalLabel.AnchorPoint = Vector2.new(0.5, 0)
	totalLabel.Position = UDim2.new(0.5, 0, 0.78, 0)
	totalLabel.Size = UDim2.new(0.85, 0, 0, 44)
	totalLabel.BackgroundTransparency = 1
	totalLabel.Font = Enum.Font.GothamBlack
	totalLabel.TextSize = 36
	totalLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
	totalLabel.TextStrokeColor3 = Color3.fromRGB(60, 40, 10)
	totalLabel.TextStrokeTransparency = 0.4
	totalLabel.Text = ""
	totalLabel.ZIndex = 902
	totalLabel.Parent = root

	-- Slide in from bottom
	chestWrap.Position = UDim2.new(0.5, 0, 1.35, 0)
	TweenService:Create(chestWrap, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.52, 0),
	}):Play()

	task.delay(0.3, function()
		if not chestWrap.Parent then
			return
		end
		-- Wobble x3, increasing
		local wobbleAmp = { 4, 8, 14 }
		for i = 1, 3 do
			local sign = if i % 2 == 1 then 1 else -1
			local target = sign * wobbleAmp[i]
			TweenService:Create(chestWrap, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Rotation = target,
			}):Play()
			task.wait(0.14)
			TweenService:Create(chestWrap, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
				Rotation = 0,
			}):Play()
			task.wait(0.14)
		end
		TweenService:Create(chestWrap, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Rotation = 0,
		}):Play()
	end)

	task.delay(0.85, function()
		if not lid.Parent or not root.Parent then
			return
		end
		-- Lid pop
		TweenService:Create(lid, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.18, 0),
			Rotation = -12,
		}):Play()
		TweenService:Create(flash, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.15,
		}):Play()
		task.delay(0.12, function()
			if flash.Parent then
				TweenService:Create(flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 1,
				}):Play()
			end
		end)

		-- Sparkle burst (small frames)
		for s = 1, 14 do
			local sp = Instance.new("Frame")
			sp.Size = UDim2.new(0, 10, 0, 10)
			sp.AnchorPoint = Vector2.new(0.5, 0.5)
			sp.Position = UDim2.new(0.5, math.random(-120, 120), 0.5, math.random(-80, 40))
			sp.BackgroundColor3 = Color3.fromRGB(255, 255, 200)
			sp.BorderSizePixel = 0
			sp.ZIndex = 906
			sp.Parent = chestWrap
			local spc = Instance.new("UICorner")
			spc.CornerRadius = UDim.new(1, 0)
			spc.Parent = sp
			TweenService:Create(sp, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = sp.Position + UDim2.new(0, math.random(-40, 40), 0, math.random(-60, -20)),
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 4, 0, 4),
			}):Play()
			task.delay(0.5, function()
				sp:Destroy()
			end)
		end

		-- Coin rain
		for r = 1, 48 do
			local coin = Instance.new("Frame")
			coin.Size = UDim2.new(0, math.random(6, 12), 0, math.random(10, 16))
			coin.Position = UDim2.new(math.random(), 0, -0.05, 0)
			coin.BackgroundColor3 = Color3.fromRGB(255, 200 + math.random(0, 55), 60)
			coin.BorderSizePixel = 0
			coin.ZIndex = 898
			coin.Parent = rainFolder
			local cc = Instance.new("UICorner")
			cc.CornerRadius = UDim.new(0, 3)
			cc.Parent = coin
			local duration = 1.2 + math.random() * 0.6
			TweenService:Create(coin, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = coin.Position + UDim2.new(0, math.random(-30, 30), 1.1, 0),
				Rotation = math.random(-40, 40),
				BackgroundTransparency = 0.35,
			}):Play()
			task.delay(duration + 0.1, function()
				coin:Destroy()
			end)
		end

		-- Flying reward labels
		local startY = 0.48
		for i, it in items do
			task.delay((i - 1) * 0.12, function()
				if not root.Parent then
					return
				end
				local line = formatItemLine(it)
				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(0.7, 0, 0, 32)
				lbl.AnchorPoint = Vector2.new(0.5, 0.5)
				lbl.Position = UDim2.new(0.5, 0, startY, 0)
				lbl.BackgroundTransparency = 0.25
				lbl.BackgroundColor3 = Color3.fromRGB(20, 22, 35)
				lbl.Font = Enum.Font.GothamBold
				lbl.TextSize = 20
				lbl.TextColor3 = colorForKind(it.kind)
				lbl.Text = line
				lbl.ZIndex = 910
				lbl.Parent = root
				local lc = Instance.new("UICorner")
				lc.CornerRadius = UDim.new(0, 8)
				lc.Parent = lbl
				local pad = Instance.new("UIPadding")
				pad.PaddingLeft = UDim.new(0, 10)
				pad.PaddingRight = UDim.new(0, 10)
				pad.Parent = lbl

				SoundFacade.playOneShot("cha_ching")

				local endX = 0.2 + (i % 5) * 0.15
				local endY = 0.22 + ((i * 17) % 5) * 0.06
				TweenService:Create(lbl, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = UDim2.new(endX, 0, endY, 0),
				}):Play()
				TweenService:Create(lbl, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextTransparency = 0,
				}):Play()
			end)
		end

		-- Total counter
		task.delay(0.35 + #items * 0.12 + 0.2, function()
			if not totalLabel.Parent then
				return
			end
			local target = estimateTotalNumber(items)
			if target > 0 then
				local steps = 20
				for i = 0, steps do
					local frac = i / steps
					task.delay(i * 0.025, function()
						if not totalLabel.Parent then
							return
						end
						local v = math.floor(target * frac + 0.5)
						if i == steps then
							v = target
						end
						totalLabel.Text = "Total value: " .. Utils.formatNumber(v)
					end)
				end
			else
				totalLabel.Text = "Claimed!"
			end
		end)
	end)

	-- Fade everything after ~3.5s active, 2s fade window
	task.delay(5.5, function()
		if not root.Parent then
			return
		end
		TweenService:Create(root, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			BackgroundTransparency = 1,
		}):Play()
		for _, d in root:GetDescendants() do
			if d:IsA("TextLabel") or d:IsA("TextButton") then
				TweenService:Create(d, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				}):Play()
			elseif d:IsA("Frame") and d ~= root then
				TweenService:Create(d, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
					BackgroundTransparency = 1,
				}):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
					Transparency = 1,
				}):Play()
			end
		end
		task.delay(2.05, function()
			destroyActive()
		end)
	end)
end

return RewardChestAnimation
