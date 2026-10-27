local MacUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Ngducok/MacUI-luau/main/dist/MacUI.luau"))()

local Window = MacUI:CreateWindow({
	Size = UDim2.fromOffset(860, 520),
	ToggleKey = Enum.KeyCode.RightShift,
})

local Player = game:GetService("Players").LocalPlayer
local Dashboard = Window:AddPage({ Id = "dashboard", Title = "Dashboard", Icon = "house" })
Dashboard:AddSection({ Title = "Session" }):AddCard({
	Id = "player-profile", Title = Player.DisplayName, Description = `@{Player.Name}`,
	Icon = "person", NavigateTo = "account",
})

local General = Window:AddPage({ Id = "general", Title = "General", Icon = "gear" })
local Appearance = General:AddSection({ Title = "Appearance" })
local Interface = Appearance:AddCard({
	Id = "interface",
	Title = "Interface",
	Description = "Customize MacUI for this session.",
	Icon = "paint-brush",
})
Interface:AddDropdown({
	Title = "Theme", Options = { "Dark", "Light" }, Default = "Dark",
	Callback = function(value) Window:SetTheme(value) end,
})
Interface:AddToggle({
	Title = "Reduce motion", Default = false,
	Callback = function(value) Window:SetReducedMotion(value) end,
})
Interface:AddButton({
	Title = "Show notification",
	Callback = function()
		Window:Notify({ Title = "MacUI", Content = "Ready to use.", Kind = "success" })
	end,
})

-- Right Shift: show/hide. Ctrl+K: command palette. Profile row: Roblox account.
return Window
