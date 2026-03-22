--!strict
--[[
	Post-purchase thank-you overlay: gift-box style celebration, tier escalation,
	queue (max 3), suppressed during driving until run ends.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Constants = require(DAC:WaitForChild("Constants"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

local DrivingController = require(script.Parent:WaitForChild("DrivingController"))

local PurchaseThankYouController = {}

local player = Players.LocalPlayer

local queue: { any } = {}
local MAX_QUEUE = 3
local showing = false

local function tierFromTotal(total: number): string
	if total >= 2000 then
		return "whale"
	elseif total >= 500 then
		return "vip"
	elseif total >= 100 then
		return "supporter"
	end
	return "standard"
end

local function playRevealSound(tier: string)
	if tier == "whale" then
		SoundFacade.playOneShot("purchase_thankyou_reveal_whale")
	elseif tier == "vip" then
		SoundFacade.playOneShot("purchase_thankyou_reveal_vip")
	else
		SoundFacade.playOneShot("purchase_thankyou_reveal")
	end
end

local function destroyRain(rainConn: RBXScriptConnection?, dots: { Frame })
	if rainConn then
		rainConn:Disconnect()
	end
	for _, d in dots do
		d:Destroy()
	end
end

local function showThankYou(payload: any, onDone: () -> ())
	local sg = Instance.new("ScreenGui")
	sg.Name = "DACPurchaseThankYou"
	sg.DisplayOrder = 999
	sg.IgnoreGuiInset = true
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Parent = player:WaitForChild("PlayerGui")

	local total = math.max(0, math.floor(tonumber(payload.totalRobuxSpent) or 0))
	local tier = tierFromTotal(total)

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 1
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.ZIndex = 950
	backdrop.Parent = sg

	local vignette = Instance.new("Frame")
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = Color3.fromRGB(10, 5, 20)
	vignette.BackgroundTransparency = 1
	vignette.ZIndex = 951
	vignette.Parent = sg
	local vigGrad = Instance.new("UIGradient")
	vigGrad.Rotation = 90
	vigGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	vigGrad.Parent = vignette

	local card = Instance.new("Frame")
	card.Name = "ThankYouCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.65, 0)
	card.Size = UDim2.fromOffset(400, 340)
	card.BackgroundColor3 = Color3.fromRGB(14, 10, 28)
	card.BackgroundTransparency = 0.5
	card.ZIndex = 960
	card.Parent = sg
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 18)
	local stroke = Instance.new("UIStroke", card)
	stroke.Thickness = if tier == "supporter" or tier == "vip" then 2.8 else 2.5
	local gold = Color3.fromRGB(255, 213, 79)
	local brightGold = Color3.fromRGB(255, 225, 100)
	stroke.Color = if tier == "supporter" then brightGold else gold
	local cardGrad = Instance.new("UIGradient", card)
	cardGrad.Rotation = 90
	cardGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 28, 15)),
		ColorSequenceKeypoint.new(0.3, Color3.fromRGB(14, 10, 28)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 15, 10)),
	})

	local headline = Instance.new("TextLabel")
	headline.BackgroundTransparency = 1
	headline.Font = Enum.Font.GothamBlack
	headline.TextSize = 18
	headline.TextColor3 = gold
	headline.TextTransparency = 1
	headline.ZIndex = 965
	headline.Parent = card

	local subline = Instance.new("TextLabel")
	subline.BackgroundTransparency = 1
	subline.Font = Enum.Font.GothamBold
	subline.TextSize = 12
	subline.TextColor3 = Color3.fromRGB(220, 210, 230)
	subline.TextTransparency = 1
	subline.ZIndex = 965
	subline.Parent = card

	local productType = type(payload.productType) == "string" and payload.productType or "devproduct"
	if productType == "gamepass" then
		headline.Text = "GAMEPASS UNLOCKED!"
		subline.Text = "This power is yours FOREVER!"
	else
		headline.Text = "THANK YOU FOR YOUR PURCHASE!"
		subline.Text = "Your items have been delivered!"
	end

	headline.Size = UDim2.new(1, -32, 0, 24)
	headline.Position = UDim2.new(0.5, 0, 0, 20)
	headline.AnchorPoint = Vector2.new(0.5, 0)
	headline.TextXAlignment = Enum.TextXAlignment.Center
	subline.Size = UDim2.new(1, -32, 0, 18)
	subline.Position = UDim2.new(0.5, 0, 0, 48)
	subline.AnchorPoint = Vector2.new(0.5, 0)
	subline.TextXAlignment = Enum.TextXAlignment.Center

	local glow = Instance.new("Frame")
	glow.Size = UDim2.fromOffset(if tier == "vip" or tier == "whale" then 140 else 120, if tier == "vip" or tier == "whale" then 140 else 120)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.new(0.5, 0, 0, 125)
	glow.BackgroundColor3 = gold
	glow.BackgroundTransparency = 1
	glow.ZIndex = 973
	glow.Parent = card
	Instance.new("UICorner", glow).CornerRadius = UDim.new(0.5, 0)

	local spot = Instance.new("Frame")
	spot.Size = UDim2.fromOffset(90, 90)
	spot.AnchorPoint = Vector2.new(0.5, 0.5)
	spot.Position = UDim2.new(0.5, 0, 0, 125)
	spot.BackgroundColor3 = Color3.fromRGB(30, 24, 55)
	spot.ZIndex = 975
	spot.Parent = card
	Instance.new("UICorner", spot).CornerRadius = UDim.new(0, 14)
	local spotStroke = Instance.new("UIStroke", spot)
	spotStroke.Thickness = if tier == "supporter" then 2.5 else 2
	spotStroke.Color = Color3.fromRGB(255, 220, 100)
	spotStroke.Transparency = 0.1

	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(64, 64)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Image = type(payload.iconId) == "string" and payload.iconId or "rbxassetid://0"
	icon.ImageTransparency = 1
	icon.ZIndex = 976
	icon.Parent = spot

	if productType == "gamepass" then
		local b = Instance.new("Frame")
		b.Size = UDim2.fromOffset(70, 16)
		b.AnchorPoint = Vector2.new(0.5, 0)
		b.Position = UDim2.new(0.5, 0, 1, 4)
		b.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
		b.ZIndex = 976
		b.Parent = spot
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
		local bl = Instance.new("TextLabel")
		bl.BackgroundTransparency = 1
		bl.Size = UDim2.fromScale(1, 1)
		bl.Font = Enum.Font.GothamBlack
		bl.TextSize = 8
		bl.TextColor3 = Color3.new(1, 1, 1)
		bl.Text = "PERMANENT"
		bl.ZIndex = 977
		bl.Parent = b
	end

	local itemName = Instance.new("TextLabel")
	itemName.BackgroundTransparency = 1
	itemName.Font = Enum.Font.GothamBlack
	itemName.TextSize = 16
	itemName.TextColor3 = Color3.new(1, 1, 1)
	itemName.TextTransparency = 1
	itemName.Text = type(payload.displayName) == "string" and payload.displayName or "Thank you!"
	itemName.Position = UDim2.new(0.5, 0, 0, 178)
	itemName.AnchorPoint = Vector2.new(0.5, 0)
	itemName.Size = UDim2.new(1, -32, 0, 22)
	itemName.TextXAlignment = Enum.TextXAlignment.Center
	itemName.ZIndex = 965
	itemName.Parent = card

	local benefitsHolder = Instance.new("Frame")
	benefitsHolder.BackgroundTransparency = 1
	benefitsHolder.Position = UDim2.new(0.5, 0, 0, 205)
	benefitsHolder.AnchorPoint = Vector2.new(0.5, 0)
	benefitsHolder.Size = UDim2.new(0.85, 0, 0, 70)
	benefitsHolder.ZIndex = 965
	benefitsHolder.Parent = card
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = benefitsHolder

	local currencyCounter: TextLabel? = nil
	local cg = payload.currencyGrant
	if type(cg) == "table" and type(cg.currency) == "string" and (cg.currency == "coins" or cg.currency == "gems" or cg.currency == "crystals" or cg.currency == "skulls") then
		local amt = math.floor(tonumber(cg.amount) or 0)
		if amt > 0 then
			benefitsHolder.Visible = false
			local c = Instance.new("TextLabel")
			c.BackgroundTransparency = 1
			c.Font = Enum.Font.GothamBlack
			c.TextSize = 28
			local disp = (Constants.CURRENCY_DISPLAY :: any)[cg.currency]
			c.TextColor3 = if type(disp) == "table" and disp.color then disp.color else Color3.fromRGB(255, 200, 50)
			c.TextTransparency = 1
			c.Text = "0"
			c.Position = UDim2.new(0.5, 0, 0, 200)
			c.AnchorPoint = Vector2.new(0.5, 0)
			c.Size = UDim2.new(1, -32, 0, 36)
			c.TextXAlignment = Enum.TextXAlignment.Center
			c.ZIndex = 965
			c.Parent = card
			currencyCounter = c
			task.spawn(function()
				local t0 = os.clock()
				local dur = 0.5
				while os.clock() - t0 < dur and c.Parent do
					local a = (os.clock() - t0) / dur
					a = 1 - (1 - a) * (1 - a)
					c.Text = tostring(math.floor(amt * a + 0.5))
					task.wait()
				end
				if c.Parent then
					c.Text = tostring(amt)
				end
			end)
		end
	end

	local benefits = if type(payload.benefits) == "table" then payload.benefits else {}
	local n = 0
	for _, line in benefits do
		if type(line) == "string" and line ~= "" then
			n += 1
			if n > 4 then
				break
			end
			local row = Instance.new("TextLabel")
			row.BackgroundTransparency = 1
			row.Font = Enum.Font.Gotham
			row.TextSize = 11
			row.TextColor3 = Color3.fromRGB(180, 220, 180)
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.Text = "✓ " .. line
			row.Size = UDim2.new(1, 0, 0, 16)
			row.TextTransparency = 1
			row.Parent = benefitsHolder
		end
	end

	local divider = Instance.new("Frame")
	divider.BackgroundColor3 = gold
	divider.BackgroundTransparency = 1
	divider.Size = UDim2.new(0.7, 0, 0, 1)
	divider.Position = UDim2.new(0.5, 0, 0, 190)
	divider.AnchorPoint = Vector2.new(0.5, 0)
	divider.ZIndex = 965
	divider.Parent = card

	local enjoy = Instance.new("TextButton")
	enjoy.Name = "Enjoy"
	enjoy.Font = Enum.Font.GothamBlack
	enjoy.TextSize = 16
	enjoy.TextColor3 = Color3.fromRGB(20, 15, 40)
	enjoy.Text = "ENJOY!"
	enjoy.AutoButtonColor = false
	enjoy.Size = UDim2.new(0.5, 0, 0, 42)
	enjoy.AnchorPoint = Vector2.new(0.5, 1)
	enjoy.Position = UDim2.new(0.5, 0, 1, -24)
	enjoy.BackgroundColor3 = gold
	enjoy.BackgroundTransparency = 1
	enjoy.TextTransparency = 1
	enjoy.ZIndex = 965
	enjoy.Parent = card
	Instance.new("UICorner", enjoy).CornerRadius = UDim.new(0, 10)
	local estroke = Instance.new("UIStroke", enjoy)
	estroke.Thickness = 1.5
	estroke.Color = Color3.fromRGB(255, 240, 140)
	estroke.Transparency = 0.15

	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = card

	local spotScale = Instance.new("UIScale")
	spotScale.Scale = 0
	spotScale.Parent = spot

	local rainDots: { Frame } = {}
	local rainConn: RBXScriptConnection? = nil
	local pulseConn: RBXScriptConnection? = nil
	local autoThread: thread? = nil

	local dismissed = false
	local function dismiss()
		if dismissed then
			return
		end
		dismissed = true
		if autoThread then
			task.cancel(autoThread)
			autoThread = nil
		end
		if pulseConn then
			pulseConn:Disconnect()
			pulseConn = nil
		end
		destroyRain(rainConn, rainDots)
		TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 0.6,
		}):Play()
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.88 }):Play()
		TweenService:Create(backdrop, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.3, function()
			sg:Destroy()
			Remotes.getEvent("PurchaseThankYouAck"):FireServer()
			onDone()
		end)
	end

	SoundFacade.playOneShot("purchase_thankyou_buildup")

	TweenService:Create(backdrop, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.3,
	}):Play()
	TweenService:Create(vignette, TweenInfo.new(0.3), { BackgroundTransparency = 0.35 }):Play()

	TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 0.02,
	}):Play()
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.05 }):Play()
	task.delay(0.12, function()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)

	task.delay(0.25, function()
		if not sg.Parent then
			return
		end
		local acc = 0.0
		rainConn = RunService.RenderStepped:Connect(function(dt)
			if not sg.Parent or #rainDots >= 30 then
				return
			end
			acc += dt
			if acc < 0.1 then
				return
			end
			acc = 0
			local dot = Instance.new("Frame")
			dot.Size = UDim2.fromOffset(math.random(2, 4), math.random(2, 4))
			dot.Position = UDim2.new(math.random(), 0, 0, -8)
			if tier == "whale" then
				dot.BackgroundColor3 = Color3.fromHSV(math.random(), 0.7, 1)
			elseif tier == "supporter" and math.random(1, 5) == 1 then
				dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			else
				dot.BackgroundColor3 = Color3.fromRGB(
					math.random(235, 255),
					math.random(200, 220),
					math.random(60, 90)
				)
			end
			dot.BackgroundTransparency = 0.2
			dot.ZIndex = 970
			dot.Parent = sg
			local vy = math.random(60, 120)
			local vx = math.random(-15, 15)
			local life = 0.0
			table.insert(rainDots, dot)
			local c2: RBXScriptConnection
			c2 = RunService.RenderStepped:Connect(function(d)
				if not dot.Parent then
					c2:Disconnect()
					return
				end
				life += d
				if life > 2.5 then
					dot:Destroy()
					c2:Disconnect()
					return
				end
				local p = dot.Position
				dot.Position = UDim2.new(p.X.Scale, p.X.Offset + vx * d, p.Y.Scale, p.Y.Offset + vy * d)
				dot.BackgroundTransparency = math.min(1, 0.2 + life * 0.35)
			end)
		end)
	end)

	task.delay(0.5, function()
		if not sg.Parent then
			return
		end
		playRevealSound(tier)
		TweenService:Create(headline, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
		TweenService:Create(glow, TweenInfo.new(0.3), {
			BackgroundTransparency = if tier == "supporter" then 0.8 else 0.85,
		}):Play()
		TweenService:Create(spotScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.2 }):Play()
		task.delay(0.12, function()
			TweenService:Create(spotScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end)
	end)

	task.delay(0.55, function()
		if not sg.Parent then
			return
		end
		TweenService:Create(subline, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	end)

	task.delay(0.75, function()
		if not sg.Parent then
			return
		end
		TweenService:Create(icon, TweenInfo.new(0.2), { ImageTransparency = 0 }):Play()
	end)

	task.delay(0.8, function()
		if not sg.Parent then
			return
		end
		TweenService:Create(itemName, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	end)

	task.delay(0.95, function()
		if not sg.Parent then
			return
		end
		for _, child in benefitsHolder:GetChildren() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
			end
		end
		if currencyCounter then
			TweenService:Create(currencyCounter, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
		end
		TweenService:Create(divider, TweenInfo.new(0.15), { BackgroundTransparency = 0.4 }):Play()
	end)

	task.delay(1.3, function()
		if not sg.Parent then
			return
		end
		TweenService:Create(enjoy, TweenInfo.new(0.15), {
			BackgroundTransparency = 0,
			TextTransparency = 0,
		}):Play()
	end)

	if tier == "vip" or tier == "whale" then
		task.spawn(function()
			while sg.Parent do
				local t = os.clock() * (if tier == "whale" then 0.33 else 0.5)
				stroke.Color = gold:Lerp(Color3.fromRGB(255, 240, 160), (math.sin(t) + 1) * 0.5)
				task.wait(0.05)
			end
		end)
	end

	if tier == "whale" then
		task.spawn(function()
			while sg.Parent do
				glow.BackgroundColor3 = Color3.fromHSV((os.clock() * 0.3) % 1, 0.5, 1)
				task.wait(0.03)
			end
		end)
	end

	pulseConn = RunService.RenderStepped:Connect(function()
		if not enjoy.Parent then
			if pulseConn then
				pulseConn:Disconnect()
			end
			return
		end
		local s = 1 + 0.03 * math.sin(os.clock() * math.pi * 2)
		local es = enjoy:FindFirstChildOfClass("UIScale")
		if not es then
			es = Instance.new("UIScale")
			es.Parent = enjoy
		end
		(es :: UIScale).Scale = s
	end)

	autoThread = task.delay(5, function()
		if dismissed then
			return
		end
		dismiss()
	end)

	task.delay(4, function()
		if dismissed or not enjoy.Parent then
			return
		end
		enjoy.Text = "ENJOY! (1)"
	end)

	backdrop.MouseButton1Click:Connect(dismiss)
	enjoy.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("ui_confirm")
		dismiss()
	end)

	task.delay(1.5, function()
		if not sg.Parent then
			return
		end
		local gPulse: RBXScriptConnection? = nil
		gPulse = RunService.RenderStepped:Connect(function()
			if not glow.Parent then
				if gPulse then
					gPulse:Disconnect()
				end
				return
			end
			local gs = glow:FindFirstChildOfClass("UIScale")
			if not gs then
				gs = Instance.new("UIScale")
				gs.Parent = glow
			end
			(gs :: UIScale).Scale = 1 + 0.1 * math.sin(os.clock() * math.pi * 3)
		end)
	end)
end

local function tryShowNext()
	if showing then
		return
	end
	if #queue == 0 then
		return
	end
	if DrivingController.isInRun() then
		return
	end
	showing = true
	local payload = table.remove(queue, 1)
	showThankYou(payload, function()
		showing = false
		tryShowNext()
	end)
end

function PurchaseThankYouController.enqueue(payload: any)
	if type(payload) ~= "table" then
		return
	end
	if #queue >= MAX_QUEUE then
		return
	end
	table.insert(queue, payload)
	tryShowNext()
end

function PurchaseThankYouController.onRunEnded()
	tryShowNext()
end

function PurchaseThankYouController.init()
	Remotes.getEvent("PurchaseComplete").OnClientEvent:Connect(function(payload: any)
		PurchaseThankYouController.enqueue(payload)
	end)
end

return PurchaseThankYouController
