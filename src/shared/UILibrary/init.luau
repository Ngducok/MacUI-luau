local Theme = require(script.Core.Theme)
local Animations = require(script.Core.Animations)
local Icons = require(script.Core.Icons)
local Window = require(script.Window.Window)
local AnimatedImage = require(script.Components.AnimatedImage)

local MacUI = {
	Name = "MacUI",
	Version = "1.0.0",
	Theme = Theme,
	Icons = Icons,
	AnimatedImage = AnimatedImage,
}

function MacUI:CreateWindow(options: Window.Options?)
	return Window.new(options or {})
end

function MacUI:SetTheme(name: string)
	Theme.set(name)
end

function MacUI:RegisterTheme(name: string, tokens: { [string]: any })
	Theme.register(name, tokens)
end

function MacUI:SetReducedMotion(reduced: boolean)
	Animations.reducedMotion = reduced
end

return MacUI
