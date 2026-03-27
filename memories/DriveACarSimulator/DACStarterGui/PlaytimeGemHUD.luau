--!strict
--[[
	Playtime bonus countdown HUD.
	UI is pre-built in StarterGui.DACPlaytimeGem; this script only wires behavior.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local UILayerStack = require(DAC:WaitForChild("Config"):WaitForChild("UILayerStack"))
local Constants = require(DAC:WaitForChild("Constants"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))

local HUD = require(script.Parent:WaitForChild("HUD"))

local PlaytimeGemHUD = {}

function PlaytimeGemHUD.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild("DACPlaytimeGem") :: ScreenGui
	gui.DisplayOrder = UILayerStack.screenGui.hudPlaytimeGem
	local root = gui:WaitForChild("Root") :: Frame
	local rootScale = root:WaitForChild("UIScale") :: UIScale
	local gemIcon = root:WaitForChild("GemIcon") :: TextLabel
	local ringStroke = root:WaitForChild("RingStroke") :: UIStroke
	local label = root:WaitForChild("TimeLabel") :: TextLabel
	local barBg = root:WaitForChild("ProgressBg") :: Frame
	local barFill = barBg:WaitForChild("Fill") :: Frame

	local need = Constants.PLAYTIME_BONUS_INTERVAL or 300
	local lastLeft = need
	local lastPlaytimeProgress = 0
	local urgencyConn: RBXScriptConnection? = nil
	local lastUrgencyPulseClock = 0.0
	local URGENCY_PULSE_INTERVAL = 0.05

	local function setUrgencyVisuals(left: number)
		local urgent = left <= 10 and left > 0
		if urgent then
			local pulse = 0.5 + 0.5 * math.sin(os.clock() * 8)
			ringStroke.Color = Color3.fromRGB(255, 200, 80):Lerp(Color3.fromRGB(255, 230, 140), pulse)
			ringStroke.Transparency = 0.25 + 0.2 * pulse
		else
			ringStroke.Color = Color3.fromRGB(90, 80, 140)
			ringStroke.Transparency = 0.55
		end
	end

	local function disconnectUrgencyAnim()
		if urgencyConn then
			urgencyConn:Disconnect()
			urgencyConn = nil
		end
		ringStroke.Color = Color3.fromRGB(90, 80, 140)
		ringStroke.Transparency = 0.55
	end

	local function update(data: any)
		if not data then return end
		local p = data.playtimeSecondsSinceBonus or data.playtimeSecondsSinceGem or 0
		lastPlaytimeProgress = p
		need = Constants.PLAYTIME_BONUS_INTERVAL or 300
		local left = math.max(0, need - p)
		lastLeft = left
		local prog = if need > 0 then math.clamp(p / need, 0, 1) else 0
		barFill.Size = UDim2.new(prog, 0, 1, 0)
		local m = math.floor(left / 60)
		local s = math.floor(left % 60)
		label.Text = ` Bonus in {m}:{string.format("%02d", s)} `
		local urgent = left <= 10 and left > 0
		if urgent then
			if not urgencyConn then
				urgencyConn = RunService.Heartbeat:Connect(function()
					local now = os.clock()
					if now - lastUrgencyPulseClock < URGENCY_PULSE_INTERVAL then
						return
					end
					lastUrgencyPulseClock = now
					setUrgencyVisuals(lastLeft)
				end)
			end
		else
			disconnectUrgencyAnim()
			setUrgencyVisuals(lastLeft)
		end
	end

	Remotes.getEvent("Notification").OnClientEvent:Connect(function(n)
		if type(n) == "table" and type(n.message) == "string" and string.find(n.message, "Playtime bonus", 1, true) then
			SoundFacade.playOneShot("level_up")
			local edgeGlow = Instance.new("Frame")
			edgeGlow.Name = "AwardEdgeGlow"
			edgeGlow.BackgroundColor3 = Color3.fromRGB(255, 200, 80)
			edgeGlow.BackgroundTransparency = 0.65
			edgeGlow.BorderSizePixel = 0
			edgeGlow.Size = UDim2.new(1, 24, 1, 24)
			edgeGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
			edgeGlow.AnchorPoint = Vector2.new(0.5, 0.5)
			edgeGlow.ZIndex = 0
			edgeGlow.Parent = root
			local eg = Instance.new("UIGradient")
			eg.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 100)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 180, 60)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 160)),
			})
			eg.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(0.5, 0.85),
				NumberSequenceKeypoint.new(1, 1),
			})
			eg.Parent = edgeGlow
			TweenService:Create(edgeGlow, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
			task.delay(0.5, function()
				if edgeGlow.Parent then edgeGlow:Destroy() end
			end)

			rootScale.Scale = 1
			TweenService:Create(rootScale, TweenInfo.new(0.2, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1.25 }):Play()
			task.delay(0.2, function()
				TweenService:Create(rootScale, TweenInfo.new(0.2, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end)

			gemIcon.Rotation = 0
			TweenService:Create(gemIcon, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 360 }):Play()

			VFXFacade.currencyPopup("coins", Constants.PLAYTIME_BONUS_BASE_COINS, "Playtime bonus!")
			HUD.pulseCurrencyLabel("coins")
			local bright = Color3.fromRGB(255, 230, 120)
			local orig = label.TextColor3
			TweenService:Create(label, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextColor3 = bright }):Play()
			task.delay(0.14, function()
				if label.Parent then
					TweenService:Create(label, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextColor3 = orig }):Play()
				end
			end)
		end
	end)

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(update)
	local okInit, d = pcall(function()
		return Remotes.getFunction("GetPlayerData"):InvokeServer()
	end)
	if okInit and d and player.Parent then
		update(d)
	end
end

return PlaytimeGemHUD
