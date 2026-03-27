--!strict
--[[
	World panel.
	Shell UI pre-built in DACMain.Panels.World; this script wires behavior.
	World row cards are created dynamically from WorldConfig.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Constants = require(DAC:WaitForChild("Constants"))
local WorldConfig = require(DAC:WaitForChild("Config"):WaitForChild("WorldConfig"))
local WorldUnlockConfig = require(DAC:WaitForChild("Config"):WaitForChild("WorldUnlockConfig"))
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local RemoteFailSafe = require(DAC:WaitForChild("RemoteFailSafe"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))
local WorldPortalPrompt = require(DAC:WaitForChild("WorldPortalPrompt"))
local SceneTransitionGate = require(DAC:WaitForChild("SceneTransitionGate"))
local ClientPerformanceProfile = require(DAC:WaitForChild("ClientPerformanceProfile"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))

local WorldPanel = {}

local ACCENT: { [string]: Color3 } = {
	forest = Color3.fromRGB(56, 170, 80),
	desert = Color3.fromRGB(255, 152, 0),
	ice = Color3.fromRGB(90, 160, 240),
	volcano = Color3.fromRGB(255, 80, 30),
	space = Color3.fromRGB(100, 100, 255),
}

local function coinMultLabel(mult: number): string
	local s = if math.abs(mult - math.floor(mult)) < 1e-6 then tostring(math.floor(mult)) else string.format("%.1f", mult)
	return MicrocopyConfig.WorldCoinMultFormat:gsub("{MULT}", s)
end
local function highwayLabel(studs: number): string
	return MicrocopyConfig.WorldHighwayStudsFormat:gsub("{STUDS}", Utils.formatNumber(studs))
end
local function pickUnlockHeadline(): string
	local h = WorldUnlockConfig.UnlockHeadlines
	if type(h) == "table" and #h > 0 then return h[math.random(1, #h)] end
	return MicrocopyConfig.WorldUnlockHeadlineFallback
end
local function pickTravelTeaser(worldId: string): string?
	local pool = WorldUnlockConfig.TravelTeaser[worldId]
	if type(pool) == "table" and #pool > 0 then return pool[math.random(1, #pool)] end; return nil
end

function WorldPanel.init()
	local sg = MenuHub.getScreenGui()
	local root = sg:WaitForChild("World") :: Frame
	local teardownConns: { RBXScriptConnection } = {}
	MenuHub.registerPanel("worlds", root)

	local titleBar = root:WaitForChild("TitleBar") :: Frame
	titleBar:WaitForChild("Close").MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("panel_close"); MenuHub.closeAll()
	end)

	local scroll = root:WaitForChild("Scroll") :: ScrollingFrame

	type RowRefs = {
		stroke: UIStroke, currentBadge: TextLabel, action: TextButton,
		startRun: TextButton,
		status: TextLabel, row: Frame, lastUnlocked: boolean?,
		travelPulse: Tween?, actionScale: UIScale?, travelTeaser: TextLabel,
		focusDisconnect: (() -> ())?,
	}
	local rows: { [string]: RowRefs } = {}

	local function bindRowFocus(refs: RowRefs)
		if refs.focusDisconnect then
			refs.focusDisconnect()
			refs.focusDisconnect = nil
		end
		refs.focusDisconnect = WorldPortalPrompt.bindRowFocusPulse(refs.row, refs.stroke, function()
			return refs.action.Active and refs.action.Selectable and refs.action.Text ~= MicrocopyConfig.WorldActionYouAreHere
		end)
	end

	local function ensureUIScale(gui: GuiObject): UIScale
		local u = gui:FindFirstChildOfClass("UIScale")
		if not u then u = Instance.new("UIScale"); u.Parent = gui end; return u
	end
	local function clearTravelPulse(refs: RowRefs)
		if refs.travelPulse then refs.travelPulse:Cancel(); refs.travelPulse = nil end
		if refs.actionScale then refs.actionScale.Scale = 1 end
	end

	local function refresh()
		local ok, data = RemoteFailSafe.invokeGetPlayerData()
		if not ok or type(data) ~= "table" then
			return
		end
		local unlockedWorlds = data.unlockedWorlds; local currentWorld = data.currentWorld

		for worldId, refs in rows do
			local world = WorldConfig.Worlds[worldId]; if not world then continue end
			local unlocked = type(unlockedWorlds) == "table" and unlockedWorlds[worldId] == true
			local here = type(currentWorld) == "string" and currentWorld == worldId
			local accent = ACCENT[worldId] or Color3.fromRGB(120, 160, 255)
			clearTravelPulse(refs); refs.stroke.Color = accent; refs.currentBadge.Visible = here

			if unlocked then
				if here then
					refs.action.Text = MicrocopyConfig.WorldActionYouAreHere; refs.action.AutoButtonColor = false; refs.action.BackgroundColor3 = Color3.fromRGB(50, 90, 60); refs.action.Active = false; refs.action.Selectable = false
					refs.action.Size = UDim2.new(0.38, -8, 0, 36)
					refs.startRun.Visible = true; refs.startRun.Active = true; refs.startRun.Selectable = true
				else
					refs.action.Text = MicrocopyConfig.WorldActionTravel; refs.action.AutoButtonColor = true; refs.action.BackgroundColor3 = Color3.fromRGB(70, 120, 220); refs.action.Active = true; refs.action.Selectable = true
					refs.action.Size = UDim2.new(0.24, -4, 0, 36)
					refs.startRun.Visible = true; refs.startRun.Active = true; refs.startRun.Selectable = true
					local sc = ensureUIScale(refs.action); refs.actionScale = sc; sc.Scale = 1
					if ClientPerformanceProfile.allowsContinuousScreenMotion() then
						refs.travelPulse = TweenService:Create(sc, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.045 })
						refs.travelPulse:Play()
					end
				end
				refs.status.Text = if world.unlockCost > 0 then MicrocopyConfig.WorldStatusUnlocked else MicrocopyConfig.WorldStatusStarterWorld
				refs.status.TextColor3 = Color3.fromRGB(140, 220, 140)
			else
				refs.action.Text = MicrocopyConfig.WorldActionUnlock; refs.action.AutoButtonColor = true; refs.action.BackgroundColor3 = Color3.fromRGB(255, 160, 40); refs.action.Active = true; refs.action.Selectable = true
				refs.action.Size = UDim2.new(0.38, -8, 0, 36)
				refs.startRun.Visible = false; refs.startRun.Active = false
				if world.unlockCost <= 0 then refs.status.Text = MicrocopyConfig.WorldStatusFree
				else
					local cur = world.unlockCurrency; local curColor = UIHelpers.currencyColor(cur)
					local curName = if Constants.CURRENCY_DISPLAY[cur] then Constants.CURRENCY_DISPLAY[cur].name else cur
					refs.status.Text = MicrocopyConfig.WorldLockedStatusFormat:gsub("{COST}", Utils.formatNumber(world.unlockCost)):gsub("{CURRENCY}", curName)
					refs.status.TextColor3 = curColor
				end
				local teaser = pickTravelTeaser(worldId)
				if teaser then refs.travelTeaser.Text = teaser; refs.travelTeaser.Visible = true
				else refs.travelTeaser.Text = ""; refs.travelTeaser.Visible = false end
			end
			if unlocked then refs.travelTeaser.Text = ""; refs.travelTeaser.Visible = false end

			if refs.lastUnlocked == false and unlocked then
				VFXFacade.milestonePopup(pickUnlockHeadline() .. "|" .. worldId, "world_unlock")
				local row = refs.row; local rowScale = ensureUIScale(row); rowScale.Scale = 1
				TweenService:Create(rowScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.1 }):Play()
				task.delay(0.2, function() if row.Parent then TweenService:Create(rowScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play() end end)

				local unlockBanner = Instance.new("TextLabel")
				unlockBanner.Name="WorldUnlockBanner"; unlockBanner.BackgroundTransparency=1; unlockBanner.Size=UDim2.new(1,-24,0,30); unlockBanner.Position=UDim2.new(0,12,0,-34); unlockBanner.Font=Enum.Font.GothamBlack; unlockBanner.TextSize=20; unlockBanner.TextColor3=Color3.fromRGB(255,230,120); unlockBanner.TextStrokeTransparency=0.5; unlockBanner.TextStrokeColor3=Color3.fromRGB(60,30,0); unlockBanner.Text=pickUnlockHeadline(); unlockBanner.ZIndex=5; unlockBanner.Parent=row
				local ubScale = Instance.new("UIScale"); ubScale.Scale=0.45; ubScale.Parent=unlockBanner
				TweenService:Create(ubScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale=1 }):Play()
				TweenService:Create(unlockBanner, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency=1, TextStrokeTransparency=1 }):Play()
				task.delay(1.15, function() if unlockBanner.Parent then unlockBanner:Destroy() end end)

				local base = row.BackgroundColor3; row.BackgroundColor3 = Color3.fromRGB(120, 220, 160)
				TweenService:Create(row, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = base }):Play()
				TweenService:Create(refs.stroke, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Thickness = 5, Transparency = 0.1 }):Play()
				task.delay(0.4, function() TweenService:Create(refs.stroke, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Thickness = 2, Transparency = 0.35 }):Play() end)

				clearTravelPulse(refs)
				if refs.action.Text == MicrocopyConfig.WorldActionTravel and refs.action.Active and ClientPerformanceProfile.allowsContinuousScreenMotion() then
					local sc = ensureUIScale(refs.action); sc.Scale = 1
					refs.travelPulse = TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.12 })
					refs.travelPulse:Play()
					task.delay(3, function()
						if not refs.action.Parent then return end; clearTravelPulse(refs)
						local sc2 = ensureUIScale(refs.action); sc2.Scale = 1
						if refs.action.Text == MicrocopyConfig.WorldActionTravel and refs.action.Active and ClientPerformanceProfile.allowsContinuousScreenMotion() then
							refs.travelPulse = TweenService:Create(sc2, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.045 })
							refs.travelPulse:Play()
						end
					end)
				end
			end
			refs.lastUnlocked = unlocked
		end
	end

	local layoutOrder = 0
	for _, w in WorldConfig.getWorldsSorted() do
		local world = WorldConfig.Worlds[w.id]; if not world then continue end
		layoutOrder += 1; local worldId = world.id
		local accent = ACCENT[worldId] or Color3.fromRGB(120, 160, 255)

		local row = Instance.new("Frame"); row.Name="World_"..worldId; row.Size=UDim2.new(1,-12,0,152); row.BackgroundColor3=Color3.fromRGB(26,28,46); row.LayoutOrder=layoutOrder; row.Parent=scroll
		local corner = Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,12); corner.Parent=row
		local stroke = Instance.new("UIStroke"); stroke.Color=accent; stroke.Thickness=2; stroke.Transparency=0.35; stroke.Parent=row

		local badge = Instance.new("TextLabel"); badge.Name="CurrentBadge"; badge.Size=UDim2.new(0,120,0,22); badge.Position=UDim2.new(1,-128,0,8); badge.BackgroundColor3=Color3.fromRGB(40,90,50); badge.BackgroundTransparency=0.2; badge.Font=Enum.Font.GothamBold; badge.TextSize=12; badge.TextColor3=Color3.fromRGB(200,255,210); badge.Text=MicrocopyConfig.WorldCurrentWorldBadge; badge.Visible=false; badge.Parent=row
		local bc = Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,6); bc.Parent=badge

		local title = Instance.new("TextLabel"); title.Size=UDim2.new(1,-140,0,24); title.Position=UDim2.new(0,12,0,8); title.BackgroundTransparency=1; title.Font=Enum.Font.GothamBold; title.TextSize=18; title.TextXAlignment=Enum.TextXAlignment.Left; title.TextColor3=accent; title.Text=world.name; title.Parent=row
		local desc = Instance.new("TextLabel"); desc.Size=UDim2.new(1,-24,0,36); desc.Position=UDim2.new(0,12,0,34); desc.BackgroundTransparency=1; desc.Font=Enum.Font.Gotham; desc.TextSize=13; desc.TextXAlignment=Enum.TextXAlignment.Left; desc.TextYAlignment=Enum.TextYAlignment.Top; desc.TextWrapped=true; desc.TextColor3=Color3.fromRGB(220,220,235); desc.Text=world.description; desc.Parent=row

		local travelTeaser = Instance.new("TextLabel"); travelTeaser.Name="TravelTeaser"; travelTeaser.Size=UDim2.new(1,-24,0,28); travelTeaser.Position=UDim2.new(0,12,0,72); travelTeaser.BackgroundTransparency=1; travelTeaser.Font=Enum.Font.GothamMedium; travelTeaser.TextSize=12; travelTeaser.TextXAlignment=Enum.TextXAlignment.Left; travelTeaser.TextYAlignment=Enum.TextYAlignment.Top; travelTeaser.TextWrapped=true; travelTeaser.TextColor3=Color3.fromRGB(255,200,140); travelTeaser.Text=""; travelTeaser.Visible=false; travelTeaser.Parent=row

		local stats = Instance.new("TextLabel"); stats.Size=UDim2.new(1,-24,0,18); stats.Position=UDim2.new(0,12,0,102); stats.BackgroundTransparency=1; stats.Font=Enum.Font.Gotham; stats.TextSize=13; stats.TextXAlignment=Enum.TextXAlignment.Left; stats.TextColor3=Color3.fromRGB(180,190,220); stats.Text=`{coinMultLabel(world.coinMultiplier)}  \u{2022}  {highwayLabel(world.highwayLength)}`; stats.Parent=row

		local status = Instance.new("TextLabel"); status.Name="Status"; status.Size=UDim2.new(0.55,-16,0,22); status.Position=UDim2.new(0,12,1,-32); status.BackgroundTransparency=1; status.Font=Enum.Font.Gotham; status.TextSize=13; status.TextXAlignment=Enum.TextXAlignment.Left; status.TextColor3=Color3.fromRGB(200,200,210); status.Text=""; status.Parent=row

		local action = Instance.new("TextButton"); action.Name="Action"; action.Size=UDim2.new(0.24,-4,0,36); action.Position=UDim2.new(0.42,0,1,-34); action.Font=Enum.Font.GothamBold; action.TextSize=15; action.TextColor3=Color3.new(1,1,1); action.Parent=row
		local ac = Instance.new("UICorner"); ac.CornerRadius=UDim.new(0,8); ac.Parent=action

		local startRunBtn = Instance.new("TextButton"); startRunBtn.Name="StartRun"; startRunBtn.Size=UDim2.new(0.24,-4,0,36); startRunBtn.Position=UDim2.new(0.72,0,1,-34); startRunBtn.Font=Enum.Font.GothamBold; startRunBtn.TextSize=14; startRunBtn.TextColor3=Color3.new(1,1,1); startRunBtn.BackgroundColor3=Color3.fromRGB(40,180,80); startRunBtn.Text=MicrocopyConfig.WorldActionStartRun; startRunBtn.AutoButtonColor=true; startRunBtn.Visible=false; startRunBtn.Parent=row
		local src = Instance.new("UICorner"); src.CornerRadius=UDim.new(0,8); src.Parent=startRunBtn

		startRunBtn.MouseButton1Click:Connect(function()
			local ok, data = RemoteFailSafe.invokeGetPlayerData()
			if not ok or type(data) ~= "table" or type(data.unlockedWorlds) ~= "table" then return end
			local unlocked2 = data.unlockedWorlds[worldId] == true
			if not unlocked2 then return end
			local here2 = type(data.currentWorld) == "string" and data.currentWorld == worldId
			SoundFacade.playOneShot("click")
			if here2 then
				MenuHub.closeAll()
				Remotes.getEvent("StartRun"):FireServer()
			else
				if not SceneTransitionGate.tryBegin() then return end
				WorldPortalPrompt.tryPlayPortalConfirm()
				local fromW = if type(data.currentWorld) == "string" then data.currentWorld else "forest"
				SoundFacade.onWorldLeave(fromW)
				VFXFacade.worldTransition(fromW, worldId, function()
					local changeOk = RemoteFailSafe.fireEvent("WORLD", "ChangeWorld", worldId)
					if not changeOk then
						VFXFacade.abortWorldTravel(fromW)
						return
					end
					task.delay(0.5, function()
						MenuHub.closeAll()
						Remotes.getEvent("StartRun"):FireServer()
					end)
				end)
			end
		end)

		action.MouseButton1Click:Connect(function()
			local ok, data = RemoteFailSafe.invokeGetPlayerData()
			if not ok or type(data) ~= "table" or type(data.unlockedWorlds) ~= "table" then
				if ok and type(data) == "table" then
					RemoteFailSafe.notifyRemoteFailure("GetPlayerData", "worlds_shape", "DATA")
				end
				return
			end
			local unlocked2 = data.unlockedWorlds[worldId] == true
			local here2 = type(data.currentWorld) == "string" and data.currentWorld == worldId
			if here2 then return end
			if unlocked2 then
				if not SceneTransitionGate.tryBegin() then
					return
				end
				WorldPortalPrompt.tryPlayPortalConfirm()
				local fromW = if type(data.currentWorld) == "string" then data.currentWorld else "forest"
				SoundFacade.onWorldLeave(fromW)
				VFXFacade.worldTransition(fromW, worldId, function()
					local ok = RemoteFailSafe.fireEvent("WORLD", "ChangeWorld", worldId)
					if not ok then
						VFXFacade.abortWorldTravel(fromW)
					end
				end)
			else
				WorldPortalPrompt.tryPlayPortalConfirm()
				RemoteFailSafe.fireEvent("WORLD", "UnlockWorld", worldId)
			end
		end)

		rows[worldId] = {
			stroke = stroke,
			currentBadge = badge,
			action = action,
			startRun = startRunBtn,
			status = status,
			row = row,
			lastUnlocked = nil,
			travelPulse = nil,
			actionScale = nil,
			travelTeaser = travelTeaser,
			focusDisconnect = nil,
		}
		bindRowFocus(rows[worldId])
	end

	table.insert(teardownConns, root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible then
			refresh()
			for _, refs in rows do
				bindRowFocus(refs)
			end
		else
			for _, refs in rows do
				if refs.focusDisconnect then
					refs.focusDisconnect()
					refs.focusDisconnect = nil
				end
				clearTravelPulse(refs)
			end
		end
	end))
	refresh()
	table.insert(teardownConns, Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function()
		if root.Visible then refresh() end
	end))

	Players.PlayerRemoving:Connect(function(leavingPlayer)
		if leavingPlayer ~= Players.LocalPlayer then return end
		for _, refs in rows do
			if refs.focusDisconnect then
				refs.focusDisconnect()
				refs.focusDisconnect = nil
			end
		end
		for _, c in teardownConns do
			if c.Connected then
				c:Disconnect()
			end
		end
		table.clear(teardownConns)
	end)
end

return WorldPanel
