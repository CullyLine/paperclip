--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Constants = require(DAC:WaitForChild("Constants"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))

local HUD = require(script.Parent:WaitForChild("HUD"))

local PlaytimeGemHUD = {}

function PlaytimeGemHUD.init()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "DACPlaytimeGem"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.new(0, 280, 0, 44)
	root.Position = UDim2.new(1, -290, 0, 88)
	root.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	root.BackgroundTransparency = 0.2
	root.BorderSizePixel = 0
	root.Parent = gui
	local rootScale = Instance.new("UIScale")
	rootScale.Scale = 1
	rootScale.Parent = root
	local rootCorner = Instance.new("UICorner")
	rootCorner.CornerRadius = UDim.new(0, 8)
	rootCorner.Parent = root

	local gemIcon = Instance.new("TextLabel")
	gemIcon.Name = "GemIcon"
	gemIcon.BackgroundTransparency = 1
	gemIcon.Size = UDim2.fromOffset(22, 22)
	gemIcon.Position = UDim2.new(0, 6, 0.5, -11)
	gemIcon.Font = Enum.Font.GothamBold
	gemIcon.TextSize = 18
	gemIcon.Text = "◆"
	gemIcon.TextColor3 = Color3.fromRGB(200, 140, 255)
	gemIcon.TextXAlignment = Enum.TextXAlignment.Center
	gemIcon.Parent = root

	local ringStroke = Instance.new("UIStroke")
	ringStroke.Name = "RingStroke"
	ringStroke.Thickness = 2
	ringStroke.Transparency = 0.55
	ringStroke.Color = Color3.fromRGB(90, 80, 140)
	ringStroke.Parent = root

	local label = Instance.new("TextLabel")
	label.Name = "TimeLabel"
	label.Size = UDim2.new(1, -40, 0, 22)
	label.Position = UDim2.new(0, 32, 0, 4)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(200, 120, 255)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = root

	local barBg = Instance.new("Frame")
	barBg.Name = "ProgressBg"
	barBg.Size = UDim2.new(1, -40, 0, 6)
	barBg.Position = UDim2.new(0, 32, 1, -10)
	barBg.BackgroundColor3 = Color3.fromRGB(20, 22, 40)
	barBg.BorderSizePixel = 0
	barBg.Parent = root
	local barBgCorner = Instance.new("UICorner")
	barBgCorner.CornerRadius = UDim.new(1, 0)
	barBgCorner.Parent = barBg

	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(180, 100, 255)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg
	local barFillCorner = Instance.new("UICorner")
	barFillCorner.CornerRadius = UDim.new(1, 0)
	barFillCorner.Parent = barFill

	local need = Constants.PLAYTIME_GEM_INTERVAL or 300
	local lastLeft = need
	local lastPlaytimeProgress = 0
	local urgencyConn: RBXScriptConnection? = nil

	local function update(data: any)
		if not data then
			return
		end
		local p = data.playtimeSecondsSinceGem or 0
		lastPlaytimeProgress = p
		need = Constants.PLAYTIME_GEM_INTERVAL or 300
		local left = math.max(0, need - p)
		lastLeft = left
		local prog = if need > 0 then math.clamp(p / need, 0, 1) else 0
		barFill.Size = UDim2.new(prog, 0, 1, 0)
		local m = math.floor(left / 60)
		local s = math.floor(left % 60)
		label.Text = ` Playtime gem in {m}:{string.format("%02d", s)} `
	end

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

	urgencyConn = RunService.RenderStepped:Connect(function()
		setUrgencyVisuals(lastLeft)
	end)

	Remotes.getEvent("Notification").OnClientEvent:Connect(function(n)
		if type(n) == "table" and type(n.message) == "string" and string.find(n.message, "Playtime bonus", 1, true) then
			SoundFacade.playOneShot("level_up")
			local edgeGlow = Instance.new("Frame")
			edgeGlow.Name = "AwardEdgeGlow"
			edgeGlow.BackgroundColor3 = Color3.fromRGB(200, 120, 255)
			edgeGlow.BackgroundTransparency = 0.65
			edgeGlow.BorderSizePixel = 0
			edgeGlow.Size = UDim2.new(1, 24, 1, 24)
			edgeGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
			edgeGlow.AnchorPoint = Vector2.new(0.5, 0.5)
			edgeGlow.ZIndex = 0
			edgeGlow.Parent = root
			local eg = Instance.new("UIGradient")
			eg.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 180, 255)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 80, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 220, 160)),
			})
			eg.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(0.5, 0.85),
				NumberSequenceKeypoint.new(1, 1),
			})
			eg.Parent = edgeGlow
			TweenService:Create(edgeGlow, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			}):Play()
			task.delay(0.5, function()
				if edgeGlow.Parent then
					edgeGlow:Destroy()
				end
			end)

			rootScale.Scale = 1
			TweenService:Create(rootScale, TweenInfo.new(0.2, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1.25 }):Play()
			task.delay(0.2, function()
				TweenService:Create(rootScale, TweenInfo.new(0.2, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end)

			gemIcon.Rotation = 0
			TweenService:Create(gemIcon, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 360 }):Play()

			local pool = MicrocopyConfig.PlaytimeGemReward
			local template = pool[math.random(1, #pool)]
			local secs = lastPlaytimeProgress
			if secs < 1 then
				secs = Constants.PLAYTIME_GEM_INTERVAL or 300
			end
			local mins = math.max(1, math.floor(secs / 60))
			local flavor = template:gsub("{AMOUNT}", "1"):gsub("{MINUTES}", tostring(mins))
			VFXFacade.currencyPopup("gems", 1, flavor)
			HUD.pulseCurrencyLabel("gems")
			local bright = Color3.fromRGB(255, 200, 255)
			local orig = label.TextColor3
			TweenService:Create(label, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextColor3 = bright,
			}):Play()
			task.delay(0.14, function()
				if label.Parent then
					TweenService:Create(label, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						TextColor3 = orig,
					}):Play()
				end
			end)
		end
	end)

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(update)
	local d = Remotes.getFunction("GetPlayerData"):InvokeServer()
	update(d)
end

return PlaytimeGemHUD
