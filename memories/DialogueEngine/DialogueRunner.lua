--[[
    DialogueRunner.lua
    Tree processor: manages traversal, condition evaluation, branching, and event hooks.
]]

local DialogueRunner = {}
DialogueRunner.__index = DialogueRunner

function DialogueRunner.new()
    local self = setmetatable({}, DialogueRunner)
    self._trees = {}
    self._conditionCallbacks = {}
    self._visitedNodes = {}
    return self
end

function DialogueRunner:RegisterTree(treeId: string, treeData: any)
    self._trees[treeId] = treeData
    if not self._visitedNodes[treeId] then
        self._visitedNodes[treeId] = {}
    end
end

function DialogueRunner:GetTree(treeId: string): any?
    return self._trees[treeId]
end

function DialogueRunner:GetNode(treeId: string, nodeId: string): any?
    local tree = self._trees[treeId]
    if not tree then return nil end
    return tree.nodes[nodeId]
end

function DialogueRunner:GetStartNode(treeId: string): any?
    local tree = self._trees[treeId]
    if not tree then return nil end
    return tree.nodes[tree.startNodeId], tree.startNodeId
end

function DialogueRunner:RegisterConditionCallback(callback: (key: string, value: any) -> boolean)
    table.insert(self._conditionCallbacks, callback)
end

function DialogueRunner:EvaluateConditions(conditions: { [string]: any }?): boolean
    if not conditions then return true end

    for key, expectedValue in pairs(conditions) do
        local passed = false
        for _, callback in ipairs(self._conditionCallbacks) do
            if callback(key, expectedValue) then
                passed = true
                break
            end
        end
        if not passed then
            return false
        end
    end
    return true
end

function DialogueRunner:GetAvailableChoices(treeId: string, nodeId: string): { any }
    local node = self:GetNode(treeId, nodeId)
    if not node or not node.choices then return {} end

    local available = {}
    for i, choice in ipairs(node.choices) do
        local isAvailable = self:EvaluateConditions(choice.conditions)
        table.insert(available, {
            index = i,
            text = choice.text,
            targetNodeId = choice.targetNodeId,
            available = isAvailable,
            hideWhenUnavailable = choice.hideWhenUnavailable or false,
        })
    end
    return available
end

function DialogueRunner:MarkVisited(treeId: string, nodeId: string)
    if not self._visitedNodes[treeId] then
        self._visitedNodes[treeId] = {}
    end
    self._visitedNodes[treeId][nodeId] = true
end

function DialogueRunner:IsVisited(treeId: string, nodeId: string): boolean
    return self._visitedNodes[treeId] and self._visitedNodes[treeId][nodeId] or false
end

function DialogueRunner:GetVisitedNodes(treeId: string): { [string]: boolean }
    return self._visitedNodes[treeId] or {}
end

function DialogueRunner:SaveState(treeId: string, currentNodeId: string): any
    return {
        treeId = treeId,
        currentNodeId = currentNodeId,
        visitedNodes = self:GetVisitedNodes(treeId),
        timestamp = os.time(),
    }
end

function DialogueRunner:LoadState(treeId: string, savedState: any): string?
    if not savedState or savedState.treeId ~= treeId then
        return nil
    end

    local tree = self._trees[treeId]
    if not tree then return nil end

    if not tree.nodes[savedState.currentNodeId] then
        return nil
    end

    self._visitedNodes[treeId] = savedState.visitedNodes or {}
    return savedState.currentNodeId
end

function DialogueRunner:ResetVisited(treeId: string)
    self._visitedNodes[treeId] = {}
end

return DialogueRunner
