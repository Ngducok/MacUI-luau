local Core = script.Parent.Parent.Core
local Factory = require(Core.Factory)
local Input = require(Core.Input)
local Icons = require(Core.Icons)

local DragResize = {}

-- position is in screen pixels, size in unscaled units; window:_apply() clamps both.
function DragResize.drag(window, handles: { GuiObject })
	for _, handle in handles do
		window.cleanup:connect(handle.InputBegan, function(input)
			if not window.options.Draggable or window.maximized or not Input.isPointer(input) then
				return
			end
			local startPoint = Input.position(input)
			local startPos = window.position
			window.stopDrag = Input.drag(input, function(point)
				window.position = startPos + (point - startPoint)
				window:_apply(false)
			end)
		end)
	end
end

function DragResize.resize(window, frame: GuiObject)
	local grip = Factory.button({
		Name = "ResizeGrip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -4),
		Size = UDim2.fromOffset(18, 18),
		ZIndex = 20,
		Parent = frame,
	})
	Icons.create({ Icon = "square-corner-line-small", Color = "TextMuted" }, 14, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = 90,
		TextTransparency = 0.4,
		Parent = grip,
	})

	window.cleanup:connect(grip.InputBegan, function(input)
		if window.maximized or window.minimized or not Input.isPointer(input) then
			return
		end
		local startPoint = Input.position(input)
		local startSize = window.size
		window.stopDrag = Input.drag(input, function(point)
			local scale = window.ctx.scale()
			window.size = startSize + (point - startPoint) / scale
			window:_apply(false)
		end)
	end)
	return grip
end

return DragResize
