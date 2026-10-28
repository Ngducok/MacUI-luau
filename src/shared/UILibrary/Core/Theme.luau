local FAMILY = "rbxasset://fonts/families/Roboto.json"

local Theme = {}

Theme.Fonts = {
	Regular = Font.new(FAMILY, Enum.FontWeight.Regular),
	Medium = Font.new(FAMILY, Enum.FontWeight.Medium),
	-- ponytail: bundled Roboto resolves 600 to a nearby face; upload a family for exact SemiBold.
	SemiBold = Font.new(FAMILY, Enum.FontWeight.SemiBold),
}

Theme.TextSize = { Body = 13, Small = 12, Title = 18, Section = 13 }

Theme.Typography = {
	WindowTitle = { FontFace = Theme.Fonts.SemiBold, TextSize = 18 },
	Navigation = { FontFace = Theme.Fonts.Medium, TextSize = 14 },
	Feature = { FontFace = Theme.Fonts.Medium, TextSize = 14 },
	Section = { FontFace = Theme.Fonts.Medium, TextSize = 13 },
	Control = { FontFace = Theme.Fonts.Regular, TextSize = 13 },
	Description = { FontFace = Theme.Fonts.Regular, TextSize = 12 },
	Hint = { FontFace = Theme.Fonts.Medium, TextSize = 11 },
	Search = { FontFace = Theme.Fonts.Regular, TextSize = 14 },
}

Theme.Motion = {
	Hover = 0.12,
	Select = 0.15,
	Page = 0.22,
	Toggle = 0.18,
	Expand = 0.2,
	Dropdown = 0.15,
	Popup = 0.18,
	Notify = 0.22,
	Minimize = 0.25,
}

local Dark = {
	Background = Color3.fromRGB(16, 16, 18),
	Sidebar = Color3.fromRGB(29, 29, 31),
	Surface = Color3.fromRGB(25, 25, 27),
	SurfaceHover = Color3.fromRGB(39, 39, 41),
	SurfaceActive = Color3.fromRGB(51, 51, 53),
	Border = Color3.fromRGB(60, 60, 64),
	Shadow = Color3.fromRGB(0, 0, 0),
	Sheen = Color3.fromRGB(255, 255, 255),

	TextPrimary = Color3.fromRGB(245, 245, 247),
	TextSecondary = Color3.fromRGB(178, 178, 184),
	TextMuted = Color3.fromRGB(143, 143, 151),
	TextDisabled = Color3.fromRGB(111, 111, 119),

	Accent = Color3.fromRGB(110, 168, 255),
	Success = Color3.fromRGB(48, 209, 88),
	Warning = Color3.fromRGB(255, 159, 10),
	Danger = Color3.fromRGB(255, 69, 58),
	UpdateAdded = Color3.fromRGB(96, 202, 139),
	UpdateFixed = Color3.fromRGB(239, 164, 94),
	UpdateRemoved = Color3.fromRGB(240, 120, 121),
	UpdateText = Color3.fromRGB(219, 219, 224),

	Palette = Color3.fromRGB(27, 27, 29),
	PaletteBorder = Color3.fromRGB(69, 69, 72),
	PaletteSelected = Color3.fromRGB(50, 50, 53),
	PaletteDivider = Color3.fromRGB(54, 54, 56),
	PalettePlaceholder = Color3.fromRGB(146, 146, 151),
	Knob = Color3.fromRGB(255, 255, 255),
	OnAccent = Color3.fromRGB(255, 255, 255),
	Scrim = Color3.fromRGB(0, 0, 0),

	RadiusWindow = 22,
	RadiusCard = 12,
	RadiusControl = 9,

	SpacingSmall = 6,
	SpacingMedium = 12,
	SpacingLarge = 18,
}

local Light = setmetatable({
	Background = Color3.fromRGB(246, 246, 247),
	Sidebar = Color3.fromRGB(236, 236, 238),
	Surface = Color3.fromRGB(255, 255, 255),
	SurfaceHover = Color3.fromRGB(240, 240, 242),
	SurfaceActive = Color3.fromRGB(226, 226, 229),
	Border = Color3.fromRGB(212, 212, 216),

	TextPrimary = Color3.fromRGB(28, 28, 30),
	TextSecondary = Color3.fromRGB(99, 99, 104),
	TextMuted = Color3.fromRGB(142, 142, 147),
	TextDisabled = Color3.fromRGB(142, 142, 147),

	Accent = Color3.fromRGB(0, 122, 255),
	Success = Color3.fromRGB(40, 167, 69),
	Warning = Color3.fromRGB(230, 140, 0),
	Danger = Color3.fromRGB(230, 57, 47),
	UpdateAdded = Color3.fromRGB(28, 121, 72),
	UpdateFixed = Color3.fromRGB(155, 79, 24),
	UpdateRemoved = Color3.fromRGB(183, 45, 45),
	UpdateText = Color3.fromRGB(28, 28, 30),

	Palette = Color3.fromRGB(252, 252, 253),
	PaletteBorder = Color3.fromRGB(208, 208, 212),
	PaletteSelected = Color3.fromRGB(230, 230, 233),
	PaletteDivider = Color3.fromRGB(212, 212, 216),
	PalettePlaceholder = Color3.fromRGB(115, 115, 122),
}, { __index = Dark })

Theme.Presets = { Dark = Dark, Light = Light }
Theme.name = "Dark"

local current = Dark
local bindings = {}
local listeners = {}
local disabledText = setmetatable({}, { __mode = "k" })

local function resolve(token)
	if type(token) == "function" then
		token = token()
	end
	if typeof(token) == "Color3" then
		return token
	end
	return current[token]
end

local function apply(inst, prop, token)
	inst[prop] = if prop == "TextColor3" and disabledText[inst] then current.TextDisabled else resolve(token)
end

function Theme.get(token: string): any
	return current[token]
end

-- map: { Property = "Token" | () -> "Token" | Color3 }
function Theme.bind(inst: Instance, map: { [string]: any })
	local existing = bindings[inst]
	if not existing then
		existing = {}
		bindings[inst] = existing
		inst.Destroying:Once(function()
			bindings[inst] = nil
		end)
	end
	for prop, token in map do
		existing[prop] = token
		apply(inst, prop, token)
	end
end

-- Keep the original color binding so enabling restores semantic/custom colors.
function Theme.setTextDisabled(inst: TextLabel | TextButton | TextBox, disabled: boolean)
	if not bindings[inst] or bindings[inst].TextColor3 == nil then
		Theme.bind(inst, { TextColor3 = inst.TextColor3 })
	end
	disabledText[inst] = disabled or nil
	inst.TextTransparency = 0
	apply(inst, "TextColor3", bindings[inst].TextColor3)
end

function Theme.resolve(inst: Instance, prop: string): any
	local map = bindings[inst]
	return map and map[prop] and resolve(map[prop])
end

function Theme.bindingCount(): number
	local count = 0
	for _ in bindings do
		count += 1
	end
	return count
end

function Theme.onChanged(fn: () -> ()): () -> ()
	table.insert(listeners, fn)
	return function()
		local index = table.find(listeners, fn)
		if index then
			table.remove(listeners, index)
		end
	end
end

function Theme.register(name: string, tokens: { [string]: any })
	Theme.Presets[name] = setmetatable(tokens, { __index = Dark })
end

function Theme.set(name: string)
	local preset = Theme.Presets[name]
	assert(preset, `Unknown theme "{name}"`)
	current = preset
	Theme.name = name
	for inst, map in bindings do
		for prop, token in map do
			apply(inst, prop, token)
		end
	end
	for _, fn in table.clone(listeners) do
		fn()
	end
end

return Theme
