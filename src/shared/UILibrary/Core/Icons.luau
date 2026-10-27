local Theme = require(script.Parent.Theme)
local Factory = require(script.Parent.Factory)

-- Builder Icons ships with every Roblox client; icons render as font ligatures.
local FAMILY = "rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json"

local Icons = {}

Icons.Font = {
	Regular = Font.new(FAMILY, Enum.FontWeight.Regular),
	Filled = Font.new(FAMILY, Enum.FontWeight.Bold),
}

Icons.Aliases = {
	settings = "gear",
	general = "gear",
	search = "magnifying-glass",
	home = "house",
	dashboard = "four-squares-grid",
	automation = "two-arrows-loop-clockwise",
	combat = "sword",
	movement = "person-running",
	visuals = "eye",
	misc = "three-dots-horizontal",
	back = "chevron-large-left",
	forward = "chevron-large-right",
	down = "chevron-small-down",
	right = "chevron-small-right",
	close = "x",
	add = "plus-small",
	remove = "minus",
	info = "circle-i",
	success = "circle-check",
	warning = "triangle-exclamation",
	error = "circle-x",
	reset = "arrow-rotate-right",
	delete = "trash-can",
	edit = "pencil",
	color = "paint-brush",
	keybind = "keyboard",
	sidebar = "sidebar",
	maximize = "dual-arrows-to-corners",
	minimize = "minus",
	check = "check-small",
	clear = "circle-x",
	workspace = "three-stacked-squares-tilted",
}

function Icons.name(icon: string): string
	local alias = Icons.Aliases[string.lower(icon)]
	if alias then
		return alias
	end
	if string.find(icon, "%u") then
		local kebab = string.gsub(icon, "(%l)(%u)", "%1-%2")
		kebab = string.gsub(kebab, "(%d)(%u)", "%1-%2")
		kebab = string.gsub(kebab, "_", "-")
		return string.lower(kebab)
	end
	return icon
end

function Icons.spec(icon: any): { [string]: any }
	if type(icon) == "table" then
		return icon
	end
	return { Icon = icon or "circle", Color = "TextSecondary" }
end

-- Sets an icon's tint whether it rendered as a font glyph or an image.
function Icons.tint(inst: GuiObject, token: any)
	if inst:IsA("TextLabel") then
		Theme.bind(inst, { TextColor3 = token })
	elseif inst:IsA("ImageLabel") then
		Theme.bind(inst, { ImageColor3 = token })
	end
end

function Icons.isImage(icon: any): boolean
	return type(icon) == "string" and (string.find(icon, "^rbxasset") ~= nil or string.find(icon, "^rbxthumb") ~= nil or string.find(icon, "^http") ~= nil)
end

-- spec: "gear" | "rbxassetid://..." | { Icon = "gear", Color = Color3|token, Tile = Color3|token, Filled = bool }
function Icons.create(spec: any, size: number, props: { [string]: any }?): GuiObject
	local options = if type(spec) == "table" then spec else { Icon = spec }
	local icon = options.Icon or options.Image
	local color = options.Color or "TextSecondary"

	local inst
	if Icons.isImage(icon) then
		inst = Factory.new("ImageLabel", {
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			Image = icon,
			ScaleType = Enum.ScaleType.Fit,
			Theme = if options.Tint then { ImageColor3 = color } else nil,
		})
	else
		inst = Factory.new("TextLabel", {
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			FontFace = if options.Filled then Icons.Font.Filled else Icons.Font.Regular,
			Text = Icons.name(icon or "circle"),
			TextSize = size,
			TextScaled = false,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Theme = { TextColor3 = color },
		})
	end

	if options.Tile then
		local tile = Factory.new("Frame", {
			Size = UDim2.fromOffset(size + 8, size + 8),
			Theme = { BackgroundColor3 = options.Tile },
		}, { Factory.corner(math.round((size + 8) * 0.26)) })
		inst.AnchorPoint = Vector2.new(0.5, 0.5)
		inst.Position = UDim2.fromScale(0.5, 0.5)
		if not options.Color then
			Theme.bind(inst, { [if inst:IsA("TextLabel") then "TextColor3" else "ImageColor3"] = Color3.new(1, 1, 1) })
		end
		inst.Parent = tile
		inst = tile
	end

	for key, value in props or {} do
		if key == "Parent" then
			continue
		end
		inst[key] = value
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

return Icons
