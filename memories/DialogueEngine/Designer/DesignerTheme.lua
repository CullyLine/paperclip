local Theme = {}

Theme.Colors = {
	Background      = Color3.fromRGB(30, 30, 30),
	Canvas          = Color3.fromRGB(22, 22, 26),
	GridDot         = Color3.fromRGB(44, 44, 48),

	NodeBg          = Color3.fromRGB(42, 42, 46),
	NodeBorder      = Color3.fromRGB(62, 62, 68),
	NodeSelected    = Color3.fromRGB(0, 120, 215),
	HeaderNormal    = Color3.fromRGB(55, 55, 62),
	HeaderStart     = Color3.fromRGB(40, 130, 55),
	HeaderEnd       = Color3.fromRGB(170, 45, 45),

	Text            = Color3.fromRGB(220, 220, 225),
	TextDim         = Color3.fromRGB(130, 130, 140),
	TextHeader      = Color3.fromRGB(255, 255, 255),
	TextPlaceholder = Color3.fromRGB(80, 80, 85),

	ConnNormal      = Color3.fromRGB(160, 160, 170),
	ConnConditional = Color3.fromRGB(230, 185, 50),
	ConnAction      = Color3.fromRGB(50, 170, 220),
	ConnDragging    = Color3.fromRGB(100, 200, 255),

	ChoiceDot       = Color3.fromRGB(90, 180, 255),
	InputDot        = Color3.fromRGB(90, 220, 110),

	Toolbar         = Color3.fromRGB(38, 38, 42),
	BtnNormal       = Color3.fromRGB(52, 52, 58),
	BtnHover        = Color3.fromRGB(68, 68, 76),
	BtnPress        = Color3.fromRGB(0, 100, 180),
	BtnDanger       = Color3.fromRGB(180, 50, 50),

	Panel           = Color3.fromRGB(32, 32, 36),
	Field           = Color3.fromRGB(48, 48, 54),
	FieldBorder     = Color3.fromRGB(62, 62, 68),

	StatusBar       = Color3.fromRGB(0, 120, 215),
	Accent          = Color3.fromRGB(0, 120, 215),
	Danger          = Color3.fromRGB(200, 55, 55),
	Success         = Color3.fromRGB(55, 175, 75),
}

Theme.Fonts = {
	Default = Enum.Font.SourceSans,
	Bold    = Enum.Font.SourceSansBold,
	Mono    = Enum.Font.Code,
}

Theme.Sizes = {
	NodeWidth       = 200,
	NodeMinHeight   = 80,
	HeaderHeight    = 26,
	NodeCorner      = UDim.new(0, 6),
	DotRadius       = 6,
	ConnThickness   = 2,

	ToolbarHeight   = 34,
	BtnHeight       = 26,
	BtnPadding      = 4,

	PanelWidth      = 280,
	FieldHeight     = 26,
	FieldPadding    = 6,

	StatusHeight    = 22,

	Text            = 14,
	HeaderText      = 13,
	SmallText       = 12,

	CanvasSize      = 6000,
	GridSpacing     = 60,
}

return Theme
