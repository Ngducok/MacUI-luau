local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Util = require(Core.Util)
local PopupManager = require(script.Parent.PopupManager)
local Button = require(script.Parent.Parent.Components.Button)

local Dialog = {}

export type Options = {
	Title: string,
	Content: string?,
	ConfirmText: string?,
	CancelText: string?,
	Destructive: boolean?,
	OnConfirm: (() -> ())?,
	OnCancel: (() -> ())?,
}

function Dialog.confirm(popups, within: GuiObject, options: Options)
	local surface = PopupManager.surface(360, { Name = "Dialog" })
	surface:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 15)
	Factory.list(6).Parent = surface
	Factory.padding(18).Parent = surface

	Factory.text({
		Text = options.Title,
		Typography = "WindowTitle",
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = 1,
		Parent = surface,
	})
	if options.Content then
		Factory.text({
			Text = options.Content,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = surface,
			Theme = { TextColor3 = "TextSecondary" },
		})
	end

	local actions = Factory.new("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = surface,
	}, {
		Factory.padding(12, 0, 0, 0),
		Factory.list(8, true, { HorizontalAlignment = Enum.HorizontalAlignment.Right }),
	})

	local popup
	local decided = false
	local function finish(confirmed: boolean)
		if decided then
			return
		end
		decided = true
		popup.close()
		Util.safeCall(if confirmed then options.OnConfirm else options.OnCancel)
	end

	local cancel = Button.make({ Text = options.CancelText or "Cancel", Variant = "Ghost", LayoutOrder = 1 })
	cancel.Parent = actions
	cancel.Activated:Connect(function()
		finish(false)
	end)

	local confirm = Button.make({
		Text = options.ConfirmText or "Confirm",
		Variant = if options.Destructive then "Destructive" else "Primary",
		LayoutOrder = 2,
	})
	confirm.Parent = actions
	confirm.Activated:Connect(function()
		finish(true)
	end)

	popup = popups:open({
		content = surface,
		within = within,
		placement = "center",
		modal = true,
		onClose = function()
			if not decided then
				decided = true
				Util.safeCall(options.OnCancel)
			end
		end,
	})
	return popup
end

return Dialog
