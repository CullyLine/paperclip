--!strict
--[[
	Quest panel.
	Shell UI pre-built in DACMain.Panels.Quest; this script wires behavior.
	Quest rows and milestone rows are created dynamically.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local QuestConfig = require(DAC:WaitForChild("Config"):WaitForChild("QuestConfig"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))

local MenuHub = require(script.Parent:WaitForChild("MenuHub"))

local QuestPanel = {}

local questCompletionSeeded = false
local questCompletedSeen: { [string]: boolean } = {}
local questNudgeLineCache: { [string]: string } = {}
local questNudgeSoundPlayed: { [string]: boolean } = {}
local nudgePulseTween: { [Instance]: Tween } = {}

local GOLD = Color3.fromRGB(255, 215, 64)
local GOLD_DIM = Color3.fromRGB(120, 100, 40)
local SPARKLE_CHARS = { "\u{2605}", "\u{25CF}", "\u{25C6}" }

local function pickRandom(pool: { string }): string if #pool == 0 then return "" end; return pool[math.random(1, #pool)] end
local function smoothstep(t: number): number return t * t * (3 - 2 * t) end

local function stopNudgePulse(row: Instance)
	local tw = nudgePulseTween[row]; if tw then tw:Cancel(); nudgePulseTween[row] = nil end
	local nudge = row:FindFirstChild("Nudge"); if nudge and nudge:IsA("TextLabel") then local sc = nudge:FindFirstChildOfClass("UIScale"); if sc then sc:Destroy() end end
end

local function startNudgePulse(nudge: TextLabel)
	local sc = nudge:FindFirstChildOfClass("UIScale") :: UIScale?
	if not sc then sc = Instance.new("UIScale"); sc.Scale = 1; sc.Parent = nudge end
	local row = nudge.Parent; if not row then return end; stopNudgePulse(row)
	local tw = TweenService:Create(sc, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.05 })
	nudgePulseTween[row] = tw; tw:Play()
end

local function clearCelebration(row: Instance)
	stopNudgePulse(row)
	for _, ch in row:GetChildren() do
		if ch.Name == "CompleteBanner" or ch.Name == "CompleteSubtitle" or ch.Name == "RewardCount" or ch.Name == "Sparkle" then ch:Destroy() end
	end
	local celebStroke = row:FindFirstChildOfClass("UIStroke"); if celebStroke then celebStroke:Destroy() end
end

local function spawnSparkles(parent: Instance)
	for i = 1, 10 do
		local s = Instance.new("TextLabel"); s.Name="Sparkle"; s.BackgroundTransparency=1; s.Size=UDim2.fromOffset(0,0); s.AnchorPoint=Vector2.new(0.5,0.5)
		local startX = math.random() * 0.8 + 0.1; local startY = 0.5; s.Position=UDim2.new(startX,0,startY,0); s.ZIndex=10; s.Font=Enum.Font.GothamBold; s.TextSize=math.random(10,18)
		s.TextColor3 = if math.random() > 0.3 then GOLD else Color3.fromRGB(255,255,220); s.Text=SPARKLE_CHARS[math.random(1,#SPARKLE_CHARS)]; s.TextTransparency=0; s.Rotation=math.random(0,360); s.Parent=parent
		local d = (i-1)*0.035
		task.delay(d, function() if not s.Parent then return end; TweenService:Create(s, TweenInfo.new(0.5+math.random()*0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position=UDim2.new(startX+(math.random()-0.5)*0.5,0,startY+(math.random()-0.6)*0.8,0), TextTransparency=1, Rotation=s.Rotation+math.random(-120,120) }):Play() end)
		task.delay(0.9+d, function() s:Destroy() end)
	end
end

local function playRowCelebration(row: Instance, def: any, lightAfterGlobal: boolean?)
	clearCelebration(row)
	local stroke = Instance.new("UIStroke"); stroke.Color=GOLD
	local thick0 = if lightAfterGlobal then 2 else 3; local thickPulse = if lightAfterGlobal then 3 else 4
	stroke.Thickness=thick0; stroke.Transparency=0; stroke.Parent=row
	TweenService:Create(stroke, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Thickness=thickPulse }):Play()
	task.delay(0.35, function() if stroke.Parent then TweenService:Create(stroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true), { Color=GOLD_DIM, Thickness=if lightAfterGlobal then 1.5 else 2 }):Play() end end)

	local banner: TextLabel? = nil
	if not lightAfterGlobal then
		banner = Instance.new("TextLabel"); banner.Name="CompleteBanner"; banner.AnchorPoint=Vector2.new(0.5,0); banner.Position=UDim2.new(0.5,0,0,2); banner.BackgroundTransparency=1; banner.Font=Enum.Font.GothamBold; banner.TextSize=15; banner.TextColor3=GOLD; banner.Text="QUEST COMPLETE!"; banner.ZIndex=8; banner.Size=UDim2.new(0,0,0,0); banner.Parent=row
		TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size=UDim2.new(0.8,0,0,18) }):Play()
	end

	local sub = Instance.new("TextLabel"); sub.Name="CompleteSubtitle"; sub.AnchorPoint=Vector2.new(0.5,1); sub.Position=UDim2.new(0.5,0,1,-2); sub.Size=UDim2.new(0.8,0,0,14); sub.BackgroundTransparency=1; sub.Font=Enum.Font.Gotham; sub.TextSize=11; sub.TextColor3=Color3.fromRGB(255,240,180); sub.Text=pickRandom(MicrocopyConfig.QuestComplete); sub.TextTransparency=1; sub.ZIndex=8; sub.Parent=row
	task.delay(0.2, function() if sub.Parent then TweenService:Create(sub, TweenInfo.new(0.3), { TextTransparency=0 }):Play() end end)

	if def then
		local reward = def.xpReward or 0
		if reward > 0 then
			local cl = Instance.new("TextLabel"); cl.Name="RewardCount"; cl.AnchorPoint=Vector2.new(1,0.5); cl.Position=UDim2.new(1,-6,0.5,0); cl.Size=UDim2.new(0,90,0,18); cl.BackgroundTransparency=1; cl.Font=Enum.Font.GothamBold; cl.TextSize=14; cl.TextColor3=Color3.fromRGB(160,255,200); cl.TextXAlignment=Enum.TextXAlignment.Right; cl.Text="+0 XP"; cl.ZIndex=8; cl.Parent=row
			local t0 = os.clock(); local dur = 0.5
			local conn: RBXScriptConnection? = nil
			conn = RunService.RenderStepped:Connect(function()
				if not cl.Parent then if conn then conn:Disconnect() end; return end
				local u = math.clamp((os.clock() - t0) / dur, 0, 1); cl.Text = `+{math.floor(reward * smoothstep(u))} XP`
				if u >= 1 then cl.Text = `+{reward} XP`; if conn then conn:Disconnect() end end
			end)
		end
	end
	spawnSparkles(row)
	task.delay(3.5, function()
		if banner and banner.Parent then TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency=1 }):Play() end
		if sub.Parent then TweenService:Create(sub, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency=1 }):Play() end
		local rl = row:FindFirstChild("RewardCount"); if rl and rl:IsA("TextLabel") then TweenService:Create(rl :: TextLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency=1 }):Play() end
		task.delay(0.5, function() clearCelebration(row) end)
	end)
end

local function collectCompletedQuestIds(q: any): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if type(q) ~= "table" then return out end
	if type(q.daily) == "table" then for _, slot in q.daily do if type(slot) == "table" and slot.completed == true and type(slot.defId) == "string" then out[slot.defId] = true end end end
	if type(q.weekly) == "table" then for _, slot in q.weekly do if type(slot) == "table" and slot.completed == true and type(slot.defId) == "string" then out[slot.defId] = true end end end
	if type(q.milestone) == "table" then for mid, slot in q.milestone do if type(slot) == "table" and slot.completed == true and type(mid) == "string" then out[mid] = true end end end
	return out
end

local function describeSlot(slot: any): (string, string)
	local def = QuestConfig.getById(slot.defId); if not def then return "?", "?" end
	return `{def.title}  ({slot.progress or 0}/{def.target})`, `+{def.xpReward} Season XP`
end

local function progressRatio(slot: any, def: any): number
	if def.target <= 0 then return 0 end; return math.clamp((slot.progress or 0) / def.target, 0, 1)
end

local function buildQuestRowFrame(parent: Instance, bg: Color3, layoutOrder: number): Frame
	local row = Instance.new("Frame"); row.Size=UDim2.new(1,-8,0,72); row.BackgroundColor3=bg; row.BorderSizePixel=0; row.LayoutOrder=layoutOrder; row.Parent=parent
	local rc = Instance.new("UICorner"); rc.CornerRadius=UDim.new(0,8); rc.Parent=row
	local title = Instance.new("TextLabel"); title.Name="TitleLabel"; title.Size=UDim2.new(1,-16,0,40); title.Position=UDim2.new(0,8,0,4); title.BackgroundTransparency=1; title.Font=Enum.Font.Gotham; title.TextSize=13; title.TextColor3=Color3.new(1,1,1); title.TextXAlignment=Enum.TextXAlignment.Left; title.TextYAlignment=Enum.TextYAlignment.Top; title.TextWrapped=true; title.Parent=row
	local barBack = Instance.new("Frame"); barBack.Name="ProgBack"; barBack.Size=UDim2.new(1,-16,0,4); barBack.Position=UDim2.new(0,8,0,46); barBack.BackgroundColor3=Color3.fromRGB(22,30,52); barBack.BorderSizePixel=0; barBack.Visible=false; barBack.Parent=row
	local bc = Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,2); bc.Parent=barBack
	local barFill = Instance.new("Frame"); barFill.Name="ProgFill"; barFill.Size=UDim2.new(0.2,0,1,0); barFill.BackgroundColor3=Color3.fromRGB(255,200,60); barFill.BorderSizePixel=0; barFill.Parent=barBack
	local fc = Instance.new("UICorner"); fc.CornerRadius=UDim.new(0,2); fc.Parent=barFill
	local nudge = Instance.new("TextLabel"); nudge.Name="Nudge"; nudge.Size=UDim2.new(1,-16,0,14); nudge.Position=UDim2.new(0,8,0,52); nudge.BackgroundTransparency=1; nudge.Font=Enum.Font.GothamBold; nudge.TextSize=11; nudge.TextColor3=Color3.fromRGB(255,235,150); nudge.TextXAlignment=Enum.TextXAlignment.Left; nudge.Text=""; nudge.Visible=false; nudge.Parent=row
	return row
end

local function updateQuestRowFrame(row: Frame, slot: any, def: any, line: string, sub: string, questKey: string, newlyCompleted: boolean)
	clearCelebration(row)
	local title = row:FindFirstChild("TitleLabel") :: TextLabel
	local barBack = row:FindFirstChild("ProgBack") :: Frame
	local barFill = barBack:FindFirstChild("ProgFill") :: Frame
	local nudge = row:FindFirstChild("Nudge") :: TextLabel
	stopNudgePulse(row)
	title.Text = line .. "\n" .. sub
	if not def then barBack.Visible = false; nudge.Visible = false; return end
	if slot.completed then
		barBack.Visible = false; nudge.Visible = false; questNudgeLineCache[questKey] = nil; questNudgeSoundPlayed[questKey] = nil
		if newlyCompleted then playRowCelebration(row, def, true) end; return
	end
	local ratio = progressRatio(slot, def); barBack.Visible = true; barFill.Size = UDim2.new(ratio, 0, 1, 0)
	if ratio < 0.8 then questNudgeLineCache[questKey] = nil; questNudgeSoundPlayed[questKey] = nil; nudge.Visible = false; return end
	if questNudgeLineCache[questKey] == nil then questNudgeLineCache[questKey] = pickRandom(MicrocopyConfig.QuestProgress) end
	nudge.Text = questNudgeLineCache[questKey] or ""; nudge.Visible = true
	if not questNudgeSoundPlayed[questKey] then questNudgeSoundPlayed[questKey] = true; SoundFacade.playOneShot("quest_progress") end
	startNudgePulse(nudge)
end

local function resetEmptyQuestRow(row: Frame)
	clearCelebration(row); stopNudgePulse(row)
	local title = row:FindFirstChild("TitleLabel") :: TextLabel; local barBack = row:FindFirstChild("ProgBack") :: Frame; local nudge = row:FindFirstChild("Nudge") :: TextLabel
	title.Text = "\u{2014}"; barBack.Visible = false; nudge.Visible = false
end

local function milestoneLine(id: string, slot: any): (string, string)
	local def = QuestConfig.getById(id); if not def then return "?", "?" end
	if slot.completed then return `{def.title}  \u{2713}`, "Complete" end
	return `{def.title}  ({slot.progress or 0}/{def.target})`, `+{def.xpReward} Season XP`
end

function QuestPanel.init()
	local sg = MenuHub.getScreenGui()
	local root = sg:WaitForChild("Quest") :: Frame
	MenuHub.registerPanel("quests", root)

	local titleBar = root:WaitForChild("TitleBar") :: Frame
	titleBar:WaitForChild("Close").MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click"); root.Visible = false
	end)

	local scroll = root:WaitForChild("QuestScroll") :: ScrollingFrame
	local mileScroll = scroll:WaitForChild("Milestones") :: Frame

	local dailyRows: { Frame } = {}
	for i = 1, 3 do dailyRows[i] = buildQuestRowFrame(scroll, Color3.fromRGB(32, 36, 64), 1 + i) end
	local weeklyRows: { Frame } = {}
	for i = 1, 3 do weeklyRows[i] = buildQuestRowFrame(scroll, Color3.fromRGB(40, 36, 50), 10 + i) end

	local function refresh(data: any)
		if not data or not data.quests then return end
		local q = data.quests
		local completedNow = collectCompletedQuestIds(q)
		local newlyCompleted: { [string]: boolean } = {}
		if not questCompletionSeeded then
			for id, _ in completedNow do questCompletedSeen[id] = true end; questCompletionSeeded = true
		else
			for id, _ in completedNow do
				if not questCompletedSeen[id] then
					newlyCompleted[id] = true; questCompletedSeen[id] = true
					local def = QuestConfig.getById(id); if def then SoundFacade.playOneShot("level_up"); VFXFacade.questComplete(def.title, "season_xp", def.xpReward) end
				end
			end
		end
		for i = 1, 3 do local slot = q.daily[i]; if slot then local line, sub = describeSlot(slot); local def = QuestConfig.getById(slot.defId); updateQuestRowFrame(dailyRows[i], slot, def, line, sub, slot.defId, newlyCompleted[slot.defId] == true) else resetEmptyQuestRow(dailyRows[i]) end end
		for i = 1, 3 do local slot = q.weekly[i]; if slot then local line, sub = describeSlot(slot); local def = QuestConfig.getById(slot.defId); updateQuestRowFrame(weeklyRows[i], slot, def, line, sub, slot.defId, newlyCompleted[slot.defId] == true) else resetEmptyQuestRow(weeklyRows[i]) end end
		for _, child in mileScroll:GetChildren() do if child:IsA("Frame") then stopNudgePulse(child); child:Destroy() end end
		if q.milestone then
			for _, mdef in QuestConfig.Milestones do
				local slot = q.milestone[mdef.id]
				if slot then local line, sub = milestoneLine(mdef.id, slot); local def = QuestConfig.getById(mdef.id); local mrow = buildQuestRowFrame(mileScroll, Color3.fromRGB(28, 28, 50), 0); mrow.Size = UDim2.new(1, 0, 0, 72); updateQuestRowFrame(mrow, slot, def, line, sub, mdef.id, newlyCompleted[mdef.id] == true) end
			end
		end
	end

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(refresh)
	task.defer(function()
		local ok, initial = pcall(function() return Remotes.getFunction("GetQuests"):InvokeServer() end)
		if ok and initial then refresh(initial) end
	end)
end

return QuestPanel
