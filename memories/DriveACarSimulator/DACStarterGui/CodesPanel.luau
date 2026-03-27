--!strict
--[[
	Codes redemption panel.
	UI is pre-built in DACMain.Panels.Codes; this script only wires behavior.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))

local MenuHub = require(script.Parent:WaitForChild("MenuHub"))

local CodesPanel = {}

local function shakeInput(box: TextBox)
	local base = box.Position
	for i = 1, 6 do
		local o = if i % 2 == 0 then 10 else -10
		box.Position = UDim2.new(base.X.Scale, base.X.Offset + o, base.Y.Scale, base.Y.Offset)
		task.wait(0.045)
	end
	box.Position = base
end

function CodesPanel.init()
	local sg = MenuHub.getScreenGui()
	local root = sg:WaitForChild("Codes") :: Frame

	local box = root:WaitForChild("CodeInput") :: TextBox
	local statusLabel = root:WaitForChild("RedeemStatus") :: TextLabel
	local redeemBtn = root:WaitForChild("RedeemBtn") :: TextButton

	local redeemPending = false
	local redeemGen = 0
	local lastFiredRequestId = 0
	local lastFanfareRequestId = 0
	local origInputBg = box.BackgroundColor3
	local statusStroke = statusLabel:FindFirstChildOfClass("UIStroke") :: UIStroke?
	local origStrokeTransparency = if statusStroke then statusStroke.Transparency else nil

	local uiScale = root:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Name = "RedeemSuccessPunch"
		uiScale.Parent = root
	end

	local redeemBtnDefaultText = redeemBtn.Text

	local function setRedeemBusy(busy: boolean)
		redeemBtn.Active = not busy
		box.TextEditable = not busy
		redeemBtn.Text = if busy then "Wait…" else redeemBtnDefaultText
	end

	local function playSuccessJuice()
		SoundFacade.playOneShot("code_redeem_success")
		VFXFacade.rewardChestBurst()
		VFXFacade.codeRedeemConfettiBurst()
		uiScale.Scale = 0.9
		TweenService:Create(
			uiScale,
			TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end

	Remotes.getEvent("Notification").OnClientEvent:Connect(function(n: any)
		if not redeemPending or type(n) ~= "table" then return end
		local kind = n.type
		if kind ~= "success" and kind ~= "error" then return end
		local msg = if type(n.message) == "string" then n.message else ""
		if kind == "success" then
			if not string.find(msg, "Code redeemed", 1, true) then return end
			if lastFanfareRequestId == lastFiredRequestId then
				return
			end
			lastFanfareRequestId = lastFiredRequestId
			redeemPending = false
			setRedeemBusy(false)
			statusLabel.Text = MicrocopyConfig.CodeRedeemSuccess[math.random(1, #MicrocopyConfig.CodeRedeemSuccess)]
			statusLabel.TextColor3 = Color3.fromRGB(160, 255, 180)
			statusLabel.TextTransparency = 1
			if statusStroke and origStrokeTransparency ~= nil then
				statusStroke.Transparency = 1
			end
			playSuccessJuice()
			TweenService:Create(
				statusLabel,
				TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ TextTransparency = 0 }
			):Play()
			if statusStroke and origStrokeTransparency ~= nil then
				TweenService:Create(
					statusStroke,
					TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Transparency = origStrokeTransparency }
				):Play()
			end
			TweenService:Create(box, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = Color3.fromRGB(72, 180, 96) }):Play()
			task.delay(0.2, function()
				if box.Parent then
					TweenService:Create(box, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = origInputBg }):Play()
				end
			end)
		elseif kind == "error" then
			redeemPending = false
			setRedeemBusy(false)
			local line: string
			if string.find(msg, "expired", 1, true) then
				line = MicrocopyConfig.CodeRedeemExpired[math.random(1, #MicrocopyConfig.CodeRedeemExpired)]
			elseif string.find(msg, "Already redeemed", 1, true) then
				line = MicrocopyConfig.CodeRedeemAlreadyUsed[math.random(1, #MicrocopyConfig.CodeRedeemAlreadyUsed)]
			elseif string.find(msg, "Too many code attempts", 1, true) then
				line = MicrocopyConfig.CodeRedeemRateLimited[math.random(1, #MicrocopyConfig.CodeRedeemRateLimited)]
			elseif string.find(msg, "Invalid code format", 1, true) then
				line = MicrocopyConfig.CodeRedeemFormatError[math.random(1, #MicrocopyConfig.CodeRedeemFormatError)]
			else
				line = MicrocopyConfig.CodeRedeemError[math.random(1, #MicrocopyConfig.CodeRedeemError)]
			end
			statusLabel.Text = line
			statusLabel.TextColor3 = Color3.fromRGB(255, 140, 140)
			statusLabel.TextTransparency = 0
			if statusStroke and origStrokeTransparency ~= nil then
				statusStroke.Transparency = origStrokeTransparency
			end
			SoundFacade.playOneShot("purchase_fail")
			task.spawn(function() shakeInput(box) end)
			TweenService:Create(box, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = Color3.fromRGB(120, 50, 50) }):Play()
			task.delay(0.25, function()
				if box.Parent then
					TweenService:Create(box, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = origInputBg }):Play()
				end
			end)
		end
	end)

	redeemBtn.MouseButton1Click:Connect(function()
		if redeemPending then
			return
		end
		SoundFacade.playOneShot("click")
		lastFiredRequestId += 1
		redeemPending = true
		setRedeemBusy(true)
		redeemGen += 1
		local gen = redeemGen
		statusLabel.Text = MicrocopyConfig.CodeRedeemInProgress
		statusLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
		statusLabel.TextTransparency = 0
		if statusStroke and origStrokeTransparency ~= nil then
			statusStroke.Transparency = origStrokeTransparency
		end
		Remotes.getEvent("RedeemCode"):FireServer(box.Text)
		task.delay(15, function()
			if gen ~= redeemGen then return end
			if redeemPending and statusLabel.Text == MicrocopyConfig.CodeRedeemInProgress then
				redeemPending = false
				setRedeemBusy(false)
				statusLabel.Text = ""
			end
		end)
	end)
end

return CodesPanel
