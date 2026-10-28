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

function Section:AddToggleDropdownGroup(options): any
	local group = Card.newDropdownGroup(self, options)
	table.insert(self.cards, group)
	self:_refresh()
	return group
end

function Section:AddPrioritySelector(options): any
	options = table.clone(options or {})
	local host = self:AddCard({ Title = options.Title or "Priority", Searchable = false })
	host.header.Visible = false
	host.content:FindFirstChildOfClass("UIPadding").PaddingTop = UDim.new(0, Theme.get("SpacingMedium"))
	local ok, element = pcall(host.AddPrioritySelector, host, options)
	if not ok then host:Destroy(); error(element, 2) end
	local setVisible, onDestroy = element.SetVisible, element.onDestroy
	element.SetVisible = function(control, visible)
		setVisible(control, visible)
		host:SetVisible(visible)
	end
	element.onDestroy = function(control)
		onDestroy(control)
		host:Destroy()
	end
	return element
end

function Section:AddUpdateLog(options): any
	options = table.clone(options or {})
	local host = self:AddCard({ Title = options.Title or "Update Logs", Searchable = false })
	host.header.Visible = false
	host.content:FindFirstChildOfClass("UIPadding").PaddingTop = UDim.new(0, Theme.get("SpacingMedium"))
	local ok, element = pcall(host.AddUpdateLog, host, options)
	if not ok then host:Destroy(); error(element, 2) end
	local setVisible, onDestroy = element.SetVisible, element.onDestroy
	element.SetVisible = function(control, visible)
		setVisible(control, visible)
		host:SetVisible(visible)
	end
	element.onDestroy = function(control)
		onDestroy(control)
		host:Destroy()
	end
	return element
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
