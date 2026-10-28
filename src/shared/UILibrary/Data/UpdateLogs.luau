-- Current MacUI changes. Register once per log, when constructing its page.
return function(add, fix, remove)
	add("Reusable PrioritySelector with insert-and-shift ordering")
	add("Compact dropdown groups")
	add("Draggable mobile show/hide button")
	fix("Priority position popovers anchor to the selected chip without page reflow")
	fix("Feature popovers stay open while adjusting controls")
	remove("Legacy room-priority dropdown editor")
end
