--[[
    DialoguePro.lua
    Main facade module. RegisterTree, Start, Skip, Close, SetTheme, SaveState, LoadState.
]]

local DialogueRunner = require(script.Parent.DialogueRunner)
local DialogueUI = require(script.Parent.DialogueUI)

local DialoguePro = {}
DialoguePro.__index = DialoguePro

local instance = nil

function DialoguePro.new(themeOverrides: { [string]: any }?)
    if instance then
        instance:Close()
    end

    local self = setmetatable({}, DialoguePro)
    self._runner = DialogueRunner.new()
    self._ui = DialogueUI.new(themeOverrides)
    self._baseThemeOverrides = themeOverrides
    self._currentTreeId = nil
    self._currentNodeId = nil
    self._callbacks = nil
    self._active = false
    self._variableResolvers = {}
    self._flags = {}
    self._actions = {}
    self:_initBuiltInCondition()
    self:RegisterVariable(function(varName)
        return self._flags[varName]
    end)
    instance = self
    return self
end

function DialoguePro:RegisterTree(treeId: string, dialogueData: any)
    self._runner:RegisterTree(treeId, dialogueData)
end

function DialoguePro:RegisterCondition(callback: (key: string, value: any) -> boolean)
    self._runner:RegisterConditionCallback(callback)
end

function DialoguePro:_initBuiltInCondition()
    self._runner:RegisterConditionCallback(function(key: string, value: any): boolean
        local flagValue = self._flags[key]
        if flagValue == nil then return false end
        if type(value) == "number" then
            return (tonumber(flagValue) or 0) >= value
        end
        return flagValue == value
    end)
end

function DialoguePro:RegisterVariable(resolver: (variableName: string) -> any?)
    table.insert(self._variableResolvers, resolver)
end

function DialoguePro:SetFlag(key: string, value: any)
    self._flags[key] = value
end

function DialoguePro:GetFlag(key: string): any
    return self._flags[key]
end

function DialoguePro:GetFlags(): { [string]: any }
    return self._flags
end

function DialoguePro:RegisterAction(name: string, callback: () -> ())
    self._actions[name] = callback
end

function DialoguePro:_processActions(actions: { any }?)
    if not actions then return end
    for _, action in ipairs(actions) do
        if action.type == "set" then
            self._flags[action.key] = action.value
        elseif action.type == "call" then
            local fn = self._actions[action.key]
            if fn then
                fn()
            else
                warn("[DialoguePro] Action not found: " .. tostring(action.key))
            end
        end
    end
end

function DialoguePro:_resolveVariables(text: string): string
    return text:gsub("{([%w_%.]+)}", function(varName)
        for _, resolver in ipairs(self._variableResolvers) do
            local value = resolver(varName)
            if value ~= nil then
                return tostring(value)
            end
        end
        return "{" .. varName .. "}"
    end)
end

function DialoguePro:Start(treeId: string, npcModelOrCallbacks: (Model | any)?, callbacks: any?)
    if self._active and self._currentTreeId == treeId then
        self:Advance()
        return
    end

    local npcModel: Model? = nil
    local cbs: any

    if typeof(npcModelOrCallbacks) == "Instance" then
        npcModel = npcModelOrCallbacks
        cbs = callbacks or {}
    else
        cbs = npcModelOrCallbacks or {}
    end

    local startNode, startNodeId = self._runner:GetStartNode(treeId)
    if not startNode then
        warn("[DialoguePro] Tree not found: " .. treeId)
        return
    end

    self._currentTreeId = treeId
    self._npcModel = npcModel
    self._callbacks = cbs
    self._active = true

    if cbs.theme then
        self._ui:SetTheme(cbs.theme)
    end

    self:_displayNode(startNodeId)
end

function DialoguePro:StartFromState(treeId: string, savedState: any, npcModelOrCallbacks: (Model | any)?, callbacks: any?)
    local npcModel: Model? = nil
    local cbs: any

    if typeof(npcModelOrCallbacks) == "Instance" then
        npcModel = npcModelOrCallbacks
        cbs = callbacks or {}
    else
        cbs = npcModelOrCallbacks or {}
    end

    local nodeId = self._runner:LoadState(treeId, savedState)
    if not nodeId then
        warn("[DialoguePro] Could not load state for tree: " .. treeId)
        self:Start(treeId, npcModel, cbs)
        return
    end

    self._currentTreeId = treeId
    self._npcModel = npcModel
    self._callbacks = cbs
    self._active = true

    if cbs.theme then
        self._ui:SetTheme(cbs.theme)
    end

    self:_displayNode(nodeId)
end

function DialoguePro:_displayNode(nodeId: string)
    if not self._active then return end

    local node = self._runner:GetNode(self._currentTreeId, nodeId)
    if not node then
        warn("[DialoguePro] Node not found: " .. nodeId)
        self:Close()
        return
    end

    self._currentNodeId = nodeId
    self._runner:MarkVisited(self._currentTreeId, nodeId)

    self:_processActions(node.actions)

    if self._callbacks.onNodeEnter then
        self._callbacks.onNodeEnter(nodeId)
    end

    local resolvedNode = {}
    for k, v in pairs(node) do
        resolvedNode[k] = v
    end
    resolvedNode.text = self:_resolveVariables(node.text)

    local choices = self._runner:GetAvailableChoices(self._currentTreeId, nodeId)
    for _, choice in ipairs(choices) do
        choice.text = self:_resolveVariables(choice.text)
    end

    self._ui:DisplayNode(resolvedNode, choices, self._npcModel, function(choiceIndex)
        local choice = node.choices[choiceIndex]
        if choice then
            self:_processActions(choice.actions)
        end

        if self._callbacks.onChoice then
            self._callbacks.onChoice(nodeId, choiceIndex)
        end

        if choice and choice.targetNodeId then
            self:_displayNode(choice.targetNodeId)
        else
            self:_endDialogue()
        end
    end, function()
        self:_endDialogue()
    end, function()
        self:Close()
    end)
end

function DialoguePro:_endDialogue()
    if self._callbacks and self._callbacks.onEnd then
        self._callbacks.onEnd()
    end
    self:Close()
end

function DialoguePro:Skip()
    if self._ui then
        self._ui:SkipTypewriter()
    end
end

function DialoguePro:Advance()
    if self._ui then
        self._ui:Advance()
    end
end

function DialoguePro:IsActive(): boolean
    return self._active
end

function DialoguePro:Close()
    local hadPerNpcTheme = self._callbacks and self._callbacks.theme ~= nil
    self._active = false
    self._currentTreeId = nil
    self._currentNodeId = nil
    self._npcModel = nil
    self._callbacks = nil
    if self._ui then
        self._ui:Hide(function()
            if hadPerNpcTheme and self._ui then
                self._ui:SetTheme(self._baseThemeOverrides)
            end
        end)
    end
end

function DialoguePro:SetTheme(themeOverrides: { [string]: any })
    if self._ui then
        self._ui:SetTheme(themeOverrides)
    end
end

function DialoguePro:SaveState(treeId: string?): any?
    local tId = treeId or self._currentTreeId
    local nId = self._currentNodeId
    if not tId then return nil end
    if not nId then
        local _, startId = self._runner:GetStartNode(tId)
        nId = startId
    end
    return self._runner:SaveState(tId, nId)
end

function DialoguePro:LoadState(treeId: string, savedState: any): boolean
    local nodeId = self._runner:LoadState(treeId, savedState)
    return nodeId ~= nil
end

function DialoguePro:GetVisitedNodes(treeId: string): { [string]: boolean }
    return self._runner:GetVisitedNodes(treeId)
end

function DialoguePro:Destroy()
    self._active = false
    if self._ui then
        self._ui:Destroy()
        self._ui = nil
    end
    if instance == self then
        instance = nil
    end
end

return DialoguePro
