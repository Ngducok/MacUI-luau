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
