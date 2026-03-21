--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))

local CodesPanel = {}

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

	UIHelpers.textButton(root, "Redeem", Color3.fromRGB(76, 175, 80), 2, function()
		statusLabel.Text = "Redeeming…"
		statusLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
		Remotes.getEvent("RedeemCode"):FireServer(box.Text)
		task.delay(4, function()
			if statusLabel.Text == "Redeeming…" then
				statusLabel.Text = ""
			end
		end)
	end)
end

return CodesPanel
