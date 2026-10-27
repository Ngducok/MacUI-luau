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
