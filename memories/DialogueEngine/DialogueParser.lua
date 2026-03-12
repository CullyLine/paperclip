--[[
    DialogueParser.lua
    Converts a simple text format into a dialogue tree table.

    FORMAT GUIDE:
    ─────────────────────────────────────────────────
    === my_tree_id
    start: greeting

    # greeting
    Hello! Welcome to my shop!
    What can I do for you today?
    > I need a weapon. -> weapon_shop
    > Tell me about town. -> town_info
    > Goodbye. -> farewell
    > Secret option -> secret [if hasKey true] [hide]

    # weapon_shop
    @ A Different Speaker
    I've got swords and axes!
    > Buy sword -> bought_sword [if gold 500] [set gold -500] [call playCashSound]
    > Too expensive. -> farewell

    # bought_sword [end] [set hasSword true]
    Enjoy your new sword!

    # farewell [end]
    See you later!

    -- QUEST EXAMPLE:
    # quest_giver
    Go talk to the elder in the village.
    > I'll do it! -> quest_accepted [set talkToElder true] [call startQuestMusic]
    > No thanks. -> farewell

    # quest_accepted [end] [call showQuestMarker]
    Hurry back when you've spoken to her!

    # quest_return [set questComplete true]
    You spoke with the elder! Here's your reward.
    > Thanks! -> farewell [call giveReward]
    ─────────────────────────────────────────────────

    LINE TYPES:
      === tree_id          → Sets the tree's ID
      start: node_name     → Sets which node the dialogue begins at
      # node_name          → Starts a new node (add [end] to mark it as an end node)
      # node_name [auto 3] → Auto-advance after typewriter + 3 seconds (no-choice nodes only)
      @ Speaker Name       → Overrides the speaker name for this node
      > Choice text -> target_node
                           → Adds a choice. Append [if key value] for conditions,
                             [hide] to hide when the condition isn't met
      [set key value]      → Sets a flag when the node is entered or choice is clicked
      [call actionName]    → Fires a registered action when the node is entered or choice is clicked
      -- comment           → Ignored
      {variableName}       → Replaced at runtime with the value from a registered resolver
      [pause N]            → Pauses typewriter for N seconds mid-text
      [speed N]            → Changes typewriter speed to N seconds per character
      (anything else)      → Dialogue text (multiple lines get joined with spaces)
]]

local DialogueParser = {}

local function trim(s: string): string
    return s:match("^%s*(.-)%s*$") or ""
end

local function parseConditionValue(raw: string): any
    if raw == "true" then return true end
    if raw == "false" then return false end
    local num = tonumber(raw)
    if num then return num end
    return raw
end

local function parseActions(text: string): ({ any }?, string)
    local actions = {}

    for key, val in text:gmatch("%[set%s+(%S+)%s+(%S+)%]") do
        table.insert(actions, { type = "set", key = key, value = parseConditionValue(val) })
    end
    text = text:gsub("%[set%s+%S+%s+%S+%]", "")

    for name in text:gmatch("%[call%s+(%S+)%]") do
        table.insert(actions, { type = "call", key = name })
    end
    text = text:gsub("%[call%s+%S+%]", "")

    if #actions == 0 then
        return nil, text
    end
    return actions, text
end

function DialogueParser.Parse(source: string): any
    local treeId = "untitled"
    local startNodeId = nil
    local nodes = {}

    local currentNodeId = nil
    local currentNode = nil

    local lines = {}
    for line in (source .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end

    local function finishNode()
        if currentNodeId and currentNode then
            currentNode.text = trim(currentNode.text)
            if currentNode._choices and #currentNode._choices > 0 then
                currentNode.choices = currentNode._choices
            end
            currentNode._choices = nil
            nodes[currentNodeId] = currentNode
        end
        currentNodeId = nil
        currentNode = nil
    end

    for _, rawLine in ipairs(lines) do
        local line = trim(rawLine)

        if line == "" or line:sub(1, 2) == "--" then
            continue
        end

        -- === tree_id
        local treeMatch = line:match("^===%s*(.+)$")
        if treeMatch then
            treeId = trim(treeMatch)
            continue
        end

        -- start: node_name
        local startMatch = line:match("^start:%s*(.+)$")
        if startMatch then
            startNodeId = trim(startMatch)
            continue
        end

        -- # node_name [end] [auto N] [set key value] [call name]
        local nodeMatch = line:match("^#%s*(.+)$")
        if nodeMatch then
            finishNode()
            local isEnd = nodeMatch:match("%[end%]") ~= nil
            local autoDelay = tonumber(nodeMatch:match("%[auto%s+(%d+%.?%d*)%]"))
            local nodeActions, remaining = parseActions(nodeMatch)
            local nodeName = trim(remaining:gsub("%[end%]", ""):gsub("%[auto%s+%d+%.?%d*%]", ""))
            currentNodeId = nodeName
            currentNode = {
                text = "",
                _choices = {},
                isEndNode = isEnd or nil,
                autoAdvanceDelay = autoDelay,
                actions = nodeActions,
            }
            continue
        end

        if not currentNode then continue end

        -- @ Speaker Name
        local speakerMatch = line:match("^@%s*(.+)$")
        if speakerMatch then
            currentNode.speaker = trim(speakerMatch)
            continue
        end

        -- > Choice text -> target [if key value] [hide] [set key value] [call name]
        local choiceMatch = line:match("^>%s*(.+)$")
        if choiceMatch then
            local choiceText, targetNodeId
            local conditionKey, conditionValue
            local hideWhenUnavailable = false

            local hasHide = choiceMatch:match("%[hide%]") ~= nil
            if hasHide then
                hideWhenUnavailable = true
                choiceMatch = choiceMatch:gsub("%[hide%]", "")
            end

            local ifKey, ifVal = choiceMatch:match("%[if%s+(%S+)%s+(%S+)%]")
            if ifKey then
                conditionKey = ifKey
                conditionValue = parseConditionValue(ifVal)
                choiceMatch = choiceMatch:gsub("%[if%s+%S+%s+%S+%]", "")
            end

            local choiceActions
            choiceActions, choiceMatch = parseActions(choiceMatch)

            choiceMatch = choiceMatch:gsub("%s+%-%-.*$", "")

            choiceText, targetNodeId = choiceMatch:match("^(.-)%s*%->%s*(.+)$")
            if choiceText and targetNodeId then
                choiceText = trim(choiceText)
                targetNodeId = trim(targetNodeId)

                local choice: any = {
                    text = choiceText,
                    targetNodeId = targetNodeId,
                }

                if conditionKey then
                    choice.conditions = { [conditionKey] = conditionValue }
                end
                if hideWhenUnavailable then
                    choice.hideWhenUnavailable = true
                end
                if choiceActions then
                    choice.actions = choiceActions
                end

                table.insert(currentNode._choices, choice)
            end
            continue
        end

        -- Regular text line — append to dialogue
        if currentNode.text == "" then
            currentNode.text = line
        else
            currentNode.text = currentNode.text .. " " .. line
        end
    end

    finishNode()

    if not startNodeId then
        for id in pairs(nodes) do
            startNodeId = id
            break
        end
    end

    return {
        id = treeId,
        startNodeId = startNodeId,
        nodes = nodes,
    }
end

return DialogueParser
