local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Icons = require(Core.Icons)
local Util = require(Core.Util)
local Control = require(script.Parent.Control)

local VARIANTS = {
	Primary = { rest = "Accent", hover = "Accent", text = "OnAccent", hoverAlpha = 0.12 },
	Secondary = { rest = "SurfaceActive", hover = "SurfaceHover", text = "TextPrimary" },
	Ghost = { rest = "SurfaceHover", hover = "SurfaceHover", text = "TextPrimary", restAlpha = 1 },
	Destructive = { rest = "SurfaceActive", hover = "SurfaceHover", text = "Danger" },
}

local Button = Control.extend("Button")

-- Plain styled button, usable anywhere (dialogs, headers, inputs).
function Button.make(options: { [string]: any }): TextButton
	local variant = VARIANTS[options.Variant or "Secondary"] or VARIANTS.Secondary
	local restAlpha = variant.restAlpha or 0
	local height = options.Height or 28

	local button = Factory.button({
		Name = options.Text or "Button",
		Size = UDim2.fromOffset(options.Width or 0, height),
		AutomaticSize = if options.Width then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
		BackgroundTransparency = restAlpha,
		LayoutOrder = options.LayoutOrder or 0,
		Theme = { BackgroundColor3 = variant.rest },
	}, {
		Factory.corner(Theme.get("RadiusControl") - 1),
		Factory.padding(0, if options.Text then 12 else 6),
		Factory.list(6, true, { HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})

	if options.Icon then
		Icons.create({ Icon = options.Icon, Color = variant.text }, 16, { LayoutOrder = 1, Parent = button })
	end
	local label
	if options.Text then
		label = Factory.text({
			Name = "Label",
			Text = options.Text,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, height),
			TextTruncate = if options.Width then Enum.TextTruncate.AtEnd else Enum.TextTruncate.None,
			LayoutOrder = 2,
			Parent = button,
			Theme = { TextColor3 = variant.text },
		}, { Factory.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Shrink }) })
	end

	local hovered = false
	local function paint()
		local alpha = restAlpha
		if hovered then
			alpha = if variant.hoverAlpha then variant.hoverAlpha else 0
		end
		Theme.bind(button, { BackgroundColor3 = if hovered then variant.hover else variant.rest })
		Animations.tween(button, { BackgroundTransparency = alpha }, Theme.Motion.Hover)
	end
	button.MouseEnter:Connect(function()
		hovered = true
		paint()
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		paint()
	end)

	local scale = Factory.new("UIScale", { Parent = button })
	button.MouseButton1Down:Connect(function()
		Animations.tween(scale, { Scale = 0.97 }, 0.08)
	end)
	button.MouseButton1Up:Connect(function()
		Animations.tween(scale, { Scale = 1 }, 0.12)
	end)
	button.MouseLeave:Connect(function()
		Animations.tween(scale, { Scale = 1 }, 0.12)
	end)

	if options.Callback then
		button.Activated:Connect(function()
			Util.safeCall(options.Callback)
		end)
	end
	return button, label
end

function Button.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, {
		Id = options.Id,
		Title = options.Label,
		Description = options.Description,
		LayoutOrder = options.LayoutOrder,
	}), Button)
	self.options = options

	local button, label = Button.make({
		Text = options.Title or "Button",
		Icon = options.Icon,
		Variant = options.Variant,
	})
	button.Parent = self.widget
	self.button, self.label = button, label

	if options.Label == nil then
		self.widget.Size = UDim2.fromScale(1, 0)
		self.widget:FindFirstChildOfClass("UIListLayout").HorizontalAlignment =
			if options.Align == "Right" then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
	end

	self.cleanup:connect(button.Activated, function()
		if not self.disabled then
			Util.safeCall(options.Callback)
		end
	end)

	self:register("button")
	return self
end

function Button:searchTitle(): string
	local options, ctx = self.options, self.ctx
	local title = options.Label or options.Title or "Action"
	return options.SearchTitle or (if ctx.cardTitle then `{ctx.cardTitle}: {title}` else title)
end

function Button:register()
	local options = self.options
	if options.Searchable == false then
		return
	end
	local title = options.Label or options.Title
	if (title == nil or string.lower(title) == "open" or string.lower(title) == "button") and not options.SearchTitle and options.Searchable ~= true then
		return
	end
	local ctx = self.ctx
	self.registryKey = options._SearchId or `{ctx.searchId}/control:{options.Id or options.LayoutOrder or title}`
	self.cleanup:add(ctx.registry:add({
		id = self.registryKey,
		kind = "control",
		title = self:searchTitle(),
		subtitle = ctx.searchPath,
		keywords = `button {options.Keywords or ""}`,
		aliases = options.Aliases,
		icon = options.Icon or "cursor",
		activate = function()
			if ctx.locate then
				ctx.locate(self.Instance)
			end
		end,
		visible = function()
			return self.visible
		end,
	}))
end

function Button:SetText(text: string)
	self.options.Label = text
	if self.registryKey then
		self.ctx.registry:update(self.registryKey, { title = self:searchTitle() })
	end
	if self.label then
		self.label.Text = text
	end
end

function Button:GetValue()
	return nil
end

function Button:SetValue() end

return Button
