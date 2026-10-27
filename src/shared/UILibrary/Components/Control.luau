local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Cleanup = require(Core.Cleanup)
local Util = require(Core.Util)

-- Shared base for every control: a row with title/description on the left and a widget on the right.
local Control = {}
Control.__index = Control

export type Context = {
	store: any,
	registry: any,
	popups: any,
	notify: (any) -> (),
	locate: (() -> ())?,
	pageTitle: string?,
	cardTitle: string?,
}

function Control.new(ctx: Context, parent: GuiObject, options: { [string]: any }, stacked: boolean?)
	local self = setmetatable({
		ctx = ctx,
		options = options,
		cleanup = Cleanup.new(),
		disabled = false,
		visible = true,
	}, Control)

	local hasText = options.Title ~= nil or options.Description ~= nil
	self.Instance = self.cleanup:add(Factory.new("Frame", {
		Name = options.Id or options.Title or "Control",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = options.LayoutOrder or 0,
	}, {
		Factory.list(if stacked then 8 else 12, not stacked, {
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalFlex = if stacked then nil else Enum.UIFlexAlignment.None,
		}),
	}))

	if hasText then
		local text = Factory.new("Frame", {
			Name = "Text",
			Size = UDim2.fromScale(if stacked then 1 else 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Parent = self.Instance,
		}, {
			Factory.list(2),
			if stacked then nil else Factory.fill(),
		})

		self.titleLabel = Factory.text({
			Text = options.Title or "",
			Size = UDim2.new(1, 0, 0, 18),
			Visible = options.Title ~= nil,
			LayoutOrder = 1,
			Parent = text,
		})

		self.descriptionLabel = Factory.text({
			Text = options.Description or "",
			Typography = "Description",
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = options.Description ~= nil,
			LayoutOrder = 2,
			Parent = text,
			Theme = { TextColor3 = "TextSecondary" },
		})
	end

	self.widget = Factory.new("Frame", {
		Name = "Widget",
		Size = if stacked then UDim2.fromScale(1, 0) else UDim2.fromScale(0, 0),
		AutomaticSize = if stacked then Enum.AutomaticSize.Y else Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = self.Instance,
	}, {
		Factory.list(8, not stacked, { HorizontalAlignment = Enum.HorizontalAlignment.Right }),
	})

	self.Instance.Parent = parent
	return self
end

-- Binds this control to a store flag. apply(value) renders, called now and on every change.
function Control:bind(default: any, apply: (any) -> ())
	local options, store = self.options, self.ctx.store
	local id, value = store:define(options.Id, default)
	self.id = id
	self.cleanup:add(store:observe(id, function(new)
		apply(new)
		Util.safeCall(options.Callback, new)
	end))
	self.cleanup:add(function()
		store:remove(id)
	end)
	apply(value)
	return id
end

function Control:register(kind: string?)
	local options = self.options
	if not options.Title or options.Searchable == false then
		return
	end
	local ctx = self.ctx
	local key = options._SearchId or `{ctx.searchId}/control:{options.Id or options.LayoutOrder or options.Title}`
	self.registryKey = key
	self.cleanup:add(ctx.registry:add({
		id = key,
		kind = "control",
		title = options.Title,
		subtitle = ctx.searchPath,
		keywords = `{kind or ""} {options.Keywords or ""} {options.Description or ""}`,
		aliases = options.Aliases,
		icon = options.Icon or "three-sliders-horizontal",
		state = function()
			return self:stateText()
		end,
		activate = function()
			if ctx.locate then
				ctx.locate(self.Instance)
			end
		end,
		visible = function()
			return self.visible
		end,
	}))
end

function Control:stateText(): string?
	return nil
end

function Control:GetValue(): any
	return if self.id then self.ctx.store:get(self.id) else nil
end

function Control:SetValue(value: any)
	if self.id then
		self.ctx.store:set(self.id, self:normalize(value))
	end
end

function Control:normalize(value: any): any
	return value
end

function Control:SetDisabled(disabled: boolean)
	self.disabled = disabled
	self.Instance.Interactable = not disabled
	local alpha = if disabled then 0.55 else 0
	for _, inst in self.Instance:GetDescendants() do
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
			Theme.setTextDisabled(inst, disabled)
		elseif inst:IsA("ImageLabel") then
			inst.ImageTransparency = alpha
		end
	end
end

function Control:SetVisible(visible: boolean)
	self.visible = visible
	self.Instance.Visible = visible
end

function Control:SetTitle(title: string)
	self.options.Title = title
	if self.registryKey then
		self.ctx.registry:update(self.registryKey, { title = title })
	end
	if self.titleLabel then
		self.titleLabel.Text = title
		self.titleLabel.Visible = true
	end
end

function Control:SetDescription(description: string?)
	self.options.Description = description
	if self.descriptionLabel then
		self.descriptionLabel.Text = description or ""
		self.descriptionLabel.Visible = description ~= nil
	end
end

function Control:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.cleanup:clean()
	if self.onDestroy then
		self.onDestroy(self)
	end
end

function Control.extend(name: string)
	local class = setmetatable({}, { __index = Control })
	class.__index = class
	class.ClassName = name
	return class
end

return Control
