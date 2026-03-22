--!strict
--[[
	Pet index panel.
	Shell UI pre-built in DACMain.Panels.PetIndex; this script wires behavior.
	Pet cards are created dynamically from PetConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))

local PetIndexPanel = {}

local discoveredSeeded = false
local previouslyDiscovered: { [string]: boolean } = {}
local milestonesShown: { [number]: boolean } = {}
local MILESTONE_THRESHOLDS = { 25, 50, 75, 100 }
local SPARKLE_CHARS = { "\u{2605}", "\u{25CF}", "\u{25C6}" }

local function pickRandom(pool: { string }): string if #pool == 0 then return "" end; return pool[math.random(1, #pool)] end

local function spawnRarityBurst(parent: Instance, rarity: string)
	local color = UIHelpers.rarityStroke(rarity)
	for i = 1, 8 do
		local s = Instance.new("TextLabel"); s.Name="RarityBurst"; s.BackgroundTransparency=1; s.Size=UDim2.fromOffset(0,0); s.AnchorPoint=Vector2.new(0.5,0.5); s.Position=UDim2.new(0.5,0,0.5,0); s.ZIndex=12; s.Font=Enum.Font.GothamBold; s.TextSize=math.random(12,20); s.TextColor3=color; s.Text=SPARKLE_CHARS[math.random(1,#SPARKLE_CHARS)]; s.TextTransparency=0; s.Rotation=math.random(0,360); s.Parent=parent
		local angle = (i/8)*math.pi*2; local dist = 0.4+math.random()*0.2; local endX = 0.5+math.cos(angle)*dist; local endY = 0.5+math.sin(angle)*dist
		task.delay((i-1)*0.03, function() if not s.Parent then return end; TweenService:Create(s, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position=UDim2.new(endX,0,endY,0), TextTransparency=1, Rotation=s.Rotation+math.random(-90,90) }):Play() end)
		task.delay(0.7+(i-1)*0.03, function() s:Destroy() end)
	end
end

function PetIndexPanel.init()
	local sg = MenuHub.getScreenGui()
	local root = sg:WaitForChild("PetIndex") :: Frame
	MenuHub.registerPanel("pets", root)

	local titleBar = root:WaitForChild("TitleBar") :: Frame
	titleBar:WaitForChild("Close").MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click"); root.Visible = false
	end)

	local scroll = root:WaitForChild("Scroll") :: ScrollingFrame
	local progress = root:WaitForChild("IndexProgress") :: TextLabel
	local barBg = root:WaitForChild("ProgressBarBg") :: Frame
	local barFill = barBg:WaitForChild("Fill") :: Frame
	local milestoneBanner = root:WaitForChild("MilestoneBanner") :: TextLabel

	local function showMilestoneCelebration(pct: number)
		SoundFacade.playOneShot("level_up")
		local template = pickRandom(MicrocopyConfig.PetIndexMilestone)
		milestoneBanner.Text = template:gsub("{PERCENT}", tostring(pct))
		milestoneBanner.Visible = true; milestoneBanner.TextTransparency = 0; milestoneBanner.BackgroundTransparency = 0.15
		milestoneBanner.Size = UDim2.new(0, 0, 0, 0)
		TweenService:Create(milestoneBanner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0.8, 0, 0, 40) }):Play()
		task.delay(2.8, function()
			if milestoneBanner.Visible then
				TweenService:Create(milestoneBanner, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
				task.delay(0.5, function() milestoneBanner.Visible = false end)
			end
		end)
	end

	local function redraw()
		for _, c in scroll:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
		local data = Remotes.getFunction("GetPlayerData"):InvokeServer()
		local disc = if data and data.discoveredPets then data.discoveredPets else {}
		local total = PetConfig.getTotalSpeciesCount(); local found = 0
		for _, v in pairs(disc) do if v == true then found += 1 end end

		local newlyDiscovered: { [string]: boolean } = {}
		if not discoveredSeeded then
			for pid, v in pairs(disc) do if v == true then previouslyDiscovered[pid] = true end end
			local pctSeed = if total > 0 then math.floor((100 * found) / total) else 0
			for _, threshold in MILESTONE_THRESHOLDS do if pctSeed >= threshold then milestonesShown[threshold] = true end end
			discoveredSeeded = true
		else
			for pid, v in pairs(disc) do if v == true and not previouslyDiscovered[pid] then newlyDiscovered[pid] = true; previouslyDiscovered[pid] = true end end
		end

		local pct = if total > 0 then math.floor((100 * found) / total) else 0
		progress.Text = `Index {found}/{total} \u{2022} {pct}%`
		TweenService:Create(barFill, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(if total > 0 then found / total else 0, 0, 1, 0) }):Play()

		if next(newlyDiscovered) then
			for _, threshold in MILESTONE_THRESHOLDS do
				if pct >= threshold and not milestonesShown[threshold] then milestonesShown[threshold] = true; task.delay(0.5, function() showMilestoneCelebration(threshold) end) end
			end
		end

		for pid, def in PetConfig.Pets do
			local card = Instance.new("Frame"); card.Size=UDim2.new(0,130,0,150); card.BackgroundColor3=Color3.fromRGB(240,240,240); card.Parent=scroll
			local cc = Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,8); cc.Parent=card
			local stroke = Instance.new("UIStroke"); stroke.Color=UIHelpers.rarityStroke(def.rarity); stroke.Thickness=3; stroke.Parent=card
			local known = disc[pid] == true
			local t = Instance.new("TextLabel"); t.Size=UDim2.new(1,-6,1,-6); t.Position=UDim2.new(0,3,0,3); t.BackgroundTransparency=1; t.Font=Enum.Font.GothamBold; t.TextSize=13; t.TextColor3=Color3.fromRGB(40,40,40); t.TextWrapped=true; t.Text=known and (def.name .. "\n" .. def.rarity .. "\nPow " .. tostring(def.basePower)) or "???"; t.Parent=card

			if known and newlyDiscovered[pid] then
				local badge = Instance.new("TextLabel"); badge.Name="NewBadge"; badge.AnchorPoint=Vector2.new(1,0); badge.Position=UDim2.new(1,-4,0,4); badge.Size=UDim2.fromOffset(38,18); badge.BackgroundColor3=Color3.fromRGB(255,60,80); badge.Font=Enum.Font.GothamBold; badge.TextSize=11; badge.TextColor3=Color3.new(1,1,1); badge.Text="NEW!"; badge.ZIndex=6; badge.Parent=card
				local badgeCorner = Instance.new("UICorner"); badgeCorner.CornerRadius=UDim.new(0,6); badgeCorner.Parent=badge
				SoundFacade.playOneShot("notification")
				task.spawn(function()
					while badge.Parent do
						TweenService:Create(badge, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Size=UDim2.fromOffset(42,20), BackgroundColor3=Color3.fromRGB(255,100,120) }):Play(); task.wait(0.5)
						if not badge.Parent then break end
						TweenService:Create(badge, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Size=UDim2.fromOffset(38,18), BackgroundColor3=Color3.fromRGB(255,60,80) }):Play(); task.wait(0.5)
					end
				end)
			end

			if known then
				local tap = Instance.new("TextButton"); tap.Name="TapOverlay"; tap.Size=UDim2.new(1,0,1,0); tap.BackgroundTransparency=1; tap.Text=""; tap.ZIndex=5; tap.Parent=card
				local isNew = newlyDiscovered[pid] == true
				tap.MouseButton1Click:Connect(function()
					if isNew then
						SoundFacade.playOneShot("click")
						TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size=UDim2.new(0,145,0,165) }):Play()
						local origColor = stroke.Color
						TweenService:Create(stroke, TweenInfo.new(0.2), { Thickness=5, Color=Color3.new(1,1,1) }):Play()
						spawnRarityBurst(card, def.rarity)
						task.delay(0.6, function()
							if card.Parent then
								TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size=UDim2.new(0,130,0,150) }):Play()
								TweenService:Create(stroke, TweenInfo.new(0.3), { Thickness=3, Color=origColor }):Play()
							end
						end)
					end
				end)
			end
		end
	end

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function() if root.Visible then redraw() end end)
	redraw()
end

return PetIndexPanel
