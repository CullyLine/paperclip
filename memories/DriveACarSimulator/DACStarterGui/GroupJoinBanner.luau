--!strict
--[[
	Non-intrusive bottom banner prompting players to join the Roblox group.
	UI shell: StarterGui.DACGroupJoinBanner (Rojo default.project.json).
]]

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local HudSafeArea = require(DAC:WaitForChild("HudSafeArea"))
local HudLayoutConfig = require(DAC:WaitForChild("Config"):WaitForChild("HudLayoutConfig"))
local GroupRewardConfig = require(DAC:WaitForChild("Config"):WaitForChild("GroupRewardConfig"))
local UILayerStack = require(DAC:WaitForChild("Config"):WaitForChild("UILayerStack"))
local Remotes = require(DAC:WaitForChild("Remotes"))

local GroupJoinBanner = {}

function GroupJoinBanner.init()
	if type(GroupRewardConfig.groupId) ~= "number" or GroupRewardConfig.groupId <= 0 then
		return
	end

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local g = playerGui:WaitForChild("DACGroupJoinBanner", 30) :: ScreenGui?
	if not g then
		warn("[DAC] DACGroupJoinBanner missing under PlayerGui — sync default.project.json / Rojo")
		return
	end

	g.DisplayOrder = UILayerStack.screenGui.hudPromoBanner

	local bar = g:WaitForChild("Bar") :: Frame
	local joinBtn = bar:WaitForChild("JoinBtn") :: TextButton
	local closeBtn = bar:WaitForChild("CloseBtn") :: TextButton
	local headline = bar:WaitForChild("Headline") :: TextLabel
	local sub = bar:WaitForChild("Sub") :: TextLabel

	headline.Text = GroupRewardConfig.bannerHeadline
	sub.Text = GroupRewardConfig.bannerSub

	local function bottomInsetPx(): number
		local _, _, _, b = HudSafeArea.getManualInsetsForScreenGui(g)
		return b + HudLayoutConfig.edgeMarginPx
	end

	local function getRestPos(): UDim2
		return UDim2.new(0.5, 0, 1, -16 - bottomInsetPx())
	end

	local function getOffPos(): UDim2
		return UDim2.new(0.5, 0, 1, 140 + bottomInsetPx())
	end

	local bannerVisible = false
	local sliding = false

	local function slideIn()
		if sliding or bannerVisible then
			return
		end
		bannerVisible = true
		sliding = true
		bar.Position = getOffPos()
		g.Enabled = true
		local tw = TweenService:Create(bar, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = getRestPos() })
		tw:Play()
		tw.Completed:Once(function()
			sliding = false
		end)
	end

	local function slideOut()
		if sliding or not bannerVisible then
			return
		end
		sliding = true
		local tw = TweenService:Create(bar, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = getOffPos() })
		tw:Play()
		tw.Completed:Once(function()
			g.Enabled = false
			bannerVisible = false
			sliding = false
		end)
	end

	local function shouldShow(data: any): boolean
		if player:GetAttribute("DAC_GroupMember") == true then
			return false
		end
		if type(data) ~= "table" or data.groupJoinPromptDismissed == true then
			return false
		end
		local runs = 0
		if type(data.stats) == "table" and type(data.stats.totalRunsCompleted) == "number" then
			runs = data.stats.totalRunsCompleted
		end
		return runs >= GroupRewardConfig.runsBeforePrompt
	end

	local function evaluate(data: any)
		if shouldShow(data) then
			if not bannerVisible and not sliding then
				slideIn()
			end
		elseif bannerVisible or g.Enabled then
			slideOut()
		end
	end

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(evaluate)

	player:GetAttributeChangedSignal("DAC_GroupMember"):Connect(function()
		if player:GetAttribute("DAC_GroupMember") == true then
			slideOut()
		end
	end)

	joinBtn.MouseButton1Click:Connect(function()
		GuiService:OpenBrowserWindow(GroupRewardConfig.groupPageUrl)
	end)

	closeBtn.MouseButton1Click:Connect(function()
		Remotes.getEvent("DismissGroupJoinPrompt"):FireServer()
		slideOut()
	end)

	task.defer(function()
		local data = Remotes.getFunction("GetPlayerData"):InvokeServer()
		if type(data) == "table" then
			evaluate(data)
		end
	end)

	HudSafeArea.onLayoutChanged(function()
		if bannerVisible and not sliding then
			bar.Position = getRestPos()
		end
	end)
end

return GroupJoinBanner
