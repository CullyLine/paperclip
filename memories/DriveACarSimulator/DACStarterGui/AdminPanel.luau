--!strict
--[[
	Admin Panel — in-game god-mode UI with 12 tabs.
	UI is pre-built in StarterGui.AdminPanel; this script only wires events.
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

local AdminPanel = {}

local gui: ScreenGui
local contentArea: Frame
local isOpen = false
local flyEnabled = false
local flyConn: RBXScriptConnection? = nil
local activePageName: string? = nil
local godOn = false

local TAB_COLOR = Color3.fromRGB(30, 30, 48)
local TAB_ACTIVE = Color3.fromRGB(65, 50, 140)
local BTN_HOVER = Color3.fromRGB(75, 60, 150)

local pages: { [string]: ScrollingFrame } = {}
local tabButtons: { [string]: TextButton } = {}

local function sendCommand(action: string, args: { [string]: any }?)
	local payload = args or {}
	payload.action = action
	Remotes.getEvent("AdminCommand"):FireServer(payload)
end

local function find(parent: Instance, name: string): Instance?
	return parent:FindFirstChild(name, true)
end

local function addHover(btn: TextButton)
	local base = btn.BackgroundColor3
	local r, g, b = base.R, base.G, base.B
	local hover = Color3.new(math.min(r + 0.08, 1), math.min(g + 0.08, 1), math.min(b + 0.08, 1))
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = hover }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = base }):Play()
	end)
end

local function wireBtn(page: Instance, btnName: string, callback: () -> ())
	local btn = find(page, btnName) :: TextButton?
	if btn and btn:IsA("TextButton") then
		addHover(btn)
		btn.MouseButton1Click:Connect(callback)
	end
end

local function wireSimple(page: Instance, btnName: string, action: string, args: { [string]: any }?)
	wireBtn(page, btnName, function()
		sendCommand(action, if args then table.clone(args) else nil)
	end)
end

-- ============= TAB SWITCHING =============

local TAB_NAMES = {
	"Currency", "Progression", "Vehicles", "Pets", "World", "Passes",
	"Player", "Mad Science", "Classic VIP", "Server Wide", "All Servers", "Server Hop",
}

local function switchTab(name: string)
	activePageName = name
	local pageName = "Page_" .. name:gsub(" ", "_")
	for pn, page in pages do
		page.Visible = (pn == pageName)
	end
	for tn, btn in tabButtons do
		btn.BackgroundColor3 = if tn == name then TAB_ACTIVE else TAB_COLOR
	end
	if name == "Passes" then AdminPanel.populatePasses() end
	if name == "Server Hop" then AdminPanel.populatePlayerList() end
end

-- ============= DYNAMIC CONTENT =============

function AdminPanel.populatePasses()
	local passPage = pages["Page_Passes"]
	if not passPage then return end
	local container = find(passPage, "PassContainer")
	if not container then return end
	for _, child in container:GetChildren() do
		if child:IsA("TextButton") then child:Destroy() end
	end
	for passId, passDef in GamePassConfig.Passes do
		local btn = Instance.new("TextButton")
		btn.Name = "Pass_" .. tostring(passId)
		btn.Text = passDef.name or tostring(passId)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 13
		btn.TextColor3 = Color3.fromRGB(230, 230, 240)
		btn.BackgroundColor3 = Color3.fromRGB(55, 45, 110)
		btn.Size = UDim2.new(1, 0, 0, 30)
		btn.AutoButtonColor = false
		btn.Parent = container
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 5)
		c.Parent = btn
		addHover(btn)
		local capturedId = passId
		btn.MouseButton1Click:Connect(function()
			sendCommand("toggle_pass", { passId = capturedId })
		end)
	end
end

function AdminPanel.populatePlayerList()
	local hopPage = pages["Page_Server_Hop"]
	if not hopPage then return end
	local list = find(hopPage, "PlayerList") :: ScrollingFrame?
	if not list then return end
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") and child.Name ~= "PlayerTemplate" then
			child:Destroy()
		end
	end
	local template = list:FindFirstChild("PlayerTemplate") :: TextLabel?
	for i, p in Players:GetPlayers() do
		local lbl: TextLabel
		if template then
			lbl = template:Clone() :: TextLabel
		else
			lbl = Instance.new("TextLabel")
			lbl.Font = Enum.Font.Gotham
			lbl.TextSize = 13
			lbl.TextColor3 = Color3.fromRGB(230, 230, 240)
			lbl.BackgroundTransparency = 1
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Size = UDim2.new(1, 0, 0, 22)
		end
		lbl.Name = "Player_" .. tostring(p.UserId)
		lbl.Text = `{p.Name}  (ID: {p.UserId})`
		lbl.Visible = true
		lbl.LayoutOrder = i
		lbl.Parent = list
	end
end

-- ============= PER-PAGE WIRING =============

local function wireCurrencyPage(pg: Instance)
	for _, cur in { "Coins", "Gems", "Crystals", "Skulls" } do
		local lower = string.lower(cur)
		local amounts = { ["1K"] = 1000, ["10K"] = 10000, ["100K"] = 100000, ["1M"] = 1000000, ["10M"] = 10000000 }
		for suffix, amt in amounts do
			local capturedAmt = amt
			wireBtn(pg, "Btn_" .. cur .. "_" .. suffix, function()
				sendCommand("give_currency", { currency = lower, amount = capturedAmt })
			end)
		end
		local input = find(pg, "Input_" .. cur) :: TextBox?
		wireBtn(pg, "Btn_" .. cur .. "_Set", function()
			if input then
				local n = tonumber(input.Text)
				if n then sendCommand("set_currency", { currency = lower, amount = n }) end
			end
		end)
	end
end

local function wireProgressionPage(pg: Instance)
	local rebInput = find(pg, "Input_Rebirths") :: TextBox?
	wireBtn(pg, "Btn_SetRebirths", function()
		if rebInput then
			local n = tonumber(rebInput.Text)
			if n then sendCommand("set_rebirths", { count = n }) end
		end
	end)
	wireSimple(pg, "Btn_MaxStats", "max_stats")
	wireSimple(pg, "Btn_CompleteTutorial", "complete_tutorial")
	local bpInput = find(pg, "Input_BPTier") :: TextBox?
	wireBtn(pg, "Btn_SetBPTier", function()
		if bpInput then
			local t = tonumber(bpInput.Text)
			if t then sendCommand("set_bp_tier", { tier = t }) end
		end
	end)
	local resetCount = 0
	wireBtn(pg, "Btn_ResetData", function()
		resetCount += 1
		if resetCount >= 3 then
			sendCommand("reset_data")
			resetCount = 0
		end
	end)
end

local function wireVehiclesPage(pg: Instance)
	wireSimple(pg, "Btn_UnlockAllCars", "unlock_all_cars")
	wireSimple(pg, "Btn_MaxUpgrades", "max_stats")
	wireSimple(pg, "Btn_InfiniteFuel", "infinite_fuel")
end

local function wirePetsPage(pg: Instance)
	wireSimple(pg, "Btn_GiveAllPets", "give_all_pets")
	wireSimple(pg, "Btn_MaxSlots", "max_pet_slots")
	wireSimple(pg, "Btn_ClearPets", "clear_pets")
end

local function wireWorldPage(pg: Instance)
	wireSimple(pg, "Btn_UnlockAllWorlds", "unlock_all_worlds")
	local gravInput = find(pg, "Input_Gravity") :: TextBox?
	wireBtn(pg, "Btn_SetGravity", function()
		if gravInput then
			local g = tonumber(gravInput.Text)
			if g then sendCommand("set_gravity", { gravity = g }) end
		end
	end)
	local timeInput = find(pg, "Input_Time") :: TextBox?
	wireBtn(pg, "Btn_SetTime", function()
		if timeInput then
			local t = tonumber(timeInput.Text)
			if t then sendCommand("set_time", { time = t }) end
		end
	end)
end

local function wirePlayerPage(pg: Instance)
	local spdInput = find(pg, "Input_WalkSpeed") :: TextBox?
	wireBtn(pg, "Btn_SetWalkSpeed", function()
		if spdInput then
			local s = tonumber(spdInput.Text)
			if s then sendCommand("set_walkspeed", { speed = s }) end
		end
	end)
	local scaleInput = find(pg, "Input_Scale") :: TextBox?
	wireBtn(pg, "Btn_SetScale", function()
		if scaleInput then
			local s = tonumber(scaleInput.Text)
			if s then sendCommand("set_scale", { scale = s }) end
		end
	end)
	wireBtn(pg, "Btn_GodMode", function()
		godOn = not godOn
		sendCommand("god_mode", { enabled = godOn })
	end)
	wireSimple(pg, "Btn_Sparkles", "sparkles")
	wireBtn(pg, "Btn_Explosion", function()
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local pos = hrp.Position + hrp.CFrame.LookVector * 30
				sendCommand("explosion", { position = { x = pos.X, y = pos.Y, z = pos.Z }, radius = 40 })
			end
		end
	end)
	wireSimple(pg, "Btn_MaxEverything", "max_everything")
end

local function wireMadSciencePage(pg: Instance)
	wireBtn(pg, "Btn_MoonGravity", function() sendCommand("set_gravity", { gravity = 30 }) end)
	wireBtn(pg, "Btn_NormalGravity", function() sendCommand("set_gravity", { gravity = 196.2 }) end)
	wireBtn(pg, "Btn_Fling", function() sendCommand("sw_fling_all") end)
	wireBtn(pg, "Btn_Launch", function()
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				hrp.AssemblyLinearVelocity = Vector3.new(0, 200, 0)
			end
		end
	end)
	wireBtn(pg, "Btn_Tiny", function() sendCommand("set_scale", { scale = 0.3 }) end)
	wireBtn(pg, "Btn_Giant", function() sendCommand("set_scale", { scale = 5 }) end)
	wireBtn(pg, "Btn_Normal", function() sendCommand("set_scale", { scale = 1 }) end)
	wireBtn(pg, "Btn_Speed100", function() sendCommand("set_walkspeed", { speed = 100 }) end)
	wireBtn(pg, "Btn_Speed200", function() sendCommand("set_walkspeed", { speed = 200 }) end)
	wireBtn(pg, "Btn_Speed16", function() sendCommand("set_walkspeed", { speed = 16 }) end)
	wireSimple(pg, "Btn_ConfettiSelf", "sw_confetti")
	wireSimple(pg, "Btn_FireSelf", "sw_everyone_on_fire")
	wireSimple(pg, "Btn_SparklesSelf", "sparkles")
	wireSimple(pg, "Btn_ClearFX", "sw_undo_all")
end

local function wireClassicVIPPage(pg: Instance)
	local toolKeys = { Sword = "sword", Trowel = "trowel", Superball = "superball", Rocket = "rocket", Slingshot = "slingshot", Bomb = "bomb", DeleteTool = "delete_tool", PaintBucket = "paint_bucket" }
	for uiName, key in toolKeys do
		wireBtn(pg, "Btn_" .. uiName, function() sendCommand("give_tool", { tool = key }) end)
	end
	wireSimple(pg, "Btn_OGSparkles", "sparkles")
	wireBtn(pg, "Btn_OGFire", function() sendCommand("sw_everyone_on_fire") end)
end

local function wireServerWidePage(pg: Instance)
	local annInput = find(pg, "Input_Announce") :: TextBox?
	wireBtn(pg, "Btn_Announce", function()
		if annInput and annInput.Text ~= "" then
			sendCommand("server_announce", { message = annInput.Text })
		end
	end)
	wireSimple(pg, "Btn_SW_Tiny", "sw_everyone_tiny")
	wireSimple(pg, "Btn_SW_Giant", "sw_everyone_giant")
	wireSimple(pg, "Btn_SW_Normal", "sw_everyone_normal")
	wireSimple(pg, "Btn_SW_SpeedDemon", "sw_speed_demon", { speed = 200 })
	wireSimple(pg, "Btn_SW_Freeze", "sw_freeze_all")
	wireSimple(pg, "Btn_SW_Unfreeze", "sw_unfreeze_all")
	wireSimple(pg, "Btn_SW_BringAll", "sw_bring_all")
	wireSimple(pg, "Btn_SW_Scatter", "sw_scatter")
	wireSimple(pg, "Btn_SW_FlingAll", "sw_fling_all")
	wireSimple(pg, "Btn_SW_TripAll", "sw_trip_all")
	wireSimple(pg, "Btn_SW_Fire", "sw_everyone_on_fire")
	wireSimple(pg, "Btn_SW_Confetti", "sw_confetti")
	wireSimple(pg, "Btn_SW_Sparkle", "sw_everyone_sparkle")
	wireSimple(pg, "Btn_SW_SpinAll", "sw_spin_all")
	wireSimple(pg, "Btn_SW_Disco", "sw_disco")
	wireSimple(pg, "Btn_SW_Blackout", "sw_blackout")
	wireSimple(pg, "Btn_SW_LightsOn", "sw_lights_on")
	wireSimple(pg, "Btn_SW_MoonGrav", "sw_moon_gravity")
	wireSimple(pg, "Btn_SW_NormalGrav", "sw_normal_gravity")
	wireBtn(pg, "Btn_SW_FakeShutdown", function()
		sendCommand("sw_fake_shutdown", { seconds = 10 })
	end)
	wireSimple(pg, "Btn_SW_RainExplosions", "sw_rain_explosions")
	wireSimple(pg, "Btn_SW_SkillIssue", "sw_skill_issue")
	wireSimple(pg, "Btn_SW_LRatio", "sw_l_ratio")
	wireSimple(pg, "Btn_SW_Sigma", "sw_sigma")
	wireSimple(pg, "Btn_SW_Caught4K", "sw_caught_4k")
	wireSimple(pg, "Btn_SW_Ohio", "sw_ohio")
	wireSimple(pg, "Btn_SW_EmoDmg", "sw_emotional_damage")
	wireSimple(pg, "Btn_SW_NPC", "sw_npc_mode")
	wireSimple(pg, "Btn_SW_Baller", "sw_baller")
	wireSimple(pg, "Btn_SW_FakeGlitch", "sw_fake_glitch")
	wireSimple(pg, "Btn_SW_Yeet", "sw_yeet")
	wireSimple(pg, "Btn_SW_Based", "sw_based")
	wireSimple(pg, "Btn_SW_Oof", "sw_oof")
	wireSimple(pg, "Btn_SW_Joever", "sw_its_joever")
	wireSimple(pg, "Btn_SW_WeBack", "sw_we_are_so_back")
	wireSimple(pg, "Btn_SW_Compliment", "sw_compliment_all")
	wireSimple(pg, "Btn_SW_GoldStars", "sw_gold_stars")
	wireSimple(pg, "Btn_SW_GroupHug", "sw_group_hug")
	wireSimple(pg, "Btn_SW_Motivation", "sw_motivation")
	wireSimple(pg, "Btn_SW_BestServer", "sw_best_server")
	wireSimple(pg, "Btn_SW_Ovation", "sw_standing_ovation")
	local kickInput = find(pg, "Input_KickPlayer") :: TextBox?
	wireBtn(pg, "Btn_SW_Kick", function()
		if kickInput and kickInput.Text ~= "" then
			sendCommand("sw_kick_player", { playerName = kickInput.Text })
		end
	end)
	wireSimple(pg, "Btn_SW_UndoAll", "sw_undo_all")
end

local function wireAllServersPage(pg: Instance)
	local gAnnInput = find(pg, "Input_GAnnounce") :: TextBox?
	wireBtn(pg, "Btn_GAnnounce", function()
		if gAnnInput and gAnnInput.Text ~= "" then
			sendCommand("global_announce", { message = gAnnInput.Text })
		end
	end)
	wireSimple(pg, "Btn_G_Prank", "global_prank")
	wireSimple(pg, "Btn_G_FakeShutdown", "global_fake_shutdown")
	wireSimple(pg, "Btn_G_Tiny", "global_tiny")
	wireSimple(pg, "Btn_G_Giant", "global_giant")
	wireSimple(pg, "Btn_G_Normal", "global_normal_size")
	wireSimple(pg, "Btn_G_MoonGrav", "global_moon")
	wireSimple(pg, "Btn_G_NormalGrav", "global_normal_gravity")
	wireSimple(pg, "Btn_G_SpeedBoost", "global_speed_boost")
	wireSimple(pg, "Btn_G_Freeze", "global_freeze")
	wireSimple(pg, "Btn_G_Unfreeze", "global_unfreeze")
	wireSimple(pg, "Btn_G_Blackout", "global_blackout")
	wireSimple(pg, "Btn_G_LightsOn", "global_lights_on")
	wireSimple(pg, "Btn_G_Disco", "global_disco")
	wireSimple(pg, "Btn_G_RainExp", "global_rain_explosions")
	wireSimple(pg, "Btn_G_Confetti", "global_confetti")
	wireSimple(pg, "Btn_G_FlingAll", "global_fling")
	wireSimple(pg, "Btn_G_CoinGift", "global_coin_gift", { amount = 1000 })
	wireSimple(pg, "Btn_G_LRatio", "global_l_ratio")
	wireSimple(pg, "Btn_G_Rizzler", "global_rizzler")
	wireSimple(pg, "Btn_G_OhioBoss", "global_ohio_boss")
	wireSimple(pg, "Btn_G_SkillIssue", "global_skill_issue")
	wireSimple(pg, "Btn_G_Based", "global_based")
	wireSimple(pg, "Btn_G_Joever", "global_its_joever")
	wireSimple(pg, "Btn_G_WeBack", "global_we_are_so_back")
	wireSimple(pg, "Btn_G_Compliment", "global_compliment")
	wireSimple(pg, "Btn_G_GoldStars", "global_gold_stars")
	wireSimple(pg, "Btn_G_Appreciation", "global_appreciation")
	wireSimple(pg, "Btn_G_Motivation", "global_motivation")
	wireSimple(pg, "Btn_G_BestGame", "global_best_game")
	wireSimple(pg, "Btn_G_UndoAll", "global_undo")
end

local function wireServerHopPage(pg: Instance)
	local findInput = find(pg, "Input_FindPlayer") :: TextBox?
	wireBtn(pg, "Btn_FindJoin", function()
		if findInput and findInput.Text ~= "" then
			local uid = tonumber(findInput.Text)
			if uid then
				sendCommand("find_and_join", { userId = uid })
			else
				sendCommand("find_and_join", { playerName = findInput.Text })
			end
		end
	end)
	wireBtn(pg, "Btn_ForceJoin", function()
		if findInput and findInput.Text ~= "" then
			local uid = tonumber(findInput.Text)
			if uid then
				sendCommand("force_join", { userId = uid })
			else
				sendCommand("force_join", { playerName = findInput.Text })
			end
		end
	end)
end

local PAGE_WIRERS: { [string]: (Instance) -> () } = {
	Page_Currency = wireCurrencyPage,
	Page_Progression = wireProgressionPage,
	Page_Vehicles = wireVehiclesPage,
	Page_Pets = wirePetsPage,
	Page_World = wireWorldPage,
	Page_Player = wirePlayerPage,
	Page_Mad_Science = wireMadSciencePage,
	Page_Classic_VIP = wireClassicVIPPage,
	Page_Server_Wide = wireServerWidePage,
	Page_All_Servers = wireAllServersPage,
	Page_Server_Hop = wireServerHopPage,
}

-- ============= INIT =============

local function wireUI()
	gui = playerGui:WaitForChild("AdminPanel") :: ScreenGui
	local main = gui:WaitForChild("Main") :: Frame
	contentArea = main:WaitForChild("Content") :: Frame
	local sidebar = main:WaitForChild("SidebarClip"):WaitForChild("Sidebar") :: ScrollingFrame

	local closeBtn = main:WaitForChild("CloseButton") :: TextButton
	closeBtn.MouseButton1Click:Connect(function() AdminPanel.toggle() end)

	local backdrop = gui:WaitForChild("Backdrop") :: TextButton
	backdrop.MouseButton1Click:Connect(function() AdminPanel.toggle() end)

	for _, child in contentArea:GetChildren() do
		if child:IsA("ScrollingFrame") and string.sub(child.Name, 1, 5) == "Page_" then
			pages[child.Name] = child :: ScrollingFrame
			child.Visible = false
		end
	end

	for _, tabName in TAB_NAMES do
		local btnName = "Tab_" .. tabName:gsub(" ", "_")
		local btn = sidebar:FindFirstChild(btnName) :: TextButton?
		if btn then
			tabButtons[tabName] = btn
			local captured = tabName
			btn.MouseButton1Click:Connect(function() switchTab(captured) end)
		end
	end

	for pageName, wirer in PAGE_WIRERS do
		local pg = pages[pageName]
		if pg then wirer(pg) end
	end

	gui.Enabled = false
end

function AdminPanel.toggle()
	isOpen = not isOpen
	gui.Enabled = isOpen
	if isOpen and not activePageName then
		switchTab("Currency")
	end
end

function AdminPanel.init()
	local authorized = false
	local ok, result = pcall(function()
		return Remotes.getFunction("AdminAuth"):InvokeServer()
	end)
	if ok and result == true then authorized = true end
	if not authorized then return end

	wireUI()

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
		local adminBtn = actionBar:FindFirstChild("AdminButton") :: TextButton?
		if adminBtn then
			adminBtn.Visible = true
			adminBtn.MouseButton1Click:Connect(function()
				AdminPanel.toggle()
			end)
		end
	end)
end

return AdminPanel
