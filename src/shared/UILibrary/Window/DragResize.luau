local Core = script.Parent.Parent.Core
local Factory = require(Core.Factory)
local Input = require(Core.Input)
local Icons = require(Core.Icons)
local UserInputService = game:GetService("UserInputService")

local DragResize = {}

-- Query the rendered stack in screen pixels, in the same space as InputObject.Position.
function DragResize.target(window, point: Vector2): GuiObject?
	local container = window.gui:FindFirstAncestorWhichIsA("BasePlayerGui")
	if not container then return nil end
	for _, hit in container:GetGuiObjectsAtPosition(math.round(point.X), math.round(point.Y)) do
		if hit == window.frame or hit:IsDescendantOf(window.frame) then return hit end
		-- Ignore inert, transparent layout wrappers, but never drag through another visible surface.
		if hit.Active or hit.BackgroundTransparency < 1 or hit:IsA("GuiButton") or hit:IsA("TextBox")
			or hit:IsA("TextLabel") or hit:IsA("ImageLabel") or hit:GetAttribute("NoWindowDrag") or hit:GetAttribute("DragBlock") then
			return nil
		end
	end
	return nil
end

function DragResize.canDrag(window, target: GuiObject?, point: Vector2, touch: boolean): boolean
	if not target or (target ~= window.frame and not target:IsDescendantOf(window.frame)) then return false end
	local node = target
	while node do
		if node:GetAttribute("NoWindowDrag") or node:GetAttribute("DragBlock") or node:IsA("TextBox")
			or (node:IsA("GuiButton") and (touch or node:GetAttribute("NoWindowDrag") ~= false)) then
			return false
		end
		if node:IsA("ScrollingFrame") and node.ScrollingEnabled then
			-- Touch pans content; mouse may drag blank content, except the scrollbar gutter.
			if touch then return false end
			local pos, size = node.AbsolutePosition, node.AbsoluteSize
			local thickness = node.ScrollBarThickness * window.scale
			local vertical = node.AbsoluteCanvasSize.Y > node.AbsoluteWindowSize.Y
			local horizontal = node.AbsoluteCanvasSize.X > node.AbsoluteWindowSize.X
			local left = node.VerticalScrollBarPosition == Enum.VerticalScrollBarPosition.Left
			if (vertical and (if left then point.X < pos.X + thickness else point.X >= pos.X + size.X - thickness))
				or (horizontal and point.Y >= pos.Y + size.Y - thickness) then return false end
		end
		if node == window.frame then return true end
		node = node.Parent
	end
	return false
end

-- One controller per window; permanent listeners are never re-created by a gesture or page change.
function DragResize.drag(window)
	local controller = {}
	function controller.stop()
		controller.candidate = nil
		if window.stopDrag == controller.stop then window.stopDrag = nil end
	end
	function controller:begin(input)
		if window.destroyed or not window.options.Draggable or not window.visible or window.maximized or window.stopDrag or not Input.isPointer(input) then return false end
		local point = Input.position(input)
		local touch = input.UserInputType == Enum.UserInputType.Touch
		if touch and window.options.MobileTouchDrag == false then return false end
		local target = DragResize.target(window, point)
		if not DragResize.canDrag(window, target, point, touch) then return false end
		-- Root UIScale changes size; only scaled ancestors change Position units.
		local root, parentScale = window.root, Vector2.new(1, 1)
		local logical = Vector2.new(root.Size.X.Offset, root.Size.Y.Offset) * window.uiScale.Scale
		if logical.X > 0 and logical.Y > 0 and root.AbsoluteSize.X > 0 and root.AbsoluteSize.Y > 0 then
			parentScale = root.AbsoluteSize / logical
		end
		self.candidate = { input = input, point = point, position = window.position, parentScale = parentScale,
			threshold = if touch then 8 else 4, dragging = false }
		window.stopDrag = controller.stop
		return false
	end
	function controller:move(input)
		local drag = self.candidate
		if not drag or (if drag.input.UserInputType == Enum.UserInputType.Touch then input ~= drag.input
			else input.UserInputType ~= Enum.UserInputType.MouseMovement) then return end
		if input.UserInputState == Enum.UserInputState.Cancel then controller.stop() return end
		local point = Input.position(input)
		if not drag.dragging and (point - drag.point).Magnitude < drag.threshold then return end
		drag.dragging = true
		window.position = drag.position + (point - drag.point) / drag.parentScale
		window:_apply(false)
	end
	function controller:finish(input)
		local drag = self.candidate
		if not drag or (input ~= drag.input and not (drag.input.UserInputType == Enum.UserInputType.MouseButton1
			and input.UserInputType == Enum.UserInputType.MouseButton1)) then return end
		controller.stop()
	end
	window.cleanup:add(Input.listen(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then return controller:begin(input) end
		return false
	end))
	window.cleanup:connect(UserInputService.TouchStarted, function(input) controller:begin(input) end)
	window.cleanup:connect(UserInputService.InputChanged, function(input) controller:move(input) end)
	window.cleanup:connect(UserInputService.InputEnded, function(input) controller:finish(input) end)
	window.cleanup:connect(UserInputService.WindowFocusReleased, controller.stop)
	window.cleanup:add(controller.stop)
	return controller
end

function DragResize.resize(window, frame: GuiObject)
	local grip = Factory.button({
		Name = "ResizeGrip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -1, 1, -1),
		Size = UDim2.fromOffset(24, 24),
		ZIndex = 20,
		Parent = frame,
	})
	grip:SetAttribute("NoWindowDrag", true)
	Icons.create({ Icon = "square-corner-line-small", Color = "TextMuted" }, 14, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = 90,
		TextTransparency = 0.4,
		Parent = grip,
	})

	window.cleanup:connect(grip.InputBegan, function(input)
		if window.destroyed or not window.visible or not window.options.Resizable or window.maximized or window.minimized
			or not grip.Visible or not Input.isPointer(input) then
			return
		end
		if window.stopDrag then
			local candidate = window.dragController and window.dragController.candidate
			if not candidate or candidate.input ~= input then return end
			window.stopDrag() -- The grip owns this input, even if the window listener ran first.
		end
		local startPoint = Input.position(input)
		local root = window.root
		local startSize = Vector2.new(root.Size.X.Offset, root.Size.Y.Offset)
		local actual = root.AbsoluteSize
		if startSize.X <= 0 or startSize.Y <= 0 or actual.X <= 0 or actual.Y <= 0 then return end
		local scale = actual / startSize -- Includes root UIScale and any scaled ancestors, exactly once.
		local startPos, anchor = window.position, root.AnchorPoint
		local ownScale = window.uiScale.Scale
		window.stopDrag = Input.drag(input, function(point)
			local size = startSize + (point - startPoint) / scale
			window.size = Vector2.new(math.round(math.max(window.minSize.X, size.X)), math.round(math.max(window.minSize.Y, size.Y)))
			window.position = startPos + (window.size - startSize) * anchor * ownScale
			window:_apply(false)
		end, function()
			window.stopDrag = nil
		end)
	end)
	window.cleanup:add(function()
		if window.stopDrag then window.stopDrag() end
	end)
	return grip
end

return DragResize
