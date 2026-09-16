-- Thin instance factory. Every widget below is built from these helpers so the
-- widget files stay readable and colours never drift between components.

local ctx = ...
local Theme = ctx.require("core/Theme")

local Builder = {}

-- Later tables win, so call sites read as defaults -> overrides -> forced values.
function Builder.merge(...)
	local merged = {}
	for index = 1, select("#", ...) do
		local source = select(index, ...)
		for key, value in pairs(source or {}) do
			merged[key] = value
		end
	end
	return merged
end

-- `Parent` is always applied last: parenting first would make Roblox replicate
-- a half-configured instance on every property write.
function Builder.new(className, props, children)
	local instance = Instance.new(className)
	local parent = nil

	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end

	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end

	if parent then
		instance.Parent = parent
	end
	return instance
end

function Builder.corner(parent, radius)
	return Builder.new("UICorner", {
		CornerRadius = UDim.new(0, radius),
		Parent = parent,
	})
end

function Builder.pillCorner(parent)
	return Builder.new("UICorner", {
		CornerRadius = UDim.new(1, 0),
		Parent = parent,
	})
end

function Builder.stroke(parent, props)
	return Builder.new("UIStroke", Builder.merge({
		Color = Theme.Border,
		Thickness = 1,
		Transparency = 0.25,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, props, { Parent = parent }))
end

function Builder.gradient(parent, colors, rotation)
	return Builder.new("UIGradient", {
		Color = ColorSequence.new(colors),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

function Builder.padding(parent, props)
	return Builder.new("UIPadding", Builder.merge({
		PaddingLeft = UDim.new(0, 0),
		PaddingRight = UDim.new(0, 0),
		PaddingTop = UDim.new(0, 0),
		PaddingBottom = UDim.new(0, 0),
	}, props, { Parent = parent }))
end

function Builder.listLayout(parent, props)
	return Builder.new("UIListLayout", Builder.merge({
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, props, { Parent = parent }))
end

function Builder.frame(props, children)
	return Builder.new("Frame", Builder.merge({
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, props), children)
end

function Builder.label(props, children)
	return Builder.new("TextLabel", Builder.merge({
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Theme.FontRegular,
		TextColor3 = Theme.TextMain,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = false,
		ZIndex = 6,
	}, props), children)
end

function Builder.button(props, children)
	return Builder.new("TextButton", Builder.merge({
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Font = Theme.FontRegular,
		ZIndex = 6,
	}, props), children)
end

function Builder.imageLabel(props, children)
	return Builder.new("ImageLabel", Builder.merge({
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, props), children)
end

-- THE drag fix.
--
-- Only GuiButtons sink mouse/touch input by default. A Frame (or TextLabel)
-- with the default Active = false never receives InputBegan, so a header built
-- from a Frame silently ignores every drag attempt. Roblox's own touch-drag
-- examples call this out by setting `frame.Active = true` on the drag surface.
-- Every drag handle now goes through here.
function Builder.makeInteractive(guiObject)
	guiObject.Active = true
	return guiObject
end

return Builder
