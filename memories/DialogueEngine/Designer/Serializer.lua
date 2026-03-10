local Serializer = {}

local function trim(s)
	return s:match("^%s*(.-)%s*$") or ""
end

local function fmtVal(v)
	if type(v) == "boolean" then return tostring(v) end
	return tostring(v)
end

local function parseVal(raw)
	if raw == "true"  then return true  end
	if raw == "false" then return false end
	local n = tonumber(raw)
	if n then return n end
	return raw
end

local function fmtActions(actions)
	if not actions then return "" end
	local parts = {}
	for _, a in ipairs(actions) do
		if a.type == "set" then
			table.insert(parts, " [set " .. a.key .. " " .. fmtVal(a.value) .. "]")
		elseif a.type == "call" then
			table.insert(parts, " [call " .. a.key .. "]")
		end
	end
	return table.concat(parts)
end

local function extractActions(text)
	local actions = {}
	for key, val in text:gmatch("%[set%s+(%S+)%s+(%S+)%]") do
		table.insert(actions, { type = "set", key = key, value = parseVal(val) })
	end
	text = text:gsub("%[set%s+%S+%s+%S+%]", "")
	for name in text:gmatch("%[call%s+(%S+)%]") do
		table.insert(actions, { type = "call", key = name })
	end
	text = text:gsub("%[call%s+%S+%]", "")
	return actions, text
end

------------------------------------------------------------------------
-- Export: state → text format
------------------------------------------------------------------------
function Serializer.Export(state)
	local lines = {}

	for id, node in pairs(state.nodes) do
		table.insert(lines, string.format("-- pos: %s %d %d", id, math.floor(node.x or 0), math.floor(node.y or 0)))
	end
	table.insert(lines, "")

	table.insert(lines, "=== " .. (state.treeId or "untitled"))
	if state.startNodeId then
		table.insert(lines, "start: " .. state.startNodeId)
	end
	table.insert(lines, "")

	local ordered = {}
	for id in pairs(state.nodes) do
		if id ~= state.startNodeId then table.insert(ordered, id) end
	end
	table.sort(ordered)
	if state.startNodeId and state.nodes[state.startNodeId] then
		table.insert(ordered, 1, state.startNodeId)
	end

	for _, nodeId in ipairs(ordered) do
		local node = state.nodes[nodeId]
		local header = "# " .. nodeId
		if node.isEndNode then header = header .. " [end]" end
		if node.autoAdvanceDelay then header = header .. " [auto " .. node.autoAdvanceDelay .. "]" end
		header = header .. fmtActions(node.actions)
		table.insert(lines, header)

		if node.speaker and node.speaker ~= "" then
			table.insert(lines, "@ " .. node.speaker)
		end
		if node.text and node.text ~= "" then
			for textLine in (node.text .. "\n"):gmatch("(.-)\n") do
				table.insert(lines, textLine)
			end
		end

		for _, choice in ipairs(node.choices or {}) do
			local cl = "> " .. (choice.text or "...")
			if choice.targetNodeId and choice.targetNodeId ~= "" then
				cl = cl .. " -> " .. choice.targetNodeId
			end
			if choice.conditions then
				for k, v in pairs(choice.conditions) do
					cl = cl .. " [if " .. k .. " " .. fmtVal(v) .. "]"
				end
			end
			if choice.hideWhenUnavailable then cl = cl .. " [hide]" end
			cl = cl .. fmtActions(choice.actions)
			table.insert(lines, cl)
		end
		table.insert(lines, "")
	end

	return table.concat(lines, "\n")
end

------------------------------------------------------------------------
-- Import: text format → state data table
------------------------------------------------------------------------
function Serializer.Import(source)
	local positions = {}
	local treeId = "untitled"
	local startNodeId = nil
	local nodes = {}
	local curId, curNode = nil, nil

	local function finish()
		if curId and curNode then
			curNode.text = trim(curNode.text or "")
			if curNode._choices and #curNode._choices > 0 then
				curNode.choices = curNode._choices
			else
				curNode.choices = {}
			end
			curNode._choices = nil
			local pos = positions[curId]
			if pos then curNode.x, curNode.y = pos.x, pos.y end
			nodes[curId] = curNode
		end
		curId, curNode = nil, nil
	end

	for rawLine in (source .. "\n"):gmatch("(.-)\n") do
		local line = trim(rawLine)

		local posId, px, py = line:match("^%-%-%s*pos:%s*(%S+)%s+(-?%d+)%s+(-?%d+)")
		if posId then
			positions[posId] = { x = tonumber(px), y = tonumber(py) }
			continue
		end

		if line == "" or line:sub(1, 2) == "--" then continue end

		local treeMatch = line:match("^===%s*(.+)$")
		if treeMatch then treeId = trim(treeMatch); continue end

		local startMatch = line:match("^start:%s*(.+)$")
		if startMatch then startNodeId = trim(startMatch); continue end

		local nodeMatch = line:match("^#%s*(.+)$")
		if nodeMatch then
			finish()
			local isEnd = nodeMatch:match("%[end%]") ~= nil
			local autoDelay = tonumber(nodeMatch:match("%[auto%s+(%d+%.?%d*)%]"))
			local nodeActions, remaining = extractActions(nodeMatch)
			local nodeName = trim(remaining:gsub("%[end%]", ""):gsub("%[auto%s+%d+%.?%d*%]", ""))
			curId = nodeName
			curNode = {
				id = nodeName, x = 0, y = 0,
				text = "", _choices = {},
				isEndNode = isEnd,
				autoAdvanceDelay = autoDelay,
				actions = #nodeActions > 0 and nodeActions or {},
			}
			continue
		end

		if not curNode then continue end

		local speakerMatch = line:match("^@%s*(.+)$")
		if speakerMatch then curNode.speaker = trim(speakerMatch); continue end

		local choiceMatch = line:match("^>%s*(.+)$")
		if choiceMatch then
			local hide = choiceMatch:match("%[hide%]") ~= nil
			choiceMatch = choiceMatch:gsub("%[hide%]", "")

			local ifKey, ifVal = choiceMatch:match("%[if%s+(%S+)%s+(%S+)%]")
			local conditions = {}
			if ifKey then
				conditions[ifKey] = parseVal(ifVal)
				choiceMatch = choiceMatch:gsub("%[if%s+%S+%s+%S+%]", "")
			end

			local choiceActions
			choiceActions, choiceMatch = extractActions(choiceMatch)
			choiceMatch = choiceMatch:gsub("%s+%-%-.*$", "")

			local cText, cTarget = choiceMatch:match("^(.-)%s*%->%s*(.+)$")
			if cText and cTarget then
				table.insert(curNode._choices, {
					text                = trim(cText),
					targetNodeId        = trim(cTarget),
					conditions          = conditions,
					hideWhenUnavailable = hide,
					actions             = #choiceActions > 0 and choiceActions or {},
				})
			end
			continue
		end

		if curNode.text == "" then
			curNode.text = line
		else
			curNode.text = curNode.text .. "\n" .. line
		end
	end

	finish()

	if not startNodeId then
		for id in pairs(nodes) do startNodeId = id; break end
	end

	local hasPos = false
	for _ in pairs(positions) do hasPos = true; break end
	if not hasPos then
		Serializer.AutoLayout(nodes, startNodeId)
	end

	return { treeId = treeId, startNodeId = startNodeId, nodes = nodes }
end

------------------------------------------------------------------------
-- Auto-layout: BFS tree arrangement
------------------------------------------------------------------------
function Serializer.AutoLayout(nodes, startNodeId)
	local centerX = 3000
	local centerY = 3000
	local xGap    = 300
	local yGap    = 160
	local visited = {}
	local levels  = {}

	local function bfs()
		if not startNodeId or not nodes[startNodeId] then return end
		local queue = { { id = startNodeId, level = 0 } }
		visited[startNodeId] = true
		while #queue > 0 do
			local item = table.remove(queue, 1)
			if not levels[item.level] then levels[item.level] = {} end
			table.insert(levels[item.level], item.id)
			local node = nodes[item.id]
			if node and node.choices then
				for _, c in ipairs(node.choices) do
					if c.targetNodeId and nodes[c.targetNodeId] and not visited[c.targetNodeId] then
						visited[c.targetNodeId] = true
						table.insert(queue, { id = c.targetNodeId, level = item.level + 1 })
					end
				end
			end
		end
	end
	bfs()

	for level, ids in pairs(levels) do
		local totalH = (#ids - 1) * yGap
		for i, id in ipairs(ids) do
			local node = nodes[id]
			if node then
				node.x = centerX + level * xGap
				node.y = centerY - totalH / 2 + (i - 1) * yGap
			end
		end
	end

	local idx = 0
	for id, node in pairs(nodes) do
		if not visited[id] then
			node.x = centerX - xGap
			node.y = centerY + idx * yGap
			idx = idx + 1
		end
	end
end

------------------------------------------------------------------------
-- ModuleScript source generation
------------------------------------------------------------------------
function Serializer.ToModuleScript(state)
	local txt = Serializer.Export(state)
	return 'local DialogueParser = require(game:GetService("ReplicatedStorage"):WaitForChild("DialogueEngine"):WaitForChild("DialogueParser"))\n\nreturn DialogueParser.Parse([[\n'
		.. txt .. ']])\n'
end

return Serializer
