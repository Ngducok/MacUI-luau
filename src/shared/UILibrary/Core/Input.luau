local UserInputService = game:GetService("UserInputService")

local Input = {}

local NAMES = {
	LeftShift = "Left Shift",
	RightShift = "Right Shift",
	LeftControl = "Left Ctrl",
	RightControl = "Right Ctrl",
	LeftAlt = "Left Alt",
	RightAlt = "Right Alt",
	Return = "Enter",
	Backspace = "Backspace",
	Space = "Space",
	Escape = "Esc",
	Comma = ",",
	Period = ".",
	Slash = "/",
	Semicolon = ";",
	Quote = "'",
	LeftBracket = "[",
	RightBracket = "]",
	BackSlash = "\\",
	Minus = "-",
	Equals = "=",
	Backquote = "`",
	Up = "↑",
	Down = "↓",
	Left = "←",
	Right = "→",
	MouseButton1 = "Mouse 1",
	MouseButton2 = "Mouse 2",
	MouseButton3 = "Mouse 3",
}

for i = 0, 9 do
	local names = { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" }
	NAMES[names[i + 1]] = tostring(i)
end

function Input.keyName(key: EnumItem?): string
	if not key then
		return "None"
	end
	return NAMES[key.Name] or key.Name
end

function Input.ctrlDown(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.LeftSuper)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightSuper)
end

function Input.isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

function Input.isMove(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

-- InputObject.Position and AbsolutePosition already use screen pixels; do not add the inset twice.
function Input.position(input: InputObject): Vector2
	return Vector2.new(input.Position.X, input.Position.Y)
end

function Input.inside(gui: GuiObject, point: Vector2): boolean
	local pos, size = gui.AbsolutePosition, gui.AbsoluteSize
	return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

-- Calls onMove(position) until the pointer is released. Returns a stop function.
function Input.drag(start: InputObject, onMove: (Vector2) -> (), onEnd: (() -> ())?): () -> ()
	local moved, ended, unfocused
	local function stop()
		if moved then
			moved:Disconnect()
			ended:Disconnect()
			unfocused:Disconnect()
			moved = nil
			if onEnd then
				onEnd()
			end
		end
	end

	moved = UserInputService.InputChanged:Connect(function(input)
		if (start.UserInputType == Enum.UserInputType.Touch and input == start)
			or (start.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then
			if input.UserInputState == Enum.UserInputState.Cancel then stop() return end
			onMove(Input.position(input))
		end
	end)
	ended = UserInputService.InputEnded:Connect(function(input)
		if input == start or (start.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.MouseButton1) then
			stop()
		end
	end)
	unfocused = UserInputService.WindowFocusReleased:Connect(stop)
	onMove(Input.position(start))
	return stop
end

-- One shared InputBegan connection; handlers run newest-first and may return true to consume.
local handlers = {}
local connection

function Input.listen(fn: (InputObject, boolean) -> boolean?): () -> ()
	table.insert(handlers, fn)
	if not connection then
		connection = UserInputService.InputBegan:Connect(function(input, processed)
			for i = #handlers, 1, -1 do
				local handler = handlers[i]
				if handler and handler(input, processed) then
					return
				end
			end
		end)
	end
	return function()
		local index = table.find(handlers, fn)
		if index then
			table.remove(handlers, index)
		end
		if #handlers == 0 and connection then
			connection:Disconnect()
			connection = nil
		end
	end
end

function Input.handlerCount(): number
	return #handlers
end

return Input
