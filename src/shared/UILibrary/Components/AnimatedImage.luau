local RunService = game:GetService("RunService")

local Factory = require(script.Parent.Parent.Core.Factory)
local Animations = require(script.Parent.Parent.Core.Animations)

local AnimatedImage = {}
AnimatedImage.__index = AnimatedImage

local active = {}
local heartbeat
local clock = 0

local function onScreen(inst: GuiObject): boolean
	local node: Instance? = inst
	while node and not node:IsA("LayerCollector") do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return node ~= nil and (node :: any).Enabled ~= false
end

local function step(dt: number)
	clock += dt
	for anim in active do
		if clock < anim.nextCheck then
			continue
		end
		anim.nextCheck = clock + 1 / anim.fps
		if anim.paused or Animations.reducedMotion or not onScreen(anim.Instance) then
			continue
		end
		anim:_advance()
	end
end

local function track(anim)
	active[anim] = true
	if not heartbeat then
		heartbeat = RunService.Heartbeat:Connect(step)
	end
end

local function untrack(anim)
	active[anim] = nil
	if heartbeat and next(active) == nil then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

export type Options = {
	Image: string,
	FrameSize: Vector2,
	Columns: number,
	Frames: number,
	FPS: number?,
	Loop: boolean?,
	Autoplay: boolean?,
	Speed: number?,
	Size: UDim2?,
}

function AnimatedImage.new(options: Options)
	assert(options.Image, "AnimatedImage needs Image")
	assert(options.FrameSize and options.Columns and options.Frames, "AnimatedImage needs FrameSize, Columns and Frames")

	local self = setmetatable({
		frame = 0,
		frames = options.Frames,
		columns = options.Columns,
		frameSize = options.FrameSize,
		baseFps = options.FPS or 12,
		speed = options.Speed or 1,
		loop = options.Loop ~= false,
		paused = options.Autoplay == false,
		nextCheck = 0,
	}, AnimatedImage)
	self.fps = math.max(1, self.baseFps * self.speed)

	self.Instance = Factory.new("ImageLabel", {
		Size = options.Size or UDim2.fromOffset(options.FrameSize.X, options.FrameSize.Y),
		BackgroundTransparency = 1,
		Image = options.Image,
		ImageRectSize = options.FrameSize,
		ScaleType = Enum.ScaleType.Fit,
	})
	self:_render()
	track(self)
	return self
end

function AnimatedImage:_render()
	local col = self.frame % self.columns
	local row = self.frame // self.columns
	self.Instance.ImageRectOffset = Vector2.new(col * self.frameSize.X, row * self.frameSize.Y)
end

function AnimatedImage:_advance()
	local nextFrame = self.frame + 1
	if nextFrame >= self.frames then
		if not self.loop then
			self.paused = true
			return
		end
		nextFrame = 0
	end
	self.frame = nextFrame
	self:_render()
end

function AnimatedImage:Play()
	if not self.loop and self.frame >= self.frames - 1 then
		self.frame = 0
		self:_render()
	end
	self.paused = false
end

function AnimatedImage:Pause()
	self.paused = true
end

function AnimatedImage:SetFrame(index: number)
	self.frame = math.clamp(index, 0, self.frames - 1)
	self:_render()
end

function AnimatedImage:SetSpeed(speed: number)
	self.speed = speed
	self.fps = math.max(1, self.baseFps * speed)
end

function AnimatedImage:IsPlaying(): boolean
	return not self.paused
end

function AnimatedImage:Destroy()
	untrack(self)
	self.Instance:Destroy()
end

function AnimatedImage.activeCount(): number
	local count = 0
	for _ in active do
		count += 1
	end
	return count
end

return AnimatedImage
