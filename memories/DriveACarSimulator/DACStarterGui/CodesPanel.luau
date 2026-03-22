--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
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
	local root = UIHelpers.panel(sg, "CodesRoot")
	MenuHub.registerPanel("codes", root)
	UIHelpers.titleBar(root, "Codes", function()
		root.Visible = false
	end)

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.8, 0, 0, 40)
	box.Position = UDim2.new(0.5, 0, 0, 60)
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.PlaceholderText = "Enter code..."
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.Gotham
	box.TextSize = 18
	box.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	box.TextColor3 = Color3.new(1, 1, 1)
	box.Parent = root
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = box

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "RedeemStatus"
	statusLabel.Size = UDim2.new(0.9, 0, 0, 32)
	statusLabel.Position = UDim2.new(0.5, 0, 0, 108)
	statusLabel.AnchorPoint = Vector2.new(0.5, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 15
	statusLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	statusLabel.Text = ""
	statusLabel.TextWrapped = true
	statusLabel.Parent = root

	local redeemPending = false
	local redeemGen = 0
	local origInputBg = box.BackgroundColor3

	Remotes.getEvent("Notification").OnClientEvent:Connect(function(n: any)
		if not redeemPending or type(n) ~= "table" then
			return
		end
		local kind = n.type
		if kind ~= "success" and kind ~= "error" then
			return
		end
		local msg = if type(n.message) == "string" then n.message else ""
		if kind == "success" then
			if not string.find(msg, "Code redeemed", 1, true) then
				return
			end
			redeemPending = false
			statusLabel.Text = MicrocopyConfig.CodeRedeemSuccess[math.random(1, #MicrocopyConfig.CodeRedeemSuccess)]
			statusLabel.TextColor3 = Color3.fromRGB(160, 255, 180)
			SoundFacade.playOneShot("cha_ching")
			VFXFacade.rewardChestBurst()
			local g = Color3.fromRGB(72, 180, 96)
			TweenService:Create(box, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = g,
			}):Play()
			task.delay(0.2, function()
				if box.Parent then
					TweenService:Create(box, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundColor3 = origInputBg,
					}):Play()
				end
			end)
		elseif kind == "error" then
			redeemPending = false
			local line: string
			if string.find(msg, "expired", 1, true) then
				line = MicrocopyConfig.CodeRedeemExpired[math.random(1, #MicrocopyConfig.CodeRedeemExpired)]
			else
				line = MicrocopyConfig.CodeRedeemError[math.random(1, #MicrocopyConfig.CodeRedeemError)]
			end
			statusLabel.Text = line
			statusLabel.TextColor3 = Color3.fromRGB(255, 140, 140)
			SoundFacade.playOneShot("purchase_fail")
			task.spawn(function()
				shakeInput(box)
			end)
			local r = Color3.fromRGB(120, 50, 50)
			TweenService:Create(box, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = r,
			}):Play()
			task.delay(0.25, function()
				if box.Parent then
					TweenService:Create(box, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundColor3 = origInputBg,
					}):Play()
				end
			end)
		end
	end)

	UIHelpers.textButton(root, "Redeem", Color3.fromRGB(76, 175, 80), 2, function()
		redeemPending = true
		redeemGen += 1
		local gen = redeemGen
		statusLabel.Text = "Redeeming…"
		statusLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
		Remotes.getEvent("RedeemCode"):FireServer(box.Text)
		task.delay(15, function()
			if gen ~= redeemGen then
				return
			end
			if redeemPending and statusLabel.Text == "Redeeming…" then
				redeemPending = false
				statusLabel.Text = ""
			end
		end)
	end)
end

return CodesPanel
