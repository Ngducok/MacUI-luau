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
