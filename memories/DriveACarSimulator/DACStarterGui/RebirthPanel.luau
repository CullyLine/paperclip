--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Utils = require(DAC:WaitForChild("Utils"))
local RebirthConfig = require(DAC:WaitForChild("Config"):WaitForChild("RebirthConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

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

	local lastRebirths: number? = nil

	local function refresh()
		local data = Remotes.getFunction("GetPlayerData"):InvokeServer()
		if not data then
			return
		end
		local cost = Utils.calculateRebirthCost(data.rebirths, RebirthConfig.BaseCost, RebirthConfig.CostMultiplier)
		info.Text = `Rebirths: {data.rebirths}\nCost: {Utils.formatNumber(cost)} coins (must have at least this many; coins reset on rebirth)\n\nRewards: +{RebirthConfig.Rewards.gasBoost} Gas, +{RebirthConfig.Rewards.powerBoost} Power, +{RebirthConfig.Rewards.speedBoost} Speed, +{RebirthConfig.Rewards.crystals} Crystals\n\nWARNING: Resets coins, eggs, and car upgrade levels per config.`
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

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(data: any)
		if type(data) == "table" and type(data.rebirths) == "number" then
			if lastRebirths ~= nil and data.rebirths > lastRebirths then
				VFXFacade.rebirthFlash(data.rebirths)
			end
			lastRebirths = data.rebirths
		end
		if root.Visible then
			refresh()
		end
	end)

	refresh()
end

return RebirthPanel
