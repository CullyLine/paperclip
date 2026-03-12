--[[
    TemplateSetup.local.luau
    Template Place — Thornwood Village

    A self-contained demo of every DialogueEngine feature.
    Place this as a LocalScript in StarterPlayerScripts.
    Expects NPC models in Workspace.NPCs with these names:
      "Elder Maren", "Forge Master Brok", "Merchant Lira",
      "Sage Thalindra", "Captain Aldric", "Innkeeper Mira", "Pip"
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DialogueEngine = require(ReplicatedStorage:WaitForChild("DialogueEngine"):WaitForChild("DialogueEngine"))
local DialogueParser = require(ReplicatedStorage:WaitForChild("DialogueEngine"):WaitForChild("DialogueParser"))
local Theme = require(ReplicatedStorage:WaitForChild("DialogueEngine"):WaitForChild("Theme"))

local player = Players.LocalPlayer

------------------------------------------------------------------------
-- DIALOGUE TREES
------------------------------------------------------------------------

--[[
    ELDER MAREN — Town Square
    Features: basic branching, speaker name, rich text, village intro
]]
local elderMarenTree = DialogueParser.Parse([[
=== elder_maren
start: greeting

# greeting
@ Elder Maren
Ah, welcome to <b><font color='#c8a86e'>Thornwood Village</font></b>, traveler. It's been a while since we've seen a new face around here. I am Maren, elder of this village.
> Tell me about the village. -> about_village
> Who lives here? -> villagers
> A child near the pond said they were lost... -> pip_concern [if pipLost true]
> I helped Pip find their way home! -> pip_resolved [if pipSafe true]
> I should get going. -> farewell

# about_village
@ Elder Maren
Thornwood has stood for three hundred years at the edge of the <b>Whispering Woods</b>. We're a small folk — smiths, merchants, the odd wizard. The forest keeps most trouble away, but lately...[pause 0.8] well, there have been <i>rumors</i>.
> What kind of rumors? -> rumors
> Who should I talk to first? -> who_first
> Interesting. I'll look around. -> farewell

# rumors
@ Elder Maren
Strange lights in the wizard's tower at night. Travelers going missing on the north road. And the children...[pause 0.5] they say they hear <i>singing</i> from the woods. <font color='#aa4444'>Best stay on the paths, traveler.</font>
> I'll investigate the tower. -> tower_hint
> I'll be careful. -> farewell

# tower_hint
@ Elder Maren
Speak with <b>Sage Thalindra</b> — she lives in the tower on the east side. She's... eccentric, but wise. If anyone knows what's happening, it's her.
> Thank you, Elder. -> farewell
> Who else should I visit? -> who_first

# villagers
@ Elder Maren
Let's see... <b>Forge Master Brok</b> runs the smithy — finest blades in the region. <b>Merchant Lira</b> sells supplies at the market. <b>Captain Aldric</b> keeps the peace at the gate. <b>Innkeeper Mira</b> runs the tavern — good food, warm beds. And <b>Sage Thalindra</b> in her tower, studying the arcane.
> That's quite the cast. Anyone else? -> pip_mention
> I'll go meet them. -> farewell

# pip_mention
@ Elder Maren
Oh, and there's little <b>Pip</b> — always running around by the pond. Harmless child, but tends to wander too far. Keep an eye out, would you?
> Of course. -> farewell

# who_first
@ Elder Maren
If you need supplies, see <b>Merchant Lira</b> at the market. If you need a weapon, <b>Forge Master Brok</b> is your man. And if you're tired, <b>Innkeeper Mira</b> will fix you right up.
> Thanks for the advice. -> farewell

# pip_concern
@ Elder Maren
Lost? Oh dear... Pip is always getting into trouble. Please, go speak with <b>Captain Aldric</b> at the gate — he can send someone to help. Tell him I sent you.
> I'll go find the Captain right away. -> pip_concern_end [set elderSentToAldric true]

# pip_concern_end [end]
@ Elder Maren
Thank you, traveler. Thornwood looks after its own.

# pip_resolved [end]
@ Elder Maren
Bless you, truly. That child is the heart of this village. You've earned the gratitude of all of Thornwood. Here — take this as thanks.[pause 0.5] <b><font color='#ffd700'>+500 Gold</font></b>

# farewell [end]
@ Elder Maren
Take care, traveler. Thornwood's doors are always open to you.
]])

--[[
    FORGE MASTER BROK — Blacksmith
    Features: conditions [if gold], [set] flags, [call] actions, {variables}, shop
]]
local brokTree = DialogueParser.Parse([[
=== brok
start: greeting

# greeting
@ Forge Master Brok
*CLANG* — Oh! Didn't see you there, {playerName}. Name's Brok. I forge the finest steel in Thornwood. You look like you could use a weapon. You're carrying <b>{gold} gold</b>.
> What do you have for sale? -> shop
> Can you upgrade my gear? -> upgrade
> Just browsing. -> farewell

# shop
@ Forge Master Brok
Here's what I've got on the anvil today:
> Iron Sword — 100 gold -> buy_iron_sword [if gold 100]
> Steel Greatsword — 300 gold -> buy_steel_sword [if gold 300]
> Enchanted Blade — 750 gold -> buy_enchanted [if gold 750]
> I can't afford anything right now. -> too_poor
> Never mind. -> farewell

# buy_iron_sword [set hasIronSword true] [set gold -100] [call playForgeSound]
@ Forge Master Brok
Good choice! Simple, reliable, gets the job done. *hands over the blade* <b><font color='#aaaaaa'>Iron Sword</font></b> acquired! <font color='#ff6666'>-100 gold</font>.
> Thanks, Brok! -> post_purchase
> What else do you have? -> shop

# buy_steel_sword [set hasSteelSword true] [set gold -300] [call playForgeSound]
@ Forge Master Brok
Now THAT'S a warrior's weapon! Folded steel, perfect balance. *presents the greatsword* <b><font color='#6699cc'>Steel Greatsword</font></b> acquired! <font color='#ff6666'>-300 gold</font>.
> It's beautiful. Thanks! -> post_purchase

# buy_enchanted [set hasEnchantedBlade true] [set gold -750] [call playForgeSound]
@ Forge Master Brok
You've got fine taste and deep pockets! This blade was forged under a blood moon with Thalindra's enchantments woven into the steel. <b><font color='#aa44ff'>Enchanted Blade</font></b> acquired! <font color='#ff6666'>-750 gold</font>.
> Incredible craftsmanship. -> post_purchase

# too_poor
@ Forge Master Brok
No worries! Come back when your pockets are heavier. Kill some monsters, do some quests — gold finds a way.
> Where can I earn gold? -> gold_tips
> I'll be back. -> farewell

# gold_tips
@ Forge Master Brok
Talk to <b>Captain Aldric</b> at the gate — he always has work that needs doing. Or ask <b>Innkeeper Mira</b> about bounties. Monsters in the woods carry loot too.
> Good to know. -> farewell

# upgrade
@ Forge Master Brok
Upgrades, eh? Bring me a weapon and I'll reforge it. Currently I need <b><font color='#ffaa00'>3 Iron Ore</font></b> per upgrade. Got any?
> I have iron ore! -> upgrade_yes [if hasIronOre true] [call playForgeSound]
> Not yet. Where do I find ore? -> ore_location
> Maybe later. -> farewell

# upgrade_yes [end] [set hasIronOre false]
@ Forge Master Brok
*Takes the ore, hammers furiously* [pause 1.5] Done! Your weapon's been tempered. Should hit harder now. Come back anytime, {playerName}!

# ore_location [end]
@ Forge Master Brok
There's an old mine entrance north of the village, past the guard post. Watch out for cave crawlers — nasty things. Bring a torch!

# post_purchase
@ Forge Master Brok
Pleasure doing business! Come back if you need repairs or upgrades. And tell Lira I said hello — she owes me a drink.
> Will do! -> farewell
> Actually, let me see the shop again. -> shop

# farewell [end]
@ Forge Master Brok
Keep that blade sharp, {playerName}! *returns to hammering*
]])

--[[
    MERCHANT LIRA — Market Stall
    Features: [hide] unavailable choices, multiple flag checks, inventory tracking
]]
local liraTree = DialogueParser.Parse([[
=== lira
start: greeting

# greeting
@ Merchant Lira
Welcome, welcome! Lira's Goods — finest supplies in Thornwood! What are you looking for today? You've got <b>{gold} gold</b> to spend.
> Show me what you've got. -> shop
> Do you buy things? -> sell
> Heard any news? -> news
> Just passing through. -> farewell

# shop
@ Merchant Lira
Take your pick, dear:
> Health Potion — 50 gold -> buy_potion [if gold 50]
> Traveler's Map — 150 gold -> buy_map [if gold 150] [hide]
> Lockpick Set — 200 gold -> buy_lockpick [if gold 200] [hide]
> Enchanted Compass — 400 gold -> buy_compass [if gold 400] [hide]
> Back to chat. -> greeting

# buy_potion [set hasPotion true] [set gold -50] [call playBuySound]
@ Merchant Lira
Here you go! One <b><font color='#44dd44'>Health Potion</font></b>. Drink it when things get rough. <font color='#ff6666'>-50 gold</font>.
> Got anything else? -> shop
> Thanks! -> farewell

# buy_map [set hasMap true] [set gold -150] [call playBuySound]
@ Merchant Lira
A <b><font color='#ddcc44'>Traveler's Map</font></b> — shows every path, cave, and shortcut around Thornwood. Essential for explorers! <font color='#ff6666'>-150 gold</font>.
> What else? -> shop
> Perfect, thanks! -> farewell

# buy_lockpick [set hasLockpick true] [set gold -200] [call playBuySound]
@ Merchant Lira
<b><font color='#888888'>Lockpick Set</font></b> — don't ask where I got these. Opens most locks in the region. <font color='#ff6666'>-200 gold</font>. [pause 0.3]<i>Don't tell Aldric.</i>
> Your secret's safe. -> shop
> Thanks! -> farewell

# buy_compass [set hasCompass true] [set gold -400] [call playBuySound]
@ Merchant Lira
Ooh, big spender! This <b><font color='#44aaff'>Enchanted Compass</font></b> points toward hidden treasure. Thalindra enchanted it herself. <font color='#ff6666'>-400 gold</font>.
> Incredible! -> farewell
> Anything else? -> shop

# sell
@ Merchant Lira
I'll buy what you've got! Iron ore, monster drops, old weapons — bring it all. I pay fair prices.
> What are you paying for iron ore? -> sell_ore
> Maybe later. -> greeting

# sell_ore
@ Merchant Lira
<b>10 gold per ore</b>. Market rate! Brok buys it too, but I won't make you swing a hammer for it.
> Good to know. -> greeting

# news
@ Merchant Lira
Well...[pause 0.5] a caravan went missing on the north road last week. Captain Aldric's been tense about it. And Thalindra ordered <i>three crates</i> of crystals from me — won't say what for. Something's brewing.
> Sounds ominous. -> news_pip [if pipLost true]
> Interesting. Thanks. -> greeting

# news_pip
@ Merchant Lira
Oh, and I heard little Pip's gone wandering again? That child...[pause 0.3] the woods aren't safe right now. Someone should really go find <b>Captain Aldric</b>.
> I'm on it. -> farewell

# farewell [end]
@ Merchant Lira
Come back soon, dear! I get new stock every week!
]])

--[[
    SAGE THALINDRA — Wizard Tower
    Features: Fantasy theme, [pause], [speed], rich text, [auto N] auto-advance
]]
local thalindraTree = DialogueParser.Parse([[
=== thalindra
start: tower_entrance

# tower_entrance [auto 4]
@ Sage Thalindra
[speed 0.06]The crystals align...[pause 1] the ley lines converge...[pause 1.5] yes, YES — the pattern is almost —[pause 0.5] [speed 0.03]Oh. You. A visitor.

# greeting
@ Sage Thalindra
I am <b><font color='#bb88ff'>Sage Thalindra</font></b>, keeper of the arcane arts in Thornwood. You've climbed a lot of stairs to reach me. I assume you want something?
> The Elder mentioned strange lights from your tower. -> strange_lights
> Can you teach me magic? -> teach_magic
> What are you researching? -> research
> I bought your Enchanted Compass from Lira. -> compass_talk [if hasCompass true]
> Sorry to disturb you. I'll go. -> farewell

# strange_lights
@ Sage Thalindra
[speed 0.05]Strange lights?[pause 0.8] Those are my <b><font color='#bb88ff'>Ley Line Resonance Experiments</font></b>. The veil between our world and the arcane plane grows thin. I'm trying to understand <i>why</i>.[pause 1]
[speed 0.04]The forest is... [pause 0.5]<font color='#ff6666'>changing</font>. Something ancient stirs beneath the roots. I can feel it in every spell I cast.
> That sounds dangerous. -> danger
> Can I help? -> help_offer
> I'll leave you to it. -> farewell

# danger
@ Sage Thalindra
[speed 0.05]Dangerous?[pause 0.5] <i>Everything</i> worth knowing is dangerous. But yes — if I'm right about what's awakening...[pause 1] [speed 0.04]Thornwood may not survive the season.
> What can we do? -> help_offer
> I need to warn the others. -> warn_others

# warn_others [end]
@ Sage Thalindra
[speed 0.05]Warn them, yes. Tell Aldric to double the watch. Tell Maren to prepare the evacuation wards.[pause 0.8] And tell Brok... [pause 0.5]tell him to forge <b><font color='#ffaa44'>silver weapons</font></b>. We may need them.

# help_offer [set thalindraQuestStarted true]
@ Sage Thalindra
You want to help?[pause 0.5] Hmm. Brave or foolish — either works. I need <b><font color='#88ccff'>3 Moonstone Shards</font></b> from the Whispering Caves. They amplify ley energy. Bring them to me and I can complete the ward.
> Where are the Whispering Caves? -> cave_location
> I'll find them. -> quest_accepted

# cave_location
@ Sage Thalindra
[speed 0.04]North of the village, past the guard post. Follow the river upstream until you hear...[pause 1] well, you'll hear the <i>whispering</i>. That's how the caves got their name.[pause 0.5] Bring a light. And a weapon.
> Got it. I'll head there. -> quest_accepted

# quest_accepted [end] [set thalindraQuestActive true]
@ Sage Thalindra
[speed 0.05]Good.[pause 0.5] Be careful, traveler. The caves don't welcome visitors.[pause 1] <font color='#bb88ff'>May the ley lines guide your path.</font>

# teach_magic
@ Sage Thalindra
[speed 0.05]Teach you?[pause 0.8] Magic isn't taught — it's <i>endured</i>.[pause 0.5] But...[pause 0.3] I suppose I could show you the basics. For a price.
> How much? -> magic_price
> What kind of magic? -> magic_types
> Maybe another time. -> farewell

# magic_price
@ Sage Thalindra
<b>500 gold</b> and your absolute attention. One wandering thought during an incantation and you'll turn yourself inside out. [pause 0.5]<i>Literally.</i>
> I'll come back when I have 500 gold. -> farewell
> Sounds worth the risk! -> learn_magic [if gold 500]

# learn_magic [end] [set gold -500] [set knowsMagic true] [call playMagicSound]
@ Sage Thalindra
[speed 0.06]Very well.[pause 0.5] Close your eyes.[pause 1] Feel the ley lines beneath your feet...[pause 1] the energy flows upward, through your spine, into your fingertips...[pause 1.5] [speed 0.03]<b><font color='#bb88ff'>NOW — RELEASE!</font></b>[pause 0.5]
[speed 0.04]...Not bad. Not bad at all. You've learned <b><font color='#bb88ff'>Arcane Bolt</font></b>. Use it wisely.

# magic_types [end]
@ Sage Thalindra
[speed 0.05]I study three disciplines:[pause 0.3] <b><font color='#bb88ff'>Arcane</font></b> — raw magical energy.[pause 0.3] <b><font color='#44aaff'>Frost</font></b> — slowing and shattering.[pause 0.3] <b><font color='#ff6644'>Fire</font></b> — well... fire.[pause 0.8] Come back when you're ready to learn.

# research
@ Sage Thalindra
[speed 0.05]I'm mapping the <b>Ley Line Network</b> beneath Thornwood. Every village sits on a nexus of magical energy — most people just can't feel it.[pause 0.8] But recently, the lines have been...[pause 0.5] <font color='#ff6666'>pulsing</font>. Like a heartbeat. Something is waking up.
> That's unsettling. -> strange_lights
> Fascinating. -> farewell

# compass_talk [end]
@ Sage Thalindra
[speed 0.05]Ah, you have my compass![pause 0.5] That enchantment took me three days and a <i>very</i> expensive crystal. It'll point you toward anything of magical significance — treasure, artifacts, ley nodes.[pause 0.8] Use it well. And don't drop it in water. [pause 0.3]<i>Please.</i>

# farewell [end]
@ Sage Thalindra
[speed 0.05]Yes, yes, off you go.[pause 0.3] Close the door on your way out. The drafts disturb my crystals.
]])

--[[
    CAPTAIN ALDRIC — Guard Post
    Features: end nodes, quest gating, cross-NPC quest chain, short/long
]]
local aldricTree = DialogueParser.Parse([[
=== aldric
start: greeting

# greeting
@ Captain Aldric
Halt! State your — oh, a traveler. Welcome to Thornwood. I'm Captain Aldric, head of the village guard. What do you need?
> Is the village safe? -> village_safety
> Any work available? -> bounty_board
> Elder Maren sent me — a child named Pip is lost! -> pip_quest [if elderSentToAldric true]
> I found Pip! They're safe. -> pip_complete [if pipFound true]
> Thalindra says to double the watch. -> thalindra_warning [if thalindraQuestStarted true]
> Nothing. Carry on, Captain. -> farewell_short

# village_safety
@ Captain Aldric
Safe enough <i>inside</i> the walls. The north road's been trouble lately — missing caravans, strange noises at night. I've got two guards on patrol, but...[pause 0.5] we're stretched thin.
> What happened to the caravans? -> caravan_detail
> Can I help? -> bounty_board
> Stay safe, Captain. -> farewell_short

# caravan_detail
@ Captain Aldric
Three caravans in the last month. No survivors, no wreckage — they just <i>vanish</i>. I've sent scouts, but they come back with nothing. Whatever's out there is smart.
> I'll look into it. -> bounty_board
> That's concerning. -> farewell_short

# bounty_board
@ Captain Aldric
Aye, I could use a capable hand. Here's what needs doing:
> Clear the wolves near the north road — 200 gold -> wolf_quest [set wolfQuestActive true]
> Investigate the missing caravans — 500 gold -> caravan_quest [set caravanQuestActive true]
> Scout the Whispering Caves — 300 gold -> cave_quest [set caveQuestActive true]
> I'll think about it. -> farewell_short

# wolf_quest [end]
@ Captain Aldric
Good. A pack of <b><font color='#888888'>Shadow Wolves</font></b> has been prowling the north road. Take them out and report back. <b><font color='#ffd700'>200 gold</font></b> on completion. Stay sharp.

# caravan_quest [end]
@ Captain Aldric
This one's dangerous. Follow the north road past the river fork. Look for tracks, debris, anything. <b><font color='#ffd700'>500 gold</font></b> when you return with answers. Don't become the next disappearance.

# cave_quest [end]
@ Captain Aldric
The Whispering Caves have been... active. Strange sounds echoing out at night. Go in, see what's stirring, come back alive. <b><font color='#ffd700'>300 gold</font></b> for a full report.

# pip_quest [set pipQuestActive true]
@ Captain Aldric
A child lost?! Damn — I told Maren we need to fence that pond. Where was Pip last seen?
> Near the pond, at the edge of the woods. -> pip_dispatch
> I'm not sure exactly. The Elder would know. -> pip_dispatch

# pip_dispatch [end] [set guardSentForPip true] [call showQuestUpdate]
@ Captain Aldric
I'm sending Guardsman Roth immediately. But you — you're closer to the south side. Check the pond and the forest edge. If you find Pip, bring them to safety. <b>GO!</b>

# pip_complete [end] [set pipSafe true] [set gold 300] [call playQuestComplete]
@ Captain Aldric
Thank the gods. You've done this village a great service, traveler. Here — <b><font color='#ffd700'>300 gold</font></b> and the gratitude of the Thornwood Guard. I won't forget this.

# thalindra_warning
@ Captain Aldric
Double the watch? If Thalindra says so, it must be serious. That woman doesn't scare easily.[pause 0.5] Consider it done. I'll pull guards from the south gate. Anything else?
> She mentioned silver weapons. -> silver_weapons
> That's all. Stay vigilant. -> farewell_short

# silver_weapons [end]
@ Captain Aldric
<b>Silver weapons?</b>[pause 0.5] That means she's expecting something <i>unnatural</i>. I'll talk to Brok about a rush order. Thank you for the warning, traveler. This could save lives.

# farewell_short [end]
@ Captain Aldric
Move along, traveler. Stay safe out there.
]])

--[[
    INNKEEPER MIRA — Tavern
    Features: [call] heal, Dark theme, rumors, multi-path
]]
local miraTree = DialogueParser.Parse([[
=== mira
start: greeting

# greeting
@ Innkeeper Mira
Evening, stranger! Welcome to <b>The Thorned Rose</b>. Best ale, warmest fire, and the only bed in fifty miles. What'll it be?
> I need a room for the night. -> room
> Got any food? I'm starving. -> food
> What's the local gossip? -> rumors
> I could use some healing. -> heal
> Just passing through. -> farewell

# room
@ Innkeeper Mira
One night, one bed, one gold. Cheapest you'll find anywhere. Includes breakfast — well, bread and cheese, but still.
> I'll take it. -> buy_room [if gold 1]
> Too rich for my blood. -> too_poor
> What about a hot bath? -> bath

# buy_room [end] [set gold -1] [set hasRested true] [call playRestSound]
@ Innkeeper Mira
Here's your key — room's upstairs, second on the left. Sleep well, traveler. I'll wake you at dawn.[pause 1] <b><font color='#88ff88'>HP fully restored! Status effects cleared.</font></b>

# bath
@ Innkeeper Mira
Oh, fancy! That'll be <b>5 gold</b> extra, but you'll feel like a new person. Hot springs water, piped in from the mountain.
> Worth every coin. -> buy_bath [if gold 5]
> I'll pass. -> room

# buy_bath [end] [set gold -5] [set hasRested true] [call playRestSound]
@ Innkeeper Mira
Towel's on the rack. Take your time — you've earned it.[pause 1] <b><font color='#88ff88'>HP fully restored! All buffs refreshed.</font></b>

# too_poor
@ Innkeeper Mira
*chuckles* No shame in that, love. Tell you what — help me clean some dishes and you can sleep in the common room for free.
> Deal! -> free_room [call playRestSound] [set hasRested true]
> I'll manage. -> farewell

# free_room [end]
@ Innkeeper Mira
That's the spirit! Bucket's in the kitchen. Sweet dreams, dishwasher.[pause 0.5] <b><font color='#88ff88'>HP restored.</font></b>

# food
@ Innkeeper Mira
Tonight's special: <b><font color='#ffaa44'>Thornwood Stew</font></b> — rabbit, root vegetables, secret spices. Fills you up and puts hair on your chest. 10 gold.
> One bowl, please! -> buy_stew [if gold 10]
> What else is on the menu? -> menu
> I'll eat later. -> greeting

# buy_stew [end] [set gold -10] [call playEatSound]
@ Innkeeper Mira
*slides over a steaming bowl* Careful, it's hot! Best stew in the region — don't let Brok tell you otherwise.[pause 0.5] <b><font color='#88ff88'>+20 Max HP for 1 hour!</font></b>

# menu
@ Innkeeper Mira
Besides the stew, I've got bread and cheese for <b>3 gold</b>, and honeycakes for <b>5 gold</b>. Nothing fancy, but it keeps you going.
> Bread and cheese, please. -> buy_bread [if gold 3] [set gold -3] [call playEatSound]
> Honeycakes! -> buy_honeycake [if gold 5] [set gold -5] [call playEatSound]
> I'll stick with the stew. -> buy_stew [if gold 10]
> On second thought, I'm fine. -> greeting

# buy_bread [end]
@ Innkeeper Mira
Fresh from this morning! Well... fresh-<i>ish</i>. Enjoy!

# buy_honeycake [end]
@ Innkeeper Mira
Ah, sweet tooth! These are made with real wildflower honey from the meadow. Enjoy, dear!

# rumors
@ Innkeeper Mira
*leans in conspiratorially*[pause 0.3] Well, you didn't hear this from me, but...
> Go on... -> rumor_1

# rumor_1
@ Innkeeper Mira
Brok's been forging weapons day and night — more than usual. Won't say who ordered them. And Thalindra hasn't left her tower in <i>three days</i>. Her crystal orders have tripled.
> What do you think it means? -> rumor_2
> Anything else? -> rumor_pip [if pipLost true]
> Interesting. Thanks. -> greeting

# rumor_2
@ Innkeeper Mira
I think they know something we don't. Something bad's coming.[pause 0.5] The old-timers talk about a creature called the <b><font color='#ff4444'>Thornback</font></b> — a beast that sleeps beneath the forest. They say it wakes every hundred years.[pause 0.8] This is year ninety-nine.
> That's terrifying. -> rumor_end
> Sounds like a fairy tale. -> rumor_end

# rumor_pip [if pipLost true]
@ Innkeeper Mira
Oh — and speaking of trouble, I heard little <b>Pip</b> wandered off again. That child will be the death of Elder Maren's nerves. Someone should tell <b>Captain Aldric</b>.
> I'm already on it. -> greeting
> Thanks for the tip. -> greeting

# rumor_end
@ Innkeeper Mira
Fairy tale or not, I'm keeping my axe behind the bar.[pause 0.3] <i>*pats something under the counter*</i> Now, can I get you anything else?
> Actually, yes. -> greeting
> I should go. -> farewell

# heal [call healPlayer]
@ Innkeeper Mira
You look rough, love. Here — sit down.[pause 0.5] *pours a glowing tonic*[pause 0.5] Drink this. Old family recipe — willow bark, moonpetal, and a pinch of something Thalindra gave me.[pause 1]
<b><font color='#88ff88'>HP fully restored!</font></b> On the house. Can't have travelers dying in my tavern — bad for business.
> Thank you, Mira. -> post_heal
> You're a lifesaver! -> post_heal

# post_heal
@ Innkeeper Mira
Don't mention it. Literally — if Aldric finds out I'm dispensing potions without a license, I'll never hear the end of it. Anything else?
> Actually, yes. -> greeting
> I should go. -> farewell

# farewell [end]
@ Innkeeper Mira
Safe travels! And remember — The Thorned Rose is always open. Mostly.
]])

--[[
    PIP — Lost Child near the Pond
    Features: auto-advance [auto 3], emotional pacing, quest chain, [pause]
]]
local pipTree = DialogueParser.Parse([[
=== pip
start: greeting

# greeting
@ Pip
*sniffle*[pause 0.5] H-hello...[pause 0.3] Are you a nice person?
> Of course! What's wrong? -> whats_wrong
> Are you okay, kid? -> whats_wrong
> ... -> whats_wrong

# whats_wrong [auto 5]
@ Pip
I...[pause 0.5] I was chasing a butterfly and...[pause 0.3] and it went into the trees and...[pause 0.8] now I don't know where I am![pause 0.5] I want to go home!

# crying [set pipLost true]
@ Pip
*sniffles*[pause 0.3] My name is Pip. I live in the village with Elder Maren. She's going to be SO mad at me...[pause 0.5] I'm not supposed to go past the pond.
> Don't worry, I'll help you get home. -> offer_help
> Do you know which way the village is? -> lost_direction
> Stay here — I'll go get Captain Aldric. -> get_aldric

# offer_help
@ Pip
R-really?[pause 0.3] You promise? You're not going to leave me here?
> I promise. Let's go. -> walk_home [set pipFound true] [call showQuestUpdate]
> Cross my heart. Come on. -> walk_home [set pipFound true] [call showQuestUpdate]

# lost_direction
@ Pip
I...[pause 0.3] I think it's that way?[pause 0.5] Or maybe that way...[pause 0.8] I don't know! Everything looks the same! The trees are all whispery and scary!
> It's okay. I'll take you home. -> walk_home [set pipFound true] [call showQuestUpdate]
> Let me go get help first. -> get_aldric

# get_aldric [end]
@ Pip
O-okay...[pause 0.5] but please hurry! It's getting dark and...[pause 0.3] and I heard something in the bushes...[pause 1] <i>*hugs knees and shivers*</i>

# walk_home [auto 4]
@ Pip
*grabs your hand tightly*[pause 0.5] Thank you, thank you, thank you! You're the nicest person ever![pause 0.8] Can we go fast? I don't like the woods when it's dark...

# arriving [end] [set pipSafe true] [call playQuestComplete]
@ Pip
*runs ahead*[pause 0.3] I can see the village![pause 0.5] ELDER MAREN! I'M HOME![pause 0.8]
*turns back and waves*[pause 0.3] Thank you, adventurer! You're my <b><font color='#ffd700'>hero</font></b>!
]])

------------------------------------------------------------------------
-- ENGINE SETUP
------------------------------------------------------------------------
local engine = DialogueEngine.new()

engine:RegisterTree("elder_maren", elderMarenTree)
engine:RegisterTree("brok", brokTree)
engine:RegisterTree("lira", liraTree)
engine:RegisterTree("thalindra", thalindraTree)
engine:RegisterTree("aldric", aldricTree)
engine:RegisterTree("mira", miraTree)
engine:RegisterTree("pip", pipTree)

-- Starting flags
engine:SetFlag("gold", 1000)
engine:SetFlag("pipLost", false)
engine:SetFlag("pipFound", false)
engine:SetFlag("pipSafe", false)
engine:SetFlag("pipQuestActive", false)
engine:SetFlag("elderSentToAldric", false)
engine:SetFlag("guardSentForPip", false)
engine:SetFlag("hasIronSword", false)
engine:SetFlag("hasSteelSword", false)
engine:SetFlag("hasEnchantedBlade", false)
engine:SetFlag("hasPotion", false)
engine:SetFlag("hasMap", false)
engine:SetFlag("hasLockpick", false)
engine:SetFlag("hasCompass", false)
engine:SetFlag("hasIronOre", false)
engine:SetFlag("hasRested", false)
engine:SetFlag("knowsMagic", false)
engine:SetFlag("thalindraQuestStarted", false)
engine:SetFlag("thalindraQuestActive", false)
engine:SetFlag("wolfQuestActive", false)
engine:SetFlag("caravanQuestActive", false)
engine:SetFlag("caveQuestActive", false)

-- Variable resolvers
engine:RegisterVariable(function(varName: string): any?
    if varName == "playerName" then return player.Name end
    return nil
end)

-- Actions
engine:RegisterAction("playForgeSound", function()
    print("[Action] *CLANG CLANG* Forge hammer sounds!")
end)

engine:RegisterAction("playBuySound", function()
    print("[Action] *ka-ching* Purchase sound!")
end)

engine:RegisterAction("playMagicSound", function()
    print("[Action] *WHOOSH* Magical energy crackles!")
end)

engine:RegisterAction("healPlayer", function()
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.Health = humanoid.MaxHealth
    end
    print("[Action] Player healed to full HP!")
end)

engine:RegisterAction("playRestSound", function()
    print("[Action] *peaceful music* Rest complete!")
end)

engine:RegisterAction("playEatSound", function()
    print("[Action] *munch munch* Food consumed!")
end)

engine:RegisterAction("showQuestUpdate", function()
    print("[Action] Quest updated!")
end)

engine:RegisterAction("playQuestComplete", function()
    print("[Action] Quest complete! Fanfare plays!")
end)

------------------------------------------------------------------------
-- NPC CONFIG
------------------------------------------------------------------------
local npcConfig = {
    ["Elder Maren"]       = { tree = "elder_maren", theme = Theme.Presets.Fantasy },
    ["Forge Master Brok"] = { tree = "brok" },
    ["Merchant Lira"]     = { tree = "lira", theme = Theme.Presets.Bubblegum },
    ["Sage Thalindra"]    = { tree = "thalindra", theme = Theme.Presets.Fantasy },
    ["Captain Aldric"]    = { tree = "aldric" },
    ["Innkeeper Mira"]    = { tree = "mira", theme = Theme.Presets.Dark },
    ["Pip"]               = { tree = "pip", theme = Theme.Presets.Bubblegum },
}

------------------------------------------------------------------------
-- NPC PROMPT SETUP
------------------------------------------------------------------------
local function setupNPCPrompt(npc: Model)
    local config = npcConfig[npc.Name]
    if not config then return end

    local head = npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart")
    if not head then
        warn("[TemplatePlace] NPC missing Head or HumanoidRootPart: " .. npc.Name)
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

    print("[TemplatePlace] Configured NPC:", npc.Name)
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

task.wait(3)
findNPCs()
print("[TemplatePlace] Thornwood Village loaded — 7 NPCs ready. Approach one to talk!")
