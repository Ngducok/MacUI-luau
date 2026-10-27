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
