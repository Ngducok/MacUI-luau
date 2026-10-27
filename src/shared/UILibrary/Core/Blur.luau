local Lighting = game:GetService("Lighting")

local Animations = require(script.Parent.Animations)

-- One shared BlurEffect for every window; each owner asks for a size and the largest wins.
local NAME = "UILibraryBlur"

local Blur = {}

local owners = {}
local effect: BlurEffect?
local created = false
local originalSize = 0
local originalEnabled = false

local function target(): number
	local size = if originalEnabled then originalSize else 0
	for _, s in owners do
		size = math.max(size, s)
	end
	return size
end

local function ensure(): BlurEffect
	if effect and effect.Parent then
		return effect
	end
	local found = Lighting:FindFirstChild(NAME)
	if found and found:IsA("BlurEffect") then
		effect = found
		created = false
		originalSize, originalEnabled = found.Size, found.Enabled
	else
		effect = Instance.new("BlurEffect")
		effect.Name = NAME
		effect.Size = 0
		effect.Parent = Lighting
		created = true
		originalSize, originalEnabled = 0, false
	end
	return effect :: BlurEffect
end

function Blur.set(owner: any, size: number, duration: number?)
	assert(type(size) == "number" and size == size and math.abs(size) < math.huge, "BlurSize must be a finite number")
	local current = ensure()
	owners[owner] = math.clamp(size, 0, 56)
	current.Enabled = true
	Animations.tween(current, { Size = target() }, duration, Enum.EasingStyle.Quad)
end

function Blur.release(owner: any, duration: number?)
	if owners[owner] == nil and next(owners) ~= nil then
		return
	end
	owners[owner] = nil
	local current = effect
	if not current or not current.Parent then
		return
	end
	if next(owners) ~= nil then
		Animations.tween(current, { Size = target() }, duration, Enum.EasingStyle.Quad)
		return
	end
	local function done()
		if next(owners) == nil and effect == current then
			effect = nil
			if created then
				current:Destroy()
			else
				current.Size, current.Enabled = originalSize, originalEnabled
			end
		end
	end
	local tween = Animations.tween(current, { Size = if originalEnabled then originalSize else 0 }, duration, Enum.EasingStyle.Quad)
	if tween then
		tween.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then
				done()
			end
		end)
	else
		done()
	end
end

function Blur.instanceCount(): number
	local count = 0
	for _, child in Lighting:GetChildren() do
		if child.Name == NAME then
			count += 1
		end
	end
	return count
end

return Blur
