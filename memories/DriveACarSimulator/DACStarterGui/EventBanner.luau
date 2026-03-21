--!strict
--[[
	Top HUD banner during Founder's Bonus launch window with countdown to window end.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("DAC"):WaitForChild("Remotes"))

local EventBanner = {}

local function formatCountdown(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h = math.floor(s / 3600)
	local m = math.floor((s % 3600) / 60)
	local sec = s % 60
	return string.format("%02d:%02d:%02d", h, m, sec)
end

function EventBanner.init()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "DACEventBanner"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.Parent = player:WaitForChild("PlayerGui")

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.new(0.92, 0, 0, 44)
	bar.Position = UDim2.new(0.5, 0, 0, 8)
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.BackgroundColor3 = Color3.fromRGB(40, 28, 8)
	bar.BorderSizePixel = 0
	bar.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = bar

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(255, 200, 80)
	stroke.Parent = bar

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, -16, 1, 0)
	label.Position = UDim2.new(0, 8, 0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = Color3.fromRGB(255, 230, 140)
	label.Text = "FOUNDER'S BONUS: 2x COINS!"
	label.Parent = bar

	local endsAtUnix: number? = nil

	local function refresh()
		if not endsAtUnix then
			return
		end
		local left = endsAtUnix - os.time()
		label.Text = `FOUNDER'S BONUS: 2x COINS! Ends in {formatCountdown(left)}`
		if left <= 0 then
			gui.Enabled = false
		end
	end

	RunService.RenderStepped:Connect(function()
		if gui.Enabled and endsAtUnix then
			refresh()
		end
	end)

	Remotes.getEvent("LaunchEventState").OnClientEvent:Connect(function(state: any)
		if type(state) ~= "table" then
			return
		end
		if state.founderActive == true and type(state.founderEndsAtUnix) == "number" then
			endsAtUnix = state.founderEndsAtUnix
			gui.Enabled = true
			refresh()
		else
			gui.Enabled = false
		end
	end)
end

return EventBanner
