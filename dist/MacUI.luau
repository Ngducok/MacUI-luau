-- MacUI | https://github.com/Ngducok/MacUI-luau
local nodes = { [""] = { Name = "MacUI" } }
for _, path in { "Components", "Core", "Overlays", "Window", "Components/AnimatedImage", "Components/Button", "Components/Card", "Components/ColorPicker", "Components/Control", "Components/Display", "Components/Dropdown", "Components/Input", "Components/Keybind", "Components/Slider", "Components/Toggle", "Core/Animations", "Core/Blur", "Core/Cleanup", "Core/Factory", "Core/Icons", "Core/Input", "Core/Registry", "Core/Store", "Core/Theme", "Core/Util", "Overlays/CommandPalette", "Overlays/Dialog", "Overlays/Notifications", "Overlays/PopupManager", "Window/Account", "Window/DragResize", "Window/Page", "Window/Section", "Window/Sidebar", "Window/Window" } do
    local parent, name = string.match(path, "^(.*)/([^/]+)$")
    if not name then parent, name = "", path end
    local node = { Name = name, Parent = nodes[parent] }
    nodes[path] = node
    node.Parent[name] = node
end
local loaders, cache, loading = {}, {}, {}

-- Components/AnimatedImage
loaders[nodes["Components/AnimatedImage"]] = function(script, require)
local RunService = game:GetService("RunService")

local Factory = require(script.Parent.Parent.Core.Factory)
local Animations = require(script.Parent.Parent.Core.Animations)

local AnimatedImage = {}
AnimatedImage.__index = AnimatedImage

local active = {}
local heartbeat
local clock = 0

local function onScreen(inst: GuiObject): boolean
	local node: Instance? = inst
	while node and not node:IsA("LayerCollector") do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return node ~= nil and (node :: any).Enabled ~= false
end

local function step(dt: number)
	clock += dt
	for anim in active do
		if clock < anim.nextCheck then
			continue
		end
		anim.nextCheck = clock + 1 / anim.fps
		if anim.paused or Animations.reducedMotion or not onScreen(anim.Instance) then
			continue
		end
		anim:_advance()
	end
end

local function track(anim)
	active[anim] = true
	if not heartbeat then
		heartbeat = RunService.Heartbeat:Connect(step)
	end
end

local function untrack(anim)
	active[anim] = nil
	if heartbeat and next(active) == nil then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

export type Options = {
	Image: string,
	FrameSize: Vector2,
	Columns: number,
	Frames: number,
	FPS: number?,
	Loop: boolean?,
	Autoplay: boolean?,
	Speed: number?,
	Size: UDim2?,
}

function AnimatedImage.new(options: Options)
	assert(options.Image, "AnimatedImage needs Image")
	assert(options.FrameSize and options.Columns and options.Frames, "AnimatedImage needs FrameSize, Columns and Frames")

	local self = setmetatable({
		frame = 0,
		frames = options.Frames,
		columns = options.Columns,
		frameSize = options.FrameSize,
		baseFps = options.FPS or 12,
		speed = options.Speed or 1,
		loop = options.Loop ~= false,
		paused = options.Autoplay == false,
		nextCheck = 0,
	}, AnimatedImage)
	self.fps = math.max(1, self.baseFps * self.speed)

	self.Instance = Factory.new("ImageLabel", {
		Size = options.Size or UDim2.fromOffset(options.FrameSize.X, options.FrameSize.Y),
		BackgroundTransparency = 1,
		Image = options.Image,
		ImageRectSize = options.FrameSize,
		ScaleType = Enum.ScaleType.Fit,
	})
	self:_render()
	track(self)
	return self
end

function AnimatedImage:_render()
	local col = self.frame % self.columns
	local row = self.frame // self.columns
	self.Instance.ImageRectOffset = Vector2.new(col * self.frameSize.X, row * self.frameSize.Y)
end

function AnimatedImage:_advance()
	local nextFrame = self.frame + 1
	if nextFrame >= self.frames then
		if not self.loop then
			self.paused = true
			return
		end
		nextFrame = 0
	end
	self.frame = nextFrame
	self:_render()
end

function AnimatedImage:Play()
	if not self.loop and self.frame >= self.frames - 1 then
		self.frame = 0
		self:_render()
	end
	self.paused = false
end

function AnimatedImage:Pause()
	self.paused = true
end

function AnimatedImage:SetFrame(index: number)
	self.frame = math.clamp(index, 0, self.frames - 1)
	self:_render()
end

function AnimatedImage:SetSpeed(speed: number)
	self.speed = speed
	self.fps = math.max(1, self.baseFps * speed)
end

function AnimatedImage:IsPlaying(): boolean
	return not self.paused
end

function AnimatedImage:Destroy()
	untrack(self)
	self.Instance:Destroy()
end

function AnimatedImage.activeCount(): number
	local count = 0
	for _ in active do
		count += 1
	end
	return count
end

return AnimatedImage

end

-- Components/Button
loaders[nodes["Components/Button"]] = function(script, require)
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
	self.Instance:SetAttribute("NoWindowDrag", true)

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

end

-- Components/Card
loaders[nodes["Components/Card"]] = function(script, require)
local Core = script.Parent.Parent.Core
local Overlays = script.Parent.Parent.Overlays
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Cleanup = require(Core.Cleanup)
local Icons = require(Core.Icons)
local Util = require(Core.Util)
local PopupManager = require(Overlays.PopupManager)
local Components = script.Parent
local Toggle = require(Components.Toggle)
local Display = require(Components.Display)
local AnimatedImage = require(Components.AnimatedImage)

local CONTROLS = {
	Toggle = require(Components.Toggle),
	Slider = require(Components.Slider),
	Dropdown = require(Components.Dropdown),
	Button = require(Components.Button),
	Input = require(Components.Input),
	Keybind = require(Components.Keybind),
	ColorPicker = require(Components.ColorPicker),
	Label = Display.Label,
	Paragraph = Display.Paragraph,
	Divider = Display.Divider,
	Status = Display.Status,
	Progress = Display.Progress,
	Image = Display.Image,
}

local PAD_X = 14
local ICON = 20

local Card = {}
Card.__index = Card

export type Options = {
	Id: string?,
	Title: string,
	Description: string?,
	Icon: any?,
	AnimatedIcon: { [string]: any }?,
	Badge: string?,
	Collapsible: boolean?,
	DefaultExpanded: boolean?,
	Toggle: boolean?,
	Default: boolean?,
	Callback: ((boolean) -> ())?,
	Keywords: string?,
	Aliases: (string | { string })?,
	Searchable: boolean?,
	NavigateTo: string?,
	Popover: PopupManager.Policy?,
}

function Card.new(section, options: Options)
	assert(options.NavigateTo == nil or type(options.NavigateTo) == "string", "NavigateTo must be a page ID")
	assert(options.Popover == nil or type(options.Popover) == "table", "Popover must be a table")
	local ctx = section.ctx
	local grid = section.grid
	local self = setmetatable({
		section = section,
		options = options,
		cleanup = Cleanup.new(),
		controls = {},
		count = 0,
		visible = true,
		disabled = false,
		grid = grid,
		collapsible = options.Collapsible == true or grid,
	}, Card)
	self.expanded = self.collapsible and not grid and options.DefaultExpanded == true or not self.collapsible

	-- Search hits on a control expand its card before scrolling to it.
	self.ctx = setmetatable({
		searchId = `{ctx.searchId}/card:{options.Id or section.order + 1}`,
		searchPath = `{ctx.searchPath} › {options.Title}`,
		cardTitle = options.Title,
		locate = function(target: GuiObject, after: (() -> ())?)
			if grid then
				ctx.locate(self.Instance, function()
					self:SetExpanded(true)
					if after then
						after()
					end
				end)
				return
			end
			if self.collapsible and not self.expanded then
				self:SetExpanded(true, true)
			end
			ctx.locate(target, after)
		end,
	}, { __index = ctx })

	section.order += 1
	self.Instance = self.cleanup:add(Factory.new("Frame", {
		Name = options.Id or options.Title,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = if grid then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
		BackgroundTransparency = if grid then 0.04 else 1,
		LayoutOrder = section.order,
		ClipsDescendants = grid,
		Parent = section.container,
		Theme = { BackgroundColor3 = "Surface" },
	}, {
		Factory.list(0, false, { HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		if grid then Factory.corner(Theme.get("RadiusCard") - 2) else nil,
		if grid then Factory.stroke("Border", 0.5) else nil,
	}))
	self.Instance:SetAttribute("NoWindowDrag", self.collapsible or options.NavigateTo ~= nil or options.Toggle == true)

	self:_buildHeader()
	self:_buildBody()

	if options.Toggle then
		self:_buildSwitch()
	end

	self.registryKey = self.ctx.searchId
	if options.Searchable ~= false then
		self.cleanup:add(ctx.registry:add({
			id = self.registryKey,
			kind = "card",
			title = options.Title,
			subtitle = ctx.searchPath,
			keywords = `{options.Description or ""} {options.Keywords or ""}`,
			aliases = options.Aliases,
			icon = options.Icon or "three-sliders-horizontal",
			state = function()
				return if self.enabledId then (if ctx.store:get(self.enabledId) then "On" else "Off") else nil
			end,
			activate = function()
				self:Focus()
			end,
			visible = function()
				return self.visible
			end,
		}))
	end

	section:_refresh()
	return self
end

function Card:_buildHeader()
	local options = self.options
	local grid = self.grid

	local header = Factory.button({
		Name = "Header",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Active = self.collapsible or options.NavigateTo ~= nil,
		Parent = self.Instance,
		Theme = { BackgroundColor3 = "SurfaceHover" },
	}, {
		Factory.padding(if options.Description then 9 else 12, PAD_X),
		Factory.new("UISizeConstraint", { MinSize = Vector2.new(0, 44) }),
		Factory.list(10, not grid, {
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalFlex = if grid then nil else Enum.UIFlexAlignment.None,
		}),
	})
	self.header = header
	header:SetAttribute("NoWindowDrag", self.collapsible or options.NavigateTo ~= nil)

	if options.AnimatedIcon then
		local anim = AnimatedImage.new(Util.merge(options.AnimatedIcon, { Size = UDim2.fromOffset(ICON + 4, ICON + 4) }))
		anim.Instance.LayoutOrder = 1
		anim.Instance.Parent = header
		self.animation = anim
		self.cleanup:add(anim)
	elseif options.Icon then
		self.icon = Icons.create(options.Icon, ICON - 4, { LayoutOrder = 1, Parent = header })
	end

	local text = Factory.new("Frame", {
		Name = "Text",
		Size = UDim2.fromScale(if grid then 1 else 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = header,
	}, {
		Factory.list(2),
		if grid then nil else Factory.fill(),
	})

	local titleRow = Factory.new("Frame", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = text,
	}, { Factory.list(8, true) })

	self.titleLabel = Factory.text({
		Text = options.Title,
		Typography = "Feature",
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		Parent = titleRow,
	}, { Factory.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Shrink }) })

	self.spinner = Icons.create({ Icon = "arrow-spin-clockwise", Color = "TextMuted" }, 14, {
		LayoutOrder = 3,
		Visible = false,
		Parent = titleRow,
	})

	self.descriptionLabel = Factory.text({
		Text = options.Description or "",
		Typography = "Description",
		TextWrapped = true,
		TextTruncate = if grid then Enum.TextTruncate.AtEnd else Enum.TextTruncate.None,
		Size = UDim2.new(1, 0, 0, if grid then 26 else 0),
		AutomaticSize = if grid then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
		TextYAlignment = Enum.TextYAlignment.Top,
		Visible = options.Description ~= nil,
		LayoutOrder = 2,
		Parent = text,
		Theme = { TextColor3 = "TextSecondary" },
	})

	self.actions = Factory.new("Frame", {
		Name = "Actions",
		Size = UDim2.fromScale(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = header,
	}, { Factory.list(6, true) })

	if grid then
		self.actions.AnchorPoint = Vector2.new(1, 0)
		self.actions.Position = UDim2.new(1, 0, 0, 0)
		local layout = header:FindFirstChildOfClass("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		local top = Factory.new("Frame", {
			Size = UDim2.new(1, 0, 0, ICON + 4),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Parent = header,
		})
		local icon = self.icon or (self.animation and self.animation.Instance)
		if icon then
			icon.Parent = top
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.fromScale(0, 0.5)
		end
		self.actions.Parent = top
		self.actions.AnchorPoint = Vector2.new(1, 0.5)
		self.actions.Position = UDim2.fromScale(1, 0.5)
	end

	if options.Badge then
		self:SetBadge(options.Badge)
	end

	if self.collapsible or options.NavigateTo then
		local chevron = Icons.create(if options.NavigateTo then { Icon = "chevron-small-right", Color = Color3.fromRGB(165, 165, 170) }
			else if grid then "chevron-small-right" else "chevron-small-down", if options.NavigateTo then 16 else 18, {
			Name = "Chevron",
			LayoutOrder = 10,
			Rotation = if options.NavigateTo or self.expanded or grid then 0 else -90,
			Parent = self.actions,
		})
		self.chevron = chevron

		self.cleanup:connect(header.MouseEnter, function()
			Animations.tween(header, { BackgroundTransparency = if grid then 1 else 0.6 }, Theme.Motion.Hover)
			if grid then
				Theme.bind(self.Instance, { BackgroundColor3 = "SurfaceHover" })
			end
		end)
		self.cleanup:connect(header.MouseLeave, function()
			Animations.tween(header, { BackgroundTransparency = 1 }, Theme.Motion.Hover)
			if grid then
				Theme.bind(self.Instance, { BackgroundColor3 = "Surface" })
			end
		end)
		self.cleanup:connect(header.Activated, function()
			if not self.disabled then
				if options.NavigateTo then
					self.section.page.window:SelectPage(options.NavigateTo)
				else
					self:SetExpanded(not self:IsExpanded())
				end
			end
		end)
	end
end

function Card:_buildBody()
	local holder = Factory.new("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = 2,
		Visible = false,
		Parent = self.Instance,
	})
	self.cleanup:add(holder)

	local inner = Factory.new("Frame", {
		Name = "Content",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = holder,
	}, {
		Factory.list(10),
		Factory.padding(2, PAD_X, 12, if self.icon or self.animation then PAD_X + ICON + 8 else PAD_X),
	})

	self.body, self.content = holder, inner
end

function Card:_buildSwitch()
	local options, store = self.options, self.ctx.store
	local track, render = Toggle.switch()
	track.LayoutOrder = 5
	track.Parent = self.actions

	local id, value = store:define(if options.Id then `{options.Id}.enabled` else nil, options.Default == true)
	self.enabledId = id
	render(value)
	self.cleanup:add(store:observe(id, function(on)
		render(on)
		Util.safeCall(options.Callback, on)
	end))
	self.cleanup:add(function()
		store:remove(id)
	end)
	self.cleanup:connect(track.Activated, function()
		if not self.disabled then
			store:set(id, not store:get(id))
		end
	end)
end

function Card:_naturalHeight(): number
	return self.content.AbsoluteSize.Y / self.ctx.scale()
end

function Card:_hasBody(): boolean
	return self.count > 0
end

-- Open bodies auto-size to their content; only the transition uses a measured, fixed height.
function Card:_layoutBody(animate: boolean)
	local holder = self.body
	if self.grid then
		return
	end
	local open = self.expanded and self:_hasBody()
	local token = {}
	self.animToken = token

	local function settle()
		if self.animToken ~= token then
			return
		end
		holder.AutomaticSize = if open then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
		holder.Size = UDim2.new(1, 0, 0, 0)
		holder.Visible = open
	end

	if not animate or Animations.reducedMotion then
		settle()
		return
	end

	local from = holder.AbsoluteSize.Y / self.ctx.scale()
	holder.Visible = true
	holder.AutomaticSize = Enum.AutomaticSize.None
	holder.Size = UDim2.new(1, 0, 0, from)
	local target = if open then self:_naturalHeight() else 0
	local tween = Animations.tween(holder, { Size = UDim2.new(1, 0, 0, target) }, Theme.Motion.Expand, Enum.EasingStyle.Quint)
	if tween then
		tween.Completed:Once(settle)
	else
		settle()
	end
end

function Card:SetExpanded(expanded: boolean, instant: boolean?)
	if not self.collapsible then
		return
	end
	if self.grid then
		if expanded then
			self:_openInspector()
		elseif self.inspector then
			self.inspector.close()
		end
		return
	end
	self.expanded = expanded
	if self.chevron then
		Animations.tween(self.chevron, { Rotation = if expanded then 0 else -90 }, if instant then 0 else Theme.Motion.Expand)
	end
	self:_layoutBody(not instant)
end

function Card:IsExpanded(): boolean
	return if self.grid then self.inspector ~= nil else self.expanded
end

function Card:_openInspector()
	if self.inspector then
		return
	end
	local surface = PopupManager.surface(340, { Name = "CardInspector" })
	Factory.list(0).Parent = surface

	local head = Factory.new("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = surface,
	}, { Factory.padding(14, PAD_X, 10, PAD_X), Factory.list(3) })
	Factory.text({
		Text = self.options.Title,
		Typography = "Feature",
		Size = UDim2.new(1, 0, 0, 20),
		Parent = head,
	})
	if self.options.Description then
		Factory.text({
			Text = self.options.Description,
			Typography = "Description",
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = head,
			Theme = { TextColor3 = "TextSecondary" },
		})
	end

	local content = self.content
	content.Parent = surface
	content.LayoutOrder = 2
	local padding = content:FindFirstChildOfClass("UIPadding")
	local oldLeft = padding.PaddingLeft
	padding.PaddingLeft = UDim.new(0, PAD_X)

	if self.count == 0 then
		Factory.text({
			Name = "Empty",
			Text = "No settings for this feature yet.",
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = -1,
			Parent = content,
			Theme = { TextColor3 = "TextMuted" },
		})
	end

	self.inspector = self.ctx.popups:open({
		content = surface,
		anchor = self.Instance,
		gap = 8,
		group = "feature",
		policy = self.options.Popover,
		onClose = function()
			for _, control in self.controls do
				if control.stopDrag then control.stopDrag() end
			end
			local empty = content:FindFirstChild("Empty")
			if empty then
				empty:Destroy()
			end
			padding.PaddingLeft = oldLeft
			content.Parent = self.body
			self.inspector = nil
		end,
	})
end

function Card:_add(kind: string, options: { [string]: any })
	local class = CONTROLS[kind]
	self.count += 1
	options = table.clone(options or {})
	self.controlOrder = (self.controlOrder or 0) + 1
	options._SearchId = `{self.ctx.searchId}/control:{options.Id or self.controlOrder}`
	options.LayoutOrder = options.LayoutOrder or self.count
	local control = class.new(self.ctx, self.content, options)
	control.kind = kind
	control.onDestroy = function(c)
		local index = table.find(self.controls, c)
		if index then
			table.remove(self.controls, index)
			self.count -= 1
			self:_layoutBody(false)
		end
	end
	table.insert(self.controls, control)
	if self.disabled then
		control:SetDisabled(true)
	end
	self:_layoutBody(false)
	return control
end

for kind in CONTROLS do
	Card["Add" .. kind] = function(self, options)
		return self:_add(kind, options)
	end
end

function Card:AddAnimatedImage(options)
	return self:_add("Image", options)
end

function Card:AddAction(options: { Icon: string?, Text: string?, Tooltip: string?, Callback: (() -> ())? })
	local button
	if options.Text then
		button = require(Components.Button).make({ Text = options.Text, Icon = options.Icon, Variant = options.Variant, Callback = options.Callback })
	else
		button = Display.iconButton(options.Icon or "three-dots-horizontal", 26, options.Callback)
	end
	button.LayoutOrder = 4
	button.Parent = self.actions
	if options.Tooltip then
		self.cleanup:add(Display.tooltip(self.ctx.popups, button, options.Tooltip))
	end
	self.cleanup:add(button)
	return button
end

function Card:SetBadge(text: string?, kind: string?)
	if self.badge then
		self.badge:Destroy()
		self.badge = nil
	end
	if text then
		self.badge = Display.badge(text, kind)
		self.badge.LayoutOrder = 2
		self.badge.Parent = self.titleLabel.Parent
	end
end

function Card:SetLoading(loading: boolean)
	self.spinner.Visible = loading
	if self.stopSpin then
		self.stopSpin()
		self.stopSpin = nil
	end
	if loading then
		self.stopSpin = Animations.spin(self.spinner)
	end
end

function Card:SetTitle(title: string)
	self.options.Title = title
	self.titleLabel.Text = title
	self.ctx.searchPath = `{self.section.ctx.searchPath} › {title}`
	self.ctx.cardTitle = title
	self.ctx.registry:update(self.registryKey, { title = title })
	for _, control in self.controls do
		if control.registryKey then
			self.ctx.registry:update(control.registryKey, {
				subtitle = self.ctx.searchPath,
				title = if control.searchTitle then control:searchTitle() else control.options.Title,
			})
		end
	end
end

function Card:SetDescription(description: string?)
	self.options.Description = description
	self.descriptionLabel.Text = description or ""
	self.descriptionLabel.Visible = description ~= nil
	self.ctx.registry:update(self.registryKey, { keywords = `{description or ""} {self.options.Keywords or ""}` })
end

function Card:GetEnabled(): boolean?
	return if self.enabledId then self.ctx.store:get(self.enabledId) else nil
end

function Card:SetEnabled(on: boolean)
	if self.enabledId then
		self.ctx.store:set(self.enabledId, on == true)
	end
end

function Card:SetDisabled(disabled: boolean)
	self.disabled = disabled
	self.header.Interactable = not disabled
	Theme.setTextDisabled(self.titleLabel, disabled)
	Theme.setTextDisabled(self.descriptionLabel, disabled)
	if self.icon and self.icon:IsA("TextLabel") then
		Theme.setTextDisabled(self.icon, disabled)
	end
	for _, control in self.controls do
		control:SetDisabled(disabled)
	end
end

function Card:SetVisible(visible: boolean)
	self.visible = visible
	self.Instance.Visible = visible
	self.section:_refresh()
end

function Card:Focus()
	self.ctx.locate(self.Instance, function()
		if self.collapsible and not self:IsExpanded() then
			self:SetExpanded(true)
		end
	end)
	self:Flash()
end

function Card:Flash()
	local target = if self.grid then self.Instance else self.header
	local rest = if self.grid then 0 else 1
	Theme.bind(target, { BackgroundColor3 = "SurfaceActive" })
	target.BackgroundTransparency = 0
	task.delay(0.35, function()
		Animations.tween(target, { BackgroundTransparency = rest }, 0.6)
		task.delay(0.6, function()
			Theme.bind(target, { BackgroundColor3 = if self.grid then "Surface" else "SurfaceHover" })
		end)
	end)
end

function Card:GetControls()
	return table.clone(self.controls)
end

function Card:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	if self.inspector then
		self.inspector.close()
	end
	for i = #self.controls, 1, -1 do
		self.controls[i].onDestroy = nil
		self.controls[i]:Destroy()
	end
	if self.stopSpin then
		self.stopSpin()
	end
	self.cleanup:clean()
	self.section:_forget(self)
end

return Card

end

-- Components/ColorPicker
loaders[nodes["Components/ColorPicker"]] = function(script, require)
local Core = script.Parent.Parent.Core
local Overlays = script.Parent.Parent.Overlays
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Input = require(Core.Input)
local Util = require(Core.Util)
local PopupManager = require(Overlays.PopupManager)
local Control = require(script.Parent.Control)

local WIDTH = 240
local MAX_RECENT = 8

local recent: { Color3 } = {}

local ColorPicker = Control.extend("ColorPicker")

local function remember(color: Color3)
	for i = #recent, 1, -1 do
		if recent[i]:ToHex() == color:ToHex() then
			table.remove(recent, i)
		end
	end
	table.insert(recent, 1, color)
	recent[MAX_RECENT + 1] = nil
end

local function bar(height: number, order: number, parent: Instance)
	return Factory.button({
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = order,
		Parent = parent,
	}, { Factory.corner(height // 2) })
end

local function cursor(parent: Instance, size: number)
	return Factory.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = parent,
	}, {
		Factory.corner(size // 2),
		Factory.new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }),
	})
end

local function field(width: number, order: number, parent: Instance)
	local box = Factory.new("Frame", {
		Size = UDim2.fromOffset(width, 26),
		LayoutOrder = order,
		Parent = parent,
		Theme = { BackgroundColor3 = "SurfaceActive" },
	}, { Factory.corner(7), Factory.padding(0, 8) })
	return Factory.text({
		ClassName = "TextBox",
		Size = UDim2.fromScale(1, 1),
		ClearTextOnFocus = false,
		Typography = "Description",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Parent = box,
	})
end

function ColorPicker.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, options), ColorPicker)
	self.hasAlpha = options.Transparency ~= nil

	local swatch = Factory.button({
		Name = "Swatch",
		Size = UDim2.fromOffset(44, 24),
		BackgroundTransparency = 0,
		LayoutOrder = 2,
		Parent = self.widget,
	}, { Factory.corner(7), Factory.stroke("Border") })
	self.swatch = swatch

	self.hexLabel = Factory.text({
		Size = UDim2.fromOffset(62, 24),
		Typography = "Description",
		TextXAlignment = Enum.TextXAlignment.Right,
		LayoutOrder = 1,
		Parent = self.widget,
		Theme = { TextColor3 = "TextSecondary" },
	})

	local store = ctx.store
	if self.hasAlpha then
		self.alphaId = store:define(if options.Id then `{options.Id}.transparency` else nil, math.clamp(options.Transparency, 0, 1))
		self.cleanup:add(store:observe(self.alphaId, function(alpha)
			swatch.BackgroundTransparency = alpha
			Util.safeCall(options.Callback, self:GetValue(), alpha)
			if self.renderInspector then
				self.renderInspector()
			end
		end))
		swatch.BackgroundTransparency = store:get(self.alphaId)
		self.cleanup:add(function()
			store:remove(self.alphaId)
		end)
	end

	local callback = options.Callback
	self.options = Util.merge(options, {
		Callback = function(color)
			if callback then
				callback(color, self:GetTransparency())
			end
		end,
	})
	self:bind(options.Default or Color3.new(1, 1, 1), function(color)
		swatch.BackgroundColor3 = color
		self.hexLabel.Text = "#" .. string.upper(color:ToHex())
		if self.renderInspector then
			self.renderInspector()
		end
	end)

	self.cleanup:connect(swatch.Activated, function()
		if self.popup then
			self:Close()
		elseif not self.disabled then
			self:Open()
		end
	end)
	self.cleanup:add(function()
		self:Close()
	end)

	self:register("color picker hex rgb")
	return self
end

function ColorPicker:GetTransparency(): number
	return if self.alphaId then self.ctx.store:get(self.alphaId) else 0
end

function ColorPicker:SetTransparency(alpha: number)
	if self.alphaId then
		self.ctx.store:set(self.alphaId, math.clamp(alpha, 0, 1))
	end
end

function ColorPicker:normalize(value)
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "string" then
		local ok, color = pcall(Color3.fromHex, value)
		if ok then
			return color
		end
	end
	return self:GetValue()
end

function ColorPicker:stateText()
	return "#" .. string.upper(self:GetValue():ToHex())
end

function ColorPicker:Open()
	if self.popup then
		return
	end
	local h, s, v = self:GetValue():ToHSV()

	local surface = PopupManager.surface(WIDTH, { Name = "ColorInspector" })
	Factory.list(10).Parent = surface
	Factory.padding(12).Parent = surface

	local sv = Factory.button({
		Size = UDim2.new(1, 0, 0, 140),
		BackgroundTransparency = 0,
		LayoutOrder = 1,
		ClipsDescendants = false,
		Parent = surface,
	}, { Factory.corner(8) })
	local white = Factory.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = sv,
	}, {
		Factory.corner(8),
		Factory.new("UIGradient", { Transparency = NumberSequence.new(0, 1) }),
	})
	Factory.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ZIndex = 2,
		Parent = sv,
	}, {
		Factory.corner(8),
		Factory.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }),
	})
	white.ZIndex = 1
	local svCursor = cursor(sv, 12)

	local hueBar = bar(12, 2, surface)
	local stops = {}
	for i = 0, 6 do
		table.insert(stops, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 % 1, 1, 1)))
	end
	Factory.new("UIGradient", { Color = ColorSequence.new(stops), Parent = hueBar })
	local hueCursor = cursor(hueBar, 14)

	local alphaBar, alphaCursor, alphaGradient
	if self.hasAlpha then
		alphaBar = bar(12, 3, surface)
		alphaGradient = Factory.new("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = alphaBar })
		alphaCursor = cursor(alphaBar, 14)
	end

	local inputs = Factory.new("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = surface,
	}, { Factory.list(6, true) })
	local hexBox = field(78, 1, inputs)
	local rgbBoxes = { field(40, 2, inputs), field(40, 3, inputs), field(40, 4, inputs) }
	local alphaBox = if self.hasAlpha then field(40, 5, inputs) else nil

	local recentRow = Factory.new("Frame", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		LayoutOrder = 5,
		Visible = #recent > 0,
		Parent = surface,
	}, { Factory.list(6, true) })

	local function commit()
		self:SetValue(Color3.fromHSV(h, s, v))
	end

	local function render()
		local color = Color3.fromHSV(h, s, v)
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = UDim2.fromScale(s, 1 - v)
		hueCursor.Position = UDim2.fromScale(h, 0.5)
		if alphaBar then
			alphaBar.BackgroundColor3 = color
			alphaCursor.Position = UDim2.fromScale(self:GetTransparency(), 0.5)
			alphaGradient.Transparency = NumberSequence.new(0, 0.9)
			if not alphaBox:IsFocused() then
				alphaBox.Text = `{math.round((1 - self:GetTransparency()) * 100)}%`
			end
		end
		if not hexBox:IsFocused() then
			hexBox.Text = "#" .. string.upper(color:ToHex())
		end
		local rgb = { color.R, color.G, color.B }
		for i, box in rgbBoxes do
			if not box:IsFocused() then
				box.Text = tostring(math.round(rgb[i] * 255))
			end
		end
	end

	self.renderInspector = function()
		local color = self:GetValue()
		if Color3.fromHSV(h, s, v):ToHex() ~= color:ToHex() then
			h, s, v = color:ToHSV()
		end
		render()
	end

	local function dragArea(area: GuiButton, onPoint: (Vector2) -> ())
		area.InputBegan:Connect(function(input)
			if Input.isPointer(input) then
				self.stopDrag = Input.drag(input, function(point)
					local rel = (point - area.AbsolutePosition) / area.AbsoluteSize
					onPoint(Vector2.new(math.clamp(rel.X, 0, 1), math.clamp(rel.Y, 0, 1)))
				end)
			end
		end)
	end
	dragArea(sv, function(rel)
		s, v = rel.X, 1 - rel.Y
		commit()
		render()
	end)
	dragArea(hueBar, function(rel)
		h = rel.X
		commit()
		render()
	end)
	if alphaBar then
		dragArea(alphaBar, function(rel)
			self:SetTransparency(rel.X)
		end)
	end

	hexBox.FocusLost:Connect(function()
		local text = string.gsub(hexBox.Text, "#", "")
		local ok, color = pcall(Color3.fromHex, text)
		if ok and #text == 6 then
			h, s, v = color:ToHSV()
			commit()
		end
		hexBox.Text = ""
		render()
	end)
	for i, box in rgbBoxes do
		box.FocusLost:Connect(function()
			local color = Color3.fromHSV(h, s, v)
			local rgb = { color.R * 255, color.G * 255, color.B * 255 }
			local n = tonumber(box.Text)
			if n then
				rgb[i] = math.clamp(math.round(n), 0, 255)
				h, s, v = Color3.fromRGB(rgb[1], rgb[2], rgb[3]):ToHSV()
				commit()
			end
			box.Text = ""
			render()
		end)
	end
	if alphaBox then
		alphaBox.FocusLost:Connect(function()
			local n = tonumber((string.gsub(alphaBox.Text, "%%", "")))
			if n then
				self:SetTransparency(1 - math.clamp(n, 0, 100) / 100)
			end
			alphaBox.Text = ""
			render()
		end)
	end

	for i, color in recent do
		local chip = Factory.button({
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 0,
			BackgroundColor3 = color,
			LayoutOrder = i,
			Parent = recentRow,
		}, { Factory.corner(6), Factory.stroke("Border") })
		chip.Activated:Connect(function()
			h, s, v = color:ToHSV()
			commit()
			render()
		end)
	end

	render()
	self.popup = self.ctx.popups:open({
		content = surface,
		anchor = self.swatch,
		align = "right",
		onClose = function()
			if self.stopDrag then
				self.stopDrag()
			end
			remember(self:GetValue())
			self.popup = nil
			self.renderInspector = nil
		end,
	})
end

function ColorPicker:Close()
	if self.popup then
		self.popup.close()
	end
end

return ColorPicker

end

-- Components/Control
loaders[nodes["Components/Control"]] = function(script, require)
local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Cleanup = require(Core.Cleanup)
local Util = require(Core.Util)

-- Shared base for every control: a row with title/description on the left and a widget on the right.
local Control = {}
Control.__index = Control

export type Context = {
	store: any,
	registry: any,
	popups: any,
	notify: (any) -> (),
	locate: (() -> ())?,
	pageTitle: string?,
	cardTitle: string?,
}

function Control.new(ctx: Context, parent: GuiObject, options: { [string]: any }, stacked: boolean?)
	local self = setmetatable({
		ctx = ctx,
		options = options,
		cleanup = Cleanup.new(),
		disabled = false,
		visible = true,
	}, Control)

	local hasText = options.Title ~= nil or options.Description ~= nil
	self.Instance = self.cleanup:add(Factory.new("Frame", {
		Name = options.Id or options.Title or "Control",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = options.LayoutOrder or 0,
	}, {
		Factory.list(if stacked then 8 else 12, not stacked, {
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalFlex = if stacked then nil else Enum.UIFlexAlignment.None,
		}),
	}))

	if hasText then
		local text = Factory.new("Frame", {
			Name = "Text",
			Size = UDim2.fromScale(if stacked then 1 else 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Parent = self.Instance,
		}, {
			Factory.list(2),
			if stacked then nil else Factory.fill(),
		})

		self.titleLabel = Factory.text({
			Text = options.Title or "",
			Size = UDim2.new(1, 0, 0, 18),
			Visible = options.Title ~= nil,
			LayoutOrder = 1,
			Parent = text,
		})

		self.descriptionLabel = Factory.text({
			Text = options.Description or "",
			Typography = "Description",
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = options.Description ~= nil,
			LayoutOrder = 2,
			Parent = text,
			Theme = { TextColor3 = "TextSecondary" },
		})
	end

	self.widget = Factory.new("Frame", {
		Name = "Widget",
		Size = if stacked then UDim2.fromScale(1, 0) else UDim2.fromScale(0, 0),
		AutomaticSize = if stacked then Enum.AutomaticSize.Y else Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = self.Instance,
	}, {
		Factory.list(8, not stacked, { HorizontalAlignment = Enum.HorizontalAlignment.Right }),
	})

	self.Instance.Parent = parent
	return self
end

-- Binds this control to a store flag. apply(value) renders, called now and on every change.
function Control:bind(default: any, apply: (any) -> ())
	self.Instance:SetAttribute("NoWindowDrag", true)
	local options, store = self.options, self.ctx.store
	local id, value = store:define(options.Id, default)
	self.id = id
	self.cleanup:add(store:observe(id, function(new)
		apply(new)
		Util.safeCall(options.Callback, new)
	end))
	self.cleanup:add(function()
		store:remove(id)
	end)
	apply(value)
	return id
end

function Control:register(kind: string?)
	local options = self.options
	if not options.Title or options.Searchable == false then
		return
	end
	local ctx = self.ctx
	local key = options._SearchId or `{ctx.searchId}/control:{options.Id or options.LayoutOrder or options.Title}`
	self.registryKey = key
	self.cleanup:add(ctx.registry:add({
		id = key,
		kind = "control",
		title = options.Title,
		subtitle = ctx.searchPath,
		keywords = `{kind or ""} {options.Keywords or ""} {options.Description or ""}`,
		aliases = options.Aliases,
		icon = options.Icon or "three-sliders-horizontal",
		state = function()
			return self:stateText()
		end,
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

function Control:stateText(): string?
	return nil
end

function Control:GetValue(): any
	return if self.id then self.ctx.store:get(self.id) else nil
end

function Control:SetValue(value: any)
	if self.id then
		self.ctx.store:set(self.id, self:normalize(value))
	end
end

function Control:normalize(value: any): any
	return value
end

function Control:SetDisabled(disabled: boolean)
	self.disabled = disabled
	self.Instance.Interactable = not disabled
	local alpha = if disabled then 0.55 else 0
	for _, inst in self.Instance:GetDescendants() do
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
			Theme.setTextDisabled(inst, disabled)
		elseif inst:IsA("ImageLabel") then
			inst.ImageTransparency = alpha
		end
	end
end

function Control:SetVisible(visible: boolean)
	self.visible = visible
	self.Instance.Visible = visible
end

function Control:SetTitle(title: string)
	self.options.Title = title
	if self.registryKey then
		self.ctx.registry:update(self.registryKey, { title = title })
	end
	if self.titleLabel then
		self.titleLabel.Text = title
		self.titleLabel.Visible = true
	end
end

function Control:SetDescription(description: string?)
	self.options.Description = description
	if self.descriptionLabel then
		self.descriptionLabel.Text = description or ""
		self.descriptionLabel.Visible = description ~= nil
	end
end

function Control:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.cleanup:clean()
	if self.onDestroy then
		self.onDestroy(self)
	end
end

function Control.extend(name: string)
	local class = setmetatable({}, { __index = Control })
	class.__index = class
	class.ClassName = name
	return class
end

return Control

end

-- Components/Display
loaders[nodes["Components/Display"]] = function(script, require)
local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Icons = require(Core.Icons)
local Util = require(Core.Util)
local Control = require(script.Parent.Control)
local AnimatedImage = require(script.Parent.AnimatedImage)

local Display = {}

local BADGE_TOKENS = {
	Neutral = { "SurfaceActive", "TextSecondary" },
	Success = { "Success", "Success" },
	Warning = { "Warning", "Warning" },
	Danger = { "Danger", "Danger" },
	Accent = { "Accent", "Accent" },
}

function Display.badge(text: string, kind: string?): Frame
	local tokens = BADGE_TOKENS[kind or "Neutral"] or BADGE_TOKENS.Neutral
	local tinted = kind ~= nil and kind ~= "Neutral"
	local badge = Factory.new("Frame", {
		Name = "Badge",
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = if tinted then 0.84 else 0,
		Theme = { BackgroundColor3 = tokens[1] },
	}, {
		Factory.corner(6),
		Factory.padding(0, 7),
	})
	Factory.text({
		Name = "Label",
		Text = text,
		Typography = "Hint",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextTruncate = Enum.TextTruncate.None,
		Parent = badge,
		Theme = { TextColor3 = tokens[2] },
	})
	return badge
end

-- Label: title + optional value on the right.
local Label = Control.extend("Label")
Display.Label = Label

function Label.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, options), Label)
	self.valueLabel = Factory.text({
		Text = options.Value or "",
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		TextTruncate = Enum.TextTruncate.None,
		Visible = options.Value ~= nil,
		Parent = self.widget,
		Theme = { TextColor3 = "TextSecondary" },
	})
	return self
end

function Label:SetValue(value: any)
	self.valueLabel.Text = tostring(value)
	self.valueLabel.Visible = value ~= nil
end

function Label:GetValue()
	return self.valueLabel.Text
end

-- Paragraph: wrapped body copy.
local Paragraph = Control.extend("Paragraph")
Display.Paragraph = Paragraph

function Paragraph.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, {
		Title = options.Title,
		LayoutOrder = options.LayoutOrder,
		Description = options.Content or options.Text or "",
	}, true), Paragraph)
	self.options = options
	self.widget.Visible = false
	return self
end

function Paragraph:SetValue(text: string)
	self:SetDescription(text)
end

function Paragraph:GetValue()
	return self.options.Description or self.options.Content or self.options.Text
end

-- Divider
local Divider = Control.extend("Divider")
Display.Divider = Divider

function Divider.new(_ctx, parent, options)
	local self = setmetatable({ options = options, visible = true, cleanup = require(Core.Cleanup).new() }, Divider)
	self.Instance = self.cleanup:add(Factory.new("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = options.LayoutOrder or 0,
		Parent = parent,
		Theme = { BackgroundColor3 = "Border" },
	}))
	self.Instance.BackgroundTransparency = 0.4
	return self
end

function Divider:GetValue()
	return nil
end

-- Status badge row
local Status = Control.extend("Status")
Display.Status = Status

function Status.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, options), Status)
	self:SetValue(options.Value or "Idle", options.Kind)
	return self
end

function Status:SetValue(text: string, kind: string?)
	if self.badge then
		self.badge:Destroy()
	end
	self.text, self.kind = text, kind or self.kind
	self.badge = Display.badge(text, self.kind)
	self.badge.Parent = self.widget
end

function Status:GetValue()
	return self.text
end

function Status:stateText()
	return self.text
end

-- Progress bar: Value 0..1 or nil for an indeterminate shimmer.
local Progress = Control.extend("Progress")
Display.Progress = Progress

function Progress.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, options), Progress)

	self.percent = Factory.text({
		Size = UDim2.fromOffset(40, 18),
		Typography = "Description",
		TextXAlignment = Enum.TextXAlignment.Right,
		LayoutOrder = 1,
		Parent = self.widget,
		Theme = { TextColor3 = "TextSecondary" },
	})
	local rail = Factory.new("Frame", {
		Size = UDim2.fromOffset(options.Width or 150, 4),
		LayoutOrder = 2,
		ClipsDescendants = true,
		Parent = self.widget,
		Theme = { BackgroundColor3 = "SurfaceActive" },
	}, { Factory.corner(2) })
	self.fill = Factory.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		Parent = rail,
		Theme = { BackgroundColor3 = options.Color or "Accent" },
	}, { Factory.corner(2) })
	self:SetValue(options.Value)
	return self
end

function Progress:SetValue(value: number?)
	if self.stopShimmer then
		self.stopShimmer()
		self.stopShimmer = nil
	end
	self.value = value
	if value == nil then
		self.percent.Text = ""
		self.fill.Size = UDim2.fromScale(0.3, 1)
		self.fill.Position = UDim2.fromScale(-0.3, 0)
		local tween = game:GetService("TweenService"):Create(
			self.fill,
			TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1),
			{ Position = UDim2.fromScale(1, 0) }
		)
		if not Animations.reducedMotion then
			tween:Play()
		end
		self.stopShimmer = function()
			tween:Cancel()
			self.fill.Position = UDim2.new()
		end
		self.cleanup:add(self.stopShimmer)
		return
	end
	local alpha = math.clamp(value, 0, 1)
	self.percent.Text = `{math.round(alpha * 100)}%`
	self.fill.Position = UDim2.new()
	Animations.tween(self.fill, { Size = UDim2.fromScale(alpha, 1) }, Theme.Motion.Toggle)
end

function Progress:GetValue()
	return self.value
end

function Progress:stateText()
	return if self.value then `{math.round(self.value * 100)}%` else nil
end

-- Image preview or animated sprite sheet.
local Image = Control.extend("Image")
Display.Image = Image

function Image.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, options, true), Image)
	local height = options.Height or 140

	local frame = Factory.new("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		ClipsDescendants = true,
		Parent = self.widget,
		Theme = { BackgroundColor3 = "Background" },
	}, { Factory.corner(10) })

	if options.Columns and options.Frames then
		self.animation = AnimatedImage.new({
			Image = options.Image,
			FrameSize = options.FrameSize,
			Columns = options.Columns,
			Frames = options.Frames,
			FPS = options.FPS,
			Loop = options.Loop,
			Autoplay = options.Autoplay,
			Speed = options.Speed,
			Size = UDim2.fromScale(1, 1),
		})
		self.animation.Instance.Parent = frame
		self.cleanup:add(self.animation)
	else
		Factory.new("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = options.Image or "",
			ScaleType = options.ScaleType or Enum.ScaleType.Fit,
			Parent = frame,
		})
	end
	return self
end

function Image:Play()
	if self.animation then
		self.animation:Play()
	end
end

function Image:Pause()
	if self.animation then
		self.animation:Pause()
	end
end

function Image:GetValue()
	return self.options.Image
end

-- Tooltip: hover a GuiObject to show text in the overlay layer.
function Display.tooltip(popups, target: GuiObject, text: string): () -> ()
	local open
	local token = 0
	local enter = target.MouseEnter:Connect(function()
		token += 1
		local mine = token
		task.delay(0.45, function()
			if mine ~= token or open or not target:IsDescendantOf(game) then
				return
			end
			local tip = Factory.new("Frame", {
				Size = UDim2.fromOffset(0, 24),
				AutomaticSize = Enum.AutomaticSize.X,
				Theme = { BackgroundColor3 = "SurfaceActive" },
			}, {
				Factory.corner(6),
				Factory.stroke("PaletteBorder"),
				Factory.padding(0, 8),
				Factory.new("UISizeConstraint", { MaxSize = Vector2.new(260, 24) }),
			})
			Factory.text({
				Text = text,
				Typography = "Hint",
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				Parent = tip,
			})
			open = popups:open({
				content = tip,
				anchor = target,
				gap = 6,
				onClose = function()
					open = nil
				end,
			})
		end)
	end)
	local leave = target.MouseLeave:Connect(function()
		token += 1
		if open then
			open.close()
		end
	end)
	return function()
		enter:Disconnect()
		leave:Disconnect()
		if open then
			open.close()
		end
	end
end

-- Icon button used in headers.
function Display.iconButton(icon: any, size: number?, callback: (() -> ())?): TextButton
	local box = size or 26
	local button = Factory.button({
		Name = if type(icon) == "string" then icon else "IconButton",
		Size = UDim2.fromOffset(box, box),
		BackgroundTransparency = 1,
		Theme = { BackgroundColor3 = "SurfaceHover" },
	}, { Factory.corner(7) })
	local glyph = Icons.create(icon, math.round(box * 0.62), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = button,
	})
	button.MouseEnter:Connect(function()
		Animations.tween(button, { BackgroundTransparency = 0 }, Theme.Motion.Hover)
		if type(icon) == "string" then
			Icons.tint(glyph, "TextPrimary")
		end
	end)
	button.MouseLeave:Connect(function()
		Animations.tween(button, { BackgroundTransparency = 1 }, Theme.Motion.Hover)
		if type(icon) == "string" then
			Icons.tint(glyph, "TextSecondary")
		end
	end)
	if callback then
		button.Activated:Connect(function()
			Util.safeCall(callback)
		end)
	end
	return button
end

return Display

end

-- Components/Dropdown
loaders[nodes["Components/Dropdown"]] = function(script, require)
local Core = script.Parent.Parent.Core
local Overlays = script.Parent.Parent.Overlays
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Icons = require(Core.Icons)
local Input = require(Core.Input)
local PopupManager = require(Overlays.PopupManager)
local Control = require(script.Parent.Control)

local ROW = 30
local MAX_ROWS = 8

local Dropdown = Control.extend("Dropdown")

local function label(option: any): string
	return if type(option) == "table" then option.Label or tostring(option.Value) else tostring(option)
end

local function valueOf(option: any): any
	return if type(option) == "table" then option.Value else option
end

function Dropdown.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, options), Dropdown)
	self.items = options.Options or {}
	self.multi = options.Multi == true

	local field = Factory.button({
		Name = "Field",
		Size = UDim2.fromOffset(options.Width or 160, 28),
		BackgroundTransparency = 0,
		LayoutOrder = 1,
		Parent = self.widget,
		Theme = { BackgroundColor3 = "SurfaceActive" },
	}, {
		Factory.corner(Theme.get("RadiusControl") - 1),
		Factory.padding(0, 8, 0, 10),
	})
	self.field = field

	self.valueLabel = Factory.text({
		Size = UDim2.new(1, -20, 1, 0),
		Parent = field,
	})

	Icons.create("down", 16, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Parent = field,
	})

	self.cleanup:connect(field.MouseEnter, function()
		Theme.bind(field, { BackgroundColor3 = "SurfaceHover" })
	end)
	self.cleanup:connect(field.MouseLeave, function()
		Theme.bind(field, { BackgroundColor3 = "SurfaceActive" })
	end)

	local default = options.Default
	if self.multi then
		default = if type(default) == "table" then table.clone(default) else {}
	elseif default == nil and self.items[1] ~= nil then
		default = valueOf(self.items[1])
	end
	self:bind(default, function()
		self:_renderValue()
		if self.renderList then
			self.renderList()
		end
	end)

	self.cleanup:connect(field.Activated, function()
		if self.popup then
			self:Close()
		elseif not self.disabled then
			self:Open()
		end
	end)
	self.cleanup:add(function()
		self:Close()
	end)

	self:register("dropdown select")
	return self
end

function Dropdown:_isSelected(value: any): boolean
	local current = self:GetValue()
	if self.multi then
		return table.find(current, value) ~= nil
	end
	return current == value
end

function Dropdown:_renderValue()
	self.valueLabel.Text = self:stateText() or "Select"
	Theme.bind(self.valueLabel, { TextColor3 = if self:stateText() then "TextPrimary" else "TextMuted" })
end

function Dropdown:stateText(): string?
	local current = self:GetValue()
	if self.multi then
		if #current == 0 then
			return nil
		end
		local names = {}
		for _, item in self.items do
			if table.find(current, valueOf(item)) then
				table.insert(names, label(item))
			end
		end
		return table.concat(names, ", ")
	end
	for _, item in self.items do
		if valueOf(item) == current then
			return label(item)
		end
	end
	return if current ~= nil then tostring(current) else nil
end

function Dropdown:normalize(value)
	if self.multi then
		local out = {}
		for _, v in if type(value) == "table" then value else { value } do
			if not table.find(out, v) then
				table.insert(out, v)
			end
		end
		return out
	end
	return value
end

function Dropdown:_choose(item: any)
	local value = valueOf(item)
	if self.multi then
		local current = table.clone(self:GetValue())
		local index = table.find(current, value)
		if index then
			table.remove(current, index)
		else
			table.insert(current, value)
		end
		self:SetValue(current)
	else
		self:SetValue(value)
		self:Close()
	end
end

function Dropdown:Open()
	if self.popup then
		return
	end
	local options = self.options
	local searchable = options.Searchable == true or #self.items > 10
	local width = math.max(self.field.AbsoluteSize.X / self.ctx.popups.scale, 200)
	local surface = PopupManager.surface(width, { Name = "DropdownMenu" })
	Factory.list(0).Parent = surface

	local query
	if searchable then
		local bar = Factory.new("Frame", {
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Parent = surface,
		}, { Factory.padding(0, 12) })
		query = Factory.text({
			ClassName = "TextBox",
			Size = UDim2.fromScale(1, 1),
			Text = "",
			PlaceholderText = "Search options...",
			ClearTextOnFocus = false,
			TextTruncate = Enum.TextTruncate.None,
			Parent = bar,
			Theme = { PlaceholderColor3 = "TextMuted" },
		})
		Factory.new("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			LayoutOrder = 2,
			Parent = surface,
			Theme = { BackgroundColor3 = "Border" },
		})
	end

	local list = Factory.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, ROW),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		LayoutOrder = 3,
		Parent = surface,
		Theme = { ScrollBarImageColor3 = "Border" },
	}, {
		Factory.list(2),
		Factory.padding(6),
	})

	local rows, shown = {}, {}
	local selected = 1

	local function highlight(index: number)
		selected = index
		for i, row in rows do
			if row:IsA("TextButton") then
				Animations.tween(row, { BackgroundTransparency = if i == index then 0 else 1 }, Theme.Motion.Hover)
			end
		end
		-- Keep the highlighted row visible. Absolute values are on-screen pixels; CanvasPosition is unscaled.
		local row = rows[index]
		if row then
			local ratio = self.ctx.popups.scale
			local rowTop = (row.AbsolutePosition.Y - list.AbsolutePosition.Y) / ratio
			local rowBottom = rowTop + row.AbsoluteSize.Y / ratio
			local view = list.AbsoluteWindowSize.Y / ratio
			if rowTop < 0 then
				list.CanvasPosition -= Vector2.new(0, -rowTop + 6)
			elseif rowBottom > view then
				list.CanvasPosition += Vector2.new(0, rowBottom - view + 6)
			end
		end
	end

	local function render()
		for _, row in rows do
			row:Destroy()
		end
		table.clear(rows)
		table.clear(shown)

		local text = if query then string.lower(query.Text) else ""
		for _, item in self.items do
			if text == "" or string.find(string.lower(label(item)), text, 1, true) then
				table.insert(shown, item)
			end
		end

		for i, item in shown do
			local row = Factory.button({
				Size = UDim2.new(1, 0, 0, ROW),
				BackgroundTransparency = 1,
				LayoutOrder = i,
				Parent = list,
				Theme = { BackgroundColor3 = "PaletteSelected" },
			}, {
				Factory.corner(7),
				Factory.padding(0, 10),
			})
			Factory.text({
				Text = label(item),
				Size = UDim2.new(1, -22, 1, 0),
				Parent = row,
			})
			if self:_isSelected(valueOf(item)) then
				Icons.create({ Icon = "check", Color = "Accent" }, 16, {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					Parent = row,
				})
			end
			row.MouseEnter:Connect(function()
				highlight(i)
			end)
			row.Activated:Connect(function()
				self:_choose(item)
			end)
			rows[i] = row
		end

		if #shown == 0 then
			rows[1] = Factory.text({
				Text = "No matching options",
				Size = UDim2.new(1, 0, 0, ROW),
				Parent = list,
				Theme = { TextColor3 = "TextMuted" },
			}, { Factory.padding(0, 10) })
		end

		list.Size = UDim2.new(1, 0, 0, math.min(math.max(#shown, 1), MAX_ROWS) * (ROW + 2) + 10)
		highlight(math.clamp(selected, 1, math.max(#shown, 1)))
	end
	self.renderList = render

	for i, item in self.items do
		if self:_isSelected(valueOf(item)) then
			selected = i
			break
		end
	end
	render()

	local stopKeys = Input.listen(function(input)
		if input.KeyCode == Enum.KeyCode.Down then
			highlight(math.min(selected + 1, #shown))
			return true
		elseif input.KeyCode == Enum.KeyCode.Up then
			highlight(math.max(selected - 1, 1))
			return true
		elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
			if shown[selected] then
				self:_choose(shown[selected])
			end
			if self.multi and query then
				task.defer(function()
					if query.Parent then
						query:CaptureFocus()
					end
				end)
			end
			return true
		end
		return false
	end)

	if query then
		query:GetPropertyChangedSignal("Text"):Connect(function()
			selected = 1
			render()
		end)
		task.defer(function()
			if query.Parent then
				query:CaptureFocus()
			end
		end)
	end

	self.popup = self.ctx.popups:open({
		content = surface,
		anchor = self.field,
		align = "right",
		onClose = function()
			stopKeys()
			self.popup = nil
			self.renderList = nil
		end,
	})
end

function Dropdown:Close()
	if self.popup then
		self.popup.close()
	end
end

function Dropdown:SetOptions(items: { any }, keepValue: boolean?)
	self.items = items
	if not keepValue then
		if self.multi then
			local kept = {}
			for _, value in self:GetValue() do
				for _, item in items do
					if valueOf(item) == value then
						table.insert(kept, value)
					end
				end
			end
			self:SetValue(kept)
		else
			local found = false
			for _, item in items do
				if valueOf(item) == self:GetValue() then
					found = true
				end
			end
			if not found then
				self:SetValue(if items[1] ~= nil then valueOf(items[1]) else nil)
			end
		end
	end
	self:_renderValue()
	if self.renderList then
		self.renderList()
	end
end

function Dropdown:GetOptions()
	return self.items
end

return Dropdown

end

-- Components/Input
loaders[nodes["Components/Input"]] = function(script, require)
local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Icons = require(Core.Icons)
local Util = require(Core.Util)
local Control = require(script.Parent.Control)

local TextInput = Control.extend("Input")

function TextInput.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, options), TextInput)

	local box = Factory.new("Frame", {
		Name = "Box",
		Size = UDim2.fromOffset(options.Width or 190, 28),
		LayoutOrder = 1,
		Parent = self.widget,
		Theme = { BackgroundColor3 = "SurfaceActive" },
	}, {
		Factory.corner(Theme.get("RadiusControl") - 1),
		Factory.padding(0, 6, 0, 10),
	})
	local stroke = Factory.stroke("Accent", 1)
	stroke.Parent = box

	local field = Factory.text({
		ClassName = "TextBox",
		Size = UDim2.new(1, if options.Clearable == false then 0 else -22, 1, 0),
		Text = "",
		PlaceholderText = options.Placeholder or "",
		ClearTextOnFocus = false,
		TextTruncate = Enum.TextTruncate.None,
		ClipsDescendants = true,
		Parent = box,
		Theme = { PlaceholderColor3 = "TextMuted" },
	})
	self.field = field

	local clear
	if options.Clearable ~= false then
		clear = Factory.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(18, 18),
			Visible = false,
			Parent = box,
		})
		Icons.create({ Icon = "x", Color = "TextMuted" }, 14, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = clear,
		})
		self.cleanup:connect(clear.Activated, function()
			field.Text = ""
			self:_commit("")
		end)
	end

	self.error = Factory.text({
		Typography = "Description",
		Size = UDim2.fromOffset(190, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		Visible = false,
		LayoutOrder = 2,
		Parent = self.widget,
		Theme = { TextColor3 = "Danger" },
	})
	self.widget:FindFirstChildOfClass("UIListLayout").FillDirection = Enum.FillDirection.Vertical
	self.widget:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 4)

	self:bind(options.Default or "", function(value)
		if not field:IsFocused() then
			field.Text = value
		end
		if clear then
			clear.Visible = value ~= ""
		end
	end)

	self.cleanup:connect(field.Focused, function()
		Animations.tween(stroke, { Transparency = 0.4 }, Theme.Motion.Hover)
	end)
	self.cleanup:connect(field:GetPropertyChangedSignal("Text"), function()
		if clear then
			clear.Visible = field.Text ~= ""
		end
		if options.Live then
			self:_commit(field.Text)
		end
	end)
	self.cleanup:connect(field.FocusLost, function(enter)
		Animations.tween(stroke, { Transparency = 1 }, Theme.Motion.Hover)
		if enter or not options.SubmitOnEnter then
			self:_commit(field.Text)
		else
			field.Text = self:GetValue()
		end
		if enter then
			Util.safeCall(options.OnSubmit, self:GetValue())
		end
	end)

	self:register("input text")
	return self
end

function TextInput:_commit(text: string)
	local validate = self.options.Validate
	if validate then
		local ok, result = pcall(validate, text)
		local message = if ok then (if result == true or result == nil then nil else (if type(result) == "string" then result else "Invalid value")) else "Invalid value"
		self.error.Text = message or ""
		self.error.Visible = message ~= nil
		if message then
			return
		end
	end
	self:SetValue(text)
end

function TextInput:normalize(value)
	return tostring(value or "")
end

function TextInput:stateText()
	local value = self:GetValue()
	return if value ~= "" then value else nil
end

function TextInput:Focus()
	self.field:CaptureFocus()
end

return TextInput

end

-- Components/Keybind
loaders[nodes["Components/Keybind"]] = function(script, require)
local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Input = require(Core.Input)
local Util = require(Core.Util)
local Control = require(script.Parent.Control)

local IGNORED = {
	[Enum.KeyCode.Unknown] = true,
	[Enum.KeyCode.Escape] = true,
	[Enum.KeyCode.Backspace] = true,
	[Enum.KeyCode.Delete] = true,
}

local Keybind = Control.extend("Keybind")

function Keybind.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, options), Keybind)
	self.listening = false

	local chip = Factory.button({
		Name = "Key",
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0,
		LayoutOrder = 1,
		Parent = self.widget,
		Theme = { BackgroundColor3 = "SurfaceActive" },
	}, {
		Factory.corner(7),
		Factory.padding(0, 10),
		Factory.new("UISizeConstraint", { MinSize = Vector2.new(54, 26) }),
	})
	self.chip = chip

	self.chipLabel = Factory.text({
		Size = UDim2.fromScale(1, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Parent = chip,
	})

	local default = options.Default
	if typeof(default) ~= "EnumItem" then
		default = Enum.KeyCode.Unknown
	end
	self:bind(default, function()
		self:_render()
	end)

	self.cleanup:connect(chip.Activated, function()
		if not self.disabled then
			self:_listen(not self.listening)
		end
	end)

	self.cleanup:add(Input.listen(function(input, processed)
		if self.listening then
			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				if Input.isPointer(input) and not Input.inside(self.chip, Input.position(input)) then
					self:_listen(false)
				end
				return false
			end
			local key = input.KeyCode
			if key == Enum.KeyCode.Escape then
				self:_listen(false)
			elseif key == Enum.KeyCode.Backspace or key == Enum.KeyCode.Delete then
				self:_listen(false)
				self:SetValue(Enum.KeyCode.Unknown)
			elseif not IGNORED[key] then
				local reserved = ctx.isReserved and ctx.isReserved(key, self)
				if reserved then
					ctx.notify({ Title = "Key unavailable", Content = `{Input.keyName(key)} is used by {reserved}.`, Kind = "warning" })
				else
					self:_listen(false)
					self:SetValue(key)
				end
			end
			return true
		end

		local key = self:GetValue()
		if not processed and key ~= Enum.KeyCode.Unknown and input.KeyCode == key and options.OnPress then
			Util.safeCall(options.OnPress, key)
		end
		return false
	end))

	self:register("keybind key shortcut")
	return self
end

function Keybind:_listen(on: boolean)
	self.listening = on
	self:_render()
end

function Keybind:_render()
	local key = self:GetValue()
	if self.listening then
		self.chipLabel.Text = "Press a key"
		Theme.bind(self.chipLabel, { TextColor3 = "Accent" })
	else
		self.chipLabel.Text = if key == Enum.KeyCode.Unknown then "None" else Input.keyName(key)
		Theme.bind(self.chipLabel, { TextColor3 = if key == Enum.KeyCode.Unknown then "TextMuted" else "TextPrimary" })
	end
end

function Keybind:normalize(value)
	if typeof(value) == "EnumItem" then
		return value
	end
	if type(value) == "string" then
		local ok, item = pcall(function()
			return Enum.KeyCode[value]
		end)
		if ok then
			return item
		end
	end
	return Enum.KeyCode.Unknown
end

function Keybind:stateText()
	local key = self:GetValue()
	return if key == Enum.KeyCode.Unknown then nil else Input.keyName(key)
end

return Keybind

end

-- Components/Slider
loaders[nodes["Components/Slider"]] = function(script, require)
local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Input = require(Core.Input)
local Util = require(Core.Util)
local Control = require(script.Parent.Control)

local TRACK_WIDTH = 150

local Slider = Control.extend("Slider")

function Slider.new(ctx, parent, options)
	local min, max = options.Min or 0, options.Max or 100
	assert(max > min, "Slider Max must be greater than Min")
	local step = options.Step or 1
	local suffix = options.Suffix or ""

	local self = setmetatable(Control.new(ctx, parent, options), Slider)
	self.min, self.max, self.step = min, max, step

	local value = Factory.text({
		Name = "Value",
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(44, 20),
		LayoutOrder = 1,
		Parent = self.widget,
		Theme = { TextColor3 = "TextSecondary" },
	})

	local hit = Factory.button({
		Name = "Track",
		Size = UDim2.fromOffset(TRACK_WIDTH, 20),
		LayoutOrder = 2,
		Parent = self.widget,
	})

	local rail = Factory.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 4),
		Parent = hit,
		Theme = { BackgroundColor3 = "SurfaceActive" },
	}, { Factory.corner(2) })

	local fill = Factory.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		Parent = rail,
		Theme = { BackgroundColor3 = options.Color or "Accent" },
	}, { Factory.corner(2) })

	local thumb = Factory.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(14, 14),
		Parent = hit,
		Theme = { BackgroundColor3 = "Knob" },
	}, { Factory.corner(7), Factory.stroke("Border", 0.3) })

	local dragging = false
	local function render(v: number)
		local alpha = (v - min) / (max - min)
		local duration = if dragging then 0 else Theme.Motion.Toggle
		Animations.tween(fill, { Size = UDim2.fromScale(alpha, 1) }, duration)
		Animations.tween(thumb, { Position = UDim2.fromScale(alpha, 0.5) }, duration)
		value.Text = Util.format(v, step) .. suffix
	end

	self:bind(Util.snap(options.Default or min, min, max, step), render)

	local function fromPoint(point: Vector2)
		local alpha = math.clamp((point.X - hit.AbsolutePosition.X) / hit.AbsoluteSize.X, 0, 1)
		self:SetValue(min + alpha * (max - min))
	end

	self.cleanup:connect(hit.InputBegan, function(input)
		if self.disabled or not Input.isPointer(input) then
			return
		end
		if self.stopDrag then self.stopDrag() end
		dragging = true
		Animations.tween(thumb, { Size = UDim2.fromOffset(16, 16) }, Theme.Motion.Hover)
		self.stopDrag = Input.drag(input, fromPoint, function()
			dragging = false
			Animations.tween(thumb, { Size = UDim2.fromOffset(14, 14) }, Theme.Motion.Hover)
		end)
	end)
	self.cleanup:add(function()
		if self.stopDrag then
			self.stopDrag()
		end
	end)

	self:register("slider number")
	return self
end

function Slider:normalize(value)
	return Util.snap(tonumber(value) or self.min, self.min, self.max, self.step)
end

function Slider:stateText()
	return Util.format(self:GetValue(), self.step) .. (self.options.Suffix or "")
end

return Slider

end

-- Components/Toggle
loaders[nodes["Components/Toggle"]] = function(script, require)
local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Control = require(script.Parent.Control)

local WIDTH, HEIGHT, KNOB = 34, 20, 16

local Toggle = Control.extend("Toggle")

-- Bare switch, reused by card headers. Returns the button and a render(on) function.
function Toggle.switch(colors: { On: any?, Off: any? }?)
	local onToken = colors and colors.On or "Accent"
	local offToken = colors and colors.Off or "SurfaceActive"

	local track = Factory.button({
		Name = "Switch",
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 0,
		Theme = { BackgroundColor3 = offToken },
	}, { Factory.corner(HEIGHT // 2) })

	local knob = Factory.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(KNOB, KNOB),
		Parent = track,
		Theme = { BackgroundColor3 = "Knob" },
	}, { Factory.corner(KNOB // 2) })

	local first = true
	local function render(on: boolean)
		local duration = if first then 0 else Theme.Motion.Toggle
		first = false
		local old = track.BackgroundColor3
		Theme.bind(track, { BackgroundColor3 = if on then onToken else offToken })
		local target = track.BackgroundColor3
		track.BackgroundColor3 = old
		Animations.tween(track, { BackgroundColor3 = target }, duration)
		Animations.tween(knob, {
			Position = if on then UDim2.new(1, -KNOB - 2, 0.5, 0) else UDim2.new(0, 2, 0.5, 0),
		}, duration, Enum.EasingStyle.Quart)
	end
	return track, render
end

function Toggle.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, options), Toggle)

	local track, render = Toggle.switch({ On = options.OnColor, Off = options.OffColor })
	track.Parent = self.widget
	self.track = track

	self:bind(options.Default == true, render)
	self.cleanup:connect(track.Activated, function()
		if not self.disabled then
			self:SetValue(not self:GetValue())
		end
	end)

	self:register("toggle switch")
	return self
end

function Toggle:normalize(value)
	return value == true
end

function Toggle:stateText()
	return if self:GetValue() then "On" else "Off"
end

return Toggle

end

-- Core/Animations
loaders[nodes["Core/Animations"]] = function(script, require)
local TweenService = game:GetService("TweenService")

local Animations = { reducedMotion = false }

local running = setmetatable({}, { __mode = "k" })

local function cancel(inst: Instance, goal: { [string]: any })
	local props = running[inst]
	if not props then
		return
	end
	for prop in goal do
		local tween = props[prop]
		if tween then
			tween:Cancel()
			props[prop] = nil
		end
	end
end

function Animations.tween(inst: Instance, goal: { [string]: any }, duration: number?, style: Enum.EasingStyle?): Tween?
	cancel(inst, goal)
	if Animations.reducedMotion or not duration or duration <= 0 then
		for prop, value in goal do
			inst[prop] = value
		end
		return nil
	end

	local tween = TweenService:Create(
		inst,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		goal
	)
	local props = running[inst] or {}
	running[inst] = props
	for prop in goal do
		props[prop] = tween
	end
	tween:Play()
	return tween
end

function Animations.spin(inst: GuiObject): () -> ()
	if Animations.reducedMotion then
		return function() end
	end
	inst.Rotation = 0
	local tween = TweenService:Create(inst, TweenInfo.new(0.9, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
	tween:Play()
	return function()
		tween:Cancel()
		inst.Rotation = 0
	end
end

return Animations

end

-- Core/Blur
loaders[nodes["Core/Blur"]] = function(script, require)
local Lighting = game:GetService("Lighting")

local Animations = require(script.Parent.Animations)

-- One shared BlurEffect for every window; each owner asks for a size and the largest wins.
local NAME = "UILibraryBlur"

local Blur = {}

local owners = {}
local effect: BlurEffect?
local created = false
local originalSize = 0
local originalEnabled = false

local function target(): number
	local size = if originalEnabled then originalSize else 0
	for _, s in owners do
		size = math.max(size, s)
	end
	return size
end

local function ensure(): BlurEffect
	if effect and effect.Parent then
		return effect
	end
	local found = Lighting:FindFirstChild(NAME)
	if found and found:IsA("BlurEffect") then
		effect = found
		created = false
		originalSize, originalEnabled = found.Size, found.Enabled
	else
		effect = Instance.new("BlurEffect")
		effect.Name = NAME
		effect.Size = 0
		effect.Parent = Lighting
		created = true
		originalSize, originalEnabled = 0, false
	end
	return effect :: BlurEffect
end

function Blur.set(owner: any, size: number, duration: number?)
	assert(type(size) == "number" and size == size and math.abs(size) < math.huge, "BlurSize must be a finite number")
	local current = ensure()
	owners[owner] = math.clamp(size, 0, 56)
	current.Enabled = true
	Animations.tween(current, { Size = target() }, duration, Enum.EasingStyle.Quad)
end

function Blur.release(owner: any, duration: number?)
	if owners[owner] == nil and next(owners) ~= nil then
		return
	end
	owners[owner] = nil
	local current = effect
	if not current or not current.Parent then
		return
	end
	if next(owners) ~= nil then
		Animations.tween(current, { Size = target() }, duration, Enum.EasingStyle.Quad)
		return
	end
	local function done()
		if next(owners) == nil and effect == current then
			effect = nil
			if created then
				current:Destroy()
			else
				current.Size, current.Enabled = originalSize, originalEnabled
			end
		end
	end
	local tween = Animations.tween(current, { Size = if originalEnabled then originalSize else 0 }, duration, Enum.EasingStyle.Quad)
	if tween then
		tween.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then
				done()
			end
		end)
	else
		done()
	end
end

function Blur.instanceCount(): number
	local count = 0
	for _, child in Lighting:GetChildren() do
		if child.Name == NAME then
			count += 1
		end
	end
	return count
end

return Blur

end

-- Core/Cleanup
loaders[nodes["Core/Cleanup"]] = function(script, require)
local Cleanup = {}
Cleanup.__index = Cleanup

export type Task = RBXScriptConnection | Instance | (() -> ()) | { Destroy: (any) -> () }

function Cleanup.new()
	return setmetatable({ tasks = {} }, Cleanup)
end

function Cleanup:add<T>(task: T): T
	table.insert(self.tasks, task)
	return task
end

function Cleanup:connect(signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	return self:add(signal:Connect(fn))
end

function Cleanup:count(): number
	return #self.tasks
end

function Cleanup:clean()
	local tasks = self.tasks
	for i = #tasks, 1, -1 do
		local task = tasks[i]
		tasks[i] = nil
		local kind = typeof(task)
		if kind == "RBXScriptConnection" then
			task:Disconnect()
		elseif kind == "Instance" then
			task:Destroy()
		elseif kind == "function" then
			task()
		elseif kind == "table" and task.Destroy then
			task:Destroy()
		end
	end
end

Cleanup.Destroy = Cleanup.clean

return Cleanup

end

-- Core/Factory
loaders[nodes["Core/Factory"]] = function(script, require)
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

end

-- Core/Icons
loaders[nodes["Core/Icons"]] = function(script, require)
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

end

-- Core/Input
loaders[nodes["Core/Input"]] = function(script, require)
local UserInputService = game:GetService("UserInputService")

local Input = {}

local NAMES = {
	LeftShift = "Left Shift",
	RightShift = "Right Shift",
	LeftControl = "Left Ctrl",
	RightControl = "Right Ctrl",
	LeftAlt = "Left Alt",
	RightAlt = "Right Alt",
	Return = "Enter",
	Backspace = "Backspace",
	Space = "Space",
	Escape = "Esc",
	Comma = ",",
	Period = ".",
	Slash = "/",
	Semicolon = ";",
	Quote = "'",
	LeftBracket = "[",
	RightBracket = "]",
	BackSlash = "\\",
	Minus = "-",
	Equals = "=",
	Backquote = "`",
	Up = "↑",
	Down = "↓",
	Left = "←",
	Right = "→",
	MouseButton1 = "Mouse 1",
	MouseButton2 = "Mouse 2",
	MouseButton3 = "Mouse 3",
}

for i = 0, 9 do
	local names = { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" }
	NAMES[names[i + 1]] = tostring(i)
end

function Input.keyName(key: EnumItem?): string
	if not key then
		return "None"
	end
	return NAMES[key.Name] or key.Name
end

function Input.ctrlDown(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.LeftSuper)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightSuper)
end

function Input.isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

function Input.isMove(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

-- InputObject.Position and AbsolutePosition already use screen pixels; do not add the inset twice.
function Input.position(input: InputObject): Vector2
	return Vector2.new(input.Position.X, input.Position.Y)
end

function Input.inside(gui: GuiObject, point: Vector2): boolean
	local pos, size = gui.AbsolutePosition, gui.AbsoluteSize
	return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

-- Calls onMove(position) until the pointer is released. Returns a stop function.
function Input.drag(start: InputObject, onMove: (Vector2) -> (), onEnd: (() -> ())?): () -> ()
	local moved, ended
	local function stop()
		if moved then
			moved:Disconnect()
			ended:Disconnect()
			moved = nil
			if onEnd then
				onEnd()
			end
		end
	end

	moved = UserInputService.InputChanged:Connect(function(input)
		if (start.UserInputType == Enum.UserInputType.Touch and input == start)
			or (start.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then
			onMove(Input.position(input))
		end
	end)
	ended = UserInputService.InputEnded:Connect(function(input)
		if input == start or (start.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.MouseButton1) then
			stop()
		end
	end)
	onMove(Input.position(start))
	return stop
end

-- One shared InputBegan connection; handlers run newest-first and may return true to consume.
local handlers = {}
local connection

function Input.listen(fn: (InputObject, boolean) -> boolean?): () -> ()
	table.insert(handlers, fn)
	if not connection then
		connection = UserInputService.InputBegan:Connect(function(input, processed)
			for i = #handlers, 1, -1 do
				local handler = handlers[i]
				if handler and handler(input, processed) then
					return
				end
			end
		end)
	end
	return function()
		local index = table.find(handlers, fn)
		if index then
			table.remove(handlers, index)
		end
		if #handlers == 0 and connection then
			connection:Disconnect()
			connection = nil
		end
	end
end

function Input.handlerCount(): number
	return #handlers
end

return Input

end

-- Core/Registry
loaders[nodes["Core/Registry"]] = function(script, require)
local Registry = {}
Registry.__index = Registry

export type Entry = {
	id: string,
	kind: "page" | "card" | "control",
	title: string,
	subtitle: string?,
	keywords: string?,
	aliases: (string | { string })?,
	icon: any?,
	state: (() -> string?)?,
	shortcut: string?,
	activate: () -> (),
	visible: (() -> boolean)?,
}

function Registry.new()
	return setmetatable({ entries = {}, order = {}, counter = 0 }, Registry)
end

function Registry:add(entry: Entry): () -> ()
	assert(type(entry.id) == "string" and entry.id ~= "" and type(entry.title) == "string" and type(entry.activate) == "function", "Search entries need an id, title and activate callback")
	self:remove(entry.id)
	self.counter += 1
	local record = {
		entry = entry,
		index = self.counter,
		title = string.lower(entry.title),
		haystack = "",
	}
	self.entries[entry.id] = record
	table.insert(self.order, record)
	self:update(entry.id, {})
	return function()
		if self.entries[entry.id] == record then
			self:remove(entry.id)
		end
	end
end

function Registry:remove(id: string)
	local record = self.entries[id]
	if record then
		self.entries[id] = nil
		local index = table.find(self.order, record)
		if index then
			table.remove(self.order, index)
		end
	end
end

function Registry:update(id: string, fields: { [string]: any })
	local record = self.entries[id]
	if not record then
		return
	end
	for key, value in fields do
		record.entry[key] = value
	end
	local entry = record.entry
	record.title = string.lower(entry.title)
	local aliases = if type(entry.aliases) == "table" then table.concat(entry.aliases, " ") else entry.aliases or ""
	record.haystack = string.lower(`{entry.title} {entry.subtitle or ""} {entry.keywords or ""} {aliases}`)
end

function Registry:get(id: string): Entry?
	local record = self.entries[id]
	return record and record.entry
end

function Registry:count(): number
	return #self.order
end

local KIND_BONUS = { page = 30, card = 20, control = 0 }

local function score(record, terms: { string }): number?
	local total = KIND_BONUS[record.entry.kind] or 0
	local phrase = table.concat(terms, " ")
	if record.title == phrase then
		total += 1000
	elseif string.sub(record.title, 1, #phrase) == phrase then
		total += 500
	end
	for i, term in terms do
		local at = string.find(record.haystack, term, 1, true)
		if not at then
			return nil
		end
		if i == 1 and string.sub(record.title, 1, #term) == term then
			total += 100
		elseif string.find(record.title, " " .. term, 1, true) then
			total += 60
		elseif string.find(record.title, term, 1, true) then
			total += 40
		else
			total += 10
		end
	end
	return total - #record.title * 0.1
end

function Registry:search(query: string, limit: number?): { Entry }
	local terms = string.split(string.lower(query), " ")
	for i = #terms, 1, -1 do
		if terms[i] == "" then
			table.remove(terms, i)
		end
	end

	local hits = {}
	for _, record in self.order do
		local visible = record.entry.visible
		if visible and not visible() then
			continue
		end
		local value = if #terms == 0 then 0 else score(record, terms)
		if value then
			table.insert(hits, { record = record, score = value })
		end
	end

	table.sort(hits, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.record.index < b.record.index
	end)

	local out = {}
	for i = 1, math.min(#hits, limit or 50) do
		out[i] = hits[i].record.entry
	end
	return out
end

return Registry

end

-- Core/Store
loaders[nodes["Core/Store"]] = function(script, require)
local Store = {}
Store.__index = Store

export type Adapter = {
	Load: (() -> { [string]: any }?)?,
	Save: (({ [string]: any }) -> ())?,
	Delay: number?,
}

local function encode(value: any): any
	local kind = typeof(value)
	if kind == "Color3" then
		return { __color = value:ToHex() }
	elseif kind == "EnumItem" then
		return { __enum = tostring(value.EnumType), name = value.Name }
	elseif kind == "table" then
		local out = {}
		for key, item in value do
			out[key] = encode(item)
		end
		return out
	end
	return value
end

local function decode(value: any): any
	if type(value) ~= "table" then
		return value
	end
	if value.__color then
		local ok, color = pcall(Color3.fromHex, value.__color)
		return if ok then color else nil
	end
	if value.__enum then
		local ok, item = pcall(function()
			return Enum[value.__enum][value.name]
		end)
		return if ok then item else nil
	end
	local out = {}
	for key, item in value do
		out[key] = decode(item)
	end
	return out
end

Store.encode = encode
Store.decode = decode

function Store.new(adapter: Adapter?)
	local self = setmetatable({ values = {}, listeners = {}, saved = {}, adapter = adapter, auto = 0 }, Store)
	if adapter and adapter.Load then
		local ok, data = pcall(adapter.Load)
		if ok and type(data) == "table" then
			self.saved = data
		elseif not ok then
			warn(`[MacUI] settings failed to load: {data}`)
		end
	end
	return self
end

function Store:define(id: string?, default: any): (string, any)
	if id == nil then
		self.auto += 1
		id = `_auto{self.auto}`
	elseif self.values[id] ~= nil then
		warn(`[MacUI] flag "{id}" is registered twice; the later control replaces it`)
	end

	local value = default
	local raw = self.saved[id]
	if raw ~= nil then
		local decoded = decode(raw)
		if decoded ~= nil and typeof(decoded) == typeof(default) then
			value = decoded
		end
	end
	self.values[id] = value
	return id, value
end

function Store:get(id: string): any
	return self.values[id]
end

function Store:set(id: string, value: any): boolean
	local old = self.values[id]
	if old == value and type(value) ~= "table" then
		return false
	end
	self.values[id] = value
	local list = self.listeners[id]
	if list then
		for _, fn in table.clone(list) do
			fn(value, old)
		end
	end
	self:_queueSave()
	return true
end

function Store:observe(id: string, fn: (any, any) -> ()): () -> ()
	local list = self.listeners[id]
	if not list then
		list = {}
		self.listeners[id] = list
	end
	table.insert(list, fn)
	return function()
		local index = table.find(list, fn)
		if index then
			table.remove(list, index)
		end
	end
end

-- Drops the value only; other subscribers (e.g. Window:OnFlagChanged) keep their listeners.
function Store:remove(id: string)
	self.values[id] = nil
end

function Store:snapshot(): { [string]: any }
	local out = {}
	for id, value in self.values do
		if string.sub(id, 1, 1) ~= "_" then
			out[id] = encode(value)
		end
	end
	return out
end

function Store:_queueSave()
	local adapter = self.adapter
	if not (adapter and adapter.Save) or self.pending then
		return
	end
	self.pending = true
	task.delay(adapter.Delay or 2, function()
		self.pending = false
		local ok, err = pcall(adapter.Save, self:snapshot())
		if not ok then
			warn(`[MacUI] settings failed to save: {err}`)
		end
	end)
end

return Store

end

-- Core/Theme
loaders[nodes["Core/Theme"]] = function(script, require)
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

end

-- Core/Util
loaders[nodes["Core/Util"]] = function(script, require)
local Util = {}

function Util.safeCall(fn: ((...any) -> ())?, ...: any)
	if not fn then
		return
	end
	task.spawn(function(...)
		local ok, err = xpcall(fn, debug.traceback, ...)
		if not ok then
			warn(`[MacUI] callback error: {err}`)
		end
	end, ...)
end

function Util.decimals(step: number): number
	local text = tostring(step)
	local dot = string.find(text, ".", 1, true)
	return if dot then #text - dot else 0
end

function Util.snap(value: number, min: number, max: number, step: number?): number
	local size = if step and step > 0 then step else 1
	local snapped = math.clamp(min + math.round((value - min) / size) * size, min, max)
	local factor = 10 ^ Util.decimals(size)
	return math.round(snapped * factor) / factor
end

function Util.format(value: number, step: number?): string
	return string.format(`%.{Util.decimals(step or 1)}f`, value)
end

function Util.merge(base: { [any]: any }, extra: { [any]: any }?): { [any]: any }
	local out = table.clone(base)
	for key, value in extra or {} do
		out[key] = value
	end
	return out
end

function Util.trim(text: string): string
	return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

return Util

end

-- Overlays/CommandPalette
loaders[nodes["Overlays/CommandPalette"]] = function(script, require)
local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Icons = require(Core.Icons)
local Input = require(Core.Input)
local Cleanup = require(Core.Cleanup)

local HEADER, FOOTER, ROW, GAP, PAD = 52, 30, 42, 2, 6
local MOTION = 0.16

local CommandPalette = {}
CommandPalette.__index = CommandPalette

-- All geometry uses the foreground's safe viewport, at native pixel scale.
function CommandPalette.layout(area: Vector2, count: number)
	local width = math.min(560, math.floor(area.X * 0.9))
	local rows = math.clamp(count, 1, 7)
	local margin = math.min(12, math.floor(area.Y / 2))
	local height = math.min(420, area.Y - margin * 2, HEADER + FOOTER + 2 + PAD * 2 + rows * ROW + (rows - 1) * GAP)
	return {
		width = width,
		height = height,
		listHeight = math.max(0, height - HEADER - FOOTER - 2),
		x = math.round((area.X - width) / 2),
		y = math.clamp(math.round(area.Y * 0.18), margin, math.max(margin, area.Y - height - margin)),
	}
end

function CommandPalette.new(window)
	return setmetatable({ window = window, lastQuery = "" }, CommandPalette)
end

function CommandPalette:isOpen(): boolean
	return self.popup ~= nil
end

function CommandPalette:refresh()
	if self.closing then self.closing.finish() end
	if self.session then self.session.refresh() end
end

function CommandPalette:toggle()
	if self.popup then
		self.popup.close()
	else
		self:open()
	end
end

-- Window's existing shared listener handles keys; opening adds no global listener.
function CommandPalette:handleInput(input): boolean
	local session = self.session
	if not self.popup or not session then
		return false
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.Escape then
		self.popup.close()
	elseif key == Enum.KeyCode.Down or (key == Enum.KeyCode.Tab and not Input.ctrlDown()) then
		session.highlight(math.min(session.selected + 1, #session.results), true)
	elseif key == Enum.KeyCode.Up then
		session.highlight(math.max(session.selected - 1, 1), true)
	elseif key == Enum.KeyCode.Return or key == Enum.KeyCode.KeypadEnter then
		session.activate(session.selected)
	else
		return false
	end
	return true
end

function CommandPalette:open(initial: string?)
	if self.destroyed then
		return
	end
	if self.popup then
		if initial ~= nil then
			self.session.query.Text = initial
		end
		self.session.query:CaptureFocus()
		return
	end
	if self.closing then
		self.closing.finish()
	end
	local window = self.window
	window:_buildAll()
	window.ctx.popups:closeAll()
	local registry = window.ctx.registry
	local cleanup = Cleanup.new()
	local session = { cleanup = cleanup, rows = {}, results = {}, selected = 0, open = true }
	self.session = session

	-- Dimming covers the visual viewport; controls respect CoreGui/device safe insets.
	local backdropGui = cleanup:add(Factory.new("ScreenGui", {
		Name = "CommandPaletteBackdrop",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.None,
		ClipToDeviceSafeArea = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = window.gui.DisplayOrder + 1,
		Parent = window.gui.Parent,
	}))
	local dim = Factory.new("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
		Interactable = false,
		Parent = backdropGui,
		Theme = { BackgroundColor3 = "Scrim" },
	})
	local foregroundGui = cleanup:add(Factory.new("ScreenGui", {
		Name = "CommandPaletteOverlay",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = window.gui.DisplayOrder + 2,
		Parent = window.gui.Parent,
	}))
	local layer = Factory.new("Frame", {
		Name = "SafeArea",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = foregroundGui,
	})
	session.layer, session.backdrop = layer, dim
	local position = Factory.new("Frame", {
		Name = "PalettePosition",
		BackgroundTransparency = 1,
		Active = true,
	})
	local surface = Factory.new("Frame", {
		Name = "CommandPalette",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0.03,
		ClipsDescendants = true,
		Active = true,
		Parent = position,
		Theme = { BackgroundColor3 = "Palette" },
	}, { Factory.corner(15), Factory.stroke("PaletteBorder", 0.2) })
	session.surface = surface

	Icons.create({ Icon = "magnifying-glass", Color = "TextSecondary" }, 18, {
		Position = UDim2.fromOffset(16, 17),
		Parent = surface,
	})
	local query = Factory.text({
		Name = "Query",
		ClassName = "TextBox",
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(1, -106, 0, HEADER),
		Text = initial or (if window.options.PalettePreserveQuery then self.lastQuery else ""),
		Typography = "Search",
		PlaceholderText = "Search features, settings and pages...",
		ClearTextOnFocus = false,
		TextTruncate = Enum.TextTruncate.None,
		ClipsDescendants = true,
		Parent = surface,
		Theme = { PlaceholderColor3 = "PalettePlaceholder" },
	})
	session.query = query
	Factory.text({
		Text = "ESC",
		Typography = "Hint",
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(1, -48, 0, 16),
		Size = UDim2.fromOffset(32, 20),
		BackgroundTransparency = 0,
		Parent = surface,
		Theme = { TextColor3 = "TextSecondary", BackgroundColor3 = "SurfaceHover" },
	}, { Factory.corner(5) })
	Factory.new("Frame", {
		Position = UDim2.fromOffset(0, HEADER),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = surface,
		Theme = { BackgroundColor3 = "PaletteDivider" },
	})
	local list = Factory.new("ScrollingFrame", {
		Name = "Results",
		Position = UDim2.fromOffset(0, HEADER + 1),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		VerticalScrollBarInset = Enum.ScrollBarInset.None,
		ClipsDescendants = true,
		Parent = surface,
		Theme = { ScrollBarImageColor3 = "Border" },
	})
	session.list = list
	Factory.new("Frame", {
		Position = UDim2.new(0, 0, 1, -FOOTER - 1),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = surface,
		Theme = { BackgroundColor3 = "PaletteDivider" },
	})
	Factory.text({
		Text = "↑↓  Navigate     ↵  Open     Esc  Close",
		Typography = "Hint",
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 8, 1, -FOOTER),
		Size = UDim2.new(1, -16, 0, FOOTER),
		Parent = surface,
		Theme = { TextColor3 = "TextSecondary" },
	})

	local function place()
		local geometry = CommandPalette.layout(layer.AbsoluteSize, #session.results)
		position.Size = UDim2.fromOffset(geometry.width, geometry.height)
		position.Position = UDim2.fromOffset(geometry.x, geometry.y)
		list.Size = UDim2.new(1, 0, 0, geometry.listHeight)
		for _, row in session.rows do
			if row:IsA("TextButton") then
				local available = math.max(0, geometry.width - PAD * 2 - 54 - row:GetAttribute("StatusWidth"))
				local titleWidth = math.floor(available * 0.55)
				row.Title.Size = UDim2.fromOffset(titleWidth, ROW)
				row.Path.Position = UDim2.fromOffset(42 + titleWidth + 8, 0)
				row.Path.Size = UDim2.fromOffset(math.max(0, available - titleWidth - 8), ROW)
			end
		end
	end
	session.highlight = function(index: number, scroll: boolean?)
		session.selected = if #session.results == 0 then 0 else math.clamp(index, 1, #session.results)
		for i, row in session.rows do
			if row:IsA("TextButton") then
				Animations.tween(row, { BackgroundTransparency = if i == session.selected then 0 else 1 }, 0.08)
			end
		end
		if scroll and session.selected > 0 then
			local top = PAD + (session.selected - 1) * (ROW + GAP)
			local y, view = list.CanvasPosition.Y, list.AbsoluteWindowSize.Y
			if top < y then
				list.CanvasPosition = Vector2.new(0, top)
			elseif top + ROW > y + view then
				list.CanvasPosition = Vector2.new(0, math.max(0, top + ROW - view))
			end
		end
	end
	session.activate = function(index: number)
		local entry = session.results[index]
		if entry and self.popup then
			self.popup.close()
			entry.activate()
		end
	end
	local function render()
		for _, row in session.rows do
			row:Destroy()
		end
		table.clear(session.rows)
		session.results = registry:search(query.Text, registry:count())
		for i, entry in session.results do
			local row = Factory.button({
				Name = "Result",
				Position = UDim2.fromOffset(PAD, PAD + (i - 1) * (ROW + GAP)),
				Size = UDim2.new(1, -PAD * 2, 0, ROW),
				Parent = list,
				Theme = { BackgroundColor3 = "PaletteSelected" },
			}, { Factory.corner(8) })
			Icons.create(Icons.spec(entry.icon), 18, { Position = UDim2.fromOffset(12, 12), Parent = row })
			Factory.text({
				Name = "Title",
				Text = entry.title,
				Typography = "Feature",
				Position = UDim2.fromOffset(42, 0),
				Parent = row,
			})
			Factory.text({
				Name = "Path",
				Text = entry.subtitle or "",
				Typography = "Description",
				Parent = row,
				Theme = { TextColor3 = "TextSecondary" },
			})
			local state = entry.state and entry.state()
			local status = state or entry.shortcut
			row:SetAttribute("StatusWidth", if status then 64 else 0)
			if status then
				Factory.text({
					Text = status,
					Typography = "Description",
					TextXAlignment = Enum.TextXAlignment.Right,
					Position = UDim2.new(1, -72, 0, 0),
					Size = UDim2.fromOffset(60, ROW),
					Parent = row,
					Theme = { TextColor3 = "TextSecondary" },
				})
			end
			row.MouseEnter:Connect(function()
				if session.open then session.highlight(i) end
			end)
			row.Activated:Connect(function()
				session.activate(i)
			end)
			session.rows[i] = row
		end
		if #session.results == 0 then
			session.rows[1] = Factory.text({
				Text = "No matching features",
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(PAD, PAD),
				Size = UDim2.new(1, -PAD * 2, 0, ROW),
				Parent = list,
				Theme = { TextColor3 = "TextSecondary" },
			})
		end
		local count = math.max(1, #session.results)
		list.CanvasSize = UDim2.fromOffset(0, PAD * 2 + count * ROW + (count - 1) * GAP)
		place()
		list.CanvasPosition = Vector2.zero
		session.highlight(1)
	end
	session.refresh = render
	local changed = cleanup:connect(query:GetPropertyChangedSignal("Text"), render)
	render()

	local group
	local function fadeGroup()
		if not group then
			group = Factory.new("CanvasGroup", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Parent = position,
			}, { Factory.corner(15) })
			surface.Parent = group
		end
		return group
	end
	local managerFinish
	session.finish = function()
		if session.finished then return end
		session.finished = true
		if managerFinish then managerFinish() end
		cleanup:clean()
		if self.closing == session then self.closing = nil end
	end
	self.popup = window.ctx.popups:open({
		content = position,
		layer = layer,
		backdrop = dim,
		scale = 1,
		modal = true,
		place = place,
		onClose = function()
			session.open = false
			self.lastQuery = query.Text
			changed:Disconnect()
			query:ReleaseFocus()
			self.popup, self.session = nil, nil
			self.closing = session
			-- Retiring visuals must stop intercepting input before the fade ends.
			for _, inst in foregroundGui:GetDescendants() do
				if inst:IsA("GuiObject") then inst.Interactable = false end
			end
		end,
		onClosing = function(finish)
			managerFinish = finish
			if self.destroyed or window.destroyed or Animations.reducedMotion then
				session.finish()
				return
			end
			local fade = fadeGroup()
			Animations.tween(dim, { BackgroundTransparency = 1 }, MOTION)
			local tween = Animations.tween(fade, { GroupTransparency = 1 }, MOTION)
			cleanup:connect(tween.Completed, function(state)
				if state == Enum.PlaybackState.Completed then session.finish() end
			end)
		end,
	})
	if not Animations.reducedMotion then
		local fade = fadeGroup()
		fade.GroupTransparency = 1
		fade.Position = UDim2.fromOffset(0, 8)
		Animations.tween(fade, { Position = UDim2.new() }, MOTION)
		local tween = Animations.tween(fade, { GroupTransparency = 0 }, MOTION)
		cleanup:connect(tween.Completed, function(state)
			if state == Enum.PlaybackState.Completed and session.open then
				surface.Parent = position
				group:Destroy()
				group = nil
			end
		end)
	end
	task.defer(function()
		if session.open then
			query:CaptureFocus()
			query.CursorPosition = #query.Text + 1
		end
	end)
end

function CommandPalette:Destroy()
	self.destroyed = true
	if self.popup then self.popup.close() end
	if self.closing then self.closing.finish() end
end

return CommandPalette

end

-- Overlays/Dialog
loaders[nodes["Overlays/Dialog"]] = function(script, require)
local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Util = require(Core.Util)
local PopupManager = require(script.Parent.PopupManager)
local Button = require(script.Parent.Parent.Components.Button)

local Dialog = {}

export type Options = {
	Title: string,
	Content: string?,
	ConfirmText: string?,
	CancelText: string?,
	Destructive: boolean?,
	OnConfirm: (() -> ())?,
	OnCancel: (() -> ())?,
}

function Dialog.confirm(popups, within: GuiObject, options: Options)
	local surface = PopupManager.surface(360, { Name = "Dialog" })
	surface:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 15)
	Factory.list(6).Parent = surface
	Factory.padding(18).Parent = surface

	Factory.text({
		Text = options.Title,
		Typography = "WindowTitle",
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = 1,
		Parent = surface,
	})
	if options.Content then
		Factory.text({
			Text = options.Content,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = surface,
			Theme = { TextColor3 = "TextSecondary" },
		})
	end

	local actions = Factory.new("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = surface,
	}, {
		Factory.padding(12, 0, 0, 0),
		Factory.list(8, true, { HorizontalAlignment = Enum.HorizontalAlignment.Right }),
	})

	local popup
	local decided = false
	local function finish(confirmed: boolean)
		if decided then
			return
		end
		decided = true
		popup.close()
		Util.safeCall(if confirmed then options.OnConfirm else options.OnCancel)
	end

	local cancel = Button.make({ Text = options.CancelText or "Cancel", Variant = "Ghost", LayoutOrder = 1 })
	cancel.Parent = actions
	cancel.Activated:Connect(function()
		finish(false)
	end)

	local confirm = Button.make({
		Text = options.ConfirmText or "Confirm",
		Variant = if options.Destructive then "Destructive" else "Primary",
		LayoutOrder = 2,
	})
	confirm.Parent = actions
	confirm.Activated:Connect(function()
		finish(true)
	end)

	popup = popups:open({
		content = surface,
		within = within,
		placement = "center",
		modal = true,
		onClose = function()
			if not decided then
				decided = true
				Util.safeCall(options.OnCancel)
			end
		end,
	})
	return popup
end

return Dialog

end

-- Overlays/Notifications
loaders[nodes["Overlays/Notifications"]] = function(script, require)
local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Icons = require(Core.Icons)
local Cleanup = require(Core.Cleanup)
local Util = require(Core.Util)

local WIDTH = 320
local MAX_VISIBLE = 4

local KINDS = {
	info = { "circle-i", "Accent" },
	success = { "circle-check", "Success" },
	warning = { "triangle-exclamation", "Warning" },
	error = { "circle-x", "Danger" },
}

local Notifications = {}
Notifications.__index = Notifications

export type Options = {
	Title: string,
	Content: string?,
	Duration: number?,
	Kind: ("info" | "success" | "warning" | "error")?,
	Actions: { { Text: string, Callback: (() -> ())? } }?,
}

function Notifications.new(gui: ScreenGui)
	local self = setmetatable({ cleanup = Cleanup.new(), active = {} }, Notifications)
	self.holder = self.cleanup:add(Factory.new("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 100,
		Parent = gui,
	}, {
		Factory.list(8, false, { VerticalAlignment = Enum.VerticalAlignment.Bottom }),
	}))
	self.uiScale = Factory.new("UIScale", { Parent = self.holder })
	return self
end

function Notifications:setScale(scale: number)
	self.uiScale.Scale = scale
end

function Notifications:notify(options: Options)
	local kind = KINDS[string.lower(options.Kind or "info")] or KINDS.info
	local order = (self.counter or 0) + 1
	self.counter = order

	local slot = Factory.new("Frame", {
		Name = "ToastRoot",
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = order,
		Parent = self.holder,
	})

	local card = Factory.new("Frame", {
		Name = "Surface",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(WIDTH + 24, 0),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = slot,
		Theme = { BackgroundColor3 = "Palette" },
	}, {
		Factory.corner(12),
		Factory.new("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			Thickness = 1,
			Theme = { Color = "PaletteBorder" },
		}),
		Factory.padding(12, 14),
	})

	Icons.create({ Icon = kind[1], Color = kind[2] }, 18, { Position = UDim2.fromOffset(0, 1), Parent = card })
	local text = Factory.new("Frame", {
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -52, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card,
	}, { Factory.list(3) })
	Factory.text({
		Text = options.Title,
		Typography = "Section",
		Size = UDim2.new(1, 0, 0, 18),
		Parent = text,
	})
	if options.Content then
		Factory.text({
			Text = options.Content,
			Typography = "Description",
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = text,
			Theme = { TextColor3 = "TextSecondary" },
		})
	end

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		local index = table.find(self.active, close)
		if index then
			table.remove(self.active, index)
		end
		local height = math.round(slot.AbsoluteSize.Y / math.max(self.uiScale.Scale, 0.01))
		slot.AutomaticSize = Enum.AutomaticSize.None
		slot.Size = UDim2.new(1, 0, 0, height)
		Animations.tween(card, { Position = UDim2.fromOffset(WIDTH + 24, 0) }, Theme.Motion.Notify, Enum.EasingStyle.Quad)
		local tween = Animations.tween(slot, { Size = UDim2.new(1, 0, 0, 0) }, Theme.Motion.Notify)
		if tween then
			tween.Completed:Once(function()
				slot:Destroy()
			end)
		else
			slot:Destroy()
		end
	end

	if options.Actions then
		local row = Factory.new("Frame", {
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			Parent = text,
		}, { Factory.list(6, true), Factory.padding(6, 0, 0, 0) })
		row.AutomaticSize = Enum.AutomaticSize.Y
		for i, action in options.Actions do
			local button = require(script.Parent.Parent.Components.Button).make({
				Text = action.Text,
				Variant = if i == 1 then "Primary" else "Secondary",
				Height = 24,
				LayoutOrder = i,
			})
			button.Parent = row
			button.Activated:Connect(function()
				Util.safeCall(action.Callback)
				close()
			end)
		end
	end

	local closeButton = Factory.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(18, 18),
		Parent = card,
	})
	Icons.create({ Icon = "x", Color = "TextMuted" }, 14, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = closeButton,
	})
	closeButton.Activated:Connect(close)

	task.defer(function()
		if closed then
			return
		end
		local height = math.round(card.AbsoluteSize.Y / math.max(self.uiScale.Scale, 0.01))
		local tween = Animations.tween(slot, { Size = UDim2.new(1, 0, 0, height) }, Theme.Motion.Notify)
		Animations.tween(card, { Position = UDim2.fromOffset(0, 0) }, Theme.Motion.Notify, Enum.EasingStyle.Quint)
		local function fit()
			if not closed then
				slot.AutomaticSize = Enum.AutomaticSize.Y
				slot.Size = UDim2.new(1, 0, 0, 0)
			end
		end
		if tween then
			tween.Completed:Once(fit)
		else
			fit()
		end
	end)

	table.insert(self.active, close)
	while #self.active > MAX_VISIBLE do
		self.active[1]()
	end

	local duration = options.Duration or 4
	if duration > 0 then
		task.delay(duration, close)
	end
	return close
end

function Notifications:count(): number
	return #self.active
end

function Notifications:Destroy()
	self.cleanup:clean()
end

return Notifications

end

-- Overlays/PopupManager
loaders[nodes["Overlays/PopupManager"]] = function(script, require)
local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Input = require(Core.Input)
local Cleanup = require(Core.Cleanup)

local MARGIN = 8

local PopupManager = {}
PopupManager.__index = PopupManager

export type Policy = {
	OpenOn: "Click"?,
	CloseOnOutsideClick: boolean?,
	CloseOnEscape: boolean?,
	CloseOnMouseLeave: false?,
	CloseOnInteraction: false?,
}

export type Options = {
	content: GuiObject,
	anchor: GuiObject?,
	within: GuiObject?,
	align: "left" | "right" | nil,
	placement: "below" | "center" | nil,
	gap: number?,
	modal: boolean?,
	dismissible: boolean?,
	onClose: (() -> ())?,
	layer: GuiObject?,
	backdrop: GuiObject?,
	scale: number?,
	place: ((any) -> ())?,
	onClosing: ((() -> ()) -> ())?,
	owner: any?,
	group: string?,
	regions: { GuiObject }?,
	policy: Policy?,
}

function PopupManager.new(gui: ScreenGui)
	local self = setmetatable({
		stack = {},
		closing = {},
		scale = 1,
		cleanup = Cleanup.new(),
	}, PopupManager)

	self.layer = self.cleanup:add(Factory.new("Frame", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = gui,
	}))

	self.cleanup:add(Input.listen(function(input)
		return self:_input(input)
	end))
	return self
end

function PopupManager:_input(input: InputObject): boolean
	local top = self.stack[#self.stack]
	if not top then
		return false
	end

	if input.KeyCode == Enum.KeyCode.Escape then
		if top.closeOnEscape then
			top.close()
		end
		return true
	end

	if Input.isPointer(input) then
		local point = Input.position(input)
		-- Use the stack at InputBegan; callbacks may open/close overlays during this input.
		local stack = table.clone(self.stack)
		for i = #stack, 1, -1 do
			local popup = stack[i]
			if not popup.open then continue end
			local inside = Input.inside(popup.frame, point) or (popup.anchor and Input.inside(popup.anchor, point))
			for _, region in popup.regions do
				inside = inside or (region.Parent ~= nil and Input.inside(region, point))
			end
			if inside or not popup.closeOnOutsideClick then
				break
			end
			popup.close()
			if popup.modal then break end
		end
	end
	return false
end

function PopupManager:_place(popup)
	local frame, layer = popup.frame, popup.layer
	local size = frame.AbsoluteSize
	local bounds = layer.AbsoluteSize
	local x, y

	if popup.placement == "center" then
		local within = popup.within or layer
		local pos, area = within.AbsolutePosition - layer.AbsolutePosition, within.AbsoluteSize
		x = pos.X + (area.X - size.X) / 2
		y = pos.Y + math.min(area.Y * 0.16, math.max(area.Y - size.Y, 0) / 2)
	elseif popup.anchor then
		local pos, area = popup.anchor.AbsolutePosition - layer.AbsolutePosition, popup.anchor.AbsoluteSize
		local gap = (popup.gap or 6) * self.scale
		x = if popup.align == "right" then pos.X + area.X - size.X else pos.X
		y = pos.Y + area.Y + gap
		if y + size.Y > bounds.Y - MARGIN and pos.Y - gap - size.Y >= MARGIN then
			y = pos.Y - gap - size.Y
		end
	else
		x, y = (bounds.X - size.X) / 2, (bounds.Y - size.Y) / 2
	end

	x = math.clamp(x, MARGIN, math.max(MARGIN, bounds.X - size.X - MARGIN))
	y = math.clamp(y, MARGIN, math.max(MARGIN, bounds.Y - size.Y - MARGIN))
	frame.Position = UDim2.fromOffset(math.round(x), math.round(y))
end

function PopupManager:open(options: Options)
	local policy = options.policy or {}
	-- ponytail: feature popovers are click-only; hover/interaction dismissal needs a separate policy.
	assert(policy.OpenOn == nil or policy.OpenOn == "Click", "Popover.OpenOn must be Click")
	assert(policy.CloseOnMouseLeave == nil or policy.CloseOnMouseLeave == false, "Popovers stay open on mouse leave")
	assert(policy.CloseOnInteraction == nil or policy.CloseOnInteraction == false, "Popovers stay open during interaction")
	for _, key in { "CloseOnOutsideClick", "CloseOnEscape" } do
		assert(policy[key] == nil or type(policy[key]) == "boolean", `Popover.{key} must be a boolean`)
	end
	local owner = options.owner
	if not owner and options.anchor then
		for i = #self.stack, 1, -1 do
			if options.anchor:IsDescendantOf(self.stack[i].frame) then
				owner = self.stack[i]
				break
			end
		end
	end
	if options.group then
		for _, existing in table.clone(self.stack) do
			if existing.group == options.group then existing.close() end
		end
	end
	local cleanup = Cleanup.new()
	local frame = options.content
	local popup = {
		frame = frame,
		anchor = options.anchor,
		within = options.within,
		align = options.align,
		placement = options.placement,
		gap = options.gap,
		modal = options.modal == true,
		dismissible = options.dismissible ~= false,
		closeOnOutsideClick = options.dismissible ~= false and policy.CloseOnOutsideClick ~= false,
		closeOnEscape = options.dismissible ~= false and policy.CloseOnEscape ~= false,
		owner = owner,
		group = options.group,
		regions = options.regions or {},
		open = true,
	}

	local layer = options.layer or self.layer
	popup.layer = layer
	local parent = layer
	if popup.modal then
		local scrim = cleanup:add(Factory.button({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 1,
			Parent = layer,
			Theme = { BackgroundColor3 = "Scrim" },
		}))
		Animations.tween(options.backdrop or scrim, { BackgroundTransparency = 0.55 }, Theme.Motion.Popup)
		-- Dismiss only on InputBegan through the manager, never on a drag's release.
		parent = scrim
	end

	local scale = options.scale or self.scale
	local uiScale = Factory.new("UIScale", { Scale = if options.scale then scale else scale * 0.97, Parent = frame })
	popup.uiScale = uiScale
	popup.fixedScale = options.scale ~= nil
	frame.AnchorPoint = Vector2.zero
	frame.ZIndex = 2
	frame.Parent = parent
	cleanup:add(frame)

	local function place()
		if popup.open then
			if options.place then
				options.place(popup)
			else
				self:_place(popup)
			end
		end
	end
	cleanup:connect(frame:GetPropertyChangedSignal("AbsoluteSize"), place)
	cleanup:connect(layer:GetPropertyChangedSignal("AbsoluteSize"), place)
	cleanup:connect(layer:GetPropertyChangedSignal("AbsolutePosition"), place)
	if popup.anchor then
		cleanup:connect(popup.anchor:GetPropertyChangedSignal("AbsolutePosition"), place)
		cleanup:connect(popup.anchor:GetPropertyChangedSignal("AbsoluteSize"), place)
	end
	if popup.within then
		cleanup:connect(popup.within:GetPropertyChangedSignal("AbsolutePosition"), place)
		cleanup:connect(popup.within:GetPropertyChangedSignal("AbsoluteSize"), place)
	end
	place()
	if not popup.fixedScale then
		Animations.tween(uiScale, { Scale = scale }, Theme.Motion.Popup)
	end

	function popup.close()
		if not popup.open then
			return
		end
		popup.open = false
		for _, child in table.clone(self.stack) do
			if child.owner == popup then child.close() end
		end
		local index = table.find(self.stack, popup)
		if index then
			table.remove(self.stack, index)
		end
		if options.onClose then
			options.onClose()
		end
		local function finish()
			self.closing[popup] = nil
			cleanup:clean()
		end
		if options.onClosing then
			self.closing[popup] = finish
			options.onClosing(finish)
		else
			finish()
		end
	end

	table.insert(self.stack, popup)
	if popup.anchor then
		local function checkAnchor()
			local node = popup.anchor
			while node do
				if (node:IsA("GuiObject") and not node.Visible) or (node:IsA("ScreenGui") and not node.Enabled) then
					popup.close()
					return
				end
				node = node.Parent
			end
			if not popup.anchor:IsDescendantOf(game) then popup.close() end
		end
		cleanup:connect(popup.anchor.AncestryChanged, checkAnchor)
		local node = popup.anchor
		while node do
			if node:IsA("GuiObject") then
				cleanup:connect(node:GetPropertyChangedSignal("Visible"), checkAnchor)
			elseif node:IsA("ScreenGui") then
				cleanup:connect(node:GetPropertyChangedSignal("Enabled"), checkAnchor)
			end
			node = node.Parent
		end
	end
	return popup
end

function PopupManager:setScale(scale: number)
	self.scale = scale
	for _, popup in self.stack do
		if not popup.fixedScale then
			Animations.tween(popup.uiScale, { Scale = scale })
		end
	end
end

function PopupManager:closeAll()
	for i = #self.stack, 1, -1 do
		local popup = self.stack[i]
		if popup then popup.close() end
	end
end

function PopupManager:isOpen(): boolean
	return #self.stack > 0
end

-- A floating surface with the palette styling, used by dropdowns, inspectors and dialogs.
function PopupManager.surface(width: number, props: { [string]: any }?): Frame
	local frame = Factory.new("Frame", {
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Active = true,
		Theme = { BackgroundColor3 = "Palette" },
	}, {
		Factory.corner(12),
		Factory.stroke("PaletteBorder"),
	})
	for key, value in props or {} do
		frame[key] = value
	end
	return frame
end

function PopupManager:Destroy()
	self:closeAll()
	for _, finish in table.clone(self.closing) do
		finish()
	end
	self.cleanup:clean()
end

return PopupManager

end

-- Window/Account
loaders[nodes["Window/Account"]] = function(script, require)
local Players = game:GetService("Players")
local Core = script.Parent.Parent.Core
local Factory = require(Core.Factory)
local Icons = require(Core.Icons)

local Account = {}

export type Options = {
	Enabled: boolean?,
	-- Legacy identity overrides are accepted; the active Roblox player stays authoritative.
	UseLocalPlayer: boolean?,
	DisplayName: string?,
	Subtitle: string?,
}

function Account.resolve(options)
	assert(options.Account == nil or type(options.Account) == "table", "Account must be a table")
	local config = options.Account or {}
	for _, key in { "Enabled", "UseLocalPlayer" } do
		assert(config[key] == nil or type(config[key]) == "boolean", `Account.{key} must be a boolean`)
	end
	for _, key in { "DisplayName", "Subtitle" } do
		assert(config[key] == nil or type(config[key]) == "string", `Account.{key} must be a string`)
	end
	assert(options.Title == nil or type(options.Title) == "string", "Title must be a string")
	assert(options.Subtitle == nil or type(options.Subtitle) == "string", "Subtitle must be a string")
	local player = Players.LocalPlayer
	return {
		enabled = config.Enabled ~= false,
		player = player,
		username = if player then player.Name else nil,
		displayName = if player then player.DisplayName else nil,
		userId = if player then player.UserId else nil,
		subtitle = "Account",
		avatars = {},
		listeners = {},
	}
end

-- Only presentation values belong in profile UI or its search metadata.
function Account.presentation(window)
	local account = window.account
	local censored = account.censored ~= false
	local username = if account.username then `@{account.username}` else "Unavailable in this session"
	return {
		censored = censored,
		title = if censored then "Hidden User" else account.username or "Account",
		displayName = if censored then "Hidden User" else account.displayName or "Account unavailable",
		username = if censored then "@hidden" else username,
		userId = if censored then "Hidden" elseif account.userId then tostring(account.userId) else "Unavailable in this session",
		subtitle = "Account",
		sessionDescription = if censored then "Account" elseif account.username then `Signed in as {username}` else "Open Play mode to view your account",
		image = if censored then "" else account.thumbnail or "",
	}
end

function Account.observe(window, fn)
	local listeners = window.account.listeners
	table.insert(listeners, fn)
	fn(Account.presentation(window))
	return function()
		local index = table.find(listeners, fn)
		if index then table.remove(listeners, index) end
	end
end

function Account.refresh(window, refreshSearch: boolean?)
	local data = Account.presentation(window)
	for avatar in window.account.avatars do
		avatar.Image = data.image
		avatar.Fallback.Visible = data.image == ""
	end
	for _, fn in table.clone(window.account.listeners) do fn(data) end
	-- Refresh after bindings have updated the searchable profile cards.
	if refreshSearch then
		if window.sidebar then window.sidebar:_filter(window.sidebar.query.Text) end
		if window.palette then window.palette:refresh() end
	end
end

function Account.initialize(window, store)
	local _, enabled = store:define("AutoCensorUser", true)
	window.account.censored = enabled
	window.cleanup:add(store:observe("AutoCensorUser", function(value)
		window.account.censored = value ~= false
		Account.refresh(window, true)
	end))
	window.cleanup:add(function() table.clear(window.account.listeners) end)
end

-- Shared player portrait for the sidebar and account page.
function Account.avatar(window, size: number, cleanup)
	local account = window.account
	local avatar = Factory.new("ImageLabel", {
		Name = "Avatar",
		Size = UDim2.fromOffset(size, size),
		Image = Account.presentation(window).image,
		ScaleType = Enum.ScaleType.Crop,
		Theme = { BackgroundColor3 = "SurfaceActive" },
	}, { Factory.new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Icons.create({ Icon = "person", Color = "TextPrimary" }, math.floor(size / 2), {
		Name = "Fallback",
		Visible = avatar.Image == "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = avatar,
	})
	account.avatars[avatar] = true
	cleanup:add(function() account.avatars[avatar] = nil end)
	return avatar
end

function Account.loadThumbnail(window)
	local account = window.account
	if not account.userId or account.userId <= 0 then return end
	task.spawn(function()
		local ok, content, ready = pcall(Players.GetUserThumbnailAsync, Players, account.userId,
			Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		if window.destroyed or not ok or not ready or type(content) ~= "string" or content == "" then return end
		account.thumbnail = content
		Account.refresh(window)
	end)
end

function Account.build(page)
	local window = page.window
	page.empty.Visible = false
	local hero = Factory.new("Frame", {
		Name = "AccountIdentity",
		Size = UDim2.new(1, 0, 0, 154),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Parent = page.content,
	}, { Factory.list(6, false, { HorizontalAlignment = Enum.HorizontalAlignment.Center }), Factory.padding(10, 0, 10, 0) })
	local avatar = Account.avatar(window, 80, page.cleanup)
	avatar.LayoutOrder = 1
	avatar.Parent = hero
	local name = Factory.text({ Name = "DisplayName", Typography = "WindowTitle", TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 2, Parent = hero })
	local identifier = Factory.text({ Name = "Identifier", Typography = "Description", TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 3, Parent = hero, Theme = { TextColor3 = "TextSecondary" } })
	local profile = page:AddSection({ Title = "Profile" })
	local values = {}
	local rows = { { "Display name", "displayName" }, { "Username", "username" }, { "User ID", "userId" } }
	for i, data in rows do
		local row = Factory.new("Frame", {
			Name = data[1], Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1,
			LayoutOrder = i, Parent = profile.container,
		})
		local fields = Factory.new("Frame", { Name = "Fields", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = row },
			{ Factory.padding(0, 14), Factory.list(12, true) })
		Factory.text({ Text = data[1], Size = UDim2.new(0, 0, 1, 0), Parent = fields, LayoutOrder = 1 }, { Factory.fill() })
		values[data[2]] = Factory.text({ Name = "Value", Typography = "Description", TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(0.6, 0, 1, 0), Parent = fields, LayoutOrder = 2, Theme = { TextColor3 = "TextSecondary" } })
		if i > 1 then
			Factory.new("Frame", { Name = "Divider", Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 0, 1),
				BackgroundTransparency = 0.45, Parent = row, Theme = { BackgroundColor3 = "Border" } })
		end
	end
	page.cleanup:add(Account.observe(window, function(data)
		name.Text, identifier.Text = data.title, data.username
		for key, label in values do label.Text = data[key] end
	end))
end

return Account

end

-- Window/DragResize
loaders[nodes["Window/DragResize"]] = function(script, require)
local Core = script.Parent.Parent.Core
local Factory = require(Core.Factory)
local Input = require(Core.Input)
local Icons = require(Core.Icons)
local UserInputService = game:GetService("UserInputService")

local DragResize = {}

-- Query the rendered stack in screen pixels, in the same space as InputObject.Position.
function DragResize.target(window, point: Vector2): GuiObject?
	local container = window.gui:FindFirstAncestorWhichIsA("BasePlayerGui")
	if not container then return nil end
	for _, hit in container:GetGuiObjectsAtPosition(math.round(point.X), math.round(point.Y)) do
		if hit == window.frame or hit:IsDescendantOf(window.frame) then return hit end
		-- Ignore inert, transparent layout wrappers, but never drag through another visible surface.
		if hit.Active or hit.BackgroundTransparency < 1 or hit:IsA("GuiButton") or hit:IsA("TextBox")
			or hit:IsA("TextLabel") or hit:IsA("ImageLabel") or hit:GetAttribute("NoWindowDrag") or hit:GetAttribute("DragBlock") then
			return nil
		end
	end
	return nil
end

function DragResize.canDrag(window, target: GuiObject?, point: Vector2, touch: boolean): boolean
	if not target or (target ~= window.frame and not target:IsDescendantOf(window.frame)) then return false end
	local node = target
	while node do
		if node:GetAttribute("NoWindowDrag") or node:GetAttribute("DragBlock") or node:IsA("TextBox")
			or (node:IsA("GuiButton") and node:GetAttribute("NoWindowDrag") ~= false) then
			return false
		end
		if node:IsA("ScrollingFrame") and node.ScrollingEnabled then
			-- Touch pans content; mouse may drag blank content, except the scrollbar gutter.
			if touch then return false end
			local pos, size = node.AbsolutePosition, node.AbsoluteSize
			local thickness = node.ScrollBarThickness * window.scale
			local vertical = node.AbsoluteCanvasSize.Y > node.AbsoluteWindowSize.Y
			local horizontal = node.AbsoluteCanvasSize.X > node.AbsoluteWindowSize.X
			local left = node.VerticalScrollBarPosition == Enum.VerticalScrollBarPosition.Left
			if (vertical and (if left then point.X < pos.X + thickness else point.X >= pos.X + size.X - thickness))
				or (horizontal and point.Y >= pos.Y + size.Y - thickness) then return false end
		end
		if node == window.frame then return true end
		node = node.Parent
	end
	return false
end

-- One controller per window; permanent listeners are never re-created by a gesture or page change.
function DragResize.drag(window)
	local controller = {}
	function controller.stop()
		controller.candidate = nil
		if window.stopDrag == controller.stop then window.stopDrag = nil end
	end
	function controller:begin(input)
		if not window.options.Draggable or not window.visible or window.maximized or window.stopDrag or not Input.isPointer(input) then return false end
		local point = Input.position(input)
		local touch = input.UserInputType == Enum.UserInputType.Touch
		local target = DragResize.target(window, point)
		if not DragResize.canDrag(window, target, point, touch) then return false end
		self.candidate = { input = input, point = point, position = window.position, dragging = false }
		window.stopDrag = controller.stop
		return false
	end
	function controller:move(input)
		local drag = self.candidate
		if not drag or (if drag.input.UserInputType == Enum.UserInputType.Touch then input ~= drag.input
			else input.UserInputType ~= Enum.UserInputType.MouseMovement) then return end
		local point = Input.position(input)
		if not drag.dragging and (point - drag.point).Magnitude < 4 then return end
		drag.dragging = true
		-- Root UIScale changes its size, not its parent-relative Position: apply physical delta once.
		window.position = drag.position + point - drag.point
		window:_apply(false)
	end
	function controller:finish(input)
		local drag = self.candidate
		if not drag or (input ~= drag.input and not (drag.input.UserInputType == Enum.UserInputType.MouseButton1
			and input.UserInputType == Enum.UserInputType.MouseButton1)) then return end
		controller.stop()
	end
	window.cleanup:add(Input.listen(function(input) return controller:begin(input) end))
	window.cleanup:connect(UserInputService.InputChanged, function(input) controller:move(input) end)
	window.cleanup:connect(UserInputService.InputEnded, function(input) controller:finish(input) end)
	window.cleanup:add(controller.stop)
	return controller
end

function DragResize.resize(window, frame: GuiObject)
	local grip = Factory.button({
		Name = "ResizeGrip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -1, 1, -1),
		Size = UDim2.fromOffset(24, 24),
		ZIndex = 20,
		Parent = frame,
	})
	grip:SetAttribute("NoWindowDrag", true)
	Icons.create({ Icon = "square-corner-line-small", Color = "TextMuted" }, 14, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = 90,
		TextTransparency = 0.4,
		Parent = grip,
	})

	window.cleanup:connect(grip.InputBegan, function(input)
		if window.destroyed or not window.visible or not window.options.Resizable or window.maximized or window.minimized
			or not grip.Visible or not Input.isPointer(input) then
			return
		end
		if window.stopDrag then
			local candidate = window.dragController and window.dragController.candidate
			if not candidate or candidate.input ~= input then return end
			window.stopDrag() -- The grip owns this input, even if the window listener ran first.
		end
		local startPoint = Input.position(input)
		local root = window.root
		local startSize = Vector2.new(root.Size.X.Offset, root.Size.Y.Offset)
		local actual = root.AbsoluteSize
		if startSize.X <= 0 or startSize.Y <= 0 or actual.X <= 0 or actual.Y <= 0 then return end
		local scale = actual / startSize -- Includes root UIScale and any scaled ancestors, exactly once.
		local startPos, anchor = window.position, root.AnchorPoint
		local ownScale = window.uiScale.Scale
		window.stopDrag = Input.drag(input, function(point)
			local size = startSize + (point - startPoint) / scale
			window.size = Vector2.new(math.round(math.max(window.minSize.X, size.X)), math.round(math.max(window.minSize.Y, size.Y)))
			window.position = startPos + (window.size - startSize) * anchor * ownScale
			window:_apply(false)
		end, function()
			window.stopDrag = nil
		end)
	end)
	window.cleanup:add(function()
		if window.stopDrag then window.stopDrag() end
	end)
	return grip
end

return DragResize

end

-- Window/Page
loaders[nodes["Window/Page"]] = function(script, require)
local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Cleanup = require(Core.Cleanup)
local Section = require(script.Parent.Section)

local Page = {}
Page.__index = Page

export type Options = {
	Id: string?,
	Title: string,
	Description: string?,
	Icon: any?,
	Badge: string?,
	Group: number?,
	Keywords: string?,
	Aliases: (string | { string })?,
	Build: ((any) -> ())?,
	Sidebar: boolean?,
}

function Page.new(window, options: Options)
	local self = setmetatable({
		window = window,
		options = options,
		id = options.Id or string.lower(options.Title),
		sections = {},
		order = 0,
		cleanup = Cleanup.new(),
	}, Page)

	self.ctx = setmetatable({
		searchId = `page:{self.id}`,
		searchPath = options.Title,
		pageTitle = options.Title,
		locate = function(target: GuiObject, after: (() -> ())?)
			window:SelectPage(self.id)
			task.defer(function()
				self:ScrollTo(target)
				if after then
					after()
				end
			end)
		end,
	}, { __index = window.ctx })

	self.scroller = self.cleanup:add(Factory.new("ScrollingFrame", {
		Name = self.id,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		ScrollBarImageTransparency = 0.3,
		VerticalScrollBarInset = Enum.ScrollBarInset.Always,
		Visible = false,
		Parent = window.body,
		Theme = { ScrollBarImageColor3 = "Border" },
	}))

	self.content = Factory.new("Frame", {
		Name = "Content",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self.scroller,
	}, {
		Factory.list(12),
		Factory.padding(4, 12, 16, 12),
	})

	self.empty = Factory.text({
		Text = "Nothing here yet.",
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 120),
		LayoutOrder = 100000,
		Parent = self.content,
		Theme = { TextColor3 = "TextMuted" },
	})

	self.cleanup:add(window.ctx.registry:add({
		id = `page:{self.id}`,
		kind = "page",
		title = options.Title,
		subtitle = "Page",
		keywords = `{options.Description or ""} {options.Keywords or ""}`,
		aliases = options.Aliases,
		icon = options.Icon or "circle",
		activate = function()
			window:SelectPage(self.id)
		end,
	}))

	return self
end

function Page:AddSection(options: Section.Options?)
	self.empty.Visible = false
	local section = Section.new(self, options or {})
	table.insert(self.sections, section)
	return section
end

function Page:GetSections()
	return table.clone(self.sections)
end

function Page:CardCount(): number
	local count = 0
	for _, section in self.sections do
		count += #section.cards
	end
	return count
end

function Page:ScrollTo(target: GuiObject)
	local scroller = self.scroller
	local scale = self.window.ctx.scale()
	local offset = (target.AbsolutePosition.Y - scroller.AbsolutePosition.Y) / scale
	local goal = math.max(0, scroller.CanvasPosition.Y + offset - 24)
	local maxY = math.max(0, (scroller.AbsoluteCanvasSize.Y - scroller.AbsoluteWindowSize.Y) / scale)
	Animations.tween(scroller, { CanvasPosition = Vector2.new(0, math.min(goal, maxY)) }, Theme.Motion.Expand)
end

-- Lazy pages pass Build = function(page) ... end; it runs once, on first open or first search.
function Page:EnsureBuilt()
	local build = self.options.Build
	if build and not self.built then
		self.built = true
		local ok, err = xpcall(build, debug.traceback, self)
		if not ok then
			warn(`[MacUI] page "{self.id}" failed to build: {err}`)
		end
	end
end

function Page:_show(visible: boolean)
	if visible then
		self:EnsureBuilt()
	end
	self.scroller.Visible = visible
	Animations.tween(self.scroller, { Position = UDim2.fromOffset(0, if visible and not Animations.reducedMotion then 12 else 0) })
	if visible then
		Animations.tween(self.scroller, { Position = UDim2.new() }, Theme.Motion.Page)
	end
end

function Page:SetTitle(title: string)
	self.options.Title = title
	self.ctx.pageTitle = title
	self.ctx.searchPath = title
	for _, section in self.sections do
		section.ctx.searchPath = if section.options.Title then `{title} › {section.options.Title}` else title
		for _, card in section.cards do
			card:SetTitle(card.options.Title)
			self.window.ctx.registry:update(card.registryKey, { subtitle = section.ctx.searchPath })
		end
	end
	self.window.ctx.registry:update(`page:{self.id}`, { title = title })
	self.window:_pageChanged(self)
end

function Page:SetBadge(text: string?)
	self.options.Badge = text
	self.window:_pageChanged(self)
end

function Page:Destroy()
	for i = #self.sections, 1, -1 do
		self.sections[i]:Destroy()
	end
	self.cleanup:clean()
	self.window:_removePage(self)
end

return Page

end

-- Window/Section
loaders[nodes["Window/Section"]] = function(script, require)
local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Cleanup = require(Core.Cleanup)
local Card = require(script.Parent.Parent.Components.Card)

local GRID_GAP = 10
local MIN_TILE = 220
local TILE_HEIGHT = 104

local Section = {}
Section.__index = Section

export type Options = {
	Title: string?,
	Description: string?,
	Layout: "List" | "Grid" | nil,
	Columns: number?,
}

function Section.new(page, options: Options)
	local self = setmetatable({
		page = page,
		ctx = page.ctx,
		options = options,
		cards = {},
		order = 0,
		grid = options.Layout == "Grid",
		cleanup = Cleanup.new(),
		visible = true,
	}, Section)

	page.order += 1
	self.ctx = setmetatable({
		searchId = `{page.ctx.searchId}/section:{page.order}`,
		searchPath = if options.Title then `{page.ctx.searchPath} › {options.Title}` else page.ctx.searchPath,
	}, { __index = page.ctx })
	self.Instance = self.cleanup:add(Factory.new("Frame", {
		Name = options.Title or "Section",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = page.order,
		Parent = page.content,
	}, { Factory.list(8) }))

	if options.Title or options.Description then
		local head = Factory.new("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Parent = self.Instance,
		}, { Factory.list(2), Factory.padding(4, 2, 0, 2) })

		if options.Title then
			self.titleLabel = Factory.text({
				Text = options.Title,
				Typography = "Section",
				Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = 1,
				Parent = head,
			})
		end
		if options.Description then
			Factory.text({
				Text = options.Description,
				Typography = "Description",
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.None,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				Parent = head,
				Theme = { TextColor3 = "TextSecondary" },
			})
		end
	end

	if self.grid then
		self.container = Factory.new("Frame", {
			Name = "Grid",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Parent = self.Instance,
		})
		self.gridLayout = Factory.new("UIGridLayout", {
			CellPadding = UDim2.fromOffset(GRID_GAP, GRID_GAP),
			CellSize = UDim2.fromOffset(MIN_TILE, TILE_HEIGHT),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = self.container,
		})
		self.cleanup:connect(self.container:GetPropertyChangedSignal("AbsoluteSize"), function()
			self:_fitGrid()
		end)
		self:_fitGrid()
	else
		self.container = Factory.new("Frame", {
			Name = "Group",
			Size = UDim2.fromScale(1, 0),
			BackgroundTransparency = 0.04,
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = self.Instance,
			Theme = { BackgroundColor3 = "Surface" },
		}, {
			Factory.corner(Theme.get("RadiusCard")),
			Factory.list(0),
		})
	end

	return self
end

function Section:_fitGrid()
	local scale = self.ctx.scale()
	local width = self.container.AbsoluteSize.X / scale
	if width <= 0 then
		return
	end
	local columns = self.options.Columns or math.clamp(math.floor((width + GRID_GAP) / (MIN_TILE + GRID_GAP)), 1, 3)
	local cell = math.floor((width - GRID_GAP * (columns - 1)) / columns)
	self.gridLayout.CellSize = UDim2.fromOffset(cell, TILE_HEIGHT)
end

-- Rebuilds row dividers so only visible neighbours are separated.
function Section:_refresh()
	if self.grid then
		return
	end
	local shown = 0
	for _, card in self.cards do
		local line = card.Instance:FindFirstChild("RowDivider")
		if card.visible then
			shown += 1
		end
		if card.visible and shown > 1 then
			if not line then
				Factory.new("Frame", {
					Name = "RowDivider",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.new(1, -32, 0, 1),
					BackgroundTransparency = 0.45,
					LayoutOrder = 0,
					Parent = card.Instance,
					Theme = { BackgroundColor3 = "Border" },
				})
			end
		elseif line then
			line:Destroy()
		end
	end
	self.container.Visible = shown > 0
end

function Section:AddCard(options): any
	local card = Card.new(self, options)
	table.insert(self.cards, card)
	self:_refresh()
	return card
end

function Section:_forget(card)
	local index = table.find(self.cards, card)
	if index then
		table.remove(self.cards, index)
	end
	self:_refresh()
end

function Section:GetCards()
	return table.clone(self.cards)
end

function Section:SetVisible(visible: boolean)
	self.visible = visible
	self.Instance.Visible = visible
end

function Section:Destroy()
	for i = #self.cards, 1, -1 do
		self.cards[i]:Destroy()
	end
	self.cleanup:clean()
	local index = table.find(self.page.sections, self)
	if index then
		table.remove(self.page.sections, index)
	end
end

return Section

end

-- Window/Sidebar
loaders[nodes["Window/Sidebar"]] = function(script, require)
local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Cleanup = require(Core.Cleanup)
local Icons = require(Core.Icons)
local Account = require(script.Parent.Account)
local Display = require(script.Parent.Parent.Components.Display)

local ROW = 36
local INSET = 8
local ROW_PADDING = 12
local ICON = 16
local GAP = 12
local PROFILE_ICON = 32
local LIGHT = 13
local SEARCH_Y = 40
local PROFILE_Y = 78
local NAV_Y = PROFILE_Y + 48 + 8

local Sidebar = {}
Sidebar.__index = Sidebar

local function navigationRow(parent, name, order)
	return Factory.button({
		Name = name,
		Size = UDim2.new(1, 0, 0, ROW),
		LayoutOrder = order,
		Parent = parent,
		Theme = { BackgroundColor3 = "SurfaceActive" },
	}, {
		Factory.corner(Theme.get("RadiusControl") - 1),
		Factory.padding(0, ROW_PADDING),
		Factory.list(GAP, true, { HorizontalAlignment = Enum.HorizontalAlignment.Right }),
	})
end

function Sidebar.new(window, parent: GuiObject, options)
	local self = setmetatable({
		window = window,
		rows = {},
		cleanup = Cleanup.new(),
		selected = nil,
		results = {},
		resultIndex = 0,
	}, Sidebar)

	-- Keep corners rounded when the settled window renders outside the fade CanvasGroup.
	local panel = self.cleanup:add(Factory.new("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, options.Width, 1, 0),
		BackgroundTransparency = options.Transparency or 0,
		Parent = parent,
		Theme = { BackgroundColor3 = "Sidebar" },
	}, { Factory.corner(Theme.get("RadiusWindow")) }))
	self.Instance = panel
	Factory.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, Theme.get("RadiusWindow"), 1, 0),
		BackgroundTransparency = options.Transparency or 0,
		Parent = panel,
		Theme = { BackgroundColor3 = "Sidebar" },
	})

	Factory.new("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundTransparency = 0.3,
		ZIndex = 2,
		Parent = panel,
		Theme = { BackgroundColor3 = "Border" },
	})

	self.dragZone = Factory.new("Frame", {
		Name = "DragZone",
		Position = UDim2.fromOffset(80, 0),
		Size = UDim2.new(1, -80, 0, SEARCH_Y - 4),
		BackgroundTransparency = 1,
		Active = true,
		Parent = panel,
	})

	self:_buildLights(panel)
	self:_buildSearch(panel)
	self:_buildProfile(panel, options)

	self.list = Factory.new("ScrollingFrame", {
		Name = "Navigation",
		Position = UDim2.fromOffset(0, NAV_Y),
		Size = UDim2.new(1, 0, 1, -NAV_Y - 6),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 0,
		Parent = panel,
	}, {
		Factory.list(1),
		Factory.padding(0, INSET, INSET, INSET),
	})

	-- Shared highlight that slides between rows on page change. Lives behind the list, outside its layout.
	self.pillLayer = Factory.new("Frame", {
		Name = "SelectionLayer",
		Position = self.list.Position,
		Size = self.list.Size,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = panel,
	})
	self.list.ZIndex = 2
	self.pill = Factory.new("Frame", {
		Name = "Selection",
		Size = UDim2.new(1, -INSET * 2, 0, ROW),
		Position = UDim2.fromOffset(INSET, 0),
		Visible = false,
		Parent = self.pillLayer,
		Theme = { BackgroundColor3 = "SurfaceActive" },
	}, { Factory.corner(Theme.get("RadiusControl") - 1) })
	self.cleanup:connect(self.list:GetPropertyChangedSignal("CanvasPosition"), function()
		self:_placePill(false)
	end)
	self.cleanup:connect(self.list:GetPropertyChangedSignal("AbsoluteSize"), function()
		self:_placePill(false)
	end)
	self.cleanup:connect(self.list:FindFirstChildOfClass("UIListLayout"):GetPropertyChangedSignal("AbsoluteContentSize"), function()
		self:_placePill(false)
	end)

	self.noResults = Factory.text({
		Text = "No matches",
		Size = UDim2.new(1, 0, 0, ROW),
		Visible = false,
		LayoutOrder = 1e6,
		Parent = self.list,
		Theme = { TextColor3 = "TextMuted" },
	}, { Factory.padding(0, ROW_PADDING) })

	return self
end

function Sidebar:_buildLights(panel: Frame)
	local holder = Factory.new("Frame", {
		Name = "WindowControls",
		Position = UDim2.fromOffset(16, 15),
		Size = UDim2.fromOffset(LIGHT * 3 + 16, LIGHT),
		BackgroundTransparency = 1,
		Active = true,
		Parent = panel,
	}, { Factory.list(8, true) })
	self.windowControls = holder
	holder:SetAttribute("Hovered", false)

	local specs = {
		{ "Close", Color3.fromRGB(255, 95, 87), Color3.fromRGB(106, 31, 25), {
			{ 0, 3, 7, 1, 45 }, { 0, 3, 7, 1, -45 },
		}, function()
			self.window:Hide()
		end },
		{ "Minimize", Color3.fromRGB(254, 188, 46), Color3.fromRGB(132, 88, 0), {
			{ 0, 3, 7, 1, 0 },
		}, function()
			self.window:SetMinimized(not self.window.minimized)
		end },
		{ "Maximize", Color3.fromRGB(40, 200, 64), Color3.fromRGB(0, 99, 19), {
			-- Mirrored arrowheads and short shafts, with a clear gap between arrows.
			{ 0, 0, 3, 1, 0 }, { 0, 0, 1, 3, 0 }, { 0, 1, 3, 1, 45 },
			{ 4, 6, 3, 1, 0 }, { 6, 4, 1, 3, 0 }, { 4, 5, 3, 1, 45 },
		}, function()
			self.window:ToggleMaximize()
		end },
	}

	local symbols = {}
	for i, spec in specs do
		local light = Factory.button({
			Name = spec[1],
			Size = UDim2.fromOffset(LIGHT, LIGHT),
			BackgroundTransparency = 0,
			BackgroundColor3 = spec[2],
			LayoutOrder = i,
			Parent = holder,
		}, {
			Factory.new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		})
		local symbol = Factory.new("Frame", {
			Name = "Symbol",
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.fromOffset(7, 7),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = light,
		})
		for _, line in spec[4] do
			Factory.new("Frame", {
				Size = UDim2.fromOffset(line[3], line[4]),
				Position = UDim2.fromOffset(line[1], line[2]),
				Rotation = line[5],
				BackgroundColor3 = spec[3],
				Parent = symbol,
			})
		end
		table.insert(symbols, symbol)
		if i == 3 then
			light.Visible = self.window.options.Maximizable == true
		end
		self.cleanup:connect(light:GetPropertyChangedSignal("GuiState"), function()
			local color = if light.GuiState == Enum.GuiState.Press then spec[2]:Lerp(Color3.new(), 0.15) else spec[2]
			Animations.tween(light, { BackgroundColor3 = color }, Theme.Motion.Hover / 2)
		end)
		self.cleanup:connect(light.Activated, spec[5])
	end

	self.cleanup:connect(holder:GetAttributeChangedSignal("Hovered"), function()
		for _, symbol in symbols do
			symbol.Visible = holder:GetAttribute("Hovered") == true
		end
	end)
	self.cleanup:connect(holder.MouseEnter, function()
		holder:SetAttribute("Hovered", true)
	end)
	self.cleanup:connect(holder.MouseLeave, function()
		holder:SetAttribute("Hovered", false)
	end)
	self.cleanup:connect(self.window.root:GetPropertyChangedSignal("Visible"), function()
		if not self.window.root.Visible then
			holder:SetAttribute("Hovered", false)
		end
	end)
end

function Sidebar:_buildSearch(panel: Frame)
	local box = Factory.new("Frame", {
		Name = "Search",
		Position = UDim2.fromOffset(10, SEARCH_Y),
		Size = UDim2.new(1, -20, 0, 32),
		Parent = panel,
		Theme = { BackgroundColor3 = "SurfaceActive" },
	}, { Factory.corner(10) })
	box.BackgroundTransparency = 0.35
	local stroke = Factory.stroke("Border", 1)
	stroke.Parent = box

	Icons.create({ Icon = "magnifying-glass", Color = "TextMuted" }, 15, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Parent = box,
	})

	local query = Factory.text({
		ClassName = "TextBox",
		Name = "Query",
		Position = UDim2.fromOffset(32, 0),
		Size = UDim2.new(1, -40, 1, 0),
		Text = "",
		PlaceholderText = self.window.options.SearchPlaceholder or "Search features...",
		ClearTextOnFocus = false,
		TextTruncate = Enum.TextTruncate.None,
		ClipsDescendants = true,
		Parent = box,
		Theme = { PlaceholderColor3 = "TextMuted" },
	})
	self.query = query

	self.cleanup:connect(query.Focused, function()
		Animations.tween(stroke, { Transparency = 0.2 }, Theme.Motion.Hover)
	end)
	self.cleanup:connect(query.FocusLost, function(enter)
		Animations.tween(stroke, { Transparency = 1 }, Theme.Motion.Hover)
		if enter then
			local entry = self.results[self.resultIndex]
			if entry then
				entry.activate()
				query.Text = ""
			end
		end
	end)
	self.cleanup:connect(query:GetPropertyChangedSignal("Text"), function()
		self:_filter(query.Text)
	end)
end

function Sidebar:_buildProfile(panel: Frame, options)
	local row = Factory.button({
		Name = "AccountProfile",
		Position = UDim2.fromOffset(INSET, PROFILE_Y),
		Size = UDim2.new(1, -INSET * 2, 0, 48),
		BackgroundTransparency = 0.25,
		Interactable = self.window.account.enabled,
		Selectable = self.window.account.enabled,
		Parent = panel,
		Theme = { BackgroundColor3 = "SurfaceHover" },
	}, {
		Factory.corner(8),
		-- Larger identity icon shares the navigation icon center and text column.
		Factory.padding(0, ROW_PADDING, 0, ROW_PADDING - (PROFILE_ICON - ICON) / 2),
		Factory.list(GAP - (PROFILE_ICON - ICON) / 2, true),
	})

	self.profile = row
	row:SetAttribute("Selected", false)
	local avatar = Account.avatar(self.window, PROFILE_ICON, self.cleanup)
	avatar.Name = "Avatar"
	avatar.LayoutOrder = 1
	avatar.Parent = row

	local text = Factory.new("Frame", {
		Name = "ProfileText",
		Size = UDim2.fromOffset(0, 32),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = row,
	}, { Factory.fill(), Factory.list(0) })
	self.titleLabel = Factory.text({
		Text = options.Title,
		Typography = "Feature",
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 1,
		Parent = text,
	})
	self.subtitleLabel = Factory.text({
		Text = options.Subtitle or "",
		Typography = "Description",
		Size = UDim2.new(1, 0, 0, 14),
		LayoutOrder = 2,
		Parent = text,
		Theme = { TextColor3 = "TextMuted" },
	})
	self.cleanup:add(Account.observe(self.window, function(data)
		self.titleLabel.Text, self.subtitleLabel.Text = data.title, data.subtitle
	end))
	self.cleanup:connect(row.Activated, function()
		self.window:SelectPage("account")
	end)
	self.cleanup:connect(row:GetPropertyChangedSignal("GuiState"), function()
		self:_renderProfile()
	end)
end

function Sidebar:_renderProfile()
	local row = self.profile
	local selected = self.selected ~= nil and self.selected.id == "account"
	local pressed = row.GuiState == Enum.GuiState.Press
	row:SetAttribute("Selected", selected)
	Theme.bind(row, { BackgroundColor3 = if pressed then "Border" elseif selected then "SurfaceActive" else "SurfaceHover" })
	Animations.tween(row, { BackgroundTransparency = if selected or pressed then 0 elseif row.GuiState == Enum.GuiState.Hover then 0.05 else 0.25 }, Theme.Motion.Hover)
end

function Sidebar:addPage(page)
	local options = page.options
	local group = options.Group or 1
	local count = #self.rows + 1

	local spacer
	local previous = self.rows[#self.rows]
	if previous and previous.group ~= group then
		spacer = Factory.new("Frame", {
			Name = "GroupGap",
			Size = UDim2.new(1, 0, 0, 10),
			BackgroundTransparency = 1,
			LayoutOrder = count * 2 - 1,
			Parent = self.list,
		})
	end

	local button = navigationRow(self.list, page.id, count * 2)

	local iconSpec = options.Icon or "circle"
	if type(iconSpec) == "string" then
		iconSpec = { Icon = iconSpec, Color = "TextSecondary" }
	end
	local icon = Icons.create(iconSpec, ICON, {
		Size = UDim2.fromOffset(ICON, ICON), LayoutOrder = 1, Parent = button,
	})

	local label = Factory.text({
		Text = options.Title,
		Typography = "Navigation",
		Size = UDim2.new(0, 0, 1, 0),
		LayoutOrder = 2,
		Parent = button,
	}, { Factory.fill() })

	local row = {
		page = page,
		group = group,
		button = button,
		label = label,
		icon = icon,
		spacer = spacer,
	}
	self:_setBadge(row, options.Badge)

	self.cleanup:connect(button.MouseEnter, function()
		if self.selected ~= page then
			Animations.tween(button, { BackgroundTransparency = 0.7 }, Theme.Motion.Hover)
		end
	end)
	self.cleanup:connect(button.MouseLeave, function()
		if self.selected ~= page then
			Animations.tween(button, { BackgroundTransparency = 1 }, Theme.Motion.Hover)
		end
	end)
	self.cleanup:connect(button.Activated, function()
		self.window:SelectPage(page.id)
	end)

	table.insert(self.rows, row)
	return row
end

function Sidebar:_setBadge(row, text: string?)
	if row.badge then
		row.badge:Destroy()
		row.badge = nil
	end
	if text then
		row.badge = Display.badge(text)
		row.badge.Size = UDim2.fromOffset(0, 18)
		row.badge.BackgroundTransparency = 0.25
		Theme.bind(row.badge, { BackgroundColor3 = "SurfaceHover" })
		row.badge:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 4)
		local padding = row.badge:FindFirstChildOfClass("UIPadding")
		padding.PaddingLeft = UDim.new(0, 5)
		padding.PaddingRight = UDim.new(0, 5)
		row.badge.Label.TextXAlignment = Enum.TextXAlignment.Center
		Factory.new("UISizeConstraint", { MinSize = Vector2.new(22, 18), Parent = row.badge })
		row.badge.LayoutOrder = 3
		row.badge.Parent = row.button
	end
end

function Sidebar:updatePage(page)
	for _, row in self.rows do
		if row.page == page then
			row.label.Text = page.options.Title
			self:_setBadge(row, page.options.Badge)
		end
	end
end

function Sidebar:removePage(page)
	for i, row in self.rows do
		if row.page == page then
			row.button:Destroy()
			if row.spacer then
				row.spacer:Destroy()
			end
			table.remove(self.rows, i)
			break
		end
	end
	task.defer(function()
		self:_placePill(false)
	end)
end

function Sidebar:relayout()
	self:_placePill(false)
end

function Sidebar:_selectedRow()
	for _, row in self.rows do
		if row.page == self.selected then
			return row
		end
	end
	return nil
end

function Sidebar:_placePill(animate: boolean)
	if self.window.destroyed or not self.Instance.Parent then
		return
	end
	local row = self:_selectedRow()
	local pill = self.pill
	if not row or not row.button.Visible then
		pill.Visible = false
		return
	end
	local scale = self.Instance.AbsoluteSize.X / self.Instance.Size.X.Offset
	if scale <= 0 then
		return
	end
	local offset = (row.button.AbsolutePosition - self.pillLayer.AbsolutePosition) / scale
	pill.Size = UDim2.fromOffset(math.round(row.button.AbsoluteSize.X / scale), ROW)
	local goal = UDim2.fromOffset(math.round(offset.X), math.round(offset.Y))
	if animate and pill.Visible then
		Animations.tween(pill, { Position = goal }, Theme.Motion.Page, Enum.EasingStyle.Quint)
	else
		Animations.tween(pill, { Position = goal })
	end
	pill.Visible = true
end

function Sidebar:select(page)
	self.selected = page
	self:_renderProfile()
	for _, row in self.rows do
		local active = row.page == page
		Animations.tween(row.button, { BackgroundTransparency = 1 }, Theme.Motion.Hover)
		Theme.bind(row.label, { TextColor3 = if active then "TextPrimary" else "TextSecondary" })
		if row.icon:IsA("TextLabel") and type(row.page.options.Icon) ~= "table" then
			Theme.bind(row.icon, { TextColor3 = if active then "TextPrimary" else "TextSecondary" })
		end
	end
	task.defer(function()
		self:_placePill(true)
	end)
end

-- Typing searches pages, cards and controls; results replace the nav list until cleared.
function Sidebar:_filter(text: string)
	for _, result in self.resultRows or {} do
		result:Destroy()
	end
	self.resultRows = {}
	self.results = {}
	self.resultIndex = 0

	local searching = string.gsub(text, "%s", "") ~= ""
	for _, row in self.rows do
		row.button.Visible = not searching
		if row.spacer then
			row.spacer.Visible = not searching
		end
	end
	self.noResults.Visible = false
	if not searching then
		task.defer(function()
			self:_placePill(false)
		end)
		return
	end
	self.pill.Visible = false

	self.window:_buildAll()
	local results = self.window.ctx.registry:search(text, 30)
	self.results = results
	self.noResults.Visible = #results == 0

	for i, entry in results do
		local button = navigationRow(self.list, "SearchResult", 1000 + i)
		Icons.create(Icons.spec(entry.icon), ICON, {
			Size = UDim2.fromOffset(ICON, ICON), LayoutOrder = 1, Parent = button,
		})
		local text = Factory.new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Parent = button,
		}, {
			Factory.fill(),
			Factory.list(0, false, { VerticalAlignment = Enum.VerticalAlignment.Center }),
		})
		Factory.text({ Text = entry.title, Size = UDim2.new(1, 0, 0, 20), Typography = "Feature", Parent = text })
		Factory.text({
			Text = entry.subtitle or "",
			Size = UDim2.new(1, 0, 0, 14),
			Typography = "Hint",
			LayoutOrder = 2,
			Parent = text,
			Theme = { TextColor3 = "TextMuted" },
		})
		button.MouseEnter:Connect(function()
			self:_highlight(i)
		end)
		button.Activated:Connect(function()
			entry.activate()
			self.query.Text = ""
		end)
		self.resultRows[i] = button
	end
	self:_highlight(1)
end

function Sidebar:_highlight(index: number)
	self.resultIndex = index
	for i, row in self.resultRows or {} do
		row.BackgroundTransparency = if i == index then 0.3 else 1
	end
end

function Sidebar:moveResult(step: number): boolean
	if not self.query:IsFocused() or #self.results == 0 then
		return false
	end
	self:_highlight(math.clamp(self.resultIndex + step, 1, #self.results))
	return true
end

function Sidebar:setIdentity(title: string?, subtitle: string?)
	-- Keep the legacy setter callable without replacing Roblox account identity.
	local data = Account.presentation(self.window)
	self.titleLabel.Text, self.subtitleLabel.Text = data.title, data.subtitle
end

function Sidebar:Destroy()
	self.cleanup:clean()
end

return Sidebar

end

-- Window/Window
loaders[nodes["Window/Window"]] = function(script, require)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Library = script.Parent.Parent
local Core = Library.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Cleanup = require(Core.Cleanup)
local Icons = require(Core.Icons)
local Input = require(Core.Input)
local Store = require(Core.Store)
local Registry = require(Core.Registry)
local Util = require(Core.Util)
local Blur = require(Core.Blur)
local PopupManager = require(Library.Overlays.PopupManager)
local Notifications = require(Library.Overlays.Notifications)
local CommandPalette = require(Library.Overlays.CommandPalette)
local Dialog = require(Library.Overlays.Dialog)
local Display = require(Library.Components.Display)
local Sidebar = require(script.Parent.Sidebar)
local Account = require(script.Parent.Account)
local Page = require(script.Parent.Page)
local DragResize = require(script.Parent.DragResize)

local HEADER = 48
local MARGIN = 12
local NARROW = 680
local MIN_SCALE = 0.95

local Window = {}
Window.__index = Window

export type Options = {
	Title: string?,
	Subtitle: string?,
	Icon: any?,
	AnimatedIcon: { [string]: any }?,
	Account: Account.Options?,
	Theme: string?,
	Size: UDim2?,
	MinSize: Vector2?,
	ToggleKey: Enum.KeyCode?,
	MaximizeKey: Enum.KeyCode?, -- Ctrl+Shift+key; Unknown disables the recovery shortcut.
	Resizable: boolean?,
	Draggable: boolean?,
	Maximizable: boolean?,
	Scale: number?,
	AutoScale: boolean?,
	BlurEnabled: boolean?,
	BlurSize: number?,
	BlurTweenTime: number?,
	Acrylic: boolean?,
	BackgroundTransparency: number?,
	ReducedMotion: boolean?,
	Persistence: Store.Adapter?,
	SearchPlaceholder: string?,
	PalettePreserveQuery: boolean?,
	Parent: Instance?,
	DisplayOrder: number?,
}

function Window.new(options: Options)
	options = Util.merge({
		Subtitle = "Account",
		Resizable = true,
		Draggable = true,
		Maximizable = true,
		ToggleKey = Enum.KeyCode.RightShift,
		AutoScale = true,
		BlurEnabled = true,
		BlurSize = 14,
		BlurTweenTime = 0.18,
		Acrylic = true,
		BackgroundTransparency = 0.1,
	}, options)
	local account = Account.resolve(options)
	options.MaximizeKey = options.MaximizeKey or (if options.ToggleKey == Enum.KeyCode.M then Enum.KeyCode.F10 else Enum.KeyCode.M)
	assert(typeof(options.MaximizeKey) == "EnumItem" and options.MaximizeKey.EnumType == Enum.KeyCode, "MaximizeKey must be a KeyCode")
	assert(options.MaximizeKey == Enum.KeyCode.Unknown or (options.MaximizeKey ~= options.ToggleKey and options.MaximizeKey ~= Enum.KeyCode.K), "MaximizeKey conflicts with an existing window shortcut")
	for _, key in { "Scale", "BlurSize", "BlurTweenTime", "BackgroundTransparency" } do
		local value = options[key]
		assert(value == nil or (type(value) == "number" and value == value and math.abs(value) < math.huge), `{key} must be a finite number`)
	end
	options.Scale = math.clamp(options.Scale or 1, 0.6, 1.5)
	options.BackgroundTransparency = math.clamp(options.BackgroundTransparency, 0, 1)

	if options.Theme then
		Theme.set(options.Theme)
	end
	if options.ReducedMotion ~= nil then
		Animations.reducedMotion = options.ReducedMotion
	end

	local requested = options.Size or UDim2.fromOffset(860, 520)
	local self = setmetatable({
		options = options,
		account = account,
		cleanup = Cleanup.new(),
		pages = {},
		pageOrder = {},
		history = {},
		historyIndex = 0,
		size = Vector2.new(requested.X.Offset, requested.Y.Offset),
		minSize = options.MinSize or Vector2.new(720, 440),
		scale = 1,
		visible = false,
		minimized = false,
		maximized = false,
		narrow = false,
		toggleKey = options.ToggleKey,
	}, Window)
	local store = Store.new(options.Persistence)
	Account.initialize(self, store)
	local identity = Account.presentation(self)
	options.Title, options.Subtitle = identity.title, identity.subtitle

	local parent = options.Parent
	if not parent then
		local player = Players.LocalPlayer
		assert(player, "CreateWindow must run on the client (LocalScript) or pass Parent")
		parent = player:WaitForChild("PlayerGui")
	end

	self.gui = self.cleanup:add(Factory.new("ScreenGui", {
		Name = "MacUI",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = options.DisplayOrder or 50,
		Parent = parent,
	}))
	self.safeArea = Factory.new("Frame", {
		Name = "SafeArea",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = self.gui,
	})

	local registry = Registry.new()
	self.popups = self.cleanup:add(PopupManager.new(self.gui))
	self.notifications = self.cleanup:add(Notifications.new(self.gui))
	self.ctx = {
		store = store,
		registry = registry,
		popups = self.popups,
		scale = function()
			return self.scale
		end,
		notify = function(n)
			return self:Notify(n)
		end,
		isReserved = function(key)
			if key == self.toggleKey then
				return "the window toggle"
			end
			if key == self.options.MaximizeKey then
				return "the window maximize shortcut"
			end
			return nil
		end,
	}
	self.Flags = store.values

	self:_buildFrame()
	self.palette = self.cleanup:add(CommandPalette.new(self))
	self:_bindInput()

	self.cleanup:connect(self.safeArea:GetPropertyChangedSignal("AbsoluteSize"), function()
		self:_apply(false)
	end)
	self.position = Vector2.zero
	self:_apply(false)
	local actual = self.size * self.scale
	self.position = (self.safeArea.AbsoluteSize - actual) / 2
	self:_apply(false)
	self.cleanup:add(function()
		Blur.release(self, 0)
	end)
	self:Show()
	if account.enabled then
		self:AddPage({ Id = "account", Title = "Account", Icon = "person", Sidebar = false,
			Keywords = "profile username user", Build = Account.build })
	end
	Account.loadThumbnail(self)

	return self
end

-- The fade group is temporary; the settled window renders directly beside its bounded shadow.
function Window:_buildFrame()
	local options = self.options
	local radius = Theme.get("RadiusWindow")
	local alpha = if options.Acrylic then options.BackgroundTransparency else 0

	self.root = Factory.new("Frame", {
		Name = "WindowRoot",
		BackgroundTransparency = 1,
		Visible = false,
		Parent = self.safeArea,
	})
	self.uiScale = Factory.new("UIScale", { Parent = self.root })
	self.fade = Factory.new("CanvasGroup", {
		Name = "Fade",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = self.root,
	}, { Factory.corner(radius) })

	self.shadow = Factory.new("CanvasGroup", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 6),
		Size = UDim2.new(1, 32, 1, 32),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = self.root,
	})
	for _, inset in { 0, 6, 12 } do
		Factory.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
			BackgroundTransparency = 0.96,
			Parent = self.shadow,
			Theme = { BackgroundColor3 = "Shadow" },
		}, { Factory.corner(radius + 16 - inset) })
	end

	self.frame = Factory.new("Frame", {
		Name = "Window",
		Active = true,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = alpha,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = self.fade,
		Theme = { BackgroundColor3 = "Background" },
	}, {
		Factory.corner(radius),
		Factory.stroke("Border", 0.15),
	})

	if options.Acrylic then
		Factory.new("Frame", {
			Name = "Sheen",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 0.965,
			ZIndex = 0,
			Parent = self.frame,
			Theme = { BackgroundColor3 = "Sheen" },
		}, {
			Factory.corner(radius),
			Factory.new("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.35, 0.85),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end

	self.sidebar = self.cleanup:add(Sidebar.new(self, self.frame, {
		Width = 232,
		Transparency = if options.Acrylic then math.max(0, alpha - 0.1) else 0,
		Title = options.Title,
		Subtitle = options.Subtitle,
		Icon = options.Icon,
		AnimatedIcon = options.AnimatedIcon,
	}))

	local main = Factory.new("Frame", {
		Name = "Main",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = self.frame,
	})
	self.main = main

	local header = Factory.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER),
		BackgroundTransparency = 1,
		Active = true,
		Parent = main,
	}, {
		Factory.padding(0, 12),
		Factory.list(8, true, { HorizontalFlex = Enum.UIFlexAlignment.None }),
	})
	self.header = header

	self.menuButton = Display.iconButton("sidebar", 28, function()
		self:_toggleDrawer()
	end)
	self.menuButton.LayoutOrder = 0
	self.menuButton.Visible = false
	self.menuButton.Parent = header

	local nav = Factory.new("Frame", {
		Name = "History",
		Size = UDim2.fromOffset(65, 28),
		LayoutOrder = 1,
		Parent = header,
		Theme = { BackgroundColor3 = "Sidebar" },
	}, {
		Factory.corner(14),
		Factory.stroke("Border", 0.35),
	})
	local function navButton(icon: string, x: number)
		local button = Factory.button({
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(32, 28),
			Parent = nav,
		})
		local glyph = Icons.create({ Icon = icon, Color = "TextPrimary" }, 18, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = button,
		})
		return button, glyph
	end
	local back, backGlyph = navButton("chevron-large-left", 0)
	local forward, forwardGlyph = navButton("chevron-large-right", 33)
	Factory.new("Frame", {
		Position = UDim2.new(0, 32, 0.25, 0),
		Size = UDim2.new(0, 1, 0.5, 0),
		Parent = nav,
		Theme = { BackgroundColor3 = "Border" },
	})
	self.backGlyph, self.forwardGlyph = backGlyph, forwardGlyph
	self.cleanup:connect(back.Activated, function()
		self:Back()
	end)
	self.cleanup:connect(forward.Activated, function()
		self:Forward()
	end)

	local titles = Factory.new("Frame", {
		Name = "HeaderDragRegion",
		Size = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		Active = true,
		LayoutOrder = 2,
		Parent = header,
	}, {
		Factory.fill(),
		Factory.list(10, true),
	})
	self.titleLabel = Factory.text({
		Text = "",
		Typography = "WindowTitle",
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		Parent = titles,
	}, { Factory.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Shrink }) })
	self.descriptionLabel = Factory.text({
		Text = "",
		Typography = "Description",
		Size = UDim2.new(0, 0, 0, 20),
		LayoutOrder = 2,
		Parent = titles,
		Theme = { TextColor3 = "TextMuted" },
	}, { Factory.fill() })

	self.headerActions = Factory.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = header,
	}, { Factory.list(4, true) })

	local searchButton = Display.iconButton("magnifying-glass", 28, function()
		self.palette:open()
	end)
	searchButton.LayoutOrder = 100
	searchButton.Parent = self.headerActions
	self.cleanup:add(Display.tooltip(self.popups, searchButton, "Search everything  (Ctrl+K)"))
	self.optionsButton = Display.iconButton("three-dots-horizontal", 28, function()
		self:_toggleOptions()
	end)
	self.optionsButton.Name = "Options"
	self.optionsButton.LayoutOrder = 101
	self.optionsButton.Parent = self.headerActions

	self.body = Factory.new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, HEADER),
		Size = UDim2.new(1, 0, 1, -HEADER),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = main,
	})

	self.emptyState = Factory.text({
		Text = "Add a page with Window:AddPage() to get started.",
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = self.body,
		Theme = { TextColor3 = "TextMuted" },
	})

	self.scrim = Factory.button({
		Name = "DrawerScrim",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 5,
		Parent = self.frame,
		Theme = { BackgroundColor3 = "Scrim" },
	})
	self.cleanup:connect(self.scrim.Activated, function()
		self:_toggleDrawer(false)
	end)

	self.dragController = DragResize.drag(self)
	if options.Resizable then
		self.grip = DragResize.resize(self, self.frame)
	end
	self:_updateHistoryButtons()
end

function Window:_toggleOptions()
	if self.optionsPopup then self.optionsPopup.close() return end
	local cleanup = Cleanup.new()
	local menu = PopupManager.surface(212, { Name = "WindowOptions" })
	Factory.padding(4).Parent = menu
	local row = Factory.button({ Name = "AutoCensorUser", Size = UDim2.fromOffset(204, 32), Parent = menu,
		Theme = { BackgroundColor3 = "SurfaceHover" } }, { Factory.corner(6) })
	local check = Icons.create("check", 16, { Position = UDim2.fromOffset(8, 8), Parent = row })
	Factory.text({ Text = "Auto Censor User", Position = UDim2.fromOffset(32, 0),
		Size = UDim2.new(1, -40, 1, 0), Parent = row })
	cleanup:add(self:ObserveAccount(function(data)
		check.Visible = data.censored
		row:SetAttribute("Checked", data.censored)
	end))
	cleanup:connect(row.MouseEnter, function()
		Animations.tween(row, { BackgroundTransparency = 0 }, Theme.Motion.Hover)
	end)
	cleanup:connect(row.MouseLeave, function()
		Animations.tween(row, { BackgroundTransparency = 1 }, Theme.Motion.Hover)
	end)
	cleanup:connect(row.Activated, function()
		self:SetAutoCensorUser(not self:GetAccountPresentation().censored)
	end)
	self.optionsPopup = self.popups:open({ content = menu, anchor = self.optionsButton, align = "right",
		onClose = function()
			self.optionsPopup = nil
			cleanup:clean()
		end })
end

function Window:GetAccountPresentation()
	return Account.presentation(self)
end

-- Immediately delivers current presentation; returns an unsubscribe function.
function Window:ObserveAccount(fn)
	assert(type(fn) == "function", "ObserveAccount requires a callback")
	return Account.observe(self, fn)
end

function Window:SetAutoCensorUser(enabled: boolean)
	assert(type(enabled) == "boolean", "AutoCensorUser must be a boolean")
	self.ctx.store:set("AutoCensorUser", enabled)
end

function Window:_bindInput()
	self.cleanup:add(Input.listen(function(input, processed)
		local key = input.KeyCode
		if key == self.toggleKey and not processed and self.toggleKey ~= Enum.KeyCode.Unknown then
			self:Toggle()
			return true
		end
		if not self.visible then
			return false
		end
		if self.options.Maximizable and key == self.options.MaximizeKey and key ~= Enum.KeyCode.Unknown
			and not processed and not UserInputService:GetFocusedTextBox() and Input.ctrlDown()
			and (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)) then
			self:ToggleMaximize()
			return true
		end
		if self.palette:handleInput(input) then
			return true
		end
		if key == Enum.KeyCode.K and Input.ctrlDown() then
			self.palette:toggle()
			return true
		end
		if key == Enum.KeyCode.Down and self.sidebar:moveResult(1) then
			return true
		end
		if key == Enum.KeyCode.Up and self.sidebar:moveResult(-1) then
			return true
		end
		return false
	end))
	self.cleanup:add(function()
		if self.stopDrag then
			self.stopDrag()
		end
	end)
end

function Window:_fitScale(vp: Vector2): number
	if not self.options.AutoScale then
		return self.options.Scale
	end
	local fit = math.min((vp.X - MARGIN * 2) / self.minSize.X, (vp.Y - MARGIN * 2) / self.minSize.Y)
	return math.min(self.options.Scale, math.max(MIN_SCALE, fit))
end

function Window:_apply(animate: boolean?)
	if self.destroyed then return end
	local vp = self.safeArea.AbsoluteSize
	if vp.X <= MARGIN * 2 or vp.Y <= MARGIN * 2 then
		return
	end
	local scale = self:_fitScale(vp)
	self.scale = scale
	local room = Vector2.new(math.floor((vp.X - MARGIN * 2) / scale), math.floor((vp.Y - MARGIN * 2) / scale))

	if self.maximized then
		self.size = room
		self.position = Vector2.new(MARGIN, MARGIN)
	else
		self.size = Vector2.new(math.round(math.max(self.size.X, self.minSize.X)), math.round(math.max(self.size.Y, self.minSize.Y)))
	end

	local height = if self.minimized then HEADER else self.size.Y

	Animations.tween(self.uiScale, { Scale = scale })
	self.root.Position = UDim2.fromOffset(math.round(self.position.X), math.round(self.position.Y))
	local target = UDim2.fromOffset(math.round(self.size.X), math.round(height))
	Animations.tween(self.root, { Size = target }, if animate then Theme.Motion.Minimize else nil)

	local narrow = self.size.X < NARROW
	local sidebarWidth = if narrow then math.min(232, self.size.X) else math.clamp(math.round(self.size.X * 0.27), 220, 240)
	self.sidebarWidth = sidebarWidth
	self.sidebar.Instance.Size = UDim2.new(0, sidebarWidth, 1, 0)
	if narrow ~= self.narrow then
		self.narrow = narrow
		self.drawerOpen = false
	end
	self:_layoutDrawer()
	self.sidebar:relayout()

	self.popups:setScale(scale)
	self.notifications:setScale(scale)
	if self.grip then
		self.grip.Visible = self.options.Resizable and not self.minimized and not self.maximized
	end
end

function Window:_layoutDrawer()
	local sidebar = self.sidebar.Instance
	local controls = self.sidebar.windowControls
	local controlsParent = if self.narrow then self.header else sidebar
	if controls.Parent ~= controlsParent then
		controls.Parent = controlsParent
		controls.LayoutOrder = -1
		controls.Position = UDim2.fromOffset(16, 15)
	end
	self.menuButton.Visible = self.narrow
	if self.narrow then
		self.main.Position = UDim2.new()
		self.main.Size = UDim2.fromScale(1, 1)
		sidebar.ZIndex = 6
		self.scrim.Visible = self.drawerOpen == true
		Animations.tween(self.scrim, { BackgroundTransparency = if self.drawerOpen then 0.5 else 1 }, Theme.Motion.Select)
		Animations.tween(sidebar, {
			Position = UDim2.fromOffset(if self.drawerOpen then 0 else -self.sidebarWidth - 2, 0),
		}, Theme.Motion.Expand)
	else
		self.scrim.Visible = false
		sidebar.ZIndex = 1
		sidebar.Position = UDim2.new()
		self.main.Position = UDim2.fromOffset(self.sidebarWidth, 0)
		self.main.Size = UDim2.new(1, -self.sidebarWidth, 1, 0)
	end
end

function Window:_toggleDrawer(open: boolean?)
	if not self.narrow then
		return
	end
	if open == nil then
		open = not self.drawerOpen
	end
	self.drawerOpen = open
	self:_layoutDrawer()
end

-- Pages

function Window:AddPage(options: Page.Options)
	assert(type(options) == "table" and options.Title, "AddPage needs a Title")
	local id = options.Id or string.lower(options.Title)
	assert(self.pages[id] == nil, `Page id "{id}" already exists`)
	local page = Page.new(self, options)
	self.pages[page.id] = page
	table.insert(self.pageOrder, page)
	if options.Sidebar ~= false then self.sidebar:addPage(page) end
	if not self.current and options.Sidebar ~= false then
		self:SelectPage(page.id)
	end
	return page
end

function Window:GetPage(id: string)
	return self.pages[id]
end

function Window:_pageChanged(page)
	self.sidebar:updatePage(page)
	if self.current == page then
		self.titleLabel.Text = page.options.Title
	end
end

function Window:_removePage(page)
	self.pages[page.id] = nil
	local index = table.find(self.pageOrder, page)
	if index then
		table.remove(self.pageOrder, index)
	end
	self.sidebar:removePage(page)
	for i = #self.history, 1, -1 do
		if self.history[i] == page.id then
			table.remove(self.history, i)
			if self.historyIndex >= i then
				self.historyIndex -= 1
			end
		end
	end
	if self.current == page then
		self.current = nil
		local first = self.pageOrder[1]
		if first then
			self:SelectPage(first.id, true)
		else
			self.titleLabel.Text = ""
			self.emptyState.Visible = true
		end
	end
	self:_updateHistoryButtons()
end

function Window:_buildAll()
	for _, page in self.pageOrder do
		page:EnsureBuilt()
	end
end

function Window:SelectPage(id: string, skipHistory: boolean?)
	local page = self.pages[id]
	if not page then
		warn(`[MacUI] no page "{id}"`)
		return
	end
	if self.current ~= page then
		self.emptyState.Visible = false
		if self.current then
			self.current:_show(false)
		end
		self.current = page
		page:_show(true)
		self.titleLabel.Text = page.options.Title
		self.descriptionLabel.Text = page.options.Description or ""
		for _, label in { self.titleLabel, self.descriptionLabel } do
			Animations.tween(label, { TextTransparency = if Animations.reducedMotion then 0 else 1 })
			Animations.tween(label, { TextTransparency = 0 }, Theme.Motion.Page)
		end
		self.sidebar:select(page)
		self.popups:closeAll()

		if not skipHistory then
			for i = #self.history, self.historyIndex + 1, -1 do
				self.history[i] = nil
			end
			table.insert(self.history, id)
			if #self.history > 50 then
				table.remove(self.history, 1)
			end
			self.historyIndex = #self.history
		end
		self:_updateHistoryButtons()
	end
	if self.narrow then
		self:_toggleDrawer(false)
	end
end

function Window:_updateHistoryButtons()
	Theme.bind(self.backGlyph, { TextColor3 = if self.historyIndex > 1 then "TextPrimary" else "TextMuted" })
	Theme.bind(self.forwardGlyph, { TextColor3 = if self.historyIndex < #self.history then "TextPrimary" else "TextMuted" })
end

function Window:Back()
	if self.historyIndex > 1 then
		self.historyIndex -= 1
		self:SelectPage(self.history[self.historyIndex], true)
	end
end

function Window:Forward()
	if self.historyIndex < #self.history then
		self.historyIndex += 1
		self:SelectPage(self.history[self.historyIndex], true)
	end
end

-- Visibility

function Window:_setBlur(visible: boolean)
	if visible and self.options.BlurEnabled then
		Blur.set(self, self.options.BlurSize, self.options.BlurTweenTime)
	else
		Blur.release(self, self.options.BlurTweenTime)
	end
end

function Window:Show()
	if self.destroyed or self.visible then
		return
	end
	self.visible = true
	self.root.Visible = true
	self:_apply(false)
	self.frame.Parent = self.fade
	local tween = Animations.tween(self.fade, { GroupTransparency = 0 }, Theme.Motion.Popup)
	-- Render text directly once the fade ends; persistent CanvasGroups resample glyphs.
	local function finish()
		if not self.destroyed and self.visible then
			self.frame.Parent = self.root
		end
	end
	if tween then
		tween.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then
				finish()
			end
		end)
	else
		finish()
	end
	Animations.tween(self.shadow, { GroupTransparency = 0 }, Theme.Motion.Popup)
	self:_setBlur(true)
end

function Window:Hide()
	if self.destroyed or not self.visible then
		return
	end
	self.visible = false
	if self.stopDrag then self.stopDrag() end
	self.popups:closeAll()
	self:_setBlur(false)
	self.frame.Parent = self.fade
	local tween = Animations.tween(self.fade, { GroupTransparency = 1 }, Theme.Motion.Popup)
	Animations.tween(self.shadow, { GroupTransparency = 1 }, Theme.Motion.Popup)
	local function finish()
		if not self.destroyed and not self.visible then
			self.root.Visible = false
		end
	end
	if tween then
		tween.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then
				finish()
			end
		end)
	else
		finish()
	end
end

function Window:Toggle()
	if self.visible then
		self:Hide()
	else
		self:Show()
	end
end

function Window:IsVisible(): boolean
	return self.visible
end

function Window:SetMinimized(minimized: boolean)
	assert(type(minimized) == "boolean", "SetMinimized needs a boolean")
	if self.destroyed or self.minimized == minimized then return end
	if self.stopDrag then self.stopDrag() end
	self.minimized = minimized
	self.popups:closeAll()
	self:_apply(true)
end

function Window:SetMaximized(maximized: boolean)
	assert(type(maximized) == "boolean", "SetMaximized needs a boolean")
	if self.destroyed or (self.maximized == maximized and not self.minimized) then return end
	if self.stopDrag then self.stopDrag() end
	if maximized and not self.maximized then
		self.restore = { size = self.size, position = self.position }
	elseif not maximized and self.maximized and self.restore then
		self.size, self.position = self.restore.size, self.restore.position
	end
	self.maximized = maximized
	self.minimized = false
	self:_apply(false)
end

function Window:Maximize()
	self:SetMaximized(true)
end

function Window:Restore()
	self:SetMaximized(false)
end

function Window:ToggleMaximize()
	self:SetMaximized(not self.maximized)
end

function Window:SetToggleKey(key: Enum.KeyCode)
	self.toggleKey = key
end

function Window:SetTitle(title: string?, subtitle: string?)
	self.sidebar:setIdentity(title, subtitle)
end

function Window:SetTheme(name: string)
	Theme.set(name)
end

function Window:SetReducedMotion(reduced: boolean)
	Animations.reducedMotion = reduced
end

function Window:SetScale(scale: number)
	assert(type(scale) == "number" and scale == scale and math.abs(scale) < math.huge, "Scale must be a finite number")
	self.options.Scale = math.clamp(scale, 0.6, 1.5)
	self:_apply(false)
end

-- Overlays

function Window:Notify(options: Notifications.Options)
	return self.notifications:notify(options)
end

function Window:Confirm(options: Dialog.Options)
	return Dialog.confirm(self.popups, self.frame, options)
end

function Window:OpenCommandPalette(query: string?)
	self.palette:open(query)
end

function Window:AddHeaderAction(options: { Icon: string, Tooltip: string?, Callback: () -> () })
	local button = Display.iconButton(options.Icon, 30, options.Callback)
	button.Parent = self.headerActions
	if options.Tooltip then
		self.cleanup:add(Display.tooltip(self.popups, button, options.Tooltip))
	end
	return button
end

-- State

function Window:GetFlag(id: string): any
	return self.ctx.store:get(id)
end

function Window:SetFlag(id: string, value: any)
	if id == "AutoCensorUser" then assert(type(value) == "boolean", "AutoCensorUser must be a boolean") end
	self.ctx.store:set(id, value)
end

function Window:OnFlagChanged(id: string, fn: (any, any) -> ()): () -> ()
	return self.ctx.store:observe(id, fn)
end

function Window:ExportConfig(): { [string]: any }
	return self.ctx.store:snapshot()
end

function Window:ImportConfig(data: { [string]: any })
	local store = self.ctx.store
	for id, raw in data do
		local current = store:get(id)
		local value = Store.decode(raw)
		if current ~= nil and typeof(value) == typeof(current) then
			store:set(id, value)
		end
	end
end

function Window:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	for i = #self.pageOrder, 1, -1 do
		local page = self.pageOrder[i]
		for j = #page.sections, 1, -1 do
			page.sections[j]:Destroy()
		end
		page.cleanup:clean()
	end
	table.clear(self.pages)
	table.clear(self.pageOrder)
	self.cleanup:clean()
end

return Window

end

-- init
loaders[nodes[""]] = function(script, require)
local Theme = require(script.Core.Theme)
local Animations = require(script.Core.Animations)
local Icons = require(script.Core.Icons)
local Window = require(script.Window.Window)
local AnimatedImage = require(script.Components.AnimatedImage)

local MacUI = {
	Name = "MacUI",
	Version = "1.0.0",
	Theme = Theme,
	Icons = Icons,
	AnimatedImage = AnimatedImage,
}

function MacUI:CreateWindow(options: Window.Options?)
	return Window.new(options or {})
end

function MacUI:SetTheme(name: string)
	Theme.set(name)
end

function MacUI:RegisterTheme(name: string, tokens: { [string]: any })
	Theme.register(name, tokens)
end

function MacUI:SetReducedMotion(reduced: boolean)
	Animations.reducedMotion = reduced
end

return MacUI

end
local function load(module)
    if cache[module] ~= nil then return cache[module] end
    assert(loaders[module], "MacUI: unknown module")
    assert(not loading[module], "MacUI: circular module dependency")
    loading[module] = true
    local ok, value = pcall(loaders[module], module, load)
    loading[module] = nil
    if not ok then error("MacUI / " .. module.Name .. ": " .. tostring(value), 2) end
    cache[module] = value
    return value
end
local MacUI = load(nodes[""])
local createWindow = MacUI.CreateWindow
function MacUI:CreateWindow(options)
    options = table.clone(options or {})
    if not options.Parent and type(gethui) == "function" then
        local ok, parent = pcall(gethui)
        if ok and typeof(parent) == "Instance" then options.Parent = parent end
    end
    return createWindow(self, options)
end
return MacUI
