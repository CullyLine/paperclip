--[[
    VerySimpleExampleDialog
    The simplest possible DialogueEngine examples.

    Place this as a LocalScript in StarterPlayerScripts.
    Make sure the DialogueEngine model is in ReplicatedStorage.
    Create NPC models in Workspace with the names below.

    Each example below builds on the last, from dead-simple to slightly fancier.
    Read through them to learn the text format step by step.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DialogueEngine = require(ReplicatedStorage:WaitForChild("DialogueEngine"):WaitForChild("DialogueEngine"))
local DialogueParser = require(ReplicatedStorage:WaitForChild("DialogueEngine"):WaitForChild("DialogueParser"))

local player = Players.LocalPlayer

------------------------------------------------------------------------
-- EXAMPLE 1: The absolute basics
--
-- Just a greeting with two choices. That's it.
-- Lines starting with # define a "node" (a screen of text).
-- Lines starting with > define a choice the player can click.
-- The -> arrow says which node to go to next.
-- [end] means the conversation stops at that node.
------------------------------------------------------------------------

local guardDialogue = DialogueParser.Parse([[
=== guard
start: greeting

# greeting
Halt! Who goes there?
> I'm a friend. -> friendly
> None of your business. -> rude

# friendly [end]
Ah, welcome then! You may pass.

# rude [end]
Hmph. Move along.
]])

------------------------------------------------------------------------
-- EXAMPLE 2: Branching deeper
--
-- Choices can lead to more choices. You can loop back
-- to earlier nodes too — just point -> at them.
------------------------------------------------------------------------

local shopkeeperDialogue = DialogueParser.Parse([[
=== shopkeeper
start: greeting

# greeting
Welcome to my shop! What are you looking for?
> What do you sell? -> inventory
> Just browsing. -> farewell

# inventory
I've got swords, shields, and potions. What interests you?
> Tell me about the swords. -> swords
> Tell me about the potions. -> potions
> Actually, never mind. -> farewell

# swords [end]
Fine steel, sharp edge. 100 gold each. Come back when you're ready to buy!

# potions [end]
Heals you right up. 25 gold for a small one, 50 for a large.

# farewell [end]
Come back anytime!
]])

------------------------------------------------------------------------
-- EXAMPLE 3: Speaker names
--
-- By default the speaker name comes from the NPC model's name.
-- Use @ to override it mid-conversation (great for narration).
------------------------------------------------------------------------

local storytellerDialogue = DialogueParser.Parse([[
=== storyteller
start: intro

# intro
@ The Old Storyteller
Gather 'round, child. Let me tell you a tale...
> Tell me the tale! -> tale
> Maybe later. -> farewell

# tale
@ Narrator
Long ago, a hero set out on a journey across the mountains...
> What happened next? -> climax

# climax
@ The Old Storyteller
That, my friend, is a story for another day.
> Aww, fine. -> farewell

# farewell [end]
@ The Old Storyteller
Until next time!
]])

------------------------------------------------------------------------
-- EXAMPLE 4: Using variables
--
-- Put {variableName} in your text and it gets replaced at runtime.
-- Register a resolver below to tell the engine what value to use.
------------------------------------------------------------------------

local greeterDialogue = DialogueParser.Parse([[
=== greeter
start: hello

# hello
Hey there, {playerName}! Nice to meet you!
> Nice to meet you too! -> nice
> How do you know my name? -> confused

# nice [end]
Hope you enjoy your stay!

# confused [end]
I know everyone's name around here. It's a small village!
]])

------------------------------------------------------------------------
-- EXAMPLE 5: Flags and conditions
--
-- [set key value] saves a flag when a node is entered or choice picked.
-- [if key value] on a choice means it only shows when the flag matches.
-- Great for quests, purchases, one-time events.
------------------------------------------------------------------------

local questgiverDialogue = DialogueParser.Parse([[
=== questgiver
start: greeting

# greeting
Hello, adventurer!
> Got any quests? -> offer_quest [if questDone false]
> I finished the quest! -> quest_complete [if questActive true]
> Just saying hi. -> farewell

# offer_quest
There are wolves in the forest. Can you take care of them?
> I'll do it! -> accepted [set questActive true]
> No thanks. -> farewell

# accepted [end]
Brave soul! Come back when they're dealt with.

# quest_complete [end] [set questDone true] [set questActive false]
You did it! Thank you! Here's your reward.

# farewell [end]
Take care out there!
]])

------------------------------------------------------------------------
-- EXAMPLE 6: End nodes and auto-advance
--
-- [end] = conversation stops here (no choices needed).
-- [auto N] = the text auto-advances after N seconds (for cutscenes).
------------------------------------------------------------------------

local mysticDialogue = DialogueParser.Parse([[
=== mystic
start: vision1

# vision1 [auto 3]
@ ???
A vision appears before you...

# vision2 [auto 2]
@ ???
You see a distant mountain, shrouded in mist...

# vision3
@ Mystic
The spirits have shown you your path. Will you follow it?
> Yes, I will. -> yes
> I need to think about it. -> no

# yes [end]
Then go. The mountain awaits.

# no [end]
Take your time. The mountain isn't going anywhere.
]])

------------------------------------------------------------------------
-- ENGINE SETUP
------------------------------------------------------------------------

local engine = DialogueEngine.new()

engine:RegisterTree("guard", guardDialogue)
engine:RegisterTree("shopkeeper", shopkeeperDialogue)
engine:RegisterTree("storyteller", storytellerDialogue)
engine:RegisterTree("greeter", greeterDialogue)
engine:RegisterTree("questgiver", questgiverDialogue)
engine:RegisterTree("mystic", mysticDialogue)

-- Flags for the quest example
engine:SetFlag("questActive", false)
engine:SetFlag("questDone", false)

-- Variable resolver for {playerName}
engine:RegisterVariable(function(varName)
    if varName == "playerName" then
        return player.Name
    end
    return nil
end)

------------------------------------------------------------------------
-- CONNECT NPCs
--
-- Maps NPC model names to tree IDs.
-- Create models in Workspace (or a Workspace.NPCs folder)
-- with these exact names and a Head or HumanoidRootPart.
------------------------------------------------------------------------

local npcTrees = {
    ["Guard"]       = "guard",
    ["Shopkeeper"]  = "shopkeeper",
    ["Storyteller"] = "storyteller",
    ["Greeter"]     = "greeter",
    ["Quest Giver"] = "questgiver",
    ["Mystic"]      = "mystic",
}

local function setupNPC(npc)
    local treeId = npcTrees[npc.Name]
    if not treeId then return end

    local head = npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart")
    if not head then return end

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Talk"
    prompt.ObjectText = npc.Name
    prompt.MaxActivationDistance = 10
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.Parent = head

    prompt.Triggered:Connect(function(triggerPlayer)
        if triggerPlayer ~= player then return end
        engine:Start(treeId, npc)
    end)
end

-- Find NPCs in Workspace or Workspace.NPCs
task.wait(2)
local npcsFolder = workspace:FindFirstChild("NPCs")
for _, child in (npcsFolder or workspace):GetChildren() do
    if child:IsA("Model") and npcTrees[child.Name] then
        setupNPC(child)
    end
end

print("[VerySimpleExampleDialog] Ready! Walk up to an NPC and press E.")
