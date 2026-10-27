local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Icons = require(Core.Icons)
local Util = require(Core.Util)
local Control = require(script.Parent.Control)

local TextInput = Control.extend("Input")

function TextInput.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, options), TextInput)

	local box = Factory.new("Frame", {
		Name = "Box",
		Size = UDim2.fromOffset(options.Width or 190, 28),
		LayoutOrder = 1,
		Parent = self.widget,
		Theme = { BackgroundColor3 = "SurfaceActive" },
	}, {
		Factory.corner(Theme.get("RadiusControl") - 1),
		Factory.padding(0, 6, 0, 10),
	})
	local stroke = Factory.stroke("Accent", 1)
	stroke.Parent = box

	local field = Factory.text({
		ClassName = "TextBox",
		Size = UDim2.new(1, if options.Clearable == false then 0 else -22, 1, 0),
		Text = "",
		PlaceholderText = options.Placeholder or "",
		ClearTextOnFocus = false,
		TextTruncate = Enum.TextTruncate.None,
		ClipsDescendants = true,
		Parent = box,
		Theme = { PlaceholderColor3 = "TextMuted" },
	})
	self.field = field

	local clear
	if options.Clearable ~= false then
		clear = Factory.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(18, 18),
			Visible = false,
			Parent = box,
		})
		Icons.create({ Icon = "x", Color = "TextMuted" }, 14, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = clear,
		})
		self.cleanup:connect(clear.Activated, function()
			field.Text = ""
			self:_commit("")
		end)
	end

	self.error = Factory.text({
		Typography = "Description",
		Size = UDim2.fromOffset(190, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		Visible = false,
		LayoutOrder = 2,
		Parent = self.widget,
		Theme = { TextColor3 = "Danger" },
	})
	self.widget:FindFirstChildOfClass("UIListLayout").FillDirection = Enum.FillDirection.Vertical
	self.widget:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 4)

	self:bind(options.Default or "", function(value)
		if not field:IsFocused() then
			field.Text = value
		end
		if clear then
			clear.Visible = value ~= ""
		end
	end)

	self.cleanup:connect(field.Focused, function()
		Animations.tween(stroke, { Transparency = 0.4 }, Theme.Motion.Hover)
	end)
	self.cleanup:connect(field:GetPropertyChangedSignal("Text"), function()
		if clear then
			clear.Visible = field.Text ~= ""
		end
		if options.Live then
			self:_commit(field.Text)
		end
	end)
	self.cleanup:connect(field.FocusLost, function(enter)
		Animations.tween(stroke, { Transparency = 1 }, Theme.Motion.Hover)
		if enter or not options.SubmitOnEnter then
			self:_commit(field.Text)
		else
			field.Text = self:GetValue()
		end
		if enter then
			Util.safeCall(options.OnSubmit, self:GetValue())
		end
	end)

	self:register("input text")
	return self
end

function TextInput:_commit(text: string)
	local validate = self.options.Validate
	if validate then
		local ok, result = pcall(validate, text)
		local message = if ok then (if result == true or result == nil then nil else (if type(result) == "string" then result else "Invalid value")) else "Invalid value"
		self.error.Text = message or ""
		self.error.Visible = message ~= nil
		if message then
			return
		end
	end
	self:SetValue(text)
end

function TextInput:normalize(value)
	return tostring(value or "")
end

function TextInput:stateText()
	local value = self:GetValue()
	return if value ~= "" then value else nil
end

function TextInput:Focus()
	self.field:CaptureFocus()
end

return TextInput
