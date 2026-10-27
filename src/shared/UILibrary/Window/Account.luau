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
