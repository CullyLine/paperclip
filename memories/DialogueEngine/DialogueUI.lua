--[[
    DialogueUI.lua
    ScreenGui with typewriter text, speaker portraits, choice buttons,
    keyboard/gamepad navigation, and voice playback.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local DialogueUI = {}
DialogueUI.__index = DialogueUI

function DialogueUI.new(themeOverrides: { [string]: any }?)
    local self = setmetatable({}, DialogueUI)
    self._theme = Theme.Merge(themeOverrides)
    self._gui = nil
    self._mainFrame = nil
    self._speakerLabel = nil
    self._textLabel = nil
    self._portraitImage = nil
    self._portraitViewport = nil
    self._viewportCamera = nil
    self._viewportClone = nil
    self._closeButton = nil
    self._onCloseRequested = nil
    self._choiceFrame = nil
    self._choiceButtons = {}
    self._highlightIndex = 0
    self._typewriterRunning = false
    self._typewriterSkipped = false
    self._fullText = ""
    self._onChoiceSelected = nil
    self._onSkipRequested = nil
    self._inputConnection = nil
    self._currentVoiceSound = nil
    self._connections = {}
    self._sfxPool = {} -- pool of Sound instances for typewriter SFX
    self._sfxPoolIndex = 1
    self._autoAdvanceThread = nil
    self._closingAnimation = false
    self:_buildGui()
    self:_setupInput()
    self:_initSfxPool()
    return self
end

function DialogueUI:_buildGui()
    local player = Players.LocalPlayer
    local theme = self._theme

    local gui = Instance.new("ScreenGui")
    gui.Name = "DialogueEngineGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 100
    gui.Parent = player:WaitForChild("PlayerGui")
    self._gui = gui

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "DialogueBox"
    mainFrame.Size = theme.dialogueBoxSize
    mainFrame.Position = theme.dialogueBoxPosition
    mainFrame.BackgroundColor3 = theme.backgroundColor
    mainFrame.BackgroundTransparency = theme.backgroundTransparency
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = theme.cornerRadius
    corner.Parent = mainFrame
    self._mainCorner = corner

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = theme.padding
    padding.PaddingBottom = theme.padding
    padding.PaddingLeft = theme.padding
    padding.PaddingRight = theme.padding
    padding.Parent = mainFrame
    self._mainPadding = padding
    self._mainFrame = mainFrame

    local portraitImage = Instance.new("ImageLabel")
    portraitImage.Name = "Portrait"
    portraitImage.Size = theme.portraitSize
    portraitImage.Position = UDim2.new(0, 0, 0, 0)
    portraitImage.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    portraitImage.BackgroundTransparency = 0.3
    portraitImage.BorderSizePixel = 0
    portraitImage.ScaleType = Enum.ScaleType.Fit
    portraitImage.Visible = false
    portraitImage.Parent = mainFrame

    local portraitCorner = Instance.new("UICorner")
    portraitCorner.CornerRadius = theme.cornerRadius
    portraitCorner.Parent = portraitImage
    self._portraitCorner = portraitCorner
    self._portraitImage = portraitImage

    local portraitViewport = Instance.new("ViewportFrame")
    portraitViewport.Name = "PortraitViewport"
    portraitViewport.Size = theme.portraitSize
    portraitViewport.Position = UDim2.new(0, 0, 0, 0)
    portraitViewport.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    portraitViewport.BackgroundTransparency = 0.3
    portraitViewport.BorderSizePixel = 0
    portraitViewport.Visible = false
    portraitViewport.Parent = mainFrame

    local vpCorner = Instance.new("UICorner")
    vpCorner.CornerRadius = theme.cornerRadius
    vpCorner.Parent = portraitViewport
    self._vpCorner = vpCorner

    local vpCamera = Instance.new("Camera")
    vpCamera.Parent = portraitViewport
    portraitViewport.CurrentCamera = vpCamera

    self._portraitViewport = portraitViewport
    self._viewportCamera = vpCamera

    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 28, 0, 28)
    closeButton.Position = UDim2.new(1, -28, 0, 0)
    closeButton.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
    closeButton.BackgroundTransparency = 0.3
    closeButton.BorderSizePixel = 0
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(220, 220, 220)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 16
    closeButton.AutoButtonColor = true
    closeButton.ZIndex = 10
    closeButton.Parent = mainFrame

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeButton

    closeButton.MouseButton1Click:Connect(function()
        if self._onCloseRequested then
            self._onCloseRequested()
        end
    end)
    self._closeButton = closeButton

    local textXOffset = 0
    local speakerLabel = Instance.new("TextLabel")
    speakerLabel.Name = "SpeakerName"
    speakerLabel.Size = UDim2.new(1, -textXOffset, 0, 24)
    speakerLabel.Position = UDim2.new(0, textXOffset, 0, 0)
    speakerLabel.BackgroundTransparency = 1
    speakerLabel.TextColor3 = theme.speakerColor
    speakerLabel.Font = theme.speakerFont
    speakerLabel.TextSize = theme.speakerTextSize
    speakerLabel.TextXAlignment = Enum.TextXAlignment.Left
    speakerLabel.TextYAlignment = Enum.TextYAlignment.Top
    speakerLabel.Text = ""
    speakerLabel.RichText = true
    speakerLabel.Parent = mainFrame
    self._speakerLabel = speakerLabel

    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "DialogueText"
    textLabel.Size = UDim2.new(1, -textXOffset, 1, -30)
    textLabel.Position = UDim2.new(0, textXOffset, 0, 28)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = theme.textColor
    textLabel.Font = theme.font
    textLabel.TextSize = theme.textSize
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextYAlignment = Enum.TextYAlignment.Top
    textLabel.TextWrapped = true
    textLabel.Text = ""
    textLabel.RichText = true
    textLabel.Parent = mainFrame
    self._textLabel = textLabel

    local choiceFrame = Instance.new("Frame")
    choiceFrame.Name = "Choices"
    choiceFrame.Size = UDim2.new(0.6, 0, 0, 0)
    choiceFrame.Position = UDim2.new(0.2, 0, 0, -16)
    choiceFrame.AnchorPoint = Vector2.new(0, 1)
    choiceFrame.BackgroundTransparency = 1
    choiceFrame.AutomaticSize = Enum.AutomaticSize.Y
    choiceFrame.Visible = false
    choiceFrame.Parent = mainFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 4)
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.Parent = choiceFrame
    self._choiceFrame = choiceFrame

    mainFrame.Visible = false
end

function DialogueUI:_initSfxPool()
    for i = 1, 3 do
        local sound = Instance.new("Sound")
        sound.Name = "TypewriterSfx_" .. i
        sound.Parent = SoundService
        self._sfxPool[i] = sound
    end
end

function DialogueUI:_playSfx(soundId: string?, pitchVariation: number?)
    if not soundId or soundId == "" then return end
    local theme = self._theme
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = theme.sfxVolume
    if pitchVariation then
        sound.PlaybackSpeed = 1 + (math.random() * 2 - 1) * pitchVariation
    end
    sound.Parent = SoundService
    sound:Play()
    sound.Ended:Once(function()
        sound:Destroy()
    end)
end

function DialogueUI:_playTypewriterSfx()
    local theme = self._theme
    local soundId = theme.typewriterSoundId
    if not soundId or soundId == "" then return end
    local sound = self._sfxPool[self._sfxPoolIndex]
    if not sound then return end
    sound.SoundId = soundId
    sound.Volume = theme.sfxVolume
    local pitch = theme.typewriterSoundPitch or 0.1
    sound.PlaybackSpeed = 1 + (math.random() * 2 - 1) * pitch
    sound:Play()
    self._sfxPoolIndex = (self._sfxPoolIndex % #self._sfxPool) + 1
end

function DialogueUI:_cancelAutoAdvance()
    if self._autoAdvanceThread then
        task.cancel(self._autoAdvanceThread)
        self._autoAdvanceThread = nil
    end
end

function DialogueUI:_setupInput()
    self._inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if not self._gui or not self._mainFrame.Visible then return end

        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if self._typewriterRunning then
                self._typewriterSkipped = true
            end
            return
        end

        if input.UserInputType == Enum.UserInputType.Keyboard then
            self:_handleKeyboard(input.KeyCode)
        elseif input.UserInputType == Enum.UserInputType.Gamepad1 then
            self:_handleGamepad(input.KeyCode)
        end
    end)
end

function DialogueUI:_handleKeyboard(keyCode: Enum.KeyCode)
    if keyCode == Enum.KeyCode.One or keyCode == Enum.KeyCode.KeypadOne then
        self:_selectChoiceByNumber(1)
    elseif keyCode == Enum.KeyCode.Two or keyCode == Enum.KeyCode.KeypadTwo then
        self:_selectChoiceByNumber(2)
    elseif keyCode == Enum.KeyCode.Three or keyCode == Enum.KeyCode.KeypadThree then
        self:_selectChoiceByNumber(3)
    elseif keyCode == Enum.KeyCode.Four or keyCode == Enum.KeyCode.KeypadFour then
        self:_selectChoiceByNumber(4)
    elseif keyCode == Enum.KeyCode.Up or keyCode == Enum.KeyCode.W then
        self:_moveHighlight(-1)
    elseif keyCode == Enum.KeyCode.Down or keyCode == Enum.KeyCode.S then
        self:_moveHighlight(1)
    elseif keyCode == Enum.KeyCode.Return or keyCode == Enum.KeyCode.Space then
        if self._typewriterRunning then
            self._typewriterSkipped = true
        elseif self._highlightIndex > 0 then
            self:_confirmHighlighted()
        end
    elseif keyCode == Enum.KeyCode.Escape then
        if self._onCloseRequested then
            self._onCloseRequested()
        end
    end
end

function DialogueUI:_handleGamepad(keyCode: Enum.KeyCode)
    if keyCode == Enum.KeyCode.DPadUp then
        self:_moveHighlight(-1)
    elseif keyCode == Enum.KeyCode.DPadDown then
        self:_moveHighlight(1)
    elseif keyCode == Enum.KeyCode.ButtonA then
        if self._typewriterRunning then
            self._typewriterSkipped = true
        elseif self._highlightIndex > 0 then
            self:_confirmHighlighted()
        end
    elseif keyCode == Enum.KeyCode.ButtonB then
        if self._typewriterRunning then
            self._typewriterSkipped = true
        elseif self._onCloseRequested then
            self._onCloseRequested()
        end
    end
end

function DialogueUI:_selectChoiceByNumber(number: number)
    if self._typewriterRunning then return end
    local visibleChoices = self:_getVisibleChoiceButtons()
    if number <= #visibleChoices then
        local btn = visibleChoices[number]
        if btn:GetAttribute("Available") then
            self._highlightIndex = number
            self:_updateHighlight()
            self:_confirmHighlighted()
        end
    end
end

function DialogueUI:_getVisibleChoiceButtons(): { any }
    local buttons = {}
    for _, btn in ipairs(self._choiceButtons) do
        if btn.Visible then
            table.insert(buttons, btn)
        end
    end
    table.sort(buttons, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    return buttons
end

function DialogueUI:_moveHighlight(delta: number)
    if self._typewriterRunning then return end
    local buttons = self:_getVisibleChoiceButtons()
    if #buttons == 0 then return end

    local newIndex = self._highlightIndex + delta
    if newIndex < 1 then newIndex = #buttons end
    if newIndex > #buttons then newIndex = 1 end

    self._highlightIndex = newIndex
    self:_updateHighlight()
    self:_playSfx(self._theme.choiceHoverSoundId)
end

function DialogueUI:_updateHighlight()
    local theme = self._theme
    local buttons = self:_getVisibleChoiceButtons()
    for i, btn in ipairs(buttons) do
        if i == self._highlightIndex then
            btn.BackgroundColor3 = theme.choiceHighlightColor
        elseif btn:GetAttribute("Available") then
            btn.BackgroundColor3 = theme.choiceColor
        end
    end
end

function DialogueUI:_confirmHighlighted()
    local buttons = self:_getVisibleChoiceButtons()
    local btn = buttons[self._highlightIndex]
    if btn and btn:GetAttribute("Available") and self._onChoiceSelected then
        self:_playSfx(self._theme.choiceSelectSoundId)
        local choiceIndex = btn:GetAttribute("ChoiceIndex")
        self._onChoiceSelected(choiceIndex)
    end
end

function DialogueUI:_buildRichTextSnapshots(text: string): { string }
    local snapshots = {}
    local tagStack = {}
    local i = 1
    local len = #text
    local visibleCount = 0

    while i <= len do
        local ch = string.sub(text, i, i)
        if ch == "<" then
            local closeTag = string.find(text, ">", i)
            if closeTag then
                local tag = string.sub(text, i, closeTag)
                local isClosing = string.sub(tag, 1, 2) == "</"

                if isClosing then
                    if #tagStack > 0 then
                        table.remove(tagStack)
                    end
                else
                    local tagName = string.match(tag, "<(%w+)")
                    if tagName then
                        table.insert(tagStack, tag)
                    end
                end
                i = closeTag + 1
            else
                visibleCount += 1
                local displayed = string.sub(text, 1, i)
                table.insert(snapshots, displayed)
                i += 1
            end
        else
            visibleCount += 1
            local prefix = string.sub(text, 1, i)

            local closingTags = ""
            for j = #tagStack, 1, -1 do
                local openTag = tagStack[j]
                local tagName = string.match(openTag, "<(%w+)")
                if tagName then
                    closingTags = closingTags .. "</" .. tagName .. ">"
                end
            end

            table.insert(snapshots, prefix .. closingTags)
            i += 1
        end
    end

    return snapshots
end

function DialogueUI:_disconnectNodeConnections()
    for _, conn in ipairs(self._connections) do
        conn:Disconnect()
    end
    self._connections = {}
end

function DialogueUI:DisplayNode(node: any, choices: { any }, npcModel: Model?, onChoiceSelected: (number) -> (), onAdvance: () -> (), onClose: (() -> ())?)
    self._onChoiceSelected = nil
    self._onCloseRequested = onClose
    self._pendingAdvance = nil
    self._highlightIndex = 0
    self:_cancelAutoAdvance()
    self:_disconnectNodeConnections()

    local wasVisible = self._mainFrame.Visible and not self._closingAnimation
    self:_cancelActiveTweens()
    self._closingAnimation = false
    self._mainFrame.Visible = true

    if not wasVisible then
        self:_animateOpen()
        self:_playSfx(self._theme.openSoundId)
    end

    local speakerName = node.speaker or (npcModel and npcModel.Name) or ""
    self._speakerLabel.Text = speakerName

    local pid = node.portraitImageId
    local hasImagePortrait = pid and pid ~= "" and pid ~= "0" and pid ~= 0 and pid ~= "rbxassetid://0"
    local viewportModel = node.npcModel or npcModel
    local useViewport = not hasImagePortrait and viewportModel ~= nil

    self._portraitImage.Visible = hasImagePortrait
    self._portraitViewport.Visible = useViewport
    self:_clearViewportClone()

    if hasImagePortrait then
        self._portraitImage.Image = pid
    end

    if useViewport then
        self:_setupViewportPortrait(viewportModel)
    end

    local hasAnyPortrait = hasImagePortrait or useViewport
    if hasAnyPortrait then
        local offset = self._theme.portraitSize.X.Offset + 12
        self._speakerLabel.Position = UDim2.new(0, offset, 0, 0)
        self._speakerLabel.Size = UDim2.new(1, -offset, 0, 24)
        self._textLabel.Position = UDim2.new(0, offset, 0, 28)
        self._textLabel.Size = UDim2.new(1, -offset, 1, -30)
    else
        self._speakerLabel.Position = UDim2.new(0, 0, 0, 0)
        self._speakerLabel.Size = UDim2.new(1, 0, 0, 24)
        self._textLabel.Position = UDim2.new(0, 0, 0, 28)
        self._textLabel.Size = UDim2.new(1, 0, 1, -30)
    end

    self:_stopVoice()
    if node.voiceSoundId and node.voiceSoundId ~= "" then
        self:_playVoice(node.voiceSoundId)
    end

    self:_clearChoices()
    self._choiceFrame.Visible = false

    local hasChoices = choices and #choices > 0
    local autoDelay = node.autoAdvanceDelay

    self:_startTypewriter(node.text, function()
        if node.isEndNode or not hasChoices then
            self._onChoiceSelected = nil

            if autoDelay and autoDelay > 0 and not node.isEndNode and onAdvance then
                self._pendingAdvance = onAdvance
                self._autoAdvanceThread = task.spawn(function()
                    local conn
                    local cancelled = false

                    conn = UserInputService.InputBegan:Connect(function(input, gp)
                        if gp then return end
                        if input.UserInputType == Enum.UserInputType.MouseButton1
                            or input.UserInputType == Enum.UserInputType.Touch
                            or input.KeyCode == Enum.KeyCode.Return
                            or input.KeyCode == Enum.KeyCode.Space
                            or input.KeyCode == Enum.KeyCode.ButtonA then
                            cancelled = true
                            conn:Disconnect()
                            onAdvance()
                        end
                    end)
                    table.insert(self._connections, conn)

                    task.wait(autoDelay)
                    if not cancelled then
                        conn:Disconnect()
                        onAdvance()
                    end
                end)
            elseif onAdvance then
                self._pendingAdvance = onAdvance
                local conn
                conn = UserInputService.InputBegan:Connect(function(input, gp)
                    if gp then return end
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch
                        or input.KeyCode == Enum.KeyCode.Return
                        or input.KeyCode == Enum.KeyCode.Space
                        or input.KeyCode == Enum.KeyCode.ButtonA then
                        self._pendingAdvance = nil
                        conn:Disconnect()
                        onAdvance()
                    end
                end)
                table.insert(self._connections, conn)
            end
        else
            self:_showChoices(choices, onChoiceSelected)
        end
    end)
end

function DialogueUI:_cancelActiveTweens()
    if self._activeTweens then
        for _, tween in ipairs(self._activeTweens) do
            tween:Cancel()
        end
    end
    self._activeTweens = {}
end

function DialogueUI:_animateOpen()
    local theme = self._theme
    local speed = theme.animationSpeed or 1

    self:_cancelActiveTweens()
    self._closingAnimation = false

    local frame = self._mainFrame
    local targetPos = theme.dialogueBoxPosition

    if speed <= 0 then
        frame.Position = targetPos
        frame.Size = theme.dialogueBoxSize
        frame.BackgroundTransparency = theme.backgroundTransparency
        return
    end

    local startPos = UDim2.new(targetPos.X.Scale, targetPos.X.Offset, targetPos.Y.Scale, targetPos.Y.Offset + 60)

    frame.Position = startPos
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.new(
        theme.dialogueBoxSize.X.Scale * 0.95,
        theme.dialogueBoxSize.X.Offset * 0.95,
        theme.dialogueBoxSize.Y.Scale * 0.95,
        theme.dialogueBoxSize.Y.Offset * 0.95
    )

    local duration = 0.3 / speed
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    local posTween = TweenService:Create(frame, tweenInfo, {
        Position = targetPos,
        BackgroundTransparency = theme.backgroundTransparency,
        Size = theme.dialogueBoxSize,
    })
    table.insert(self._activeTweens, posTween)
    posTween:Play()
end

function DialogueUI:_animateClose(callback: (() -> ())?)
    local theme = self._theme
    local speed = theme.animationSpeed or 1

    self:_cancelActiveTweens()

    if speed <= 0 then
        if callback then callback() end
        return
    end

    self._closingAnimation = true
    local frame = self._mainFrame
    local restPos = theme.dialogueBoxPosition
    local targetPos = UDim2.new(restPos.X.Scale, restPos.X.Offset, restPos.Y.Scale, restPos.Y.Offset + 60)
    local duration = 0.2 / speed
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.In)

    local closeTween = TweenService:Create(frame, tweenInfo, {
        Position = targetPos,
        BackgroundTransparency = 1,
    })
    table.insert(self._activeTweens, closeTween)
    closeTween:Play()
    closeTween.Completed:Once(function()
        if not self._closingAnimation then return end
        self._closingAnimation = false
        frame.Position = restPos
        if callback then callback() end
    end)
end

function DialogueUI:_setupViewportPortrait(npcModel: any)
    self:_clearViewportClone()
    local clone = npcModel:Clone()
    clone.Parent = self._portraitViewport
    self._viewportClone = clone

    local head = clone:FindFirstChild("Head")
    if not head then
        head = clone:FindFirstChildWhichIsA("BasePart")
    end
    if head then
        local headPos = head.Position + Vector3.new(0, 0.2, 0)
        local lookVector = head.CFrame.LookVector
        self._viewportCamera.CFrame = CFrame.new(headPos + lookVector * 3, headPos)
    end
end

function DialogueUI:_clearViewportClone()
    if self._viewportClone then
        self._viewportClone:Destroy()
        self._viewportClone = nil
    end
end

function DialogueUI:_extractInlineCommands(text: string): (string, { [number]: { { cmd: string, value: number } } })
    local commands = {}
    local result = {}
    local i = 1
    local len = #text
    local visibleCount = 0

    while i <= len do
        local pauseVal = string.match(text, "^%[pause%s+(%d+%.?%d*)%]", i)
        if pauseVal then
            local fullMatch = string.match(text, "^(%[pause%s+%d+%.?%d*%])", i)
            if not commands[visibleCount] then commands[visibleCount] = {} end
            table.insert(commands[visibleCount], { cmd = "pause", value = tonumber(pauseVal) })
            i = i + #fullMatch
            continue
        end

        local speedVal = string.match(text, "^%[speed%s+(%d+%.?%d*)%]", i)
        if speedVal then
            local fullMatch = string.match(text, "^(%[speed%s+%d+%.?%d*%])", i)
            if not commands[visibleCount] then commands[visibleCount] = {} end
            table.insert(commands[visibleCount], { cmd = "speed", value = tonumber(speedVal) })
            i = i + #fullMatch
            continue
        end

        local ch = string.sub(text, i, i)
        table.insert(result, ch)

        if ch == "<" then
            local closeIdx = string.find(text, ">", i + 1)
            if closeIdx then
                for j = i + 1, closeIdx do
                    table.insert(result, string.sub(text, j, j))
                end
                i = closeIdx + 1
            else
                visibleCount = visibleCount + 1
                i = i + 1
            end
        else
            visibleCount = visibleCount + 1
            i = i + 1
        end
    end

    return table.concat(result), commands
end

function DialogueUI:_startTypewriter(text: string, onComplete: () -> ())
    self._typewriterRunning = true
    self._typewriterSkipped = false

    local cleanText, inlineCommands = self:_extractInlineCommands(text)
    self._fullText = cleanText
    self._textLabel.Text = ""

    local snapshots = self:_buildRichTextSnapshots(cleanText)
    if #snapshots == 0 then
        self._textLabel.Text = cleanText
        self._typewriterRunning = false
        if onComplete then onComplete() end
        return
    end

    local currentSpeed = self._theme.typewriterSpeed

    local cmds0 = inlineCommands[0]
    if cmds0 then
        for _, cmd in ipairs(cmds0) do
            if cmd.cmd == "speed" then
                currentSpeed = cmd.value
            end
        end
    end

    task.spawn(function()
        for i, snapshot in ipairs(snapshots) do
            if self._typewriterSkipped or not self._typewriterRunning then
                break
            end
            self._textLabel.Text = snapshot
            self:_playTypewriterSfx()

            local cmds = inlineCommands[i]
            if cmds then
                for _, cmd in ipairs(cmds) do
                    if cmd.cmd == "pause" then
                        local elapsed = 0
                        while elapsed < cmd.value do
                            if self._typewriterSkipped or not self._typewriterRunning then break end
                            task.wait(0.05)
                            elapsed = elapsed + 0.05
                        end
                    elseif cmd.cmd == "speed" then
                        currentSpeed = cmd.value
                    end
                end
            end

            if self._typewriterSkipped or not self._typewriterRunning then break end
            task.wait(currentSpeed)
        end
        self._textLabel.Text = cleanText
        self._typewriterRunning = false
        if onComplete then onComplete() end
    end)
end

function DialogueUI:_showChoices(choices: { any }, onChoiceSelected: (number) -> ())
    self:_clearChoices()
    self._choiceFrame.Visible = true
    self._onChoiceSelected = onChoiceSelected
    self._highlightIndex = 0

    local theme = self._theme
    local speed = theme.animationSpeed or 1
    local animate = speed > 0
    local visibleCount = 0

    for i, choice in ipairs(choices) do
        local shouldHide = not choice.available
        if not shouldHide then
            visibleCount += 1
            local btn = Instance.new("TextButton")
            btn.Name = "Choice_" .. i
            btn.Size = UDim2.new(1, 0, 0, 36)
            btn.LayoutOrder = i
            btn.BackgroundColor3 = choice.available and theme.choiceColor or theme.choiceUnavailableColor
            btn.BackgroundTransparency = animate and 1 or 0.1
            btn.BorderSizePixel = 0
            btn.Font = theme.font
            btn.TextSize = theme.choiceTextSize
            btn.TextColor3 = choice.available and theme.choiceTextColor or Color3.fromRGB(120, 120, 120)
            btn.TextTransparency = animate and 1 or 0
            btn.TextWrapped = true
            btn.Text = visibleCount .. ". " .. choice.text
            btn.AutoButtonColor = choice.available
            btn.Visible = true
            btn:SetAttribute("ChoiceIndex", choice.index)
            btn:SetAttribute("Available", choice.available)

            if animate then
                btn.Position = UDim2.new(0.15, 0, 0, 0)
            end

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 6)
            btnCorner.Parent = btn

            if choice.available then
                btn.MouseEnter:Connect(function()
                    btn.BackgroundColor3 = theme.choiceHoverColor
                    self:_playSfx(theme.choiceHoverSoundId)
                end)
                btn.MouseLeave:Connect(function()
                    local buttons = self:_getVisibleChoiceButtons()
                    local myIdx = table.find(buttons, btn)
                    if myIdx == self._highlightIndex then
                        btn.BackgroundColor3 = theme.choiceHighlightColor
                    else
                        btn.BackgroundColor3 = theme.choiceColor
                    end
                end)
                btn.MouseButton1Click:Connect(function()
                    self:_playSfx(theme.choiceSelectSoundId)
                    if onChoiceSelected then
                        onChoiceSelected(choice.index)
                    end
                end)
            end

            btn.Parent = self._choiceFrame
            table.insert(self._choiceButtons, btn)
        end
    end

    if #self._choiceButtons > 0 then
        self._highlightIndex = 1
        self:_updateHighlight()
    end

    if animate and #self._choiceButtons > 0 then
        task.spawn(function()
            for idx, btn in ipairs(self._choiceButtons) do
                local staggerDelay = 0.05 / speed
                local tweenDur = 0.2 / speed
                local tweenInfo = TweenInfo.new(tweenDur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
                local targetColor = (idx == 1) and theme.choiceHighlightColor or theme.choiceColor
                if not btn:GetAttribute("Available") then
                    targetColor = theme.choiceUnavailableColor
                end
                local tween = TweenService:Create(btn, tweenInfo, {
                    Position = UDim2.new(0, 0, 0, 0),
                    BackgroundTransparency = 0.1,
                    BackgroundColor3 = targetColor,
                    TextTransparency = 0,
                })
                tween:Play()
                if idx < #self._choiceButtons then
                    task.wait(staggerDelay)
                end
            end
        end)
    end
end

function DialogueUI:_clearChoices()
    for _, btn in ipairs(self._choiceButtons) do
        btn:Destroy()
    end
    self._choiceButtons = {}
    self._highlightIndex = 0
end

function DialogueUI:_playVoice(soundId: string)
    self:_stopVoice()
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = self._theme.voiceVolume
    sound.Parent = SoundService
    sound:Play()
    self._currentVoiceSound = sound

    sound.Ended:Once(function()
        if self._currentVoiceSound == sound then
            sound:Destroy()
            self._currentVoiceSound = nil
        end
    end)
end

function DialogueUI:_stopVoice()
    if self._currentVoiceSound then
        self._currentVoiceSound:Stop()
        self._currentVoiceSound:Destroy()
        self._currentVoiceSound = nil
    end
end

function DialogueUI:_applyTheme()
    local theme = self._theme

    if self._mainFrame then
        self._mainFrame.BackgroundColor3 = theme.backgroundColor
        self._mainFrame.BackgroundTransparency = theme.backgroundTransparency
        self._mainFrame.Size = theme.dialogueBoxSize
        self._mainFrame.Position = theme.dialogueBoxPosition
    end
    if self._mainCorner then
        self._mainCorner.CornerRadius = theme.cornerRadius
    end
    if self._mainPadding then
        self._mainPadding.PaddingTop = theme.padding
        self._mainPadding.PaddingBottom = theme.padding
        self._mainPadding.PaddingLeft = theme.padding
        self._mainPadding.PaddingRight = theme.padding
    end
    if self._speakerLabel then
        self._speakerLabel.TextColor3 = theme.speakerColor
        self._speakerLabel.Font = theme.speakerFont
        self._speakerLabel.TextSize = theme.speakerTextSize
    end
    if self._textLabel then
        self._textLabel.TextColor3 = theme.textColor
        self._textLabel.Font = theme.font
        self._textLabel.TextSize = theme.textSize
    end
    if self._portraitImage then
        self._portraitImage.Size = theme.portraitSize
    end
    if self._portraitCorner then
        self._portraitCorner.CornerRadius = theme.cornerRadius
    end
    if self._portraitViewport then
        self._portraitViewport.Size = theme.portraitSize
    end
    if self._vpCorner then
        self._vpCorner.CornerRadius = theme.cornerRadius
    end
end

function DialogueUI:SetTheme(themeOverrides: { [string]: any })
    self._theme = Theme.Merge(themeOverrides)
    self:_applyTheme()
end

function DialogueUI:Show()
    if self._mainFrame then
        self._mainFrame.Visible = true
    end
end

function DialogueUI:Hide(callback: (() -> ())?)
    self:_cancelAutoAdvance()
    self:_disconnectNodeConnections()
    if self._mainFrame and self._mainFrame.Visible then
        self:_playSfx(self._theme.closeSoundId)
        self:_animateClose(function()
            if self._mainFrame then
                self._mainFrame.Visible = false
            end
            self:_stopVoice()
            self:_clearViewportClone()
            self._typewriterRunning = false
            if callback then callback() end
        end)
    else
        self:_stopVoice()
        self:_clearViewportClone()
        self._typewriterRunning = false
        if callback then callback() end
    end
end

function DialogueUI:SkipTypewriter()
    if self._typewriterRunning then
        self._typewriterSkipped = true
    end
end

function DialogueUI:Advance()
    if self._typewriterRunning then
        self._typewriterSkipped = true
    elseif self._pendingAdvance then
        local advance = self._pendingAdvance
        self._pendingAdvance = nil
        self:_disconnectNodeConnections()
        self:_cancelAutoAdvance()
        advance()
    end
end

function DialogueUI:Destroy()
    self:_cancelAutoAdvance()
    self:_stopVoice()
    self:_clearViewportClone()
    self._typewriterRunning = false

    for _, sound in ipairs(self._sfxPool) do
        sound:Destroy()
    end
    self._sfxPool = {}

    for _, conn in ipairs(self._connections) do
        conn:Disconnect()
    end
    self._connections = {}

    if self._inputConnection then
        self._inputConnection:Disconnect()
        self._inputConnection = nil
    end
    if self._gui then
        self._gui:Destroy()
        self._gui = nil
    end
end

return DialogueUI
