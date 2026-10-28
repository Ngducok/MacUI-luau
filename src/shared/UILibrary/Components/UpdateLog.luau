local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Cleanup = require(Core.Cleanup)
local Control = require(script.Parent.Control)
local Icons = require(Core.Icons)

local UpdateLog = Control.extend("UpdateLog")
local STATUS = {
	added = { "Added", "+", "UpdateAdded" },
	fixed = { "Fixed", "~", "UpdateFixed" },
	removed = { "Removed", "−", "UpdateRemoved" },
}

export type Entry = { Id: number, Type: string, Text: string }
export type Options = {
	Id: string?, Title: string?, Version: string?, Date: string?,
	InitialVisibleCount: number?, Expandable: boolean?, LayoutOrder: number?,
}

local function optionalText(value, name)
	assert(value == nil or type(value) == "string", `{name} must be a string`)
end

function UpdateLog.new(ctx, parent, options: Options)
	options = table.clone(options or {})
	optionalText(options.Title, "Title")
	optionalText(options.Version, "Version")
	optionalText(options.Date, "Date")
	optionalText(options.Id, "Id")
	local limit = if options.InitialVisibleCount == nil then 5 else options.InitialVisibleCount
	assert(type(limit) == "number" and limit % 1 == 0 and limit >= 1 and limit < math.huge, "InitialVisibleCount must be a positive integer")
	assert(options.Expandable == nil or type(options.Expandable) == "boolean", "Expandable must be a boolean")
	local self = setmetatable(Control.new(ctx, parent, { LayoutOrder = options.LayoutOrder }, true), UpdateLog)
	self.options, self.limit = options, limit
	self.entries, self.rows, self.sequence = {}, {}, 0
	self.expanded = false
	self.rowCleanup = self.cleanup:add(Cleanup.new())
	self.Instance.Name = options.Id or "UpdateLog"
	self.Instance:SetAttribute("NoWindowDrag", true)
	local gap = Theme.get("SpacingSmall")
	self.widget:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, gap)
	local header = Factory.new("Frame", {
		Name = "Header", Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1,
		LayoutOrder = 1, Parent = self.widget,
	}, { Factory.list(gap, true) })
	self.titleLabel = Factory.text({
		Text = options.Title or "Update Logs", Typography = "Section", Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Parent = header,
	}, { Factory.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Shrink }) })
	self.countLabel = Factory.text({
		Name = "Count", Typography = "Hint", Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.None,
		BackgroundTransparency = 0.4, LayoutOrder = 2, Parent = header,
		Theme = { TextColor3 = "TextSecondary", BackgroundColor3 = "SurfaceActive" },
	}, { Factory.corner(5), Factory.padding(0, 5) })
	Factory.new("Frame", {
		Size = UDim2.fromScale(0, 1), BackgroundTransparency = 1, LayoutOrder = 3, Parent = header,
	}, { Factory.fill() })
	self.metadata = Factory.text({
		Name = "Metadata", Typography = "Hint", Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 4, Parent = header,
		Theme = { TextColor3 = "TextMuted" },
	}, { Factory.new("UISizeConstraint", { MaxSize = Vector2.new(150, math.huge) }) })
	self.expandButton = Factory.button({
		Name = "ExpandUpdates", Size = UDim2.fromOffset(76, 28), LayoutOrder = 5,
		Selectable = true, Parent = header, Theme = { BackgroundColor3 = "SurfaceHover" },
	}, { Factory.corner(Theme.get("RadiusControl") - 1) })
	self.expandLabel = Factory.text({
		Text = "View all", Typography = "Hint", Size = UDim2.new(1, -16, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Center, Parent = self.expandButton,
		Theme = { TextColor3 = "TextSecondary" },
	})
	Icons.create({ Icon = "chevron-small-right", Color = "TextMuted" }, 12, {
		Name = "Chevron", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5),
		Parent = self.expandButton,
	})
	self.cleanup:connect(self.expandButton.Activated, function()
		if not self.disabled then self:SetExpanded(not self.expanded) end
	end)
	self.cleanup:connect(self.expandButton.MouseEnter, function()
		if not self.disabled then self.expandButton.BackgroundTransparency = 0 end
	end)
	self.cleanup:connect(self.expandButton.MouseLeave, function() self.expandButton.BackgroundTransparency = 1 end)
	Factory.new("Frame", {
		Name = "HeaderDivider", Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0.6,
		LayoutOrder = 2, Parent = self.widget, Theme = { BackgroundColor3 = "Border" },
	})
	self.list = Factory.new("Frame", {
		Name = "Entries", Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, LayoutOrder = 3, Parent = self.widget,
	}, { Factory.list(0) })
	self.empty = Factory.text({
		Text = "No updates yet.", Typography = "Description", Size = UDim2.new(1, 0, 0, 34),
		Parent = self.list, Theme = { TextColor3 = "TextMuted" },
	})
	self:_refresh()
	return self
end

function UpdateLog:_refresh()
	local count = #self.entries
	for index, row in self.rows do
		row.Visible = self.expanded or index <= self.limit
	end
	self.empty.Visible = count == 0
	self.expandButton.Visible = self.options.Expandable ~= false and count > self.limit
	self.expandLabel.Text = if self.expanded then "Show less" else "View all"
	self.countLabel.Text = tostring(count)
	self.countLabel.Visible = count > 0
	local metadata = {}
	for _, key in { "Version", "Date" } do
		if self.options[key] and self.options[key] ~= "" then table.insert(metadata, self.options[key]) end
	end
	self.metadata.Text = table.concat(metadata, " · ")
	self.metadata.Visible = #metadata > 0
end

function UpdateLog:_row(parent, entry, cleanup)
	local status = STATUS[entry.Type]
	local row = cleanup:add(Factory.new("Frame", {
		Name = `Entry{entry.Id}`, Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1, LayoutOrder = entry.Id, Parent = parent,
		Theme = { BackgroundColor3 = "SurfaceHover" },
	}, {
		Factory.list(8, true), Factory.padding(6, 0),
	}))
	row:SetAttribute("EntryId", entry.Id)
	row:SetAttribute("Status", status[1])
	local marker = Factory.new("Frame", {
		Name = "Marker", Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 0.9,
		LayoutOrder = 1, Parent = row, Theme = { BackgroundColor3 = status[3] },
	}, { Factory.corner(6) })
	Factory.text({
		Name = "Symbol", Text = status[2], Typography = "Control", Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center, Parent = marker,
		Theme = { TextColor3 = status[3] },
	})
	Factory.text({
		Name = "Description", Text = entry.Text, Typography = "Control",
		Size = UDim2.fromScale(0, 1), TextWrapped = false, RichText = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 2, Parent = row, Theme = { TextColor3 = "UpdateText" },
	}, { Factory.fill() })
	cleanup:connect(row.MouseEnter, function() row.BackgroundTransparency = 0.6 end)
	cleanup:connect(row.MouseLeave, function() row.BackgroundTransparency = 1 end)
	return row
end

function UpdateLog:AddEntry(kind: string, text: string): number
	assert(not self.destroyed, "UpdateLog is destroyed")
	assert(STATUS[kind], "Entry type must be added, fixed or removed")
	assert(type(text) == "string" and string.find(text, "%S"), "Entry text must be a non-empty string")
	self.sequence += 1
	local entry = { Id = self.sequence, Type = kind, Text = text }
	table.insert(self.entries, entry)
	table.insert(self.rows, self:_row(self.list, entry, self.rowCleanup))
	self:_refresh()
	if self.disabled then Control.SetDisabled(self, true) end
	return self.sequence
end

function UpdateLog:GetWriters()
	return function(text) return self:AddEntry("added", text) end,
		function(text) return self:AddEntry("fixed", text) end,
		function(text) return self:AddEntry("removed", text) end
end

function UpdateLog:GetEntries(): { Entry }
	local result = {}
	for _, entry in self.entries do table.insert(result, table.clone(entry)) end
	return result
end

function UpdateLog:Clear()
	assert(not self.destroyed, "UpdateLog is destroyed")
	self:SetExpanded(false)
	self.rowCleanup:clean()
	table.clear(self.entries)
	table.clear(self.rows)
	self:_refresh()
end

function UpdateLog:SetVersion(version: string?)
	assert(not self.destroyed, "UpdateLog is destroyed")
	optionalText(version, "Version")
	self.options.Version = version
	self:_refresh()
end

function UpdateLog:SetExpanded(expanded: boolean)
	assert(not self.destroyed, "UpdateLog is destroyed")
	assert(type(expanded) == "boolean", "Expanded must be a boolean")
	if expanded and self.disabled then return end
	self.expanded = expanded
	self:_refresh()
end

function UpdateLog:IsExpanded(): boolean
	return self.expanded
end

function UpdateLog:SetTitle(title: string)
	assert(type(title) == "string", "Title must be a string")
	Control.SetTitle(self, title)
	self:_refresh()
end

return UpdateLog
