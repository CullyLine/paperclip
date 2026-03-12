--[[
    ExampleUsage.lua
    LocalScript demonstrating ProximityPrompt-based NPC dialogue integration
    with four different NPCs using the simple text format.

    Place this as a LocalScript in StarterPlayerScripts.
    Expects NPC models in Workspace.NPCs (or directly in Workspace) with
    names: "Elon Musk", "Zip Zop Man", "Helper Bot", "Spongebob"
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DialoguePro = require(ReplicatedStorage:WaitForChild("DialoguePro"):WaitForChild("DialoguePro"))
local DialogueParser = require(ReplicatedStorage:WaitForChild("DialoguePro"):WaitForChild("DialogueParser"))
local Theme = require(ReplicatedStorage:WaitForChild("DialoguePro"):WaitForChild("Theme"))

local player = Players.LocalPlayer

------------------------------------------------------------------------
-- Dialogue trees written in the simple text format
------------------------------------------------------------------------

local elonDialogue = DialogueParser.Parse([[
=== elon
start: greeting

# greeting
Hey. So, I've been thinking... what if we just, like, put you on Mars? Interested?
> How much does a ticket to Mars cost? -> mars_price
> What about that Dogecoin thing? -> dogecoin
> Can I drive a Cybertruck? -> cybertruck
> Tell Helper Bot I said hi -> helperbot_errand [if talkedToHelperBot false]
> I talked to Helper Bot for you! -> errand_complete [if helperBotErrand true]
> No thanks, I like Earth. -> farewell

# mars_price
Technically it's free if you work for me for 47 years on the colony.
Otherwise... 500 gold. Bargain, honestly.
> Deal! Sign me up. -> mars_purchased [if gold 500] [call purchaseMarsTicket] [call playCashSound]
> 47 years of labor? Hard pass. -> mars_decline

# mars_purchased [end] [set hasMarsTicket true]
Welcome aboard. Your launch window is... soon-ish. We'll tweet about it. Pack light.

# mars_decline
Your loss. Mars has zero traffic jams. Zero. Think about that.
> Let me ask something else. -> greeting
> Goodbye, Elon. -> farewell

# dogecoin
Dogecoin is the people's currency. To the moon. Literally — I'm building the payment terminal. Got any?
> I actually do have some! -> doge_yes [if hasDogecoin true]
> Nope, I'm broke in meme coins. -> doge_no

# doge_yes [end]
Based. Absolute legend. Here, take this <b><font color='#f5a623'>Doge Helmet</font></b>. Much wow.

# doge_no
Unfortunate. You should fix that. Anyway, anything else?
> Let me ask something else. -> greeting
> I'll head out. -> farewell

# cybertruck
Sure. The windows are unbreakable. Mostly. Don't throw rocks at it. Or do. Content is content.
> I'll take one for a spin! -> cybertruck_ride [call startCybertruckCutscene]
> It looks like a polygon from 2003. -> cybertruck_roast

# cybertruck_ride [end]
Autopilot engaged. If it drives into a lake, that's a feature. Enjoy.

# cybertruck_roast [end]
Low-poly is the future. You just don't get it yet. Visionary stuff.

-- Quest: Elon asks you to go talk to Helper Bot
# helperbot_errand [set elonErrand true]
Hey, do me a favor? Go tell Helper Bot that I need the diagnostics report.
Come back when you've talked to it.
> Sure, I'll go talk to Helper Bot. -> errand_accepted [set helperBotErrand false]
> Nah, maybe later. -> farewell

# errand_accepted [end] [call showQuestMarker]
Thanks! Hurry back, I've got rockets to launch.

# errand_complete [end] [set helperBotErrand false] [call giveQuestReward]
You actually did it! Here — take 200 gold for your trouble.

# farewell [end]
Later. I'll be on X if you need me. Or Mars. Probably Mars.
]])

local zipZopDialogue = DialogueParser.Parse([[
=== zipzop
start: greeting

# greeting
ZIIIIP! ZOP! You have entered the <b><font color='#00ff88'>zone of zip</font></b>! Do you accept the zop?
> I accept the zop. -> accept_zop
> What is a zop? -> what_is_zop
> I refuse. -> refuse

# accept_zop
YEEEES! The zop flows through you! Quick — pick a hand! Left or right?!
> Left hand! -> left_hand
> Right hand! -> right_hand

# left_hand [end]
BZZZT! Wrong! It was the <i>middle</i> hand! You didn't even see it! ZIP ZOP!
Here's a consolation prize: nothing! HAHA!

# right_hand [end]
CORRECT-ISH! You win one (1) <b><font color='#ff00ff'>Interdimensional Marble</font></b>!
Don't eat it. Or do. I'm not your dad. Or AM I?

# what_is_zop
Nobody knows! That's the beauty! The zop is what you make it!
Unless you make it a sandwich, then it's just a sandwich.
> Okay... I accept the zop then. -> accept_zop
> This is too weird for me. -> refuse

# refuse [end]
You REFUSE the zop?! The zop does not care! The zop is eternal! ZIP! ZOP! GONE!
]])

local helperBotDialogue = DialogueParser.Parse([[
=== helperbot
start: greeting

# greeting
Hello, {playerName}! I'm <b>Helper Bot</b>. I'm here to assist you with anything you need.
You have <b>{gold} gold</b>. What can I help with?
> Elon sent me for the diagnostics report. -> elon_errand [if elonErrand true]
> How do I fight enemies? -> combat_help
> How does the shop work? -> shop_help
> Can you heal me? -> heal
> I'm good, thanks! -> farewell

# elon_errand [set helperBotErrand true] [set talkedToHelperBot true]
Oh, Elon needs the diagnostics? Say no more. Tell him everything's
<b><font color='#00ff00'>green across the board</font></b>. All systems nominal. Now go — before he tweets about it.
> Will do! -> elon_errand_done

# elon_errand_done [end]
Safe travels! Head back to Elon whenever you're ready.

# combat_help
Click or tap on an enemy to attack. Hold <b>Shift</b> to block.
Blocking at the right moment triggers a <b><font color='#00aaff'>Perfect Parry</font></b> for double damage!
> What about special abilities? -> abilities
> Got it, thanks! -> farewell

# abilities
Press <b>Q</b>, <b>E</b>, or <b>R</b> to use your equipped abilities.
You can swap them at any <b><font color='#ffcc00'>Ability Shrine</font></b> found in towns.
> Where's the nearest shrine? -> shrine_location
> Ask about something else. -> greeting

# shrine_location [end]
There's one just north of the town square, next to the fountain. Look for the glowing pillar!

# shop_help
Walk up to any merchant and interact with them.
You can buy items with <b><font color='#ffd700'>Gold</font></b> earned from quests and defeating enemies.
> How do I earn gold faster? -> gold_tips
> Ask about something else. -> greeting

# gold_tips [end]
Daily quests give the most gold! You can also sell unwanted items to merchants,
or find treasure chests hidden around the map.

# heal [call healPlayer]
Of course![pause 1] ... <i>bzzzt</i> ...[pause 0.5] Healing complete! You're at full health. Stay safe out there, {playerName}!
> Thanks! Anything else I should know? -> pro_tip
> Thanks, bye! -> farewell

# pro_tip [end]
<b><font color='#00ff00'>Pro tip:</font></b> If you crouch near bushes, enemies won't detect you.
Great for sneaking past tough fights you're not ready for!

# farewell [end]
Happy to help! Remember, you can talk to me anytime. Good luck out there!
]])

local spongebobDialogue = DialogueParser.Parse([[
=== spongebob
start: greeting

# greeting
I'M READY! I'M READY! I'M READY! Oh hi there!
Welcome to the <b><font color='#ffdd00'>Krusty Krab</font></b>! Can I take your order?
> One Krabby Patty, please! -> krabby_patty
> What's the secret formula? -> secret_formula
> Spongebob, are you okay? You seem... energetic. -> energetic
> I'll come back later. -> farewell

# krabby_patty
EXCELLENT CHOICE! One Krabby Patty, cooked with love and exactly 37 seconds of grill time!
That'll be 1 gold!
> Here you go! -> patty_served
> Can I get it with jellyfish jelly? -> jelly_patty

# patty_served [end]
Order up! <i>*flips spatula*</i> Enjoy every bite!
Remember — it's not just a patty, it's a <b><font color='#ff6347'>Krabby Patty</font></b>!

# jelly_patty
Ohhh a <b><font color='#cc44ff'>Jellyfish Jelly Krabby Patty</font></b>?!
That's my SPECIALTY! Patrick loved it! Here you go!
> This is amazing! -> amazing_reaction
> Do you have a spatula I could borrow? -> spatula_quest [if hasSpatula true]

# amazing_reaction [end]
<i>*happy giggle*</i> I KNOW RIGHT?!
Best thing since... well, since the LAST Krabby Patty! Come back anytime!

# spatula_quest [end]
You already have a spatula?! A fellow fry cook!!
Here, take my <b><font color='#c0c0c0'>Golden Spatula</font></b>. You've earned it, buddy!

# secret_formula
The secret formula?! <i>*looks around nervously*</i>
[speed 0.08]I... I can't tell you that![pause 0.5] Mr. Krabs would...[pause 0.3] he would...[pause 1][speed 0.01] AAAAAHHH!
> Calm down! I was just kidding! -> calm_down
> Is it love? -> is_it_love

# calm_down
Oh... oh phew! Hahaha! Good one! You really had me there! <i>*nervous laughter*</i>
So... want a Krabby Patty?
> Sure, one Krabby Patty! -> krabby_patty
> Nah, I'll head out. -> farewell

# is_it_love [end]
... <i>*tears up*</i> ... You GET it. You really get it.
The secret ingredient is always love. And also some other stuff Mr. Krabs won't tell me.

# energetic
I'm not just okay — I'm GREAT! Every day above sea level is a good day!
Wait, we're underwater. Every day BELOW sea level is a good day!
> That's the spirit! -> spirit
> Has anyone checked on Squidward? -> squidward

# spirit [end]
I learned it from my best friend Patrick! He says 'the inner machinations of my mind
are an enigma.' I don't know what it means but it sounds SMART!

# squidward [end]
Oh Squidward's fine! He's playing his clarinet. Well... he calls it playing.
Gary calls it a cat in a blender. I think it's beautiful!

# farewell [end]
Bye! Come back soon! And remember...
<b><font color='#ffdd00'>the best time to wear a striped sweater... is all the time!</font></b>
]])

------------------------------------------------------------------------
-- Engine setup
------------------------------------------------------------------------
local engine = DialoguePro.new()
engine:RegisterTree("elon", elonDialogue)
engine:RegisterTree("zipzop", zipZopDialogue)
engine:RegisterTree("helperbot", helperBotDialogue)
engine:RegisterTree("spongebob", spongebobDialogue)

-- Set starting flags (the engine has a built-in flag store)
engine:SetFlag("hasDogecoin", false)
engine:SetFlag("gold", 1000)
engine:SetFlag("hasSpatula", false)
engine:SetFlag("talkedToHelperBot", false)
engine:SetFlag("elonErrand", false)
engine:SetFlag("helperBotErrand", false)

-- Variables resolve flag values automatically; add extra resolvers for non-flag data
engine:RegisterVariable(function(varName: string): any?
    if varName == "playerName" then return player.Name end
    return nil
end)

-- Register actions that can be fired from [call name] tags in dialogue
engine:RegisterAction("purchaseMarsTicket", function()
    local gold = engine:GetFlag("gold") or 0
    engine:SetFlag("gold", gold - 500)
    print("[Action] Mars ticket purchased! -500 gold (total: " .. (gold - 500) .. ")")
end)

engine:RegisterAction("playCashSound", function()
    print("[Action] Ka-ching! Cash sound plays")
end)

engine:RegisterAction("startCybertruckCutscene", function()
    print("[Action] Cybertruck cutscene starts!")
end)

engine:RegisterAction("showQuestMarker", function()
    print("[Action] Quest marker placed on Helper Bot!")
end)

engine:RegisterAction("giveQuestReward", function()
    local gold = engine:GetFlag("gold") or 0
    engine:SetFlag("gold", gold + 200)
    print("[Action] Quest complete! +200 gold (total: " .. (gold + 200) .. ")")
end)

engine:RegisterAction("healPlayer", function()
    print("[Action] Player healed to full HP!")
end)

-- Each NPC gets a tree ID and an optional theme.
-- If theme is missing, the engine's default theme is used.
local npcConfig = {
    ["Elon Musk"] = { tree = "elon", theme = Theme.Presets.SciFi },
    ["Zip Zop Man"] = { tree = "zipzop", theme = Theme.Presets.Bubblegum },
    ["Helper Bot"] = { tree = "helperbot" },
    ["Spongebob"] = { tree = "spongebob", theme = Theme.Presets.Fantasy },
}

------------------------------------------------------------------------
-- NPC prompt setup
------------------------------------------------------------------------
local function setupNPCPrompt(npc: Model)
    local config = npcConfig[npc.Name]
    if not config then return end

    local head = npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart")
    if not head then
        warn("[DialogueExample] NPC missing Head or HumanoidRootPart: " .. npc.Name)
        return
    end

    local existingPrompt = head:FindFirstChildOfClass("ProximityPrompt")
    local prompt = existingPrompt or Instance.new("ProximityPrompt")

    if not existingPrompt then
        prompt.ActionText = "Talk"
        prompt.ObjectText = npc.Name
        prompt.MaxActivationDistance = 10
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
        prompt.Parent = head
    end

    prompt.Triggered:Connect(function(triggerPlayer)
        if triggerPlayer ~= player then return end

        engine:Start(config.tree, npc, {
            theme = config.theme,
            onNodeEnter = function(nodeId: string)
                print("[Dialogue]", npc.Name, "-> node:", nodeId)
            end,
            onChoice = function(nodeId: string, choiceIndex: number)
                print("[Dialogue]", npc.Name, "-> choice at", nodeId, "index:", choiceIndex)
            end,
            onEnd = function()
                print("[Dialogue]", npc.Name, "-> conversation ended.")
            end,
        })
    end)
end

local function findNPCs()
    local npcsFolder = workspace:FindFirstChild("NPCs")
    local searchIn = npcsFolder or workspace

    for _, child in ipairs(searchIn:GetChildren()) do
        if child:IsA("Model") and npcConfig[child.Name] then
            setupNPCPrompt(child)
        end
    end
end

wait(3)

findNPCs()
print("[DialoguePro] Example loaded with 4 NPCs. Approach one to start dialogue.")
