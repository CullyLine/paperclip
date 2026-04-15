local Studio = settings().Studio

local Theme = {}

function Theme.get()
	local theme = Studio.Theme
	local isDark = theme.Name == "Dark"

	return {
		IsDark = isDark,

		Colors = {
			Background      = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
			Surface         = theme:GetColor(Enum.StudioStyleGuideColor.InputFieldBackground),
			Border          = theme:GetColor(Enum.StudioStyleGuideColor.Border),
			Text            = theme:GetColor(Enum.StudioStyleGuideColor.MainText),
			TextDim         = theme:GetColor(Enum.StudioStyleGuideColor.DimmedText),
			TextBright      = theme:GetColor(Enum.StudioStyleGuideColor.BrightText),
			ButtonNormal    = theme:GetColor(Enum.StudioStyleGuideColor.Button),
			ButtonHover     = theme:GetColor(Enum.StudioStyleGuideColor.Button, Enum.StudioStyleGuideModifier.Hover),
			ButtonPressed   = theme:GetColor(Enum.StudioStyleGuideColor.Button, Enum.StudioStyleGuideModifier.Pressed),
			ButtonSelected  = theme:GetColor(Enum.StudioStyleGuideColor.Button, Enum.StudioStyleGuideModifier.Selected),
			ScrollBar       = theme:GetColor(Enum.StudioStyleGuideColor.ScrollBar),
			Separator       = theme:GetColor(Enum.StudioStyleGuideColor.Separator),
			Accent          = Color3.fromRGB(0, 162, 255),
			Positive        = Color3.fromRGB(60, 180, 75),
			Negative        = Color3.fromRGB(220, 60, 60),
			Warning         = Color3.fromRGB(240, 180, 40),
			TagDefault      = Color3.fromRGB(100, 140, 200),
		},

		Sizes = {
			ToolbarHeight  = 36,
			TagBarHeight   = 30,
			StatusHeight   = 24,
			ButtonSize     = 28,
			IconSize       = 18,
			Padding        = 6,
			CornerRadius   = UDim.new(0, 6),
			SmallCorner    = UDim.new(0, 4),
			FontSizeNormal = 14,
			FontSizeSmall  = 12,
			FontSizeLarge  = 16,
		},

		Fonts = {
			Default = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular),
			Bold    = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
			Semi    = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
		},
	}
end

return Theme
