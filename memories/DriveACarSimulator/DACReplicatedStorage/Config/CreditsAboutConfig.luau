--!strict
--[[
	Player-facing About / Credits copy (POLA-735).
	Canonical definitions: docs/POLA735_CreditsAndAboutCopyPass.md §3 — keep in sync.
]]

local CreditsAboutConfig = {}

CreditsAboutConfig.SECTION_ABOUT = "About"
CreditsAboutConfig.SECTION_CREDITS = "Credits"

CreditsAboutConfig.ABOUT_BODY =
	"Drive a Car Simulator is a Roblox driving experience: collect cars and pets, race laps, and push your speed. Thank you for playing!"

CreditsAboutConfig.CREDITS_BODY =
	"UI uses Roblox Gotham fonts. Music and sounds use Roblox-uploaded and Roblox Library audio set in our game; some world and driving sounds may be updated as we finalize our audio list. Cars, pets, eggs, and worlds are built for this experience. No third-party Luau packages are bundled in our open project files. For a longer store-style credits blurb, see the game description."

CreditsAboutConfig.VERSION_LABEL_PREFIX = "Build"

return CreditsAboutConfig
