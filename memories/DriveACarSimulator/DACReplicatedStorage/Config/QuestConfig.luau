--!strict
--[[
	Battle pass quest definitions (Season 1). objectiveType drives QuestService reporters.
	scope: daily | weekly | season (milestone)
]]

local QuestConfig = {}

QuestConfig.DailyPool = {
	{
		id = "d_drive_10k",
		title = "Morning Commute",
		objectiveType = "distance_driven",
		target = 10_000,
		xpReward = 50,
		scope = "daily",
	},
	{
		id = "d_laps_3",
		title = "Lap It Up",
		objectiveType = "laps_completed",
		target = 3,
		xpReward = 50,
		scope = "daily",
	},
	{
		id = "d_hatch_2",
		title = "Egg Dash",
		objectiveType = "eggs_hatched",
		target = 2,
		xpReward = 50,
		scope = "daily",
	},
	{
		id = "d_coins_25k",
		title = "Big Earner",
		objectiveType = "coins_single_run",
		target = 25_000,
		xpReward = 50,
		scope = "daily",
	},
	{
		id = "d_worlds_2",
		title = "Tourist",
		objectiveType = "worlds_unique_day",
		target = 2,
		xpReward = 50,
		scope = "daily",
	},
	{
		id = "d_pet_equip",
		title = "New Partner",
		objectiveType = "pet_equip_unique",
		target = 1,
		xpReward = 50,
		scope = "daily",
	},
	{
		id = "d_rebirth_1",
		title = "Fresh Start",
		objectiveType = "rebirths",
		target = 1,
		xpReward = 50,
		scope = "daily",
	},
	{
		id = "d_upgrade_5",
		title = "Tune-Up",
		objectiveType = "upgrades",
		target = 5,
		xpReward = 50,
		scope = "daily",
	},
	{
		id = "d_desert_5k",
		title = "Desert Run",
		objectiveType = "distance_in_world",
		target = 5_000,
		xpReward = 50,
		scope = "daily",
		worldId = "desert",
	},
	{
		id = "d_drive_5k",
		title = "Quick Spin",
		objectiveType = "distance_driven",
		target = 5_000,
		xpReward = 50,
		scope = "daily",
	},
	{
		id = "d_laps_1",
		title = "Single Lap",
		objectiveType = "laps_completed",
		target = 1,
		xpReward = 50,
		scope = "daily",
	},
	{
		id = "d_coins_10k",
		title = "Solid Run",
		objectiveType = "coins_single_run",
		target = 10_000,
		xpReward = 50,
		scope = "daily",
	},
}

QuestConfig.WeeklyPool = {
	{
		id = "w_drive_100k",
		title = "Weekly Marathon",
		objectiveType = "distance_driven",
		target = 100_000,
		xpReward = 200,
		scope = "weekly",
	},
	{
		id = "w_hatch_15",
		title = "Hatch Week",
		objectiveType = "eggs_hatched",
		target = 15,
		xpReward = 200,
		scope = "weekly",
	},
	{
		id = "w_coins_500k",
		title = "Half-Million Hustle",
		objectiveType = "coins_earned_week",
		target = 500_000,
		xpReward = 200,
		scope = "weekly",
	},
	{
		id = "w_rebirth_5",
		title = "Rebirth Rush",
		objectiveType = "rebirths",
		target = 5,
		xpReward = 200,
		scope = "weekly",
	},
	{
		id = "w_laps_50",
		title = "Lap Legend",
		objectiveType = "laps_completed",
		target = 50,
		xpReward = 200,
		scope = "weekly",
	},
	{
		id = "w_worlds_4",
		title = "World Tour",
		objectiveType = "worlds_unique_week",
		target = 4,
		xpReward = 200,
		scope = "weekly",
	},
}

QuestConfig.Milestones = {
	{
		id = "m_first_run",
		title = "First Midnight Run",
		objectiveType = "season_runs",
		target = 1,
		xpReward = 250,
		scope = "season",
		minTier = 1,
	},
	{
		id = "m_night_owl",
		title = "Night Owl",
		objectiveType = "unique_days",
		target = 5,
		xpReward = 250,
		scope = "season",
		minTier = 5,
	},
	{
		id = "m_speed_demon",
		title = "Speed Demon",
		objectiveType = "distance_driven",
		target = 50_000,
		xpReward = 250,
		scope = "season",
		minTier = 10,
	},
	{
		id = "m_egg_collector",
		title = "Egg Collector",
		objectiveType = "eggs_hatched",
		target = 25,
		xpReward = 250,
		scope = "season",
		minTier = 15,
	},
	{
		id = "m_road_warrior",
		title = "Road Warrior",
		objectiveType = "laps_completed",
		target = 100,
		xpReward = 250,
		scope = "season",
		minTier = 20,
	},
	{
		id = "m_rebirth_master",
		title = "Rebirth Master",
		objectiveType = "rebirths",
		target = 10,
		xpReward = 250,
		scope = "season",
		minTier = 25,
	},
	{
		id = "m_world_traveler",
		title = "World Traveler",
		objectiveType = "worlds_coins_one_day",
		target = 3,
		xpReward = 250,
		scope = "season",
		minTier = 20,
	},
	{
		id = "m_pet_army",
		title = "Pet Army",
		objectiveType = "pets_equipped",
		target = 8,
		xpReward = 250,
		scope = "season",
		minTier = 10,
	},
	{
		id = "m_coin_collector",
		title = "Coin Collector",
		objectiveType = "coins_earned_season",
		target = 2_000_000,
		xpReward = 250,
		scope = "season",
		minTier = 30,
	},
	{
		id = "m_midnight_legend",
		title = "Midnight Legend",
		objectiveType = "all_milestones",
		target = 1,
		xpReward = 250,
		scope = "season",
		minTier = 1,
	},
}

function QuestConfig.getById(id: string): any
	for _, q in QuestConfig.DailyPool do
		if q.id == id then
			return q
		end
	end
	for _, q in QuestConfig.WeeklyPool do
		if q.id == id then
			return q
		end
	end
	for _, q in QuestConfig.Milestones do
		if q.id == id then
			return q
		end
	end
	return nil
end

return QuestConfig
