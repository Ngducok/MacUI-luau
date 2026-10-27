-- Run in Play mode from the client command bar:
--   require(game.ReplicatedStorage.Shared.Tests)()
-- Pure-logic tests also pass from the Studio command bar in Edit mode.
local Shared = script.Parent
local Lib = Shared.UILibrary
local Util = require(Lib.Core.Util)
local Store = require(Lib.Core.Store)
local Registry = require(Lib.Core.Registry)
local CommandPalette = require(Lib.Overlays.CommandPalette)
local Cleanup = require(Lib.Core.Cleanup)
local Input = require(Lib.Core.Input)
local AnimatedImage = require(Lib.Components.AnimatedImage)

local queue = {}

local function test(name: string, fn: () -> ())
	table.insert(queue, { name = name, fn = fn })
end

local function eq(a, b, msg)
	local equal = a == b or (type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6)
	assert(equal, `{msg or "expected equal"}: got {tostring(a)}, want {tostring(b)}`)
end

test("snap clamps and steps", function()
	eq(Util.snap(150, 0, 100, 1), 100)
	eq(Util.snap(-5, 0, 100, 1), 0)
	eq(Util.snap(0.26, 0, 2, 0.05), 0.25)
	eq(Util.snap(7.4, 5, 100, 5), 5)
	eq(Util.snap(7.6, 5, 100, 5), 10)
	eq(Util.format(0.25, 0.05), "0.25")
	eq(Util.format(50, 1), "50")
end)

test("store define, set, observe", function()
	local store = Store.new()
	local id, value = store:define("speed", 16)
	eq(id, "speed")
	eq(value, 16)
	local seen
	local stop = store:observe("speed", function(v)
		seen = v
	end)
	assert(store:set("speed", 20))
	eq(seen, 20)
	assert(not store:set("speed", 20), "same value should not fire")
	stop()
	store:set("speed", 30)
	eq(seen, 20, "listener removed")
	local auto = store:define(nil, true)
	assert(string.sub(auto, 1, 1) == "_", "auto ids are private")
	assert(store:snapshot()[auto] == nil, "private ids not exported")
end)

test("store persistence round-trip", function()
	local saved
	local adapter = {
		Delay = 0,
		Load = function()
			return { color = { __color = "ff0000" }, key = { __enum = "KeyCode", name = "Q" }, bad = "nope" }
		end,
		Save = function(data)
			saved = data
		end,
	}
	local store = Store.new(adapter)
	local _, color = store:define("color", Color3.new())
	eq(color:ToHex(), "ff0000")
	local _, key = store:define("key", Enum.KeyCode.E)
	eq(key, Enum.KeyCode.Q)
	local _, bad = store:define("bad", 5)
	eq(bad, 5, "wrong-typed saved value falls back to default")
	store:set("bad", 6)
	task.wait(0.1)
	assert(saved and saved.bad == 6, "adapter saved")
	eq(saved.color.__color, "ff0000")
end)

test("registry search ranks and filters", function()
	local r = Registry.new()
	local hidden = false
	r:add({ id = "a", kind = "card", title = "Auto Farm", subtitle = "Automation", activate = function() end })
	r:add({ id = "b", kind = "card", title = "Auto Heal", subtitle = "Combat", activate = function() end })
	r:add({ id = "c", kind = "control", title = "Collect radius", subtitle = "General › Auto Collect", activate = function() end })
	r:add({ id = "d", kind = "page", title = "Visuals", activate = function() end, visible = function()
		return not hidden
	end })
	local hits = r:search("auto")
	eq(#hits, 3)
	eq(hits[1].title, "Auto Farm")
	eq(r:search("heal comb")[1].title, "Auto Heal")
	eq(#r:search("zzz"), 0)
	eq(#r:search("vis"), 1)
	hidden = true
	eq(#r:search("vis"), 0, "invisible entries skipped")
	r:remove("a")
	eq(#r:search("farm"), 0)
	eq(r:count(), 3)
end)

test("registry handles hundreds of entries", function()
	local r = Registry.new()
	for i = 1, 600 do
		r:add({ id = tostring(i), kind = "control", title = `Feature {i}`, activate = function() end })
	end
	local start = os.clock()
	local hits = r:search("feature 59", 40)
	local elapsed = os.clock() - start
	assert(#hits >= 1 and hits[1].title == "Feature 59", "best match first")
	assert(elapsed < 0.02, `search took {elapsed}s`)
end)

test("registry replaces duplicate ids and searches aliases and paths", function()
	local r = Registry.new()
	local old = r:add({ id = "same", kind = "page", title = "Old", activate = function() end })
	local remove = r:add({ id = "same", kind = "control", title = "Theme", aliases = { "appearance", "colours" }, subtitle = "Settings › Display", activate = function() end })
	old()
	eq(r:count(), 1, "stale cleanup cannot delete replacement")
	eq(r:search("colours display")[1].title, "Theme")
	r:add({ id = "prefix", kind = "page", title = "Theme settings", activate = function() end })
	r:add({ id = "path", kind = "page", title = "A", subtitle = "Theme", activate = function() end })
	local hits = r:search("theme")
	eq(hits[1].id, "same", "exact control outranks prefix page")
	eq(hits[2].id, "prefix", "title prefix outranks path")
	remove()
	eq(r:count(), 2)
end)

test("palette geometry is compact, bounded and integer aligned", function()
	local full = CommandPalette.layout(Vector2.new(1280, 720), 100)
	eq(full.width, 560)
	eq(full.height, 402)
	eq(full.height, CommandPalette.layout(Vector2.new(1280, 720), 7).height)
	local one = CommandPalette.layout(Vector2.new(1280, 720), 1)
	eq(one.height, 138)
	eq(one.height, CommandPalette.layout(Vector2.new(1280, 720), 0).height)
	for _, area in { Vector2.new(390, 600), Vector2.new(320, 240), Vector2.new(100, 60), Vector2.zero } do
		for _, count in { 0, 1, 7, 100 } do
			local g = CommandPalette.layout(area, count)
			assert(g.width <= area.X * 0.9 and g.height <= area.Y and g.height <= 420)
			assert(g.x >= 0 and g.y >= 0 and g.x + g.width <= area.X and g.y + g.height <= area.Y)
			for _, value in g do eq(value, math.round(value)) end
		end
	end
end)

test("Roboto typography and disabled colors retain theme bindings", function()
	local Theme = require(Lib.Core.Theme)
	local Factory = require(Lib.Core.Factory)
	local previous = Theme.name
	for name, role in Theme.Typography do
		local label = Factory.text({ Text = "Tiếng Việt · 日本語", Typography = name })
		eq(label.FontFace.Family, "rbxasset://fonts/families/Roboto.json")
		eq(label.FontFace.Weight, role.FontFace.Weight)
		eq(label.TextSize, role.TextSize)
		eq(label.TextScaled, false)
		eq(label.TextWrapped, false)
		eq(label.TextTransparency, 0)
		label:Destroy()
	end
	local label = Factory.text({ Text = "Disabled", Theme = { TextColor3 = "TextPrimary" } })
	Theme.setTextDisabled(label, true)
	Theme.bind(label, { TextColor3 = "Success" })
	eq(label.TextColor3, Theme.get("TextDisabled"), "render changes keep disabled contrast")
	Theme.set("Light")
	eq(label.TextColor3, Theme.get("TextDisabled"), "disabled state follows theme")
	Theme.setTextDisabled(label, false)
	eq(label.TextColor3, Theme.get("Success"), "enable restores latest semantic color")
	eq(label.TextTransparency, 0)
	label:Destroy()
	Theme.set(previous)
end)

test("cleanup releases everything", function()
	local c = Cleanup.new()
	local fired = 0
	local folder = Instance.new("Folder")
	c:add(folder)
	c:add(function()
		fired += 1
	end)
	local bindable = Instance.new("BindableEvent")
	c:connect(bindable.Event, function()
		fired += 10
	end)
	c:clean()
	bindable:Fire()
	eq(fired, 1)
	eq(folder.Parent, nil)
	eq(c:count(), 0)
end)

test("input listeners share one connection", function()
	local before = Input.handlerCount()
	local stops = {}
	for i = 1, 5 do
		stops[i] = Input.listen(function()
			return false
		end)
	end
	eq(Input.handlerCount(), before + 5)
	for _, stop in stops do
		stop()
	end
	eq(Input.handlerCount(), before)
end)

test("key names are readable", function()
	eq(Input.keyName(Enum.KeyCode.RightShift), "Right Shift")
	eq(Input.keyName(Enum.KeyCode.Five), "5")
	eq(Input.keyName(nil), "None")
end)

test("animated image frames and shared scheduler", function()
	local before = AnimatedImage.activeCount()
	local anim = AnimatedImage.new({ Image = "rbxasset://x", FrameSize = Vector2.new(10, 10), Columns = 4, Frames = 6, Loop = false, Autoplay = false })
	eq(AnimatedImage.activeCount(), before + 1)
	anim:SetFrame(5)
	eq(anim.Instance.ImageRectOffset, Vector2.new(10, 10))
	anim:_advance()
	assert(not anim:IsPlaying(), "non-looping stops at the end")
	anim:Destroy()
	eq(AnimatedImage.activeCount(), before)
end)

local guiParent: Instance? = nil
local function windowOptions(title: string)
	return { Title = title, ToggleKey = Enum.KeyCode.F12, Parent = guiParent }
end

do
	local UI = require(Lib)
	local Theme = require(Lib.Core.Theme)
	local Blur = require(Lib.Core.Blur)

	test("multilingual text stays aligned across pages and overlays", function()
		local window = require(Shared.Demo)(guiParent)
		window:_buildAll()
		local page = window:AddPage({ Id = "typography", Title = "Tiếng Việt · 日本語" })
		local section = page:AddSection({ Title = "Cài đặt · 表示設定" })
		local card = section:AddCard({ Title = "Hiển thị · 日本語", Description = "Mô tả tiếng Việt có dấu. 日本語の説明を表示します。", Toggle = true })
		local input = card:AddInput({ Title = "Tên hiển thị", Default = "Nguyễn · 日本語" })
		local dropdown = card:AddDropdown({ Title = "Ngôn ngữ", Options = { "Tiếng Việt", "日本語" } })
		card:AddSlider({ Title = "Tốc độ", Min = 0, Max = 100, Default = 50 })
		card:AddButton({ Title = "Lưu · 保存" })
		local color = card:AddColorPicker({ Title = "Màu sắc" })
		for _, item in window.pageOrder do window:SelectPage(item.id) end
		task.wait(0.3)
		eq(window.titleLabel.TextSize, 18)
		eq(window.titleLabel.FontFace.Weight, Enum.FontWeight.SemiBold)
		eq(window.sidebar.rows[1].label.TextSize, 14)
		eq(card.titleLabel.TextSize, 14)
		eq(section.titleLabel.TextSize, 13)
		eq(input.titleLabel.TextSize, 13)
		assert(card.titleLabel.TextBounds.Y <= card.titleLabel.AbsoluteSize.Y + 1, "accented/Japanese title fits vertically")
		assert(card.descriptionLabel.TextFits, "localized description grows vertically")
		assert(card.titleLabel.AbsoluteSize.X <= card.titleLabel.Parent.AbsoluteSize.X, "long titles stay inside header")
		card:SetTitle(string.rep("Hiển thị · 日本語 ", 12))
		local fixed, fixedLabel = require(Lib.Components.Button).make({ Text = "Lưu cài đặt hiển thị · 表示設定を保存", Width = 110 })
		fixed.Parent = card.actions
		task.wait()
		assert(card.titleLabel.AbsoluteSize.X <= card.titleLabel.Parent.AbsoluteSize.X + 1, "long localized title shrinks")
		assert(fixedLabel.AbsoluteSize.X <= fixed.AbsoluteSize.X, "fixed-width action truncates inside button")
		input:SetDisabled(true)
		eq(input.titleLabel.TextColor3, Theme.get("TextDisabled"))
		eq(input.titleLabel.TextTransparency, 0)
		input:SetDisabled(false)
		eq(input.titleLabel.TextColor3, Theme.get("TextPrimary"))
		local function audit(root)
			for _, node in root:GetDescendants() do
				if (node:IsA("TextLabel") or node:IsA("TextBox") or node:IsA("TextButton")) and node.Text ~= "" then
					if not string.find(node.FontFace.Family, "BuilderIcons", 1, true) then
						eq(node.FontFace.Family, "rbxasset://fonts/families/Roboto.json", node:GetFullName())
						eq(node.TextScaled, false)
						eq(node.TextSize, math.round(node.TextSize))
					end
				end
			end
		end
		dropdown:Open()
		audit(window.gui)
		dropdown:Close()
		color:Open()
		audit(window.gui)
		color:Close()
		window:Confirm({ Title = "Xác nhận · 確認", Content = "Lưu thay đổi? 変更を保存しますか？" })
		audit(window.gui)
		window.popups:closeAll()
		window:Notify({ Title = "Đã lưu · 保存済み", Content = "Đã cập nhật cài đặt. 設定を更新しました。", Duration = 0 })
		task.wait(0.3)
		audit(window.gui)
		window:OpenCommandPalette("hiển thị")
		audit(window.palette.session.layer)
		window:Destroy()
	end)

	test("search uses stable hierarchy ids and excludes generic quick links", function()
		local window = UI:CreateWindow(windowOptions("Search registry"))
		local page = window:AddPage({ Id = "settings", Title = "Settings" })
		local section = page:AddSection({ Title = "Appearance" })
		local card = section:AddCard({ Title = "Theme", Aliases = { "colours" } })
		local control = card:AddInput({ Title = "Value" })
		card:AddButton({ Title = "Open" })
		card:AddButton({ Title = "Reset" })
		local other = page:AddSection():AddCard({ Title = "Theme" })
		other:AddInput({ Title = "Value" })
		local quick = page:AddSection():AddCard({ Title = "Theme", Searchable = false })
		quick:AddButton({ Title = "Open" })
		local r = window.ctx.registry
		eq(r:count(), 7, "account page, settings page, two cards, two controls, one contextual action")
		assert(card.registryKey ~= other.registryKey)
		eq(#r:search("open"), 0)
		eq(r:search("colours appearance")[1].id, card.registryKey)
		eq(r:search("reset")[1].title, "Theme: Reset")
		local key = control.registryKey
		card:SetTitle("Palette")
		page:SetTitle("Preferences")
		eq(control.registryKey, key, "rename preserves id")
		eq(r:search("value preferences palette")[1].id, key)
		window:Destroy()
	end)

	test("palette layers, selection, queries and interrupted cleanup", function()
		local window = UI:CreateWindow(windowOptions("Palette lifecycle"))
		local page = window:AddPage({ Id = "p", Title = "Page" })
		local section = page:AddSection()
		for i = 1, 14 do section:AddCard({ Title = `Feature {i}`, Collapsible = true }) end
		local baseline, bindings = Input.handlerCount(), Theme.bindingCount()
		local palette = window.palette
		local function key(code) palette:handleInput({ KeyCode = code }) end
		for _ = 1, 3 do
			window:OpenCommandPalette("feature")
			local session = palette.session
			task.wait(0.2)
			eq(Input.handlerCount(), baseline, "open adds no global handlers")
			eq(session.surface.Parent, palette.popup.frame, "settled text bypasses CanvasGroup")
			eq(palette.popup.uiScale.Scale, 1)
			window.popups:setScale(0.8)
			eq(palette.popup.uiScale.Scale, 1, "main scale never reaches palette")
			local foreground = session.layer.Parent
			local backdrop = session.backdrop.Parent
			eq(foreground.ScreenInsets, Enum.ScreenInsets.CoreUISafeInsets)
			eq(backdrop.ScreenInsets, Enum.ScreenInsets.None)
			eq(backdrop.ClipToDeviceSafeArea, false)
			assert(foreground.DisplayOrder > backdrop.DisplayOrder and backdrop.DisplayOrder > window.gui.DisplayOrder)
			eq(session.backdrop.BorderSizePixel, 0)
			eq(#session.results, 14)
			for _ = 1, 12 do key(Enum.KeyCode.Down) end
			eq(session.selected, 13)
			assert(session.list.CanvasPosition.Y > 0, "keyboard selection scrolls into view")
			session.query.Text = "no such feature"
			task.wait()
			eq(session.selected, 0)
			eq(session.surface.Parent.Size.Y.Offset, 138)
			key(Enum.KeyCode.Down)
			key(Enum.KeyCode.Return)
			assert(palette:isOpen(), "empty Enter is safe")
			key(Enum.KeyCode.Escape)
			assert(not palette:isOpen())
			eq(session.query:IsFocused(), false)
			window:OpenCommandPalette()
			eq(palette.session.query.Text, "", "query resets by default")
			assert(session.finished, "reopen finishes retiring overlay")
			window.options.PalettePreserveQuery = true
			palette.session.query.Text = "Feature 7"
			key(Enum.KeyCode.Escape)
			window:OpenCommandPalette()
			eq(palette.session.query.Text, "Feature 7")
			key(Enum.KeyCode.Return)
			assert(not palette:isOpen())
			task.wait(0.25)
			eq(palette.closing, nil)
			assert(section.cards[7]:IsExpanded(), "result expands relevant card")
			window.options.PalettePreserveQuery = false
		end
		-- Destroy while opening, then destroy with a close fade in progress.
		window:OpenCommandPalette()
		local gui = palette.session.layer.Parent
		window:Destroy()
		eq(gui.Parent, nil)
		eq(palette.closing, nil)
		task.wait()
		assert(Theme.bindingCount() < bindings, "window and palette bindings released")
		local second = UI:CreateWindow(windowOptions("Closing palette"))
		second:OpenCommandPalette()
		local retiring = second.palette.session
		second.palette:toggle()
		second:Destroy()
		assert(retiring.finished)
	end)

	test("native text scale and bounded acrylic layers", function()
		local window = UI:CreateWindow(windowOptions("Compact"))
		eq(window.minSize, Vector2.new(720, 440))
		eq(window.gui.ScreenInsets, Enum.ScreenInsets.None)
		eq(window:_fitScale(Vector2.new(1920, 1080)), 1)
		eq(window:_fitScale(Vector2.new(1366, 768)), 1)
		eq(window:_fitScale(Vector2.new(1024, 700)), 1)
		eq(window:_fitScale(Vector2.new(390, 844)), 0.95)
		window.options.AutoScale = false
		eq(window:_fitScale(Vector2.new(1920, 1080)), 1)
		window.options.Scale = 0.9
		eq(window:_fitScale(Vector2.new(1920, 1080)), 0.9)
		eq(window.uiScale.Parent, window.root)
		eq(window.shadow.Parent, window.root, "shadow outside clipped canvas")
		eq(window.root.ClipsDescendants, false)
		eq(window.frame.BackgroundTransparency, 0.1)
		assert(window.sidebar.Instance.BackgroundTransparency < window.frame.BackgroundTransparency)
		assert(not window.frame:FindFirstChild("TopHighlight"))
		assert(window.shadow:IsA("CanvasGroup"), "native shadow, no TopBar image")
		for _, container in { window.root, window.fade, window.popups.layer, window.notifications.holder } do
			eq(container.BackgroundTransparency, 1, "wrappers draw no background")
			eq(container.BorderSizePixel, 0, "wrappers draw no edge")
			assert(not container:FindFirstChildOfClass("UIStroke"))
		end
		local section = window:AddPage({ Title = "Clarity" }):AddSection()
		local card = section:AddCard({ Title = "Card", Description = "Readable text" })
		card:AddInput({ Title = "Input" })
		eq(section.container.BackgroundTransparency, 0.04)
		for _, node in window.frame:GetDescendants() do
			if node:IsA("TextLabel") or node:IsA("TextButton") or node:IsA("TextBox") then
				eq(node.TextScaled, false)
				eq(node.TextSize, math.round(node.TextSize))
			end
		end
		window.size = Vector2.new(733.7, 467.5)
		window.position = Vector2.new(30.4, 40.6)
		window:_apply(false)
		eq(window.root.Position.X.Offset, math.round(window.root.Position.X.Offset))
		eq(window.root.Position.Y.Offset, math.round(window.root.Position.Y.Offset))
		eq(window.root.Size.X.Offset, math.round(window.root.Size.X.Offset))
		eq(window.root.Size.Y.Offset, math.round(window.root.Size.Y.Offset))
		window:Destroy()
	end)

	test("notification corners keep border inside transparent root", function()
		local window = UI:CreateWindow(windowOptions("Toast corners"))
		window.notifications:setScale(1)
		local close = window:Notify({ Title = "Saved", Content = "Settings updated", Duration = 0,
			Actions = { { Text = "Done" } },
		})
		task.wait(0.3)
		local holder = window.notifications.holder
		local root = holder:FindFirstChild("ToastRoot")
		assert(root)
		eq(root.BackgroundTransparency, 1)
		eq(root.BorderSizePixel, 0)
		assert(not root:FindFirstChildOfClass("UIStroke"))
		local surface = root:FindFirstChild("Surface")
		assert(surface and surface.ClipsDescendants)
		eq(surface.BorderSizePixel, 0)
		eq(surface.BackgroundColor3, Theme.get("Palette"))
		eq(surface:FindFirstChildOfClass("UICorner").CornerRadius, UDim.new(0, 12))
		local border = surface:FindFirstChildOfClass("UIStroke")
		eq(border.BorderStrokePosition, Enum.BorderStrokePosition.Inner)
		eq(border.Color, Theme.get("PaletteBorder"))
		eq(surface.Position, UDim2.fromOffset(0, 0))
		eq(surface.AbsoluteSize.Y, math.round(surface.AbsoluteSize.Y))
		for _, node in root:GetDescendants() do
			assert(not node:IsA("ImageLabel"), "toast has no image shadow with a bright fringe")
		end
		close()
		close()
		task.wait(0.3)
		eq(root.Parent, nil, "dismiss still removes toast")
		eq(window.notifications:count(), 0)
		window:Destroy()
	end)

	test("shared blur survives another window hiding or destroying", function()
		local baseline = Blur.instanceCount()
		local a = UI:CreateWindow(windowOptions("Blur A"))
		local b = UI:CreateWindow(windowOptions("Blur B"))
		eq(Blur.instanceCount(), math.max(baseline, 1), "one shared effect")
		a:Hide()
		a:Destroy()
		eq(Blur.instanceCount(), math.max(baseline, 1), "second window still owns blur")
		b:Hide()
		b:Show()
		task.wait(0.25)
		eq(Blur.instanceCount(), math.max(baseline, 1), "cancelled fade cannot destroy active blur")
		b:Hide()
		b:Destroy()
		eq(Blur.instanceCount(), baseline, "last destroy restores blur")
		local options = windowOptions("No blur")
		options.BlurEnabled = false
		options.Acrylic = false
		local solid = UI:CreateWindow(options)
		eq(Blur.instanceCount(), baseline)
		eq(solid.frame.BackgroundTransparency, 0)
		assert(not solid.frame:FindFirstChild("Sheen"))
		solid:Destroy()
	end)

	test("account uses existing routing, one search result and persistent page state", function()
		local window = UI:CreateWindow(windowOptions("Display alias"))
		local account = window:GetPage("account")
		assert(account and not account.built)
		local profile = window.sidebar.profile
		assert(profile:IsA("TextButton") and profile.Interactable)
		eq(profile.Size.Y.Offset, 48)
		eq(#window.sidebar.rows, 0, "profile is the account navigation entry")
		local dashboard = window:AddPage({ Id = "dashboard", Title = "Dashboard" })
		local toggle = dashboard:AddSection():AddCard({ Title = "Feature" }):AddToggle({ Title = "Enabled", Default = true })
		eq(window.current, dashboard, "first category still opens normally")
		local hits = window.ctx.registry:search("account")
		eq(#hits, 1)
		eq(hits[1].id, "page:account")
		hits[1].activate()
		task.wait(0.3)
		eq(window.current, account)
		eq(window.titleLabel.Text, "Account")
		eq(account.scroller.Visible, true)
		eq(dashboard.scroller.Visible, false)
		eq(profile:GetAttribute("Selected"), true)
		eq(window.sidebar.pill.Visible, false)
		local player = game:GetService("Players").LocalPlayer
		eq(window.account.player, player)
		eq(window.sidebar.titleLabel.Text, if player then player.Name else "Account")
		eq(account.content.AccountIdentity.DisplayName.Text, window.sidebar.titleLabel.Text)
		eq(account.content.AccountIdentity.Avatar.Image, profile.Avatar.Image)
		if player then
			eq(window.account.username, player.Name)
			eq(window.account.displayName, player.DisplayName)
			eq(window.account.userId, player.UserId)
			local group = account:GetSections()[1].container
			eq(group["Display name"].Fields.Value.Text, player.DisplayName)
			eq(group.Username.Fields.Value.Text, `@{player.Name}`)
			eq(group["User ID"].Fields.Value.Text, tostring(player.UserId))
			eq(account.content.AccountIdentity.Identifier.Text, `@{player.Name}`)
		end
		local instances, handlers = #account.scroller:GetDescendants(), window.sidebar.cleanup:count()
		for _ = 1, 10 do window:SelectPage("account") end
		eq(#window.history, 2, "same page does not duplicate history")
		window:Back()
		eq(window.current, dashboard)
		eq(profile:GetAttribute("Selected"), false)
		assert(toggle:GetValue(), "feature state survives account navigation")
		window:Forward()
		eq(window.current, account)
		window.sidebar.query.Text = "account"
		eq(#window.sidebar.results, 1)
		window.sidebar.results[1].activate()
		window.sidebar.query.Text = ""
		window:Back()
		window:OpenCommandPalette("account")
		eq(#window.palette.session.results, 1)
		window.palette.session.activate(1)
		eq(window.current, account)
		account.scroller.Size = UDim2.new(1, 0, 0, 140)
		task.wait(0.3)
		assert(account.scroller.AbsoluteCanvasSize.Y > account.scroller.AbsoluteWindowSize.Y, "account can scroll")
		account.scroller.CanvasPosition = Vector2.new(0, 40)
		window:Back()
		window:Forward()
		task.wait(0.3)
		eq(account.scroller.CanvasPosition.Y, 40, "back/forward preserves scroll")
		eq(#account.scroller:GetDescendants(), instances, "no duplicate account content")
		eq(window.sidebar.cleanup:count(), handlers, "no per-visit input listeners")
		eq(#window.pageOrder, 2)
		window:Destroy()

		local configured = UI:CreateWindow({ Parent = guiParent, Icon = "rbxassetid://1",
			Account = { UseLocalPlayer = false, DisplayName = "Vitto", Subtitle = "Signed in" } })
		eq(configured.account.player, player, "legacy options cannot substitute a player")
		eq(configured.sidebar.titleLabel.Text, if player then player.Name else "Account")
		eq(configured.sidebar.subtitleLabel.Text, "Account")
		configured:SelectPage("account")
		local identity = configured:GetPage("account").content.AccountIdentity
		eq(identity.Identifier.Text, if player then `@{player.Name}` else "Unavailable in this session")
		assert(identity.Avatar.Image ~= "rbxassetid://1", "legacy icon cannot substitute a player portrait")
		configured:SetTitle("Local alias", "Account")
		task.wait()
		eq(identity.DisplayName.Text, if player then player.Name else "Account")
		eq(configured.sidebar.titleLabel.Text, identity.DisplayName.Text)
		configured:Destroy()
		local disabled = UI:CreateWindow({ Parent = guiParent, Account = { Enabled = false } })
		eq(disabled:GetPage("account"), nil)
		eq(disabled.sidebar.profile.Interactable, false)
		disabled:Destroy()
		assert(not pcall(UI.CreateWindow, UI, { Account = { UseLocalPlayer = "yes" } }), "invalid config rejected before mounting")
	end)

	test("traffic lights keep native geometry and explicit group hover", function()
		local options = windowOptions("Traffic lights")
		options.AutoScale = false
		local window = UI:CreateWindow(options)
		local holder = window.sidebar.Instance.WindowControls
		eq(holder.Position, UDim2.fromOffset(16, 15))
		eq(holder.Size, UDim2.fromOffset(55, 13))
		eq(holder.BackgroundTransparency, 1)
		eq(holder:FindFirstChildOfClass("UIListLayout").Padding, UDim.new(0, 8))
		local colors = { Color3.fromRGB(255, 95, 87), Color3.fromRGB(254, 188, 46), Color3.fromRGB(40, 200, 64) }
		for i, name in { "Close", "Minimize", "Maximize" } do
			local button = holder[name]
			eq(button.Size, UDim2.fromOffset(13, 13))
			eq(button.BackgroundColor3, colors[i])
			eq(button:FindFirstChildOfClass("UICorner").CornerRadius, UDim.new(1, 0))
			eq(button.Text, "", "no font glyphs")
			eq(button.Symbol.Visible, false)
		end
		for _, scale in { 0.9, 1, 1.25 } do
			window:SetScale(scale)
			task.wait()
			holder:SetAttribute("Hovered", true)
			task.wait()
			for i, name in { "Close", "Minimize", "Maximize" } do
				local button = holder[name]
				assert(button.Symbol.Visible)
				local delta = button.AbsolutePosition - holder.Close.AbsolutePosition
				assert(math.abs(delta.X - (i - 1) * 21 * scale) <= 1 and math.abs(delta.Y) <= 1, "equal spacing and vertical center at every scale")
			end
			holder:SetAttribute("Hovered", false)
			task.wait()
			for _, name in { "Close", "Minimize", "Maximize" } do eq(holder[name].Symbol.Visible, false) end
		end
		window:SetMinimized(true)
		eq(window.minimized, true)
		window:SetMaximized(true)
		eq(window.minimized, false)
		eq(window.maximized, true)
		window:SetMaximized(false)
		eq(window.maximized, false)
		holder:SetAttribute("Hovered", true)
		window:Hide()
		task.wait(0.25)
		eq(holder:GetAttribute("Hovered"), false, "hide clears hover")
		local connections = {}
		for _, item in window.sidebar.cleanup.tasks do
			if typeof(item) == "RBXScriptConnection" then table.insert(connections, item) end
		end
		window:Destroy()
		for _, connection in connections do eq(connection.Connected, false, "control events released") end
	end)

	test("sidebar columns stay aligned through resize and badge changes", function()
		local options = windowOptions(nil)
		options.AutoScale = false
		options.Scale = 1
		local window = UI:CreateWindow(options)
		window:AddPage({ Id = "grid-home", Title = "Grid home" })
		local status = window:AddPage({ Id = "grid-status", Title = string.rep("Grid automation ", 8), Badge = "NEW" })
		local count = window:AddPage({ Id = "grid-count", Title = "Grid count", Badge = "24" })
		local sidebar = window.sidebar
		local player = game:GetService("Players").LocalPlayer
		eq(sidebar.titleLabel.Text, if player then player.Name else "Account")
		eq(sidebar.subtitleLabel.Text, "Account")
		local profile = sidebar.Instance.AccountProfile
		eq(profile.Size.Y.Offset, 48)
		eq(profile.Avatar.Size, UDim2.fromOffset(32, 32))
		eq(profile.Avatar:FindFirstChildOfClass("UICorner").CornerRadius, UDim.new(1, 0))
		window:SetTitle("Vitto", "Signed in")
		eq(sidebar.titleLabel.Text, if player then player.Name else "Account")
		eq(sidebar.subtitleLabel.Text, "Account")
		local function near(a, b, message)
			assert(math.abs(a - b) <= 1, `{message}: {a} vs {b}`)
		end
		for _, width in { 720, 860, 960 } do
			window.size = Vector2.new(width, 520)
			window:_apply(false)
			window:SelectPage(status.id)
			task.wait(0.3)
			local textX = sidebar.rows[1].label.AbsolutePosition.X
			for _, row in sidebar.rows do
				eq(row.button.AbsoluteSize.Y, 36)
				eq(row.icon.AbsoluteSize, Vector2.new(16, 16))
				near(row.icon.AbsolutePosition.X - row.button.AbsolutePosition.X, 12, "left padding")
				near(row.label.AbsolutePosition.X - row.icon.AbsolutePosition.X - 16, 12, "icon gap")
				near(row.label.AbsolutePosition.X, textX, "shared text column")
				near(row.icon.AbsolutePosition.Y + 8, row.button.AbsolutePosition.Y + 18, "centered icon")
				if row.badge then
					eq(row.badge.AbsoluteSize.Y, 18)
					assert(row.badge.AbsoluteSize.X >= 22, "minimum count width")
					near(row.badge.AbsolutePosition.X + row.badge.AbsoluteSize.X,
						row.button.AbsolutePosition.X + row.button.AbsoluteSize.X - 12, "right badge column")
					near(row.badge.AbsolutePosition.Y + 9, row.button.AbsolutePosition.Y + 18, "centered badge")
					assert(row.label.AbsolutePosition.X + row.label.AbsoluteSize.X <= row.badge.AbsolutePosition.X, "long title cannot overlap badge")
				end
			end
			near(sidebar.titleLabel.AbsolutePosition.X, textX, "identity title column")
			near(sidebar.subtitleLabel.AbsolutePosition.X, textX, "identity subtitle column")
			near(sidebar.subtitleLabel.AbsolutePosition.Y, sidebar.titleLabel.AbsolutePosition.Y + sidebar.titleLabel.AbsoluteSize.Y, "tight identity text")
			eq(sidebar.pill.AbsoluteSize, sidebar.rows[2].button.AbsoluteSize)
			near(sidebar.pill.AbsolutePosition.X, sidebar.rows[2].button.AbsolutePosition.X, "active row left")
			near(sidebar.pill.AbsolutePosition.Y, sidebar.rows[2].button.AbsolutePosition.Y, "active row top")
			count:SetBadge("1")
		end
		status:SetBadge(nil)
		sidebar.query.Text = "Grid"
		task.wait(0.1)
		for _, row in sidebar.resultRows do
			eq(row.AbsoluteSize.Y, 36)
			local text = row:FindFirstChildOfClass("Frame")
			near(text.AbsolutePosition.X, sidebar.titleLabel.AbsolutePosition.X, "search shares text column")
		end
		sidebar.query.Text = ""
		window:Destroy()
	end)

	test("rapid tab and visibility changes settle correctly", function()
		local window = UI:CreateWindow(windowOptions("Transitions"))
		local a = window:AddPage({ Id = "a", Title = "A" })
		local b = window:AddPage({ Id = "b", Title = "B" })
		local c = window:AddPage({ Id = "c", Title = "C" })
		task.wait()
		window:SelectPage("b")
		window:SelectPage("a")
		window:SelectPage("c")
		window:Hide()
		window:Show()
		task.wait(0.3)
		eq(window.current, c)
		eq(a.scroller.Visible, false)
		eq(b.scroller.Visible, false)
		eq(c.scroller.Visible, true)
		eq(c.scroller.Position, UDim2.new())
		eq(window.titleLabel.TextTransparency, 0)
		eq(window.fade.GroupTransparency, 0)
		eq(window.root.Visible, true)
		eq(window.frame.Parent, window.root, "settled text bypasses CanvasGroup rasterization")
		local row = window.sidebar:_selectedRow()
		local delta = math.abs(window.sidebar.pill.AbsolutePosition.Y - row.button.AbsolutePosition.Y)
		assert(delta <= 1, `selection pill offset by {delta}px`)
		window:Back()
		eq(window.current, a)
		window:Forward()
		eq(window.current, c)
		window:Destroy()
	end)

	test("reduced motion settles tab and visibility immediately", function()
		local before = require(Lib.Core.Animations).reducedMotion
		local options = windowOptions("Reduced motion")
		options.ReducedMotion = true
		local window = UI:CreateWindow(options)
		window:AddPage({ Id = "a", Title = "A" })
		local b = window:AddPage({ Id = "b", Title = "B" })
		window:SelectPage("b")
		eq(b.scroller.Position, UDim2.new())
		eq(window.titleLabel.TextTransparency, 0)
		window:Hide()
		eq(window.root.Visible, false)
		window:Show()
		eq(window.fade.GroupTransparency, 0)
		eq(window.frame.Parent, window.root)
		window:OpenCommandPalette()
		local paletteGui = window.palette.session.layer.Parent
		eq(window.palette.session.surface.Parent, window.palette.popup.frame)
		window.palette:toggle()
		eq(window.palette.closing, nil, "reduced motion closes immediately")
		eq(paletteGui.Parent, nil)
		window:Destroy()
		UI:SetReducedMotion(before)
	end)

	test("window lifecycle releases connections", function()
		local baseline = Input.handlerCount()
		local animBaseline = AnimatedImage.activeCount()
		local themeBaseline = Theme.bindingCount()
		for _ = 1, 3 do
			local window = UI:CreateWindow(windowOptions("Test"))
			local page = window:AddPage({ Id = "p", Title = "Page" })
			local card = page:AddSection({ Title = "S" }):AddCard({ Id = "c", Title = "Card", Toggle = true, Collapsible = true })
			local slider = card:AddSlider({ Id = "s", Title = "S", Min = 0, Max = 10, Default = 3 })
			card:AddKeybind({ Id = "k", Title = "K" })
			card:AddAnimatedImage({ Image = "rbxasset://x", FrameSize = Vector2.new(1, 1), Columns = 1, Frames = 2 })
			slider:SetValue(99)
			eq(slider:GetValue(), 10, "slider clamps")
			eq(window:GetFlag("s"), 10, "flag registry")
			card:SetExpanded(true)
			assert(card:IsExpanded())
			window:Destroy()
		end
		eq(Input.handlerCount(), baseline, "no leaked input handlers")
		eq(AnimatedImage.activeCount(), animBaseline, "no leaked animations")
		task.wait()
		eq(Theme.bindingCount(), themeBaseline, "no leaked theme bindings")
	end)

	test("controls update, disable and remove", function()
		local window = UI:CreateWindow(windowOptions("Test2"))
		local card = window:AddPage({ Title = "P" }):AddSection():AddCard({ Title = "C" })
		local calls = 0
		local toggle = card:AddToggle({ Id = "t", Title = "T", Callback = function()
			calls += 1
		end })
		toggle:SetValue(true)
		task.wait()
		eq(calls, 1, "callback fires on change")
		toggle:SetValue(true)
		task.wait()
		eq(calls, 1, "no callback when unchanged")
		local dropdown = card:AddDropdown({ Id = "d", Title = "D", Options = { "A", "B" }, Multi = true })
		dropdown:SetValue({ "B", "B", "A" })
		eq(#dropdown:GetValue(), 2, "multi dedupes")
		dropdown:SetOptions({ "A" })
		eq(#dropdown:GetValue(), 1, "unknown options dropped")
		toggle:SetDisabled(true)
		eq(toggle.Instance.Interactable, false)
		toggle:Destroy()
		eq(window:GetFlag("t"), nil, "destroyed control leaves registry")
		eq(#card:GetControls(), 1)
		window:Destroy()
	end)
end

-- parent: where test windows mount (PlayerGui by default; CoreGui from a plugin).
return function(parent: Instance?)
	guiParent = parent
	local passed = 0
	for _, t in queue do
		local ok, err = pcall(t.fn)
		if ok then
			passed += 1
		else
			warn(`FAIL {t.name}: {err}`)
		end
	end
	print(`[UILibrary tests] {passed}/{#queue} passed`)
	return passed == #queue
end
