local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Input = require(Core.Input)
local Util = require(Core.Util)
local Control = require(script.Parent.Control)

local IGNORED = {
	[Enum.KeyCode.Unknown] = true,
	[Enum.KeyCode.Escape] = true,
	[Enum.KeyCode.Backspace] = true,
	[Enum.KeyCode.Delete] = true,
}

local Keybind = Control.extend("Keybind")

function Keybind.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, options), Keybind)
	self.listening = false

	local chip = Factory.button({
		Name = "Key",
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0,
		LayoutOrder = 1,
		Parent = self.widget,
		Theme = { BackgroundColor3 = "SurfaceActive" },
	}, {
		Factory.corner(7),
		Factory.padding(0, 10),
		Factory.new("UISizeConstraint", { MinSize = Vector2.new(54, 26) }),
	})
	self.chip = chip

	self.chipLabel = Factory.text({
		Size = UDim2.fromScale(1, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Parent = chip,
	})

	local default = options.Default
	if typeof(default) ~= "EnumItem" then
		default = Enum.KeyCode.Unknown
	end
	self:bind(default, function()
		self:_render()
	end)

	self.cleanup:connect(chip.Activated, function()
		if not self.disabled then
			self:_listen(not self.listening)
		end
	end)

	self.cleanup:add(Input.listen(function(input, processed)
		if self.listening then
			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				if Input.isPointer(input) and not Input.inside(self.chip, Input.position(input)) then
					self:_listen(false)
				end
				return false
			end
			local key = input.KeyCode
			if key == Enum.KeyCode.Escape then
				self:_listen(false)
			elseif key == Enum.KeyCode.Backspace or key == Enum.KeyCode.Delete then
				self:_listen(false)
				self:SetValue(Enum.KeyCode.Unknown)
			elseif not IGNORED[key] then
				local reserved = ctx.isReserved and ctx.isReserved(key, self)
				if reserved then
					ctx.notify({ Title = "Key unavailable", Content = `{Input.keyName(key)} is used by {reserved}.`, Kind = "warning" })
				else
					self:_listen(false)
					self:SetValue(key)
				end
			end
			return true
		end

		local key = self:GetValue()
		if not processed and key ~= Enum.KeyCode.Unknown and input.KeyCode == key and options.OnPress then
			Util.safeCall(options.OnPress, key)
		end
		return false
	end))

	self:register("keybind key shortcut")
	return self
end

function Keybind:_listen(on: boolean)
	self.listening = on
	self:_render()
end

function Keybind:_render()
	local key = self:GetValue()
	if self.listening then
		self.chipLabel.Text = "Press a key"
		Theme.bind(self.chipLabel, { TextColor3 = "Accent" })
	else
		self.chipLabel.Text = if key == Enum.KeyCode.Unknown then "None" else Input.keyName(key)
		Theme.bind(self.chipLabel, { TextColor3 = if key == Enum.KeyCode.Unknown then "TextMuted" else "TextPrimary" })
	end
end

function Keybind:normalize(value)
	if typeof(value) == "EnumItem" then
		return value
	end
	if type(value) == "string" then
		local ok, item = pcall(function()
			return Enum.KeyCode[value]
		end)
		if ok then
			return item
		end
	end
	return Enum.KeyCode.Unknown
end

function Keybind:stateText()
	local key = self:GetValue()
	return if key == Enum.KeyCode.Unknown then nil else Input.keyName(key)
end

return Keybind
