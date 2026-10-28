-- MacUI full demo | https://github.com/Ngducok/MacUI-luau
local buildDemo = (function()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Ngducok/MacUI-luau/main/dist/MacUI.luau"))()

-- parent: optional ScreenGui parent (PlayerGui by default). Returns the window.
return function(parent: Instance?)

	local player = Players.LocalPlayer

	local Window = UI:CreateWindow({
		Subtitle = "Account",
		Size = UDim2.fromOffset(860, 520),
		ToggleKey = Enum.KeyCode.RightShift,
		Resizable = true,
		Draggable = true,
		Parent = parent,
	})

	-- Dashboard

	local Dashboard = Window:AddPage({
		Id = "dashboard",
		Title = "Dashboard",
		Description = "Session overview",
		Icon = "four-squares-grid",
	})

	local Session = Dashboard:AddSection({ Title = "Session" })

	local identity = Window:GetAccountPresentation()
	local profile = Session:AddCard({
		Id = "session-status",
		Title = identity.displayName,
		Description = identity.sessionDescription,
		Icon = "person",
		NavigateTo = "account",
	})
	profile.cleanup:add(Window:ObserveAccount(function(data)
		profile:SetTitle(data.displayName)
		profile:SetDescription(data.sessionDescription)
	end))

	local Uptime = Session:AddCard({ Title = "Session time", Description = "Time since this window opened", Icon = "clock" })
	local uptimeLabel = Uptime:AddLabel({ Title = "Elapsed", Value = "0s" })
	local fpsLabel = Uptime:AddLabel({ Title = "Frame rate", Value = "-" })
	local started = os.clock()
	task.spawn(function()
		while Window and not Window.destroyed do
			local seconds = math.floor(os.clock() - started)
			uptimeLabel:SetValue(string.format("%dm %02ds", seconds // 60, seconds % 60))
			task.wait(1)
		end
	end)
	local frames, last = 0, os.clock()
	Window.cleanup:connect(RunService.Heartbeat, function()
		frames += 1
		local now = os.clock()
		if now - last >= 1 then
			fpsLabel:SetValue(`{frames} fps`)
			frames, last = 0, now
		end
	end)

	local Activity = Session:AddCard({ Title = "Activity", Description = "Features turned on right now", Icon = "chart-line" })
	local activeStatus = Activity:AddStatus({ Title = "Enabled features", Value = "0 on", Kind = "Neutral" })
	local tracked = {}
	local function refreshActivity()
		local on = 0
		for _, card in tracked do
			if card:GetEnabled() then
				on += 1
			end
		end
		activeStatus:SetValue(`{on} on`, if on > 0 then "Success" else "Neutral")
	end

	local Quick = Dashboard:AddSection({ Title = "Quick actions", Layout = "Grid" })
	local quickActions = {
		{ "Auto Farm", "Jump to farming settings", "two-arrows-loop-clockwise", "automation", "auto-farm" },
		{ "Walk Speed", "Tune movement speed", "person-running", "movement", "walk-speed" },
		{ "Highlights", "Outline players and items", "eye", "visuals", "highlights" },
		{ "Theme", "Switch light or dark", "paint-brush", "settings", "appearance" },
		{ "Shortcuts", "Change window keys", "keyboard", "settings", "shortcuts" },
		{ "Notifications", "Preview toast styles", "bell", "misc", "toasts" },
	}
	for _, info in quickActions do
		local tile = Quick:AddCard({ Title = info[1], Description = info[2], Icon = info[3], Searchable = false })
		tile:AddParagraph({ Content = "Opens the full settings for this feature." })
		tile:AddButton({
			Title = "Open",
			Variant = "Primary",
			Callback = function()
				local page = Window:GetPage(info[4])
				page:EnsureBuilt()
				for _, section in page:GetSections() do
					for _, card in section:GetCards() do
						if card.options.Id == info[5] then
							card:Focus()
							return
						end
					end
				end
			end,
		})
	end

	local Updates = Dashboard:AddSection({}):AddUpdateLog({
		Id = "feature-updates", Title = "Update Logs", InitialVisibleCount = 5,
	})
	UI.UpdateLogs(Updates:GetWriters())

	-- General

	local General = Window:AddPage({ Id = "general", Title = "General", Icon = "gear" })

	local Behaviour = General:AddSection({ Title = "Behaviour" })
	Behaviour:AddCard({
		Id = "open-on-join",
		Title = "Open on join",
		Description = "Show this window when you join the game.",
		Toggle = true,
		Default = true,
	})
	Behaviour:AddCard({
		Id = "remember-page",
		Title = "Remember last page",
		Description = "Reopen the page you used last time.",
		Toggle = true,
		Default = true,
	})
	Behaviour:AddCard({
		Id = "confirm-reset",
		Title = "Confirm before reset",
		Description = "Ask before restoring settings to their defaults.",
		Toggle = true,
		Default = true,
	})
	Behaviour:AddPrioritySelector({
		Id = "task-priority", Title = "Task Order", Columns = 2,
		Items = {
			{ Id = "gather", Label = "Gather" },
			{ Id = "craft", Label = "Craft" },
			{ Id = "deliver", Label = "Deliver" },
		},
	})
	local Filters = General:AddSection({ Title = "Filters" }):AddToggleDropdownGroup({
		Id = "sample-filters", Title = "Filters", DefaultEnabled = true,
		DefaultExpanded = false, Columns = 3, Responsive = true,
	})
	Filters:AddDropdown({ Id = "sample-region", Title = "Region", Options = { "North", "South", "West" }, Default = "North" })
	Filters:AddDropdown({ Id = "sample-mode", Title = "Mode", Options = { "Fast", "Normal", "Safe" }, Default = "Normal" })
	Filters:AddDropdown({ Id = "sample-quality", Title = "Quality", Options = { "Low", "Medium", "High" }, Default = "High" })

	local Collect = General:AddSection({ Title = "Collection" })
	local autoCollect = Collect:AddCard({
		Id = "auto-collect",
		Title = "Auto Collect",
		Description = "Pick up drops near your character.",
		Icon = "backpack",
		Toggle = true,
		Collapsible = true,
	})
	autoCollect:AddSlider({ Id = "collect-radius", Title = "Radius", Min = 4, Max = 60, Default = 20, Suffix = " studs" })
	autoCollect:AddDropdown({
		Id = "collect-filter",
		Title = "Item types",
		Options = { "Coins", "Gems", "Chests", "Keys", "Consumables" },
		Default = { "Coins", "Gems" },
		Multi = true,
	})
	table.insert(tracked, autoCollect)

	-- Automation

	local Automation = Window:AddPage({ Id = "automation", Title = "Automation", Icon = "two-arrows-loop-clockwise", Badge = "NEW" })

	local Farm = Automation:AddSection({ Title = "Farming", Description = "Configure automated behaviours." })
	local FarmCard = Farm:AddCard({
		Id = "auto-farm",
		Title = "Auto Farm",
		Description = "Move between targets and collect rewards automatically.",
		Icon = "wheat",
		Toggle = true,
		Collapsible = true,
		DefaultExpanded = true,
		Callback = function(on)
			Window:Notify({ Title = if on then "Auto Farm on" else "Auto Farm off", Duration = 2, Kind = if on then "success" else "info" })
		end,
	})
	FarmCard:AddSlider({ Id = "farm-range", Title = "Farm range", Min = 5, Max = 100, Default = 50, Step = 1, Suffix = " studs" })
	FarmCard:AddDropdown({
		Id = "target-mode",
		Title = "Target mode",
		Options = { "Nearest", "Lowest HP", "Highest HP", "Most valuable" },
		Default = "Nearest",
		Searchable = true,
	})
	FarmCard:AddSlider({ Id = "farm-delay", Title = "Delay between targets", Min = 0, Max = 2, Step = 0.05, Default = 0.25, Suffix = "s" })
	FarmCard:AddButton({
		Title = "Reset configuration",
		Variant = "Destructive",
		Callback = function()
			Window:Confirm({
				Title = "Reset Auto Farm?",
				Content = "Range, target mode and delay go back to their defaults.",
				ConfirmText = "Reset",
				Destructive = true,
				OnConfirm = function()
					Window:SetFlag("farm-range", 50)
					Window:SetFlag("target-mode", "Nearest")
					Window:SetFlag("farm-delay", 0.25)
					Window:Notify({ Title = "Auto Farm reset", Kind = "success", Duration = 2 })
				end,
			})
		end,
	})
	table.insert(tracked, FarmCard)

	local Quest = Farm:AddCard({
		Id = "auto-quest",
		Title = "Auto Quest",
		Description = "Accept and turn in quests from nearby NPCs.",
		Icon = "book-open",
		Toggle = true,
		Collapsible = true,
	})
	Quest:AddDropdown({ Id = "quest-priority", Title = "Priority", Options = { "Daily first", "Highest reward", "Closest" } })
	Quest:AddToggle({ Id = "quest-skip-dialog", Title = "Skip dialogue", Default = true })
	local questProgress = Quest:AddProgress({ Title = "Current quest" })
	table.insert(tracked, Quest)

	local Rooms = { "Rare chest", "Treasure chest", "Hoard", "Shop", "Shrine", "Curse", "Boss", "Open chests" }
	local RoomPriority = Farm:AddCard({
		Id = "room-priority",
		Title = "Room Priority",
		Description = "Configure room priority order",
		Toggle = true, Default = true, Collapsible = true,
		DefaultExpanded = true,
	})
	-- Keep the demo's existing per-slot string flags; the reusable selector only stores stable IDs.
	local roomIds = { "rare", "treasure", "hoard", "shop", "shrine", "curse", "boss", "open-chests" }
	local roomItems, roomIdByLabel, roomLabelById = {}, {}, {}
	local hasLegacyOrder = false
	for index, label in Rooms do
		local id = roomIds[index]
		roomItems[index] = { Id = id, Label = label }
		roomIdByLabel[label], roomLabelById[id] = id, label
		local flag = Window.ctx.store:define(`priority-{index}`, label)
		hasLegacyOrder = hasLegacyOrder or Window.ctx.store.saved[flag] ~= nil
		Window.cleanup:add(function() Window.ctx.store:remove(flag) end)
	end
	local function legacyOrder()
		local order, seen = {}, {}
		for index = 1, #Rooms do
			local id = roomIdByLabel[Window:GetFlag(`priority-{index}`)]
			if id and not seen[id] then seen[id] = true; table.insert(order, id) end
		end
		for _, id in roomIds do if not seen[id] then table.insert(order, id) end end
		return order
	end
	local syncingLegacy = false
	local function writeLegacy(order)
		syncingLegacy = true
		for index, id in order do Window:SetFlag(`priority-{index}`, roomLabelById[id]) end
		syncingLegacy = false
	end
	local roomSelector = RoomPriority:AddPrioritySelector({
		Id = "room-priority-order", Items = roomItems, Default = legacyOrder(), Columns = "Auto",
		OnChanged = writeLegacy,
	})
	if hasLegacyOrder then roomSelector:SetOrder(legacyOrder(), { Silent = true }) end
	writeLegacy(roomSelector:GetOrder())
	local syncPending = false
	for index = 1, #Rooms do
		Window.cleanup:add(Window:OnFlagChanged(`priority-{index}`, function()
			if syncingLegacy or syncPending then return end
			syncPending = true
			task.defer(function()
				syncPending = false
				if not Window.destroyed then roomSelector:SetOrder(legacyOrder()) end
			end)
		end))
	end
	table.insert(tracked, RoomPriority)

	local Scan = Automation:AddSection({ Title = "Server" })
	local Scanner = Scan:AddCard({
		Id = "server-scan",
		Title = "Server scan",
		Description = "Look for rare spawns on this server.",
		Icon = "binoculars",
		Collapsible = true,
	})
	local scanStatus = Scanner:AddStatus({ Title = "Status", Value = "Idle" })
	local scanProgress = Scanner:AddProgress({ Title = "Progress", Value = 0 })
	Scanner:AddButton({
		Title = "Start scan",
		Variant = "Primary",
		Callback = function()
			Scanner:SetLoading(true)
			scanStatus:SetValue("Scanning", "Accent")
			for i = 1, 20 do
				scanProgress:SetValue(i / 20)
				questProgress:SetValue(i / 20)
				task.wait(0.08)
			end
			Scanner:SetLoading(false)
			scanStatus:SetValue("Done", "Success")
			Window:Notify({ Title = "Scan complete", Content = "No rare spawns found on this server.", Kind = "success" })
		end,
	})

	local Routines = Automation:AddSection({ Title = "Routines", Description = "Small helpers that run in the background." })
	local routineNames = {
		{ "Auto Rejoin", "Rejoin automatically if you get disconnected.", "arrow-rotate-right" },
		{ "Anti AFK", "Stop the idle kick after 20 minutes.", "clock" },
		{ "Auto Sell", "Sell inventory when it is full.", "wallet" },
		{ "Auto Equip Best", "Equip your strongest tool after each upgrade.", "trophy" },
		{ "Auto Claim Rewards", "Claim daily and playtime rewards.", "gift-box" },
		{ "Auto Rebirth", "Rebirth as soon as you meet the requirement.", "arrow-spin-clockwise" },
	}
	for i, info in routineNames do
		local card = Routines:AddCard({
			Id = `routine-{i}`,
			Title = info[1],
			Description = info[2],
			Icon = info[3],
			Toggle = true,
		})
		table.insert(tracked, card)
	end

	-- Combat (lazy)

	Window:AddPage({
		Id = "combat",
		Title = "Combat",
		Icon = "sword",
		Build = function(page)
			local Aim = page:AddSection({ Title = "Targeting" })
			local assist = Aim:AddCard({
				Id = "aim-assist",
				Title = "Aim Assist",
				Description = "Gently pull your aim toward the nearest target.",
				Icon = "crosshairs",
				Toggle = true,
				Collapsible = true,
			})
			assist:AddSlider({ Id = "aim-strength", Title = "Strength", Min = 0, Max = 100, Default = 35, Suffix = "%" })
			assist:AddSlider({ Id = "aim-fov", Title = "Field of view", Min = 10, Max = 180, Default = 60, Suffix = "°" })
			assist:AddDropdown({ Id = "aim-part", Title = "Target part", Options = { "Head", "Torso", "Closest" }, Default = "Torso" })
			assist:AddKeybind({ Id = "aim-key", Title = "Hold key", Default = Enum.KeyCode.Q })
			table.insert(tracked, assist)

			local heal = Aim:AddCard({
				Id = "auto-heal",
				Title = "Auto Heal",
				Description = "Use a potion when health drops below the threshold.",
				Icon = "heart",
				Toggle = true,
				Collapsible = true,
			})
			heal:AddSlider({ Id = "heal-threshold", Title = "Health threshold", Min = 5, Max = 95, Default = 40, Suffix = "%" })
			heal:AddDropdown({ Id = "heal-item", Title = "Item", Options = { "Small potion", "Large potion", "Bandage" } })
			table.insert(tracked, heal)

			local Abilities = page:AddSection({ Title = "Abilities", Layout = "Grid" })
			local abilities = {
				{ "Auto Block", "Block incoming hits", "shield-check" },
				{ "Combo Assist", "Chain attacks on time", "lightning-bolt" },
				{ "Auto Dodge", "Dash away from AoE", "person-running" },
				{ "Ability Cooldowns", "Show cooldown timers", "clock" },
				{ "Hit Markers", "Show damage numbers", "crosshairs" },
				{ "Kill Feed", "Show recent eliminations", "list-bulleted" },
			}
			for i, info in abilities do
				local tile = Abilities:AddCard({
					Id = `ability-{i}`,
					Title = info[1],
					Description = info[2],
					Icon = info[3],
					Toggle = true,
				})
				tile:AddSlider({ Id = `ability-{i}-intensity`, Title = "Intensity", Min = 1, Max = 10, Default = 5 })
				table.insert(tracked, tile)
			end
		end,
	})

	-- Movement (lazy)

	Window:AddPage({
		Id = "movement",
		Title = "Movement",
		Icon = "person-running",
		Build = function(page)
			local Speed = page:AddSection({ Title = "Character" })
			local walk = Speed:AddCard({
				Id = "walk-speed",
				Title = "Walk Speed",
				Description = "Change how fast your character walks.",
				Icon = "person-walking",
				Toggle = true,
				Collapsible = true,
				Callback = function(on)
					local humanoid = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.WalkSpeed = if on then Window:GetFlag("walk-speed-value") else 16
					end
				end,
			})
			walk:AddSlider({
				Id = "walk-speed-value",
				Title = "Speed",
				Min = 16,
				Max = 100,
				Default = 24,
				Callback = function(value)
					local humanoid = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid and walk:GetEnabled() then
						humanoid.WalkSpeed = value
					end
				end,
			})
			table.insert(tracked, walk)

			local jump = Speed:AddCard({
				Id = "jump-power",
				Title = "Jump Power",
				Description = "Change how high your character jumps.",
				Icon = "arrow-up-from-line",
				Toggle = true,
				Collapsible = true,
				Callback = function(on)
					local humanoid = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.UseJumpPower = true
						humanoid.JumpPower = if on then Window:GetFlag("jump-power-value") else 50
					end
				end,
			})
			jump:AddSlider({ Id = "jump-power-value", Title = "Power", Min = 50, Max = 200, Default = 75 })
			table.insert(tracked, jump)

			local Travel = page:AddSection({ Title = "Travel" })
			local waypoint = Travel:AddCard({
				Id = "waypoints",
				Title = "Waypoints",
				Description = "Save a spot and come back to it later.",
				Icon = "location-pin",
				Collapsible = true,
			})
			local saved
			waypoint:AddInput({
				Id = "waypoint-name",
				Title = "Name",
				Placeholder = "Spawn",
				Validate = function(text)
					return #text <= 20 or "Keep names under 20 characters"
				end,
			})
			waypoint:AddButton({
				Title = "Save current position",
				Callback = function()
					local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if root then
						saved = root.CFrame
						Window:Notify({ Title = "Waypoint saved", Content = Window:GetFlag("waypoint-name") ~= "" and Window:GetFlag("waypoint-name") or "Unnamed", Kind = "success", Duration = 2 })
					end
				end,
			})
			waypoint:AddButton({
				Title = "Go to waypoint",
				Variant = "Primary",
				Callback = function()
					local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if root and saved then
						root.CFrame = saved
					else
						Window:Notify({ Title = "No waypoint yet", Content = "Save a position first.", Kind = "warning", Duration = 2 })
					end
				end,
			})
			waypoint:AddKeybind({
				Id = "waypoint-key",
				Title = "Teleport key",
				Default = Enum.KeyCode.T,
				OnPress = function()
					local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if root and saved then
						root.CFrame = saved
					end
				end,
			})

			for i, info in {
				{ "Infinite Jump", "Jump again while in the air.", "arrow-large-up" },
				{ "No Clip", "Walk through walls.", "frame-collapsed" },
				{ "Swim Anywhere", "Swim through the air.", "person-swimming" },
				{ "Safe Fall", "Take no fall damage.", "person-falling" },
			} do
				table.insert(tracked, Travel:AddCard({ Id = `travel-{i}`, Title = info[1], Description = info[2], Icon = info[3], Toggle = true }))
			end
		end,
	})

	-- Visuals (lazy, 20+ cards)

	Window:AddPage({
		Id = "visuals",
		Title = "Visuals",
		Icon = "eye",
		Badge = "24",
		Build = function(page)
			local Highlight = page:AddSection({ Title = "Highlights" })
			local hl = Highlight:AddCard({
				Id = "highlights",
				Title = "Player highlights",
				Description = "Outline other players through walls.",
				Icon = "eye",
				Toggle = true,
				Collapsible = true,
			})
			hl:AddColorPicker({ Id = "hl-fill", Title = "Fill colour", Default = Color3.fromRGB(110, 168, 255), Transparency = 0.5 })
			hl:AddColorPicker({ Id = "hl-outline", Title = "Outline colour", Default = Color3.fromRGB(255, 255, 255) })
			hl:AddDropdown({ Id = "hl-teams", Title = "Show", Options = { "Enemies", "Teammates", "Everyone" }, Default = "Enemies" })
			table.insert(tracked, hl)

			local World = page:AddSection({ Title = "World", Description = "Every option below is a separate card to show density and scrolling." })
			local worldOptions = {
				"Full bright", "Remove fog", "Remove shadows", "Day time lock", "Clear weather",
				"Show hitboxes", "Item labels", "Chest markers", "Rare spawn alerts", "Distance labels",
				"Health bars", "Name tags", "Tracer lines", "Crosshair", "FPS counter",
				"Ping display", "Low graphics", "Disable particles", "Hide UI in screenshots", "Motion blur off",
			}
			for i, name in worldOptions do
				local card = World:AddCard({
					Id = `world-{i}`,
					Title = name,
					Description = `Turn {string.lower(name)} on or off.`,
					Toggle = true,
					Collapsible = i % 4 == 0,
				})
				if i % 4 == 0 then
					card:AddSlider({ Id = `world-{i}-amount`, Title = "Amount", Min = 0, Max = 1, Step = 0.05, Default = 0.5 })
				end
				table.insert(tracked, card)
			end

			local Camera = page:AddSection({ Title = "Camera" })
			local fov = Camera:AddCard({ Id = "camera-fov", Title = "Field of view", Icon = "video-camera", Collapsible = true })
			fov:AddSlider({
				Id = "camera-fov-value",
				Title = "Degrees",
				Min = 50,
				Max = 120,
				Default = 70,
				Callback = function(value)
					workspace.CurrentCamera.FieldOfView = value
				end,
			})
		end,
	})

	-- Miscellaneous

	local Misc = Window:AddPage({ Id = "misc", Title = "Miscellaneous", Icon = "three-dots-horizontal", Group = 2 })

	local Toasts = Misc:AddSection({ Title = "Notifications" })
	local toastCard = Toasts:AddCard({
		Id = "toasts",
		Title = "Notification preview",
		Description = "Send a sample of each notification style.",
		Icon = "bell",
		Collapsible = true,
		DefaultExpanded = true,
	})
	for _, kind in { "info", "success", "warning", "error" } do
		toastCard:AddButton({
			Title = `Send {kind}`,
			Callback = function()
				Window:Notify({
					Title = `{string.upper(string.sub(kind, 1, 1))}{string.sub(kind, 2)} notification`,
					Content = "This is how this style looks.",
					Kind = kind,
				})
			end,
		})
	end
	toastCard:AddButton({
		Title = "Send with actions",
		Variant = "Primary",
		Callback = function()
			Window:Notify({
				Title = "Update ready",
				Content = "Restart to apply the new settings.",
				Duration = 0,
				Actions = {
					{ Text = "Restart", Callback = function()
						Window:Notify({ Title = "Restarted", Kind = "success", Duration = 2 })
					end },
					{ Text = "Later" },
				},
			})
		end,
	})

	local Media = Misc:AddSection({ Title = "Media" })
	local mediaCard = Media:AddCard({
		Id = "sprite-demo",
		Title = "Animated image",
		Description = "Sprite sheets play like GIFs. Replace the asset with your own sheet.",
		Icon = "image",
		Collapsible = true,
	})
	mediaCard:AddParagraph({
		Content = "Roblox can't play GIF files. Export your GIF as a grid of frames (a sprite sheet), upload it, then pass FrameSize, Columns and Frames. See README for the steps.",
	})
	local sprite = mediaCard:AddAnimatedImage({
		Image = "rbxasset://textures/StudioSharedUI/arrowSpritesheet.png",
		FrameSize = Vector2.new(12, 12),
		Columns = 4,
		Frames = 4,
		FPS = 4,
		Loop = true,
		Autoplay = true,
		Height = 64,
	})
	mediaCard:AddButton({
		Title = "Pause / play",
		Callback = function()
			if sprite.animation:IsPlaying() then
				sprite:Pause()
			else
				sprite:Play()
			end
		end,
	})

	local Notes = Misc:AddSection({ Title = "Notes" })
	local notes = Notes:AddCard({ Id = "notes", Title = "Session notes", Icon = "pencil", Collapsible = true })
	notes:AddInput({ Id = "notes-text", Title = "Note", Placeholder = "Type and press Enter", Width = 240 })

	-- Settings

	local Settings = Window:AddPage({ Id = "settings", Title = "Settings", Icon = "gear", Group = 2 })

	local Appearance = Settings:AddSection({ Title = "Appearance" })
	local appearance = Appearance:AddCard({
		Id = "appearance",
		Title = "Appearance",
		Description = "Theme, motion and interface size.",
		Icon = "paint-brush",
		Collapsible = true,
		DefaultExpanded = true,
	})
	appearance:AddDropdown({
		Id = "theme",
		Title = "Theme",
		Options = { "Dark", "Light" },
		Default = "Dark",
		Callback = function(name)
			Window:SetTheme(name)
		end,
	})
	appearance:AddToggle({
		Id = "reduced-motion",
		Title = "Reduce motion",
		Description = "Turn off most animations.",
		Callback = function(on)
			Window:SetReducedMotion(on)
		end,
	})
	appearance:AddSlider({
		Id = "ui-scale",
		Title = "Interface size",
		Min = 0.8,
		Max = 1.2,
		Step = 0.05,
		Default = 1,
		Suffix = "×",
		Callback = function(value)
			Window:SetScale(value)
		end,
	})

	local Keys = Settings:AddSection({ Title = "Shortcuts" })
	local shortcuts = Keys:AddCard({
		Id = "shortcuts",
		Title = "Shortcuts",
		Description = "Ctrl+K always opens search.",
		Icon = "keyboard",
		Collapsible = true,
		DefaultExpanded = true,
	})
	shortcuts:AddKeybind({
		Id = "toggle-key",
		Title = "Show or hide window",
		Default = Enum.KeyCode.RightShift,
		Callback = function(key)
			Window:SetToggleKey(key)
		end,
	})

	local Data = Settings:AddSection({ Title = "Data" })
	local config = Data:AddCard({ Id = "config", Title = "Configuration", Icon = "floppy-disk", Collapsible = true })
	local exported
	config:AddButton({
		Title = "Copy current config",
		Callback = function()
			exported = Window:ExportConfig()
			local count = 0
			for _ in exported do
				count += 1
			end
			Window:Notify({ Title = "Config saved", Content = `{count} values stored for this session.`, Kind = "success", Duration = 2 })
		end,
	})
	config:AddButton({
		Title = "Restore saved config",
		Callback = function()
			if exported then
				Window:ImportConfig(exported)
				Window:Notify({ Title = "Config restored", Kind = "success", Duration = 2 })
			else
				Window:Notify({ Title = "Nothing saved yet", Content = "Copy the current config first.", Kind = "warning", Duration = 2 })
			end
		end,
	})

	local About = Settings:AddSection({ Title = "About" })
	local about = About:AddCard({ Title = "MacUI", Description = "Raycast-inspired UI library for Roblox.", Icon = "circle-i" })
	about:AddLabel({ Title = "Version", Value = UI.Version })

	-- ponytail: polls once a second; switch to OnFlagChanged per card if this ever matters.
	task.spawn(function()
		while not Window.destroyed do
			refreshActivity()
			task.wait(1)
		end
	end)

	if not Window:GetFlag("open-on-join.enabled") then
		Window:Hide()
	end

	return Window
end

end)()
return buildDemo()
