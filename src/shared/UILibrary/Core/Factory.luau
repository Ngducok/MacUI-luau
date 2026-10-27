local Theme = require(script.Parent.Theme)

local Factory = {}

function Factory.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
	end

	local parent
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		elseif key == "Theme" then
			Theme.bind(inst, value)
		else
			inst[key] = value
		end
	end

	for _, child in children or {} do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

function Factory.text(props: { [string]: any }, children: { Instance }?): any
	local typography = Theme.Typography[props.Typography or "Control"]
	assert(typography, `Unknown typography "{props.Typography}"`)
	local theme = { TextColor3 = "TextPrimary" }
	for key, value in props.Theme or {} do
		theme[key] = value
	end

	local merged = {
		BackgroundTransparency = 1,
		FontFace = typography.FontFace,
		TextSize = typography.TextSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		TextTransparency = 0,
	}
	for key, value in props do
		if key ~= "ClassName" and key ~= "Typography" then
			merged[key] = value
		end
	end
	merged.Theme = theme
	merged.TextScaled = false
	merged.TextSize = math.max(1, math.round(merged.TextSize))

	return Factory.new(props.ClassName or "TextLabel", merged, children)
end

function Factory.button(props: { [string]: any }?, children: { Instance }?): TextButton
	local merged = { AutoButtonColor = false, Text = "", BackgroundTransparency = 1 }
	for key, value in props or {} do
		merged[key] = value
	end
	return Factory.new("TextButton", merged, children)
end

function Factory.corner(radius: number): UICorner
	return Factory.new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Factory.stroke(token: any?, transparency: number?): UIStroke
	return Factory.new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1,
		Transparency = transparency or 0,
		Theme = { Color = token or "Border" },
	})
end

function Factory.padding(top: number, right: number?, bottom: number?, left: number?): UIPadding
	right = right or top
	return Factory.new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or right),
	})
end

function Factory.list(gap: number?, horizontal: boolean?, props: { [string]: any }?): UIListLayout
	local merged = {
		Padding = UDim.new(0, gap or 0),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top,
	}
	for key, value in props or {} do
		merged[key] = value
	end
	return Factory.new("UIListLayout", merged)
end

function Factory.fill(): UIFlexItem
	return Factory.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill })
end

return Factory
