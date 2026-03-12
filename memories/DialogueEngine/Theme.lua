--[[
    Theme.lua
    Built-in themes and merge utility for the Dialogue Engine.

    Usage:
      DialogueEngine.new()                          -- uses "Dark" (default)
      DialogueEngine.new(Theme.Presets.Fantasy)      -- use a preset
      DialogueEngine.new({ textSize = 22 })          -- override individual fields
      DialogueEngine.new(Theme.Extend("Bubblegum", { textSize = 22 }))
                                                     -- preset + overrides
]]

local Types = require(script.Parent.Types)
type ThemeConfig = Types.ThemeConfig

local Theme = {}

local DEFAULT_THEME = {
    backgroundColor = Color3.fromRGB(15, 15, 25),
    backgroundTransparency = 0.15,
    textColor = Color3.fromRGB(230, 230, 240),
    speakerColor = Color3.fromRGB(255, 200, 80),
    choiceColor = Color3.fromRGB(35, 35, 55),
    choiceHoverColor = Color3.fromRGB(60, 60, 100),
    choiceHighlightColor = Color3.fromRGB(80, 80, 140),
    choiceTextColor = Color3.fromRGB(200, 200, 220),
    choiceUnavailableColor = Color3.fromRGB(80, 80, 80),
    font = Enum.Font.GothamMedium,
    speakerFont = Enum.Font.GothamBold,
    textSize = 18,
    speakerTextSize = 20,
    choiceTextSize = 16,
    cornerRadius = UDim.new(0, 8),
    portraitSize = UDim2.new(0, 100, 0, 100),
    dialogueBoxSize = UDim2.new(0.8, 0, 0, 180),
    dialogueBoxPosition = UDim2.new(0.1, 0, 1, -200),
    typewriterSpeed = 0.03,
    voiceVolume = 1,
    padding = UDim.new(0, 12),
    animationSpeed = 1,
    sfxVolume = 1,
    openSoundId = nil,
    closeSoundId = nil,
    typewriterSoundId = nil,
    typewriterSoundPitch = 0.1,
    choiceHoverSoundId = nil,
    choiceSelectSoundId = nil,
}

------------------------------------------------------------------------
-- Presets
------------------------------------------------------------------------

Theme.Presets = {
    -- "Dark" — the default. Sleek dark UI for anime RPGs and action games.
    Dark = {},

    -- "Fantasy" — warm parchment tones with serif-style fonts. Great for
    -- medieval, adventure, and classic RPG settings.
    Fantasy = {
        backgroundColor = Color3.fromRGB(42, 30, 18),
        backgroundTransparency = 0.1,
        textColor = Color3.fromRGB(240, 225, 195),
        speakerColor = Color3.fromRGB(255, 185, 50),
        choiceColor = Color3.fromRGB(60, 42, 25),
        choiceHoverColor = Color3.fromRGB(90, 65, 35),
        choiceHighlightColor = Color3.fromRGB(120, 85, 40),
        choiceTextColor = Color3.fromRGB(230, 215, 180),
        choiceUnavailableColor = Color3.fromRGB(100, 85, 65),
        font = Enum.Font.Merriweather,
        speakerFont = Enum.Font.Merriweather,
        textSize = 18,
        speakerTextSize = 22,
        choiceTextSize = 16,
        cornerRadius = UDim.new(0, 4),
        typewriterSpeed = 0.04,
    },

    -- "Sci-Fi" — neon cyan accents on a deep dark background. Fits
    -- cyberpunk, space, and futuristic game aesthetics.
    SciFi = {
        backgroundColor = Color3.fromRGB(8, 12, 20),
        backgroundTransparency = 0.1,
        textColor = Color3.fromRGB(200, 230, 255),
        speakerColor = Color3.fromRGB(0, 220, 255),
        choiceColor = Color3.fromRGB(15, 30, 50),
        choiceHoverColor = Color3.fromRGB(20, 60, 90),
        choiceHighlightColor = Color3.fromRGB(0, 100, 140),
        choiceTextColor = Color3.fromRGB(180, 220, 255),
        choiceUnavailableColor = Color3.fromRGB(50, 60, 70),
        font = Enum.Font.Ubuntu,
        speakerFont = Enum.Font.Ubuntu,
        textSize = 17,
        speakerTextSize = 20,
        choiceTextSize = 15,
        cornerRadius = UDim.new(0, 2),
        typewriterSpeed = 0.015,
    },

    -- "Bubblegum" — bright, playful pastels. Perfect for tycoons, simulators,
    -- and kid-friendly games.
    Bubblegum = {
        backgroundColor = Color3.fromRGB(255, 230, 245),
        backgroundTransparency = 0.05,
        textColor = Color3.fromRGB(60, 30, 60),
        speakerColor = Color3.fromRGB(220, 50, 160),
        choiceColor = Color3.fromRGB(255, 200, 230),
        choiceHoverColor = Color3.fromRGB(255, 170, 210),
        choiceHighlightColor = Color3.fromRGB(255, 140, 200),
        choiceTextColor = Color3.fromRGB(80, 30, 80),
        choiceUnavailableColor = Color3.fromRGB(200, 180, 190),
        font = Enum.Font.FredokaOne,
        speakerFont = Enum.Font.FredokaOne,
        textSize = 20,
        speakerTextSize = 24,
        choiceTextSize = 18,
        cornerRadius = UDim.new(0, 16),
        typewriterSpeed = 0.025,
    },

    -- "Horror" — blood-red accents on near-black. Slow typewriter for tension.
    -- Designed for horror, survival, and thriller games.
    Horror = {
        backgroundColor = Color3.fromRGB(10, 5, 5),
        backgroundTransparency = 0.05,
        textColor = Color3.fromRGB(180, 170, 160),
        speakerColor = Color3.fromRGB(180, 30, 30),
        choiceColor = Color3.fromRGB(25, 10, 10),
        choiceHoverColor = Color3.fromRGB(50, 15, 15),
        choiceHighlightColor = Color3.fromRGB(80, 20, 20),
        choiceTextColor = Color3.fromRGB(170, 150, 140),
        choiceUnavailableColor = Color3.fromRGB(60, 50, 50),
        font = Enum.Font.Antique,
        speakerFont = Enum.Font.Antique,
        textSize = 18,
        speakerTextSize = 20,
        choiceTextSize = 16,
        cornerRadius = UDim.new(0, 0),
        typewriterSpeed = 0.06,
    },
}

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------

function Theme.GetDefault(): ThemeConfig
    local copy = {}
    for k, v in pairs(DEFAULT_THEME) do
        copy[k] = v
    end
    return copy
end

function Theme.Merge(overrides: { [string]: any }?): ThemeConfig
    local theme = Theme.GetDefault()
    if overrides then
        for k, v in pairs(overrides) do
            theme[k] = v
        end
    end
    return theme
end

function Theme.Extend(presetName: string, overrides: { [string]: any }?): { [string]: any }
    local preset = Theme.Presets[presetName]
    if not preset then
        warn("[DialogueEngine] Unknown theme preset: " .. tostring(presetName) .. ". Using default.")
        preset = {}
    end

    local combined = Theme.GetDefault()
    for k, v in pairs(preset) do
        combined[k] = v
    end
    if overrides then
        for k, v in pairs(overrides) do
            combined[k] = v
        end
    end
    return combined
end

return Theme
