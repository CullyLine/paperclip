--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

local PayoutPanel = {}

function PayoutPanel.init()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "DACPayout"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.Size = UDim2.new(0.5, 0, 0.55, 0)
	root.Position = UDim2.new(0.5, 0, 0.5, 0)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.BackgroundColor3 = Color3.fromRGB(22, 22, 44)
	root.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 16)
	c.Parent = root

	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 44)
	titleBar.BackgroundTransparency = 1
	titleBar.Parent = root

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -56, 1, 0)
	title.Position = UDim2.new(0, 16, 0, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 24
	title.TextColor3 = Color3.fromRGB(255, 213, 79)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Run Payout"
	title.Parent = titleBar

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.new(0, 40, 0, 40)
	close.Position = UDim2.new(1, -48, 0, 4)
	close.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
	close.Text = "X"
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Font = Enum.Font.GothamBold
	close.Parent = titleBar
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 8)
	cc.Parent = close
	close.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		gui.Enabled = false
	end)

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, -24, 1, -100)
	body.Position = UDim2.new(0, 12, 0, 52)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextSize = 16
	body.TextColor3 = Color3.new(1, 1, 1)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.Parent = root

	local again = Instance.new("TextButton")
	again.Size = UDim2.new(0.42, 0, 0, 40)
	again.Position = UDim2.new(0.06, 0, 1, -52)
	again.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
	again.Text = "Drive Again"
	again.TextColor3 = Color3.new(1, 1, 1)
	again.Font = Enum.Font.GothamBold
	again.Parent = root
	again.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		gui.Enabled = false
		Remotes.getEvent("StartRun"):FireServer()
	end)

	local lobby = Instance.new("TextButton")
	lobby.Size = UDim2.new(0.42, 0, 0, 40)
	lobby.Position = UDim2.new(0.52, 0, 1, -52)
	lobby.BackgroundColor3 = Color3.fromRGB(100, 140, 255)
	lobby.Text = "Back to menu"
	lobby.TextColor3 = Color3.new(1, 1, 1)
	lobby.Font = Enum.Font.GothamBold
	lobby.Parent = root
	lobby.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		gui.Enabled = false
	end)

	Remotes.getEvent("EndRun").OnClientEvent:Connect(function(results: any)
		local mult = results.breakdown and results.breakdown.runOfDayMultiplier or results.runOfDayMultiplier or 1
		local founderM = results.breakdown and results.breakdown.founderMultiplier or results.founderMultiplier or 1
		local skulls = results.skullsEarned or 0
		local powerM = results.breakdown and results.breakdown.powerMultiplier
		local powerLine = if type(powerM) == "number" then `\nPower mult: x{string.format("%.2f", powerM)}` else ""
		local celebration = results.runOfDayCelebration == true
		if celebration then
			title.Text = "RUN OF THE DAY!"
		else
			title.Text = "Run Payout"
		end
		local rotLine = if celebration then "\n★ RUN OF THE DAY: 3x COINS on this run! ★\n" else "\n"
		body.Text = `{rotLine}Distance: {Utils.formatNumber(results.totalDistance)} m\nLaps: {results.laps}\nCoins earned: {Utils.formatNumber(results.coinsEarned)}\nRun of the Day mult: {mult}x\nFounder's mult: {founderM}x\nSkulls: {skulls}{powerLine}\n\nBreakdown — base coins: {results.breakdown and Utils.formatNumber(results.breakdown.base) or "?"}, world x{results.breakdown and results.breakdown.worldMultiplier or "?"}`
		VFXFacade.currencyPopup("coins", results.coinsEarned or 0)
		if skulls > 0 then
			VFXFacade.skullDrop(skulls)
		end
		gui.Enabled = true
	end)
end

return PayoutPanel
