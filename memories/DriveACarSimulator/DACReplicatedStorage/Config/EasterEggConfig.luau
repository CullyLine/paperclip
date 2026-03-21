--!strict
--[[
	Hidden easter egg placements. imageId stays rbxassetid://0 until Bard assigns assets.
	At runtime, EasterEggService resolves textures via imageKey → ReplicatedStorage.Images.<name>.
]]

export type DisplayType = "poster" | "framed" | "billboard" | "decal"

export type EasterEggPlacement = {
	id: string,
	worldId: "grasslands" | "desert" | "frozen" | "neon",
	-- Offset from Workspace.Worlds.<world> model pivot (studs).
	position: Vector3,
	-- Degrees; applied as X/Y/Z Euler on top of placement CFrame.
	rotation: Vector3,
	-- Display pixel-ish size (billboard/gui) or stud width/height for parts.
	size: Vector2,
	displayType: DisplayType,
	description: string,
	-- Placeholder until Bard fills real rbxassetid URLs.
	imageId: string,
	-- Child name under ReplicatedStorage.Images (Decal / ImageLabel / ImageButton).
	imageKey: string?,
	-- e.g. "ReplicatedStorage.Images.SomeDecalName" — resolved at runtime.
	imageSource: string?,
	hint: string?,
	rarity: ("common" | "hidden" | "secret")?,
}

export type GalleryFrame = {
	id: string,
	-- Position inside the gallery room model's local space (center = room center).
	localPosition: Vector3,
	rotation: Vector3,
	size: Vector2,
	displayType: DisplayType,
	description: string,
	imageId: string,
	imageKey: string?,
	imageSource: string?,
	hint: string?,
	rarity: ("common" | "hidden" | "secret")?,
}

export type GalleryRoomConfig = {
	-- World-space position for the hidden gallery (far from main highway).
	centerPosition: Vector3,
	interiorSize: Vector3,
	frames: { GalleryFrame },
}

local EasterEggConfig = {}

-- 5 slots per world (20 total) + gallery frames below.
-- imageKey/imageSource stay nil until Board provides the ReplicatedStorage.Images catalog.
-- Hints and rarity tiers assigned by Bard (POLA-66).
EasterEggConfig.Placements = {
	-- ── Grasslands ──────────────────────────────────────────────
	-- Theme: "Welcome home" — warm, nostalgic. First world = friendly secrets.
	{
		id = "grass_1",
		worldId = "grasslands",
		position = Vector3.new(-120, 18, -2800),
		rotation = Vector3.new(0, 15, 0),
		size = Vector2.new(180, 120),
		displayType = "poster",
		description = "Off-road poster at the first bend — founding-era logo or studio branding",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "The founders signed their first road. Look left at the bend.",
		rarity = "common",
	},
	{
		id = "grass_2",
		worldId = "grasslands",
		position = Vector3.new(85, 6, -4200),
		rotation = Vector3.new(0, -110, 0),
		size = Vector2.new(120, 80),
		displayType = "framed",
		description = "Tiny framed portrait on a roadside barrier — character avatar",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "Someone left a photo on the guardrail. Were they here first?",
		rarity = "hidden",
	},
	{
		id = "grass_3",
		worldId = "grasslands",
		position = Vector3.new(-40, 3, -1800),
		rotation = Vector3.new(0, 90, 0),
		size = Vector2.new(200, 80),
		displayType = "decal",
		description = "Low shoulder-wall decal — meme or in-joke, only visible at walking speed",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "The road remembers everything. Even the jokes.",
		rarity = "secret",
	},
	{
		id = "grass_4",
		worldId = "grasslands",
		position = Vector3.new(200, 35, -3600),
		rotation = Vector3.new(0, 0, 0),
		size = Vector2.new(160, 100),
		displayType = "billboard",
		description = "Floating billboard above the treeline — landscape or scenic art",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "Look up past the trees. Someone hung a memory in the sky.",
		rarity = "common",
	},
	{
		id = "grass_5",
		worldId = "grasslands",
		position = Vector3.new(-95, 12, -900),
		rotation = Vector3.new(0, 45, 0),
		size = Vector2.new(100, 100),
		displayType = "poster",
		description = "Poster behind a start-area outcrop — abstract or artistic piece",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "Before you drive forward, check what's behind you.",
		rarity = "hidden",
	},
	-- ── Scorching Desert ────────────────────────────────────────
	-- Theme: "Lost and found" — sun-bleached, abandoned, left in the sand long ago.
	{
		id = "desert_1",
		worldId = "desert",
		position = Vector3.new(140, 22, -3100),
		rotation = Vector3.new(0, -25, 0),
		size = Vector2.new(220, 140),
		displayType = "billboard",
		description = "Distant mirage-like billboard — promo splash or game thumbnail",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "Is that a mirage, or did someone leave a sign in the sand?",
		rarity = "common",
	},
	{
		id = "desert_2",
		worldId = "desert",
		position = Vector3.new(-60, 8, -5200),
		rotation = Vector3.new(0, 170, 0),
		size = Vector2.new(140, 90),
		displayType = "poster",
		description = "Sun-bleached rock-face poster — character or avatar portrait",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "The desert keeps secrets on its stones.",
		rarity = "hidden",
	},
	{
		id = "desert_3",
		worldId = "desert",
		position = Vector3.new(30, 4, -4100),
		rotation = Vector3.new(0, 90, 0),
		size = Vector2.new(180, 60),
		displayType = "decal",
		description = "Ground-level concrete divider decal — logo or watermark",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "Watch your wheels. The road has marks older than the map.",
		rarity = "hidden",
	},
	{
		id = "desert_4",
		worldId = "desert",
		position = Vector3.new(-200, 14, -2800),
		rotation = Vector3.new(0, 0, 0),
		size = Vector2.new(110, 110),
		displayType = "framed",
		description = "Framed piece on a rusted panel far off-highway — personal/sentimental",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "Someone framed a memory and left it where no one would look.",
		rarity = "secret",
	},
	{
		id = "desert_5",
		worldId = "desert",
		position = Vector3.new(75, 40, -6000),
		rotation = Vector3.new(0, 0, 0),
		size = Vector2.new(200, 120),
		displayType = "billboard",
		description = "High billboard past the dunes — landscape or scene render",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "Past the last dune, the sky tells a story.",
		rarity = "common",
	},
	-- ── Frozen Tundra ───────────────────────────────────────────
	-- Theme: "Frozen in time" — preserved, crystallized, trapped in ice.
	{
		id = "frozen_1",
		worldId = "frozen",
		position = Vector3.new(-110, 20, -4500),
		rotation = Vector3.new(0, 55, 0),
		size = Vector2.new(160, 100),
		displayType = "poster",
		description = "Icy cliff poster — splash image or old game thumbnail",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "The ice preserves what it catches. Even art.",
		rarity = "hidden",
	},
	{
		id = "frozen_2",
		worldId = "frozen",
		position = Vector3.new(90, 6, -2200),
		rotation = Vector3.new(0, -90, 0),
		size = Vector2.new(130, 85),
		displayType = "framed",
		description = "Guard rail column frame — character portrait, elegant like a locket",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "A portrait guards the rail. It's been here since the first frost.",
		rarity = "common",
	},
	{
		id = "frozen_3",
		worldId = "frozen",
		position = Vector3.new(0, 3, -5800),
		rotation = Vector3.new(0, 0, 0),
		size = Vector2.new(240, 70),
		displayType = "decal",
		description = "Frozen asphalt decal strip — meme or in-joke, invisible at speed",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "The asphalt has a confession. You have to stop to hear it.",
		rarity = "secret",
	},
	{
		id = "frozen_4",
		worldId = "frozen",
		position = Vector3.new(160, 32, -7000),
		rotation = Vector3.new(0, 0, 0),
		size = Vector2.new(150, 100),
		displayType = "billboard",
		description = "Billboard over blue overpass — studio branding or logo",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "Above the overpass, neon meets ice.",
		rarity = "common",
	},
	{
		id = "frozen_5",
		worldId = "frozen",
		position = Vector3.new(-70, 12, -3400),
		rotation = Vector3.new(0, 125, 0),
		size = Vector2.new(100, 100),
		displayType = "poster",
		description = "Poster behind an ice shelf — abstract or artistic piece",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "Behind the ice, where the wind doesn't reach, there's color.",
		rarity = "hidden",
	},
	-- ── Neon City ───────────────────────────────────────────────
	-- Theme: "Digital graffiti" — cyberpunk ads, glowing street art.
	{
		id = "neon_1",
		worldId = "neon",
		position = Vector3.new(130, 28, -5000),
		rotation = Vector3.new(0, -15, 0),
		size = Vector2.new(240, 140),
		displayType = "billboard",
		description = "Neon skyline billboard — promo image or flashy splash art (largest in game)",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "The biggest screen in the city has the oldest memory.",
		rarity = "common",
	},
	{
		id = "neon_2",
		worldId = "neon",
		position = Vector3.new(-90, 10, -3200),
		rotation = Vector3.new(0, 90, 0),
		size = Vector2.new(150, 95),
		displayType = "poster",
		description = "Alleyway poster on a side building — character or OC art",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "Turn off the highway. The alleys have stories the road doesn't tell.",
		rarity = "hidden",
	},
	{
		id = "neon_3",
		worldId = "neon",
		position = Vector3.new(40, 5, -8100),
		rotation = Vector3.new(0, 0, 0),
		size = Vector2.new(200, 80),
		displayType = "decal",
		description = "Street-level lane divider decal — logo or abstract art",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "The city writes on its own streets. Read between the lanes.",
		rarity = "hidden",
	},
	{
		id = "neon_4",
		worldId = "neon",
		position = Vector3.new(-150, 16, -6400),
		rotation = Vector3.new(0, 180, 0),
		size = Vector2.new(120, 120),
		displayType = "framed",
		description = "Framed art in a rooftop nook — most personal image (hardest to find)",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "The rooftops know. Only the ones who climb will see.",
		rarity = "secret",
	},
	{
		id = "neon_5",
		worldId = "neon",
		position = Vector3.new(200, 45, -9000),
		rotation = Vector3.new(0, 0, 0),
		size = Vector2.new(260, 130),
		displayType = "billboard",
		description = "Mega billboard at the far arc — landscape or scenic piece at massive scale",
		imageId = "rbxassetid://0",
		imageKey = nil,
		hint = "At the end of the arc, the city dreams in color.",
		rarity = "common",
	},
} :: { EasterEggPlacement }

-- Loading screen splash images from the Board's ReplicatedStorage.Images library.
-- Board to provide 3-4 rbxassetid:// IDs: one landscape/scene, one logo/branding,
-- one character/avatar, one artistic/abstract. Prioritise high-res, landscape-oriented.
EasterEggConfig.LoadingScreenImages = {
	-- Slot 1: Landscape/Scene — sets visual tone before gameplay loads
	-- Slot 2: Logo/Branding — establishes studio identity
	-- Slot 3: Character/Avatar — makes it feel personal
	-- Slot 4: Artistic/Abstract — eye candy while waiting
}

EasterEggConfig.SecretGallery = {
	enabled = true,
	worldId = "neon",
	centerPosition = Vector3.new(24000, 400, 12000),
	interiorSize = Vector3.new(36, 10, 28),
	frames = {
		{
			id = "gallery_north",
			localPosition = Vector3.new(0, 0, -13),
			rotation = Vector3.new(0, 0, 0),
			size = Vector2.new(160, 100),
			displayType = "framed",
			description = "North wall — founder collage: the most iconic Board/Stylxus image",
			imageId = "rbxassetid://0",
			imageKey = nil,
			hint = "The centerpiece. The one that started it all.",
			rarity = "secret",
		},
		{
			id = "gallery_south",
			localPosition = Vector3.new(0, 0, 13),
			rotation = Vector3.new(0, 180, 0),
			size = Vector2.new(160, 100),
			displayType = "framed",
			description = "South wall — Stylxus tribute: a Stylxus-created or joint Board+Stylxus piece",
			imageId = "rbxassetid://0",
			imageKey = nil,
			hint = "Turn around. The partnership hangs behind you.",
			rarity = "secret",
		},
		{
			id = "gallery_east",
			localPosition = Vector3.new(17, 0, 0),
			rotation = Vector3.new(0, 90, 0),
			size = Vector2.new(140, 90),
			displayType = "framed",
			description = "East wall — legacy splash: old game thumbnail or promo from a past project",
			imageId = "rbxassetid://0",
			imageKey = nil,
			hint = "Remember when? The older, the better.",
			rarity = "secret",
		},
		{
			id = "gallery_west",
			localPosition = Vector3.new(-17, 0, 0),
			rotation = Vector3.new(0, -90, 0),
			size = Vector2.new(140, 90),
			displayType = "framed",
			description = "West wall — studio in-joke: the funniest image in the library",
			imageId = "rbxassetid://0",
			imageKey = nil,
			hint = "Only the team gets this one.",
			rarity = "secret",
		},
	},
}

return EasterEggConfig
