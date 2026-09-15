-- Decorates a tab object with its widget constructors.
--
-- Each widget lives in its own file so layout constants stay local to the
-- component that owns them; this module is only the wiring.

local ctx = ...

local LabelWidget = ctx.require("ui/widgets/Label")
local ButtonWidget = ctx.require("ui/widgets/Button")
local ToggleWidget = ctx.require("ui/widgets/Toggle")
local SliderWidget = ctx.require("ui/widgets/Slider")
local SectionWidget = ctx.require("ui/widgets/Section")
local TextInputWidget = ctx.require("ui/widgets/TextInput")

return function(tab)
	function tab:AddSection(title)
		return SectionWidget(self, title)
	end

	function tab:AddLabel(text, dim)
		return LabelWidget(self, text, dim)
	end

	function tab:AddButton(text, callback, danger)
		return ButtonWidget(self, text, callback, danger)
	end

	function tab:AddToggle(text, default, onChange)
		return ToggleWidget(self, text, default, onChange)
	end

	function tab:AddSlider(text, min, max, default, onChange, step)
		return SliderWidget(self, text, min, max, default, onChange, step)
	end

	function tab:AddInput(labelText, placeholder, default, onCommit)
		return TextInputWidget(self, labelText, placeholder, default, onCommit)
	end

	return tab
end
