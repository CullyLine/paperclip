--!strict
--[[
	Admin Panel — in-game god-mode UI with 9 tabs.
	Access: backtick key or wrench button on ActionBar.
	Auth: AdminAuth RemoteFunction gates visibility; all commands validated server-side.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local GamePassConfig = require(DAC:WaitForChild("Config"):WaitForChild("GamePassConfig"))
local Utils = require(DAC:WaitForChild("Utils"))

local AdminPanel = {}

local gui: ScreenGui
local mainFrame: Frame
local contentArea: Frame
local isOpen = false
local flyEnabled = false
local flyConn: RBXScriptConnection? = nil

local BG_COLOR = Color3.fromRGB(18, 18, 28)
local SIDEBAR_COLOR = Color3.fromRGB(12, 12, 22)
local TAB_COLOR = Color3.fromRGB(30, 30, 48)
local TAB_ACTIVE = Color3.fromRGB(65, 50, 140)
local BTN_COLOR = Color3.fromRGB(55, 45, 110)
local BTN_HOVER = Color3.fromRGB(75, 60, 150)
local DANGER_COLOR = Color3.fromRGB(180, 40, 40)
local SUCCESS_COLOR = Color3.fromRGB(40, 160, 80)
local TEXT_COLOR = Color3.fromRGB(230, 230, 240)
local DIM_TEXT = Color3.fromRGB(160, 160, 180)
local INPUT_BG = Color3.fromRGB(35, 35, 55)

local function sendCommand(action: string, args: { [string]: any }?)
	local payload = args or {}
	payload.action = action
	Remotes.getEvent("AdminCommand"):FireServer(payload)
end

local function corner(parent: GuiObject, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
end

local function stroke(parent: GuiObject, color: Color3?, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(60, 55, 100)
	s.Thickness = thickness or 1
	s.Parent = parent
end

local function makeButton(parent: GuiObject, text: string, color: Color3?, size: UDim2?, callback: () -> ()): TextButton
	local btn = Instance.new("TextButton")
	btn.Text = text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 13
	btn.TextColor3 = TEXT_COLOR
	btn.BackgroundColor3 = color or BTN_COLOR
	btn.Size = size or UDim2.new(0, 90, 0, 32)
	btn.AutoButtonColor = false
	btn.Parent = parent
	corner(btn, 5)

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = BTN_HOVER }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = color or BTN_COLOR }):Play()
	end)
	btn.MouseButton1Click:Connect(callback)
	return btn
end

local function makeLabel(parent: GuiObject, text: string, size: number?, bold: boolean?): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Text = text
	lbl.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	lbl.TextSize = size or 14
	lbl.TextColor3 = TEXT_COLOR
	lbl.BackgroundTransparency = 1
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Size = UDim2.new(1, 0, 0, 20)
	lbl.Parent = parent
	return lbl
end

local function makeInput(parent: GuiObject, placeholder: string, width: number?): TextBox
	local box = Instance.new("TextBox")
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = DIM_TEXT
	box.Text = ""
	box.Font = Enum.Font.Gotham
	box.TextSize = 14
	box.TextColor3 = TEXT_COLOR
	box.BackgroundColor3 = INPUT_BG
	box.Size = UDim2.new(0, width or 120, 0, 30)
	box.ClearTextOnFocus = false
	box.Parent = parent
	corner(box, 4)
	stroke(box)
	return box
end

local function makeSectionTitle(parent: GuiObject, text: string)
	local lbl = makeLabel(parent, text, 16, true)
	lbl.Size = UDim2.new(1, 0, 0, 28)
	lbl.TextColor3 = Color3.fromRGB(180, 170, 255)
	return lbl
end

local function makeFlowLayout(parent: GuiObject, padding: number?)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding or 8)
	layout.Parent = parent
end

local function makeHRow(parent: GuiObject, padding: number?): Frame
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 36)
	row.BackgroundTransparency = 1
	row.Parent = parent
	local hl = Instance.new("UIListLayout")
	hl.FillDirection = Enum.FillDirection.Horizontal
	hl.SortOrder = Enum.SortOrder.LayoutOrder
	hl.Padding = UDim.new(0, padding or 6)
	hl.VerticalAlignment = Enum.VerticalAlignment.Center
	hl.Parent = row
	return row
end

local function makeScrollContent(): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 4
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Parent = contentArea

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.PaddingBottom = UDim.new(0, 16)
	pad.Parent = scroll

	makeFlowLayout(scroll, 10)
	return scroll
end

local activePage: ScrollingFrame? = nil
local tabButtons: { [string]: TextButton } = {}

local function switchTab(name: string)
	if activePage then activePage:Destroy() end
	for n, btn in tabButtons do
		btn.BackgroundColor3 = if n == name then TAB_ACTIVE else TAB_COLOR
	end
end

-- ============= TAB BUILDERS =============

local function buildCurrencyTab()
	switchTab("Currency")
	local page = makeScrollContent()
	activePage = page

	for _, cur in { "coins", "gems", "crystals", "skulls" } do
		makeSectionTitle(page, cur:sub(1, 1):upper() .. cur:sub(2))
		local row = makeHRow(page)
		for _, amt in { 1000, 10000, 100000, 1000000, 10000000 } do
			local label
			if amt >= 1000000 then label = "+" .. (amt / 1000000) .. "M"
			elseif amt >= 1000 then label = "+" .. (amt / 1000) .. "K"
			else label = "+" .. amt end
			makeButton(row, label, nil, UDim2.new(0, 68, 0, 30), function()
				sendCommand("give_currency", { currency = cur, amount = amt })
			end)
		end

		local setRow = makeHRow(page)
		local input = makeInput(setRow, "Exact amount", 120)
		makeButton(setRow, "Set", SUCCESS_COLOR, UDim2.new(0, 50, 0, 30), function()
			local n = tonumber(input.Text)
			if n then sendCommand("set_currency", { currency = cur, amount = n }) end
		end)
	end
end

local function buildProgressionTab()
	switchTab("Progression")
	local page = makeScrollContent()
	activePage = page

	makeSectionTitle(page, "Rebirths")
	local rebRow = makeHRow(page)
	local rebInput = makeInput(rebRow, "Count", 80)
	makeButton(rebRow, "Set", SUCCESS_COLOR, UDim2.new(0, 60, 0, 30), function()
		local n = tonumber(rebInput.Text)
		if n then sendCommand("set_rebirths", { count = n }) end
	end)

	makeSectionTitle(page, "Quick Actions")
	local row = makeHRow(page)
	makeButton(row, "Max Stats", BTN_COLOR, UDim2.new(0, 90, 0, 30), function() sendCommand("max_stats") end)
	makeButton(row, "Complete Tutorial", BTN_COLOR, UDim2.new(0, 130, 0, 30), function() sendCommand("complete_tutorial") end)

	makeSectionTitle(page, "Danger Zone")
	local dRow = makeHRow(page)
	local resetConfirm = { count = 0 }
	makeButton(dRow, "Reset Data", DANGER_COLOR, UDim2.new(0, 110, 0, 30), function()
		resetConfirm.count += 1
		if resetConfirm.count >= 3 then
			sendCommand("reset_data")
			resetConfirm.count = 0
		end
	end)
	local note = makeLabel(dRow, "Click 3x to confirm", 11)
	note.TextColor3 = DIM_TEXT
	note.Size = UDim2.new(0, 140, 0, 30)
end

local function buildVehiclesTab()
	switchTab("Vehicles")
	local page = makeScrollContent()
	activePage = page

	makeSectionTitle(page, "Cars")
	local row1 = makeHRow(page)
	makeButton(row1, "Unlock All Cars", SUCCESS_COLOR, UDim2.new(0, 130, 0, 30), function() sendCommand("unlock_all_cars") end)
	makeButton(row1, "Max Upgrades", BTN_COLOR, UDim2.new(0, 120, 0, 30), function() sendCommand("max_stats") end)

	makeSectionTitle(page, "Fuel")
	local row2 = makeHRow(page)
	makeButton(row2, "Infinite Fuel", SUCCESS_COLOR, UDim2.new(0, 110, 0, 30), function() sendCommand("infinite_fuel") end)
end

local function buildPetsTab()
	switchTab("Pets")
	local page = makeScrollContent()
	activePage = page

	makeSectionTitle(page, "Pets")
	local row1 = makeHRow(page)
	makeButton(row1, "Give All Pets", SUCCESS_COLOR, UDim2.new(0, 120, 0, 30), function() sendCommand("give_all_pets") end)
	makeButton(row1, "Max Slots (64)", BTN_COLOR, UDim2.new(0, 120, 0, 30), function() sendCommand("max_pet_slots") end)

	local row2 = makeHRow(page)
	makeButton(row2, "Clear All Pets", DANGER_COLOR, UDim2.new(0, 120, 0, 30), function() sendCommand("clear_pets") end)
end

local function buildWorldTab()
	switchTab("World")
	local page = makeScrollContent()
	activePage = page

	makeSectionTitle(page, "Worlds")
	local row = makeHRow(page)
	makeButton(row, "Unlock All Worlds", SUCCESS_COLOR, UDim2.new(0, 150, 0, 30), function() sendCommand("unlock_all_worlds") end)

	makeSectionTitle(page, "Time of Day")
	local timeRow = makeHRow(page)
	local timeInput = makeInput(timeRow, "0-24", 60)
	timeInput.Text = "14"
	makeButton(timeRow, "Set", BTN_COLOR, UDim2.new(0, 50, 0, 30), function()
		local t = tonumber(timeInput.Text)
		if t then sendCommand("set_time", { time = t }) end
	end)
	for _, preset in { { "Dawn", 6 }, { "Noon", 12 }, { "Sunset", 18 }, { "Night", 0 } } do
		makeButton(timeRow, preset[1], TAB_COLOR, UDim2.new(0, 60, 0, 30), function()
			sendCommand("set_time", { time = preset[2] })
		end)
	end

	makeSectionTitle(page, "Gravity")
	local gravRow = makeHRow(page)
	local gravInput = makeInput(gravRow, "196.2", 80)
	gravInput.Text = "196.2"
	makeButton(gravRow, "Set", BTN_COLOR, UDim2.new(0, 50, 0, 30), function()
		local g = tonumber(gravInput.Text)
		if g then sendCommand("set_gravity", { gravity = g }) end
	end)
	makeButton(gravRow, "Moon", TAB_COLOR, UDim2.new(0, 55, 0, 30), function()
		sendCommand("set_gravity", { gravity = 30 })
	end)
	makeButton(gravRow, "Zero-G", TAB_COLOR, UDim2.new(0, 60, 0, 30), function()
		sendCommand("set_gravity", { gravity = 0.1 })
	end)
	makeButton(gravRow, "Jupiter", TAB_COLOR, UDim2.new(0, 60, 0, 30), function()
		sendCommand("set_gravity", { gravity = 600 })
	end)
end

local function buildPassesTab()
	switchTab("Passes")
	local page = makeScrollContent()
	activePage = page

	makeSectionTitle(page, "Game Passes (toggle)")
	for passId, passDef in GamePassConfig.Passes do
		local row = makeHRow(page)
		makeButton(row, passDef.name or passId, BTN_COLOR, UDim2.new(0, 180, 0, 30), function()
			sendCommand("toggle_pass", { passId = passId })
		end)
	end

	makeSectionTitle(page, "Battle Pass")
	local bpRow = makeHRow(page)
	local bpInput = makeInput(bpRow, "Tier #", 60)
	makeButton(bpRow, "Set Tier", SUCCESS_COLOR, UDim2.new(0, 80, 0, 30), function()
		local t = tonumber(bpInput.Text)
		if t then sendCommand("set_bp_tier", { tier = t }) end
	end)
end

local function buildPlayerTab()
	switchTab("Player")
	local page = makeScrollContent()
	activePage = page

	makeSectionTitle(page, "Walk Speed")
	local spdRow = makeHRow(page)
	local spdInput = makeInput(spdRow, "16", 60)
	spdInput.Text = "16"
	makeButton(spdRow, "Set", BTN_COLOR, UDim2.new(0, 50, 0, 30), function()
		local s = tonumber(spdInput.Text)
		if s then sendCommand("set_walkspeed", { speed = s }) end
	end)
	for _, v in { 50, 100, 200, 500 } do
		makeButton(spdRow, tostring(v), TAB_COLOR, UDim2.new(0, 50, 0, 30), function()
			sendCommand("set_walkspeed", { speed = v })
		end)
	end

	makeSectionTitle(page, "Scale")
	local scaleRow = makeHRow(page)
	local scaleInput = makeInput(scaleRow, "1.0", 60)
	scaleInput.Text = "1"
	makeButton(scaleRow, "Set", BTN_COLOR, UDim2.new(0, 50, 0, 30), function()
		local s = tonumber(scaleInput.Text)
		if s then sendCommand("set_scale", { scale = s }) end
	end)
	makeButton(scaleRow, "Mini", TAB_COLOR, UDim2.new(0, 50, 0, 30), function()
		sendCommand("set_scale", { scale = 0.3 })
	end)
	makeButton(scaleRow, "Normal", TAB_COLOR, UDim2.new(0, 60, 0, 30), function()
		sendCommand("set_scale", { scale = 1 })
	end)
	makeButton(scaleRow, "Giant", TAB_COLOR, UDim2.new(0, 50, 0, 30), function()
		sendCommand("set_scale", { scale = 5 })
	end)

	makeSectionTitle(page, "Toggles")
	local togRow = makeHRow(page)
	local godOn = false
	makeButton(togRow, "God Mode", BTN_COLOR, UDim2.new(0, 90, 0, 30), function()
		godOn = not godOn
		sendCommand("god_mode", { enabled = godOn })
	end)
	makeButton(togRow, "Fly / Noclip", BTN_COLOR, UDim2.new(0, 100, 0, 30), function()
		flyEnabled = not flyEnabled
		local char = player.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		if flyEnabled then
			local bv = Instance.new("BodyVelocity")
			bv.Name = "AdminFly"
			bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			bv.Velocity = Vector3.zero
			bv.Parent = hrp
			local RunService = game:GetService("RunService")
			flyConn = RunService.RenderStepped:Connect(function()
				if not flyEnabled then return end
				local cam = game.Workspace.CurrentCamera
				local mv = Vector3.zero
				if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv += cam.CFrame.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv -= cam.CFrame.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv -= cam.CFrame.RightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv += cam.CFrame.RightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv += Vector3.yAxis end
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then mv -= Vector3.yAxis end
				local flyBv = hrp:FindFirstChild("AdminFly")
				if flyBv and flyBv:IsA("BodyVelocity") then
					flyBv.Velocity = if mv.Magnitude > 0 then mv.Unit * 120 else Vector3.zero
				end
			end)
		else
			local flyBv = hrp:FindFirstChild("AdminFly")
			if flyBv then flyBv:Destroy() end
			if flyConn then flyConn:Disconnect(); flyConn = nil end
		end
	end)

	makeSectionTitle(page, "Teleport to Player")
	local tpRow = makeHRow(page)
	local tpInput = makeInput(tpRow, "Player name", 140)
	makeButton(tpRow, "Teleport", BTN_COLOR, UDim2.new(0, 80, 0, 30), function()
		local name = tpInput.Text
		for _, p in Players:GetPlayers() do
			if string.lower(p.Name):find(string.lower(name)) then
				local char = player.Character
				local tChar = p.Character
				if char and tChar then
					local hrp = char:FindFirstChild("HumanoidRootPart")
					local tHrp = tChar:FindFirstChild("HumanoidRootPart")
					if hrp and tHrp then hrp.CFrame = tHrp.CFrame * CFrame.new(5, 0, 0) end
				end
				break
			end
		end
	end)
end

local function buildMadScienceTab()
	switchTab("Mad Science")
	local page = makeScrollContent()
	activePage = page

	makeSectionTitle(page, "Nuclear Options")
	local row1 = makeHRow(page)
	makeButton(row1, "MAX EVERYTHING", Color3.fromRGB(200, 150, 0), UDim2.new(0, 160, 0, 36), function()
		sendCommand("max_everything")
	end)

	makeSectionTitle(page, "Speed Multiplier")
	local row2 = makeHRow(page)
	for _, mul in { 1, 10, 50, 100 } do
		local label = if mul == 1 then "Normal" else `x{mul}`
		makeButton(row2, label, BTN_COLOR, UDim2.new(0, 70, 0, 30), function()
			sendCommand("speed_multiplier", { multiplier = mul })
		end)
	end

	makeSectionTitle(page, "Chaos")
	local row3 = makeHRow(page)
	makeButton(row3, "Explosion Here", DANGER_COLOR, UDim2.new(0, 120, 0, 30), function()
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local pos = hrp.Position + hrp.CFrame.LookVector * 30
				sendCommand("explosion", { position = { x = pos.X, y = pos.Y, z = pos.Z }, radius = 40 })
			end
		end
	end)
	makeButton(row3, "Sparkle Time", Color3.fromRGB(200, 180, 50), UDim2.new(0, 110, 0, 30), function()
		sendCommand("sparkles")
	end)

	makeSectionTitle(page, "Server Announce")
	local annRow = makeHRow(page)
	local annInput = makeInput(annRow, "Message to all players", 240)
	makeButton(annRow, "Send", SUCCESS_COLOR, UDim2.new(0, 60, 0, 30), function()
		if annInput.Text ~= "" then sendCommand("server_announce", { message = annInput.Text }) end
	end)
end

local function buildClassicVIPTab()
	switchTab("Classic VIP")
	local page = makeScrollContent()
	activePage = page

	makeSectionTitle(page, "Classic Roblox Gear (2006-2010)")
	local note = makeLabel(page, "Just like the old VIP rooms...", 12)
	note.TextColor3 = DIM_TEXT

	local tools = {
		{ key = "sword", label = "Classic Linked Sword", color = Color3.fromRGB(140, 50, 50) },
		{ key = "trowel", label = "Trowel (Path Giver)", color = Color3.fromRGB(60, 130, 60) },
		{ key = "superball", label = "Superball Launcher", color = Color3.fromRGB(50, 100, 180) },
		{ key = "rocket", label = "Rocket Launcher", color = Color3.fromRGB(180, 80, 30) },
		{ key = "slingshot", label = "Slingshot", color = Color3.fromRGB(140, 120, 50) },
		{ key = "bomb", label = "Bomb", color = Color3.fromRGB(160, 40, 40) },
		{ key = "delete_tool", label = "Delete Hammer", color = Color3.fromRGB(100, 50, 150) },
		{ key = "paint_bucket", label = "Paint Bucket", color = Color3.fromRGB(50, 150, 130) },
	}

	for _, t in tools do
		local row = makeHRow(page)
		makeButton(row, t.label, t.color, UDim2.new(0, 200, 0, 34), function()
			sendCommand("give_tool", { tool = t.key })
		end)
	end

	makeSectionTitle(page, "Character Effects")
	local fxRow1 = makeHRow(page)
	makeButton(fxRow1, "Sparkle Time", Color3.fromRGB(200, 180, 50), UDim2.new(0, 120, 0, 32), function()
		sendCommand("sparkles")
	end)

	local fxRow2 = makeHRow(page)
	makeButton(fxRow2, "Ghost Mode", Color3.fromRGB(80, 80, 120), UDim2.new(0, 110, 0, 32), function()
		local char = player.Character
		if not char then return end
		for _, part in char:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = if part.Transparency < 0.5 then 0.8 else 0
			end
		end
	end)
	makeButton(fxRow2, "Giant Mode", Color3.fromRGB(160, 100, 40), UDim2.new(0, 110, 0, 32), function()
		sendCommand("set_scale", { scale = 5 })
	end)
	makeButton(fxRow2, "Mini Mode", Color3.fromRGB(60, 140, 140), UDim2.new(0, 110, 0, 32), function()
		sendCommand("set_scale", { scale = 0.3 })
	end)
	makeButton(fxRow2, "Normal", TAB_COLOR, UDim2.new(0, 70, 0, 32), function()
		sendCommand("set_scale", { scale = 1 })
	end)
end

local TROLL_COLOR = Color3.fromRGB(180, 80, 20)
local TROLL_HOVER = Color3.fromRGB(210, 100, 30)
local GLOBAL_COLOR = Color3.fromRGB(160, 30, 30)
local GLOBAL_HOVER = Color3.fromRGB(200, 50, 50)

local function makeTrollButton(parent: GuiObject, text: string, color: Color3, size: UDim2?, callback: () -> ()): TextButton
	local btn = Instance.new("TextButton")
	btn.Text = text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 13
	btn.TextColor3 = TEXT_COLOR
	btn.BackgroundColor3 = color
	btn.Size = size or UDim2.new(0, 140, 0, 32)
	btn.AutoButtonColor = false
	btn.Parent = parent
	corner(btn, 5)

	local hoverColor = if color == GLOBAL_COLOR then GLOBAL_HOVER else TROLL_HOVER
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = hoverColor }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = color }):Play()
	end)
	btn.MouseButton1Click:Connect(callback)
	return btn
end

local function buildServerWideTab()
	switchTab("Server Wide")
	local page = makeScrollContent()
	activePage = page

	makeSectionTitle(page, "Size Trolls")
	local sizeRow = makeHRow(page)
	makeTrollButton(sizeRow, "Everyone Tiny", TROLL_COLOR, UDim2.new(0, 120, 0, 30), function()
		sendCommand("sw_everyone_tiny")
	end)
	makeTrollButton(sizeRow, "Everyone Giant", TROLL_COLOR, UDim2.new(0, 130, 0, 30), function()
		sendCommand("sw_everyone_giant")
	end)
	makeButton(sizeRow, "Normal", TAB_COLOR, UDim2.new(0, 70, 0, 30), function()
		sendCommand("sw_everyone_normal")
	end)

	makeSectionTitle(page, "Movement")
	local moveRow = makeHRow(page)
	makeTrollButton(moveRow, "Freeze All", TROLL_COLOR, UDim2.new(0, 100, 0, 30), function()
		sendCommand("sw_freeze_all")
	end)
	makeButton(moveRow, "Unfreeze", TAB_COLOR, UDim2.new(0, 80, 0, 30), function()
		sendCommand("sw_unfreeze_all")
	end)
	makeTrollButton(moveRow, "Speed Demon", TROLL_COLOR, UDim2.new(0, 110, 0, 30), function()
		sendCommand("sw_speed_demon", { speed = 200 })
	end)

	local moveRow2 = makeHRow(page)
	makeTrollButton(moveRow2, "FLING ALL", DANGER_COLOR, UDim2.new(0, 100, 0, 30), function()
		sendCommand("sw_fling_all")
	end)
	makeTrollButton(moveRow2, "Trip Everyone", TROLL_COLOR, UDim2.new(0, 120, 0, 30), function()
		sendCommand("sw_trip_all")
	end)
	makeTrollButton(moveRow2, "Spin Cycle", TROLL_COLOR, UDim2.new(0, 100, 0, 30), function()
		sendCommand("sw_spin_all")
	end)

	makeSectionTitle(page, "Teleportation")
	local tpRow = makeHRow(page)
	makeButton(tpRow, "Bring Everyone", BTN_COLOR, UDim2.new(0, 130, 0, 30), function()
		sendCommand("sw_bring_all")
	end)
	makeTrollButton(tpRow, "Scatter!", TROLL_COLOR, UDim2.new(0, 80, 0, 30), function()
		sendCommand("sw_scatter")
	end)

	makeSectionTitle(page, "Visual Effects")
	local vfxRow = makeHRow(page)
	makeTrollButton(vfxRow, "Everyone On Fire", DANGER_COLOR, UDim2.new(0, 140, 0, 30), function()
		sendCommand("sw_everyone_on_fire")
	end)
	makeTrollButton(vfxRow, "Confetti", Color3.fromRGB(180, 130, 30), UDim2.new(0, 90, 0, 30), function()
		sendCommand("sw_confetti")
	end)
	makeTrollButton(vfxRow, "Sparkle All", Color3.fromRGB(180, 160, 40), UDim2.new(0, 100, 0, 30), function()
		sendCommand("sw_everyone_sparkle")
	end)

	makeSectionTitle(page, "Environment")
	local envRow = makeHRow(page)
	makeTrollButton(envRow, "DISCO!", Color3.fromRGB(180, 50, 180), UDim2.new(0, 80, 0, 30), function()
		sendCommand("sw_disco")
	end)
	makeTrollButton(envRow, "Blackout", Color3.fromRGB(30, 30, 30), UDim2.new(0, 80, 0, 30), function()
		sendCommand("sw_blackout")
	end)
	makeButton(envRow, "Lights On", TAB_COLOR, UDim2.new(0, 80, 0, 30), function()
		sendCommand("sw_lights_on")
	end)
	makeTrollButton(envRow, "Moon Gravity", TROLL_COLOR, UDim2.new(0, 110, 0, 30), function()
		sendCommand("sw_moon_gravity")
	end)

	local envRow2 = makeHRow(page)
	makeTrollButton(envRow2, "Rain Explosions", DANGER_COLOR, UDim2.new(0, 130, 0, 30), function()
		sendCommand("sw_rain_explosions")
	end)
	makeButton(envRow2, "Normal Gravity", TAB_COLOR, UDim2.new(0, 120, 0, 30), function()
		sendCommand("sw_normal_gravity")
	end)

	makeSectionTitle(page, "Psych Ops")
	local psychRow = makeHRow(page)
	makeTrollButton(psychRow, "Fake Shutdown (10s)", DANGER_COLOR, UDim2.new(0, 160, 0, 30), function()
		sendCommand("sw_fake_shutdown", { seconds = 10 })
	end)
	makeTrollButton(psychRow, "Fake Shutdown (30s)", DANGER_COLOR, UDim2.new(0, 160, 0, 30), function()
		sendCommand("sw_fake_shutdown", { seconds = 30 })
	end)

	makeSectionTitle(page, "Moderation")
	local modRow = makeHRow(page)
	local kickInput = makeInput(modRow, "Player name", 140)
	makeTrollButton(modRow, "Kick", DANGER_COLOR, UDim2.new(0, 60, 0, 30), function()
		if kickInput.Text ~= "" then
			sendCommand("sw_kick_player", { playerName = kickInput.Text })
		end
	end)

	makeSectionTitle(page, "Wholesome Commands")
	local wholeNote = makeLabel(page, "spread joy and confuse streamers with aggressive positivity", 11)
	wholeNote.TextColor3 = DIM_TEXT

	local wholeRow1 = makeHRow(page)
	makeButton(wholeRow1, "Compliment All", SUCCESS_COLOR, UDim2.new(0, 120, 0, 30), function()
		sendCommand("sw_compliment_all")
	end)
	makeButton(wholeRow1, "Gold Stars", Color3.fromRGB(200, 170, 30), UDim2.new(0, 100, 0, 30), function()
		sendCommand("sw_gold_stars")
	end)
	makeButton(wholeRow1, "Motivational", BTN_COLOR, UDim2.new(0, 110, 0, 30), function()
		sendCommand("sw_motivation")
	end)

	local wholeRow2 = makeHRow(page)
	makeButton(wholeRow2, "Group Hug", Color3.fromRGB(200, 100, 150), UDim2.new(0, 100, 0, 30), function()
		sendCommand("sw_group_hug")
	end)
	makeButton(wholeRow2, "Best Server Award", Color3.fromRGB(40, 140, 180), UDim2.new(0, 140, 0, 30), function()
		sendCommand("sw_best_server")
	end)
	makeButton(wholeRow2, "Standing Ovation", Color3.fromRGB(180, 140, 40), UDim2.new(0, 130, 0, 30), function()
		sendCommand("sw_standing_ovation")
	end)

	makeSectionTitle(page, "Meme Arsenal")
	local memeNote = makeLabel(page, "extremely based, extremely unhinged", 11)
	memeNote.TextColor3 = DIM_TEXT

	local memeRow1 = makeHRow(page)
	makeTrollButton(memeRow1, "SKILL ISSUE", DANGER_COLOR, UDim2.new(0, 110, 0, 30), function()
		sendCommand("sw_skill_issue")
	end)
	makeTrollButton(memeRow1, "L + Ratio", DANGER_COLOR, UDim2.new(0, 90, 0, 30), function()
		sendCommand("sw_l_ratio")
	end)
	makeTrollButton(memeRow1, "EMOTIONAL DAMAGE", DANGER_COLOR, UDim2.new(0, 155, 0, 30), function()
		sendCommand("sw_emotional_damage")
	end)

	local memeRow2 = makeHRow(page)
	makeTrollButton(memeRow2, "Sigma Grindset", Color3.fromRGB(200, 170, 30), UDim2.new(0, 130, 0, 30), function()
		sendCommand("sw_sigma")
	end)
	makeTrollButton(memeRow2, "Caught in 4K", TROLL_COLOR, UDim2.new(0, 120, 0, 30), function()
		sendCommand("sw_caught_4k")
	end)
	makeTrollButton(memeRow2, "NPC Mode", TROLL_COLOR, UDim2.new(0, 90, 0, 30), function()
		sendCommand("sw_npc_mode")
	end)

	local memeRow3 = makeHRow(page)
	makeTrollButton(memeRow3, "Ohio Mode", Color3.fromRGB(120, 20, 20), UDim2.new(0, 100, 0, 30), function()
		sendCommand("sw_ohio")
	end)
	makeTrollButton(memeRow3, "BALLER", Color3.fromRGB(180, 120, 30), UDim2.new(0, 80, 0, 30), function()
		sendCommand("sw_baller")
	end)
	makeTrollButton(memeRow3, "YEET", DANGER_COLOR, UDim2.new(0, 60, 0, 30), function()
		sendCommand("sw_yeet")
	end)
	makeTrollButton(memeRow3, "Fake Glitch", Color3.fromRGB(80, 20, 80), UDim2.new(0, 100, 0, 30), function()
		sendCommand("sw_fake_glitch")
	end)

	local memeRow4 = makeHRow(page)
	makeTrollButton(memeRow4, "Based Department", Color3.fromRGB(40, 120, 40), UDim2.new(0, 140, 0, 30), function()
		sendCommand("sw_based")
	end)
	makeTrollButton(memeRow4, "oof", Color3.fromRGB(100, 100, 100), UDim2.new(0, 50, 0, 30), function()
		sendCommand("sw_oof")
	end)

	local memeRow5 = makeHRow(page)
	makeTrollButton(memeRow5, "It's Joever", Color3.fromRGB(60, 60, 100), UDim2.new(0, 110, 0, 30), function()
		sendCommand("sw_its_joever")
	end)
	makeButton(memeRow5, "We're So Back", SUCCESS_COLOR, UDim2.new(0, 130, 0, 30), function()
		sendCommand("sw_we_are_so_back")
	end)

	makeSectionTitle(page, "Reset")
	local resetRow = makeHRow(page)
	makeButton(resetRow, "Undo ALL Effects", SUCCESS_COLOR, UDim2.new(0, 160, 0, 34), function()
		sendCommand("sw_undo_all")
	end)
	local undoNote = makeLabel(resetRow, "Restores gravity, size, speed, lighting, removes FX", 10)
	undoNote.TextColor3 = DIM_TEXT
	undoNote.Size = UDim2.new(0, 300, 0, 30)
end

local function buildAllServersTab()
	switchTab("All Servers")
	local page = makeScrollContent()
	activePage = page

	local warnLabel = makeLabel(page, "These commands affect EVERY server in the live game!", 13, true)
	warnLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	warnLabel.Size = UDim2.new(1, 0, 0, 24)
	local subNote = makeLabel(page, "Uses MessagingService -- perfect for stream trolling", 11)
	subNote.TextColor3 = DIM_TEXT

	makeSectionTitle(page, "Announcements")
	local annRow = makeHRow(page)
	local annInput = makeInput(annRow, "Message to ALL servers", 240)
	makeTrollButton(annRow, "Broadcast", GLOBAL_COLOR, UDim2.new(0, 100, 0, 30), function()
		if annInput.Text ~= "" then sendCommand("global_announce", { message = annInput.Text }) end
	end)

	local prankRow = makeHRow(page)
	makeTrollButton(prankRow, "Prank Notification (Random)", GLOBAL_COLOR, UDim2.new(0, 230, 0, 30), function()
		sendCommand("global_prank")
	end)

	makeSectionTitle(page, "Psych Ops (All Servers)")
	local psychRow = makeHRow(page)
	makeTrollButton(psychRow, "Fake Shutdown ALL", GLOBAL_COLOR, UDim2.new(0, 160, 0, 30), function()
		sendCommand("global_fake_shutdown")
	end)

	makeSectionTitle(page, "Size (All Servers)")
	local sizeRow = makeHRow(page)
	makeTrollButton(sizeRow, "Everyone Tiny", GLOBAL_COLOR, UDim2.new(0, 120, 0, 30), function()
		sendCommand("global_tiny")
	end)
	makeTrollButton(sizeRow, "Everyone Giant", GLOBAL_COLOR, UDim2.new(0, 130, 0, 30), function()
		sendCommand("global_giant")
	end)
	makeButton(sizeRow, "Normal Size", TAB_COLOR, UDim2.new(0, 100, 0, 30), function()
		sendCommand("global_normal_size")
	end)

	makeSectionTitle(page, "Physics (All Servers)")
	local physRow = makeHRow(page)
	makeTrollButton(physRow, "Moon Gravity", GLOBAL_COLOR, UDim2.new(0, 120, 0, 30), function()
		sendCommand("global_moon")
	end)
	makeButton(physRow, "Normal Gravity", TAB_COLOR, UDim2.new(0, 120, 0, 30), function()
		sendCommand("global_normal_gravity")
	end)
	makeTrollButton(physRow, "FLING ALL", GLOBAL_COLOR, UDim2.new(0, 100, 0, 30), function()
		sendCommand("global_fling")
	end)

	local physRow2 = makeHRow(page)
	makeTrollButton(physRow2, "Freeze All", GLOBAL_COLOR, UDim2.new(0, 100, 0, 30), function()
		sendCommand("global_freeze")
	end)
	makeButton(physRow2, "Unfreeze All", TAB_COLOR, UDim2.new(0, 110, 0, 30), function()
		sendCommand("global_unfreeze")
	end)

	makeSectionTitle(page, "Environment (All Servers)")
	local envRow = makeHRow(page)
	makeTrollButton(envRow, "BLACKOUT", GLOBAL_COLOR, UDim2.new(0, 100, 0, 30), function()
		sendCommand("global_blackout")
	end)
	makeButton(envRow, "Lights On", TAB_COLOR, UDim2.new(0, 90, 0, 30), function()
		sendCommand("global_lights_on")
	end)
	makeTrollButton(envRow, "DISCO!", Color3.fromRGB(160, 30, 160), UDim2.new(0, 80, 0, 30), function()
		sendCommand("global_disco")
	end)
	makeTrollButton(envRow, "Rain Explosions", GLOBAL_COLOR, UDim2.new(0, 130, 0, 30), function()
		sendCommand("global_rain_explosions")
	end)

	makeSectionTitle(page, "Effects (All Servers)")
	local fxRow = makeHRow(page)
	makeTrollButton(fxRow, "Speed Boost ALL", GLOBAL_COLOR, UDim2.new(0, 140, 0, 30), function()
		sendCommand("global_speed_boost")
	end)
	makeTrollButton(fxRow, "Confetti ALL", Color3.fromRGB(160, 120, 30), UDim2.new(0, 120, 0, 30), function()
		sendCommand("global_confetti")
	end)

	makeSectionTitle(page, "Gifts (All Servers)")
	local giftRow = makeHRow(page)
	for _, amt in { 1000, 10000, 100000, 1000000 } do
		local label
		if amt >= 1000000 then label = Utils.formatNumber(amt) .. " Coins"
		elseif amt >= 1000 then label = (amt / 1000) .. "K Coins"
		else label = amt .. " Coins" end
		makeButton(giftRow, label, SUCCESS_COLOR, UDim2.new(0, 100, 0, 30), function()
			sendCommand("global_coin_gift", { amount = amt })
		end)
	end

	makeSectionTitle(page, "Wholesome (All Servers)")
	local gWholeNote = makeLabel(page, "aggressively wholesome across the entire game", 11)
	gWholeNote.TextColor3 = DIM_TEXT

	local gwRow1 = makeHRow(page)
	makeButton(gwRow1, "Compliment Everyone", SUCCESS_COLOR, UDim2.new(0, 160, 0, 30), function()
		sendCommand("global_compliment")
	end)
	makeButton(gwRow1, "Gold Stars (Global)", Color3.fromRGB(200, 170, 30), UDim2.new(0, 150, 0, 30), function()
		sendCommand("global_gold_stars")
	end)

	local gwRow2 = makeHRow(page)
	makeButton(gwRow2, "Creator Appreciation", Color3.fromRGB(200, 100, 150), UDim2.new(0, 160, 0, 30), function()
		sendCommand("global_appreciation")
	end)
	makeButton(gwRow2, "Motivational Quote", BTN_COLOR, UDim2.new(0, 140, 0, 30), function()
		sendCommand("global_motivation")
	end)

	local gwRow3 = makeHRow(page)
	makeButton(gwRow3, "Best Game Ceremony", Color3.fromRGB(40, 140, 180), UDim2.new(0, 160, 0, 30), function()
		sendCommand("global_best_game")
	end)

	makeSectionTitle(page, "Meme Arsenal (All Servers)")
	local gMemeNote = makeLabel(page, "deploy the brainrot across the entire game", 11)
	gMemeNote.TextColor3 = DIM_TEXT

	local gmRow1 = makeHRow(page)
	makeTrollButton(gmRow1, "SKILL ISSUE (Global)", GLOBAL_COLOR, UDim2.new(0, 170, 0, 30), function()
		sendCommand("global_skill_issue")
	end)
	makeTrollButton(gmRow1, "L + Ratio (Global)", GLOBAL_COLOR, UDim2.new(0, 150, 0, 30), function()
		sendCommand("global_l_ratio")
	end)

	local gmRow2 = makeHRow(page)
	makeTrollButton(gmRow2, "The Rizzler Approaches", GLOBAL_COLOR, UDim2.new(0, 190, 0, 30), function()
		sendCommand("global_rizzler")
	end)
	makeTrollButton(gmRow2, "Ohio Final Boss", Color3.fromRGB(120, 20, 20), UDim2.new(0, 130, 0, 30), function()
		sendCommand("global_ohio_boss")
	end)

	local gmRow3 = makeHRow(page)
	makeTrollButton(gmRow3, "Based Department (Global)", Color3.fromRGB(40, 120, 40), UDim2.new(0, 200, 0, 30), function()
		sendCommand("global_based")
	end)

	local gmRow4 = makeHRow(page)
	makeTrollButton(gmRow4, "It's Joever (Global)", Color3.fromRGB(60, 60, 100), UDim2.new(0, 160, 0, 30), function()
		sendCommand("global_its_joever")
	end)
	makeButton(gmRow4, "We're So Back (Global)", SUCCESS_COLOR, UDim2.new(0, 180, 0, 30), function()
		sendCommand("global_we_are_so_back")
	end)

	makeSectionTitle(page, "Reset (All Servers)")
	local resetRow = makeHRow(page)
	makeButton(resetRow, "Undo ALL Effects (Every Server)", SUCCESS_COLOR, UDim2.new(0, 260, 0, 34), function()
		sendCommand("global_undo")
	end)
end

local function buildServerHopTab()
	switchTab("Server Hop")
	local page = makeScrollContent()
	activePage = page

	makeSectionTitle(page, "Find & Join Player's Server")
	local note = makeLabel(page, "Search by username or User ID. Uses MessagingService to find them across all servers.", 11)
	note.TextColor3 = DIM_TEXT
	note.TextWrapped = true
	note.Size = UDim2.new(1, 0, 0, 30)

	makeSectionTitle(page, "By Username")
	local nameRow = makeHRow(page)
	local nameInput = makeInput(nameRow, "Player name", 180)
	makeButton(nameRow, "Find & Join", BTN_COLOR, UDim2.new(0, 100, 0, 30), function()
		if nameInput.Text ~= "" then
			sendCommand("find_and_join", { playerName = nameInput.Text })
		end
	end)
	makeTrollButton(nameRow, "FORCE JOIN", DANGER_COLOR, UDim2.new(0, 100, 0, 30), function()
		if nameInput.Text ~= "" then
			sendCommand("force_join", { playerName = nameInput.Text })
		end
	end)

	makeSectionTitle(page, "By User ID")
	local idRow = makeHRow(page)
	local idInput = makeInput(idRow, "User ID", 140)
	makeButton(idRow, "Find & Join", BTN_COLOR, UDim2.new(0, 100, 0, 30), function()
		local uid = tonumber(idInput.Text)
		if uid then sendCommand("find_and_join", { userId = uid }) end
	end)
	makeTrollButton(idRow, "FORCE JOIN", DANGER_COLOR, UDim2.new(0, 100, 0, 30), function()
		local uid = tonumber(idInput.Text)
		if uid then sendCommand("force_join", { userId = uid }) end
	end)

	makeSectionTitle(page, "How It Works")
	local howRow1 = makeLabel(page, "Find & Join: Searches all servers, teleports you when found.", 11)
	howRow1.TextColor3 = DIM_TEXT
	howRow1.TextWrapped = true
	howRow1.Size = UDim2.new(1, 0, 0, 20)
	local howRow2 = makeLabel(page, "Force Join: Same, but if full, kicks a RANDOM (never the target or their friends).", 11)
	howRow2.TextColor3 = Color3.fromRGB(255, 100, 100)
	howRow2.TextWrapped = true
	howRow2.Size = UDim2.new(1, 0, 0, 30)
	local howRow3 = makeLabel(page, "Timeout: 15 seconds. If player isn't found, you'll get a notification.", 11)
	howRow3.TextColor3 = DIM_TEXT
	howRow3.TextWrapped = true
	howRow3.Size = UDim2.new(1, 0, 0, 20)

	makeSectionTitle(page, "Players In This Server")
	for _, p in Players:GetPlayers() do
		local pRow = makeHRow(page)
		local pLabel = makeLabel(pRow, `{p.Name}  (ID: {p.UserId})`, 12)
		pLabel.Size = UDim2.new(0, 280, 0, 24)
	end
end

-- ============= BUILD UI =============

local TABS = {
	{ name = "Currency", icon = "$", build = buildCurrencyTab },
	{ name = "Progression", icon = "^", build = buildProgressionTab },
	{ name = "Vehicles", icon = "C", build = buildVehiclesTab },
	{ name = "Pets", icon = "P", build = buildPetsTab },
	{ name = "World", icon = "W", build = buildWorldTab },
	{ name = "Passes", icon = "G", build = buildPassesTab },
	{ name = "Player", icon = "@", build = buildPlayerTab },
	{ name = "Mad Science", icon = "!", build = buildMadScienceTab },
	{ name = "Classic VIP", icon = "*", build = buildClassicVIPTab },
	{ name = "Server Wide", icon = "#", build = buildServerWideTab },
	{ name = "All Servers", icon = "~", build = buildAllServersTab },
	{ name = "Server Hop", icon = ">", build = buildServerHopTab },
}

local function buildUI()
	gui = Instance.new("ScreenGui")
	gui.Name = "AdminPanel"
	gui.DisplayOrder = 50_000
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local backdrop = Instance.new("TextButton")
	backdrop.Text = ""
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.4
	backdrop.BorderSizePixel = 0
	backdrop.AutoButtonColor = false
	backdrop.Parent = gui
	backdrop.MouseButton1Click:Connect(function()
		AdminPanel.toggle()
	end)

	mainFrame = Instance.new("Frame")
	mainFrame.Name = "Main"
	mainFrame.Size = UDim2.new(0, 780, 0, 500)
	mainFrame.Position = UDim2.new(0.5, -390, 0.5, -250)
	mainFrame.BackgroundColor3 = BG_COLOR
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = gui
	corner(mainFrame, 10)
	stroke(mainFrame, Color3.fromRGB(80, 70, 140), 2)

	local title = Instance.new("TextLabel")
	title.Text = "ADMIN PANEL"
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 18
	title.TextColor3 = Color3.fromRGB(200, 180, 255)
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -40, 0, 40)
	title.Position = UDim2.new(0, 16, 0, 0)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = mainFrame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "X"
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 18
	closeBtn.TextColor3 = TEXT_COLOR
	closeBtn.BackgroundTransparency = 1
	closeBtn.Size = UDim2.new(0, 40, 0, 40)
	closeBtn.Position = UDim2.new(1, -40, 0, 0)
	closeBtn.Parent = mainFrame
	closeBtn.MouseButton1Click:Connect(function() AdminPanel.toggle() end)

	local sidebarClip = Instance.new("Frame")
	sidebarClip.Name = "SidebarClip"
	sidebarClip.Size = UDim2.new(0, 140, 1, -44)
	sidebarClip.Position = UDim2.new(0, 0, 0, 42)
	sidebarClip.BackgroundColor3 = SIDEBAR_COLOR
	sidebarClip.BorderSizePixel = 0
	sidebarClip.ClipsDescendants = true
	sidebarClip.Parent = mainFrame
	local sideCorner = Instance.new("UICorner")
	sideCorner.CornerRadius = UDim.new(0, 8)
	sideCorner.Parent = sidebarClip

	local sidebar = Instance.new("ScrollingFrame")
	sidebar.Name = "Sidebar"
	sidebar.Size = UDim2.new(1, 0, 1, 0)
	sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
	sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sidebar.ScrollBarThickness = 3
	sidebar.BackgroundTransparency = 1
	sidebar.BorderSizePixel = 0
	sidebar.Parent = sidebarClip

	local sideLayout = Instance.new("UIListLayout")
	sideLayout.FillDirection = Enum.FillDirection.Vertical
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sideLayout.Padding = UDim.new(0, 2)
	sideLayout.Parent = sidebar

	local sidePad = Instance.new("UIPadding")
	sidePad.PaddingTop = UDim.new(0, 6)
	sidePad.PaddingLeft = UDim.new(0, 4)
	sidePad.PaddingRight = UDim.new(0, 4)
	sidePad.PaddingBottom = UDim.new(0, 6)
	sidePad.Parent = sidebar

	contentArea = Instance.new("Frame")
	contentArea.Name = "Content"
	contentArea.Size = UDim2.new(1, -148, 1, -44)
	contentArea.Position = UDim2.new(0, 144, 0, 42)
	contentArea.BackgroundTransparency = 1
	contentArea.Parent = mainFrame

	for i, tab in TABS do
		local btn = Instance.new("TextButton")
		btn.Name = tab.name
		btn.Text = tab.icon .. "  " .. tab.name
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 12
		btn.TextColor3 = TEXT_COLOR
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.BackgroundColor3 = TAB_COLOR
		btn.AutoButtonColor = false
		btn.Size = UDim2.new(1, 0, 0, 30)
		btn.LayoutOrder = i
		btn.Parent = sidebar
		corner(btn, 5)

		local btnPad = Instance.new("UIPadding")
		btnPad.PaddingLeft = UDim.new(0, 10)
		btnPad.Parent = btn

		tabButtons[tab.name] = btn
		btn.MouseButton1Click:Connect(function()
			tab.build()
		end)
	end

	gui.Enabled = false
end

function AdminPanel.toggle()
	isOpen = not isOpen
	gui.Enabled = isOpen
	if isOpen and not activePage then
		TABS[1].build()
	end
end

function AdminPanel.init()
	local authorized = false
	local ok, result = pcall(function()
		return Remotes.getFunction("AdminAuth"):InvokeServer()
	end)
	if ok and result == true then authorized = true end

	if not authorized then return end

	buildUI()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.Backquote then
			AdminPanel.toggle()
		end
	end)

	task.defer(function()
		local screenGui = playerGui:FindFirstChild("DACMain")
		if not screenGui then return end
		local actionBar = screenGui:FindFirstChild("ActionBar")
		if not actionBar then return end

		local adminBtn = Instance.new("ImageButton")
		adminBtn.Name = "AdminButton"
		adminBtn.Size = UDim2.new(0, 48, 0, 48)
		adminBtn.Position = UDim2.new(0, 8, 0.5, -24)
		adminBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 90)
		adminBtn.Image = "rbxassetid://15460672893"
		adminBtn.Parent = actionBar
		corner(adminBtn, 8)
		stroke(adminBtn, Color3.fromRGB(100, 80, 180), 2)

		local lbl = Instance.new("TextLabel")
		lbl.Text = "ADM"
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextSize = 9
		lbl.TextColor3 = Color3.fromRGB(200, 180, 255)
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1, 0, 0, 14)
		lbl.Position = UDim2.new(0, 0, 1, -14)
		lbl.Parent = adminBtn

		adminBtn.MouseButton1Click:Connect(function()
			AdminPanel.toggle()
		end)
	end)
end

return AdminPanel
