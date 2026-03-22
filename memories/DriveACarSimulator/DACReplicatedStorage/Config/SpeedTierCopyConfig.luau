--!strict
--[[
	Speed tier HUD copy, acceleration callouts, and pet unequip flavor.
	UI picks a random entry at runtime per category.
]]

local SpeedTierCopyConfig = {}

--------------------------------------------------------------------------
-- SPEED TIER DISPLAY NAMES
-- Color-coded label beside the speedometer. 1-2 words, ALL CAPS.
-- 3 alternatives per tier; UI picks one at session start or randomly.
--------------------------------------------------------------------------

SpeedTierCopyConfig.TierNames = {
	-- 0-50 studs/s
	Cruising = {
		"CRUISING",
		"ROLLING",
		"EASY RIDE",
	},
	-- 50-100
	Fast = {
		"FAST!",
		"MOVING!",
		"PICKING UP!",
	},
	-- 100-200
	Blazing = {
		"BLAZING!",
		"ON FIRE!",
		"SCORCHING!",
	},
	-- 200-300
	Insane = {
		"INSANE!",
		"UNREAL!",
		"BERSERK!",
	},
	-- 300+
	Legendary = {
		"LEGENDARY!",
		"GODSPEED!",
		"MYTHIC!",
	},
}

SpeedTierCopyConfig.TierThresholds = {
	{ min = 0,   key = "Cruising"  },
	{ min = 50,  key = "Fast"      },
	{ min = 100, key = "Blazing"   },
	{ min = 200, key = "Insane"    },
	{ min = 300, key = "Legendary" },
}

--------------------------------------------------------------------------
-- ACCELERATION CALLOUTS
-- Brief text flash on sudden hard acceleration. Max 12 characters each.
--------------------------------------------------------------------------

SpeedTierCopyConfig.AccelerationCallouts = {
	"LAUNCH!",
	"TURBO!",
	"FLOOR IT!",
	"PUNCH IT!",
	"BOOST!",
	"FULL SEND!",
	"NITRO!",
	"BLAST OFF!",
	"ENGAGE!",
	"OVERDRIVE!",
}

--------------------------------------------------------------------------
-- PET UNEQUIP FAREWELL
-- Short line the pet "says" when unequipped. Cute, max 20 characters.
--------------------------------------------------------------------------

SpeedTierCopyConfig.PetUnequipFarewell = {
	"See ya later!",
	"I'll be here!",
	"Miss you already!",
	"Bring me back soon!",
	"Take care out there!",
	"Nap time for me!",
	"Go get 'em!",
	"I'll keep warm!",
}

return SpeedTierCopyConfig
