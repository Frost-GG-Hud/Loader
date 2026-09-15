-- A single tab: its rail button, its page, and the vertical layout cursor that
-- the widgets use to stack themselves without manual pixel bookkeeping.

local ctx = ...
local Util = ctx.require("core/Util")
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")
local DecorateTab = ctx.require("ui/widgets/Init")

local BUTTON_HEIGHT = 30
local BUTTON_GAP = 6
local BOTTOM_PADDING = 12

local Tab = {}
Tab.__index = Tab

function Tab.new(config)
	local self = setmetatable({}, Tab)

	self._name = config.name
	self._accent = config.accent
	self._pushNotify = config.notify
	self._contentWidth = config.contentWidth
	self._cleanups = {}
	self._y = 4

	self._btn = Builder.button({
		Name = config.name,
		Size = UDim2.new(1, -4, 0, BUTTON_HEIGHT),
		BackgroundColor3 = Theme.SurfaceAlt,
		Text = "  " .. config.name,
		Font = Theme.FontMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.TextDim,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = config.index,
		Parent = config.buttonParent,
	})
	Builder.corner(self._btn, 7)

	self._page = Builder.new("ScrollingFrame", {
		Name = config.name,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.SurfaceAlt,
		ScrollBarImageTransparency = 0.3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(0, 0, 0, BOTTOM_PADDING),
		Visible = false,
		ClipsDescendants = true,
		-- Above the content panel (ZIndex 1) rather than relying on creation order.
		ZIndex = 2,
		Parent = config.pageParent,
	})

	self._btn.MouseButton1Click:Connect(function()
		config.onSelect(config.name)
	end)

	return DecorateTab(self)
end

function Tab:getName()
	return self._name
end

function Tab:setButtonVisible(visible)
	visible = visible == true
	self._btn.Visible = visible
	if not visible and self._page.Visible then
		self._page.Visible = false
	end
end

function Tab:setActive(active)
	self._page.Visible = active
	self._btn.BackgroundColor3 = active and self._accent or Theme.SurfaceAlt
	self._btn.TextColor3 = active and Theme.White or Theme.TextDim
	self._btn.Font = active and Theme.FontMedium or Theme.FontRegular
end

-- Returns the y offset for the next widget and advances the cursor past it.
-- CanvasSize is derived from the same cursor, so a page always scrolls to
-- exactly its content instead of trusting AutomaticCanvasSize to keep up.
function Tab:nextSlot(height, gap)
	self._y = self._y + (gap or 8)
	local y = self._y
	self._y = self._y + height
	self._page.CanvasSize = UDim2.new(0, 0, 0, self._y + BOTTOM_PADDING)
	return y
end

-- AbsoluteSize is only meaningful after the first render pass, so fall back to
-- the geometry we already know while a tab is being built.
function Tab:contentWidth()
	local measured = self._page.AbsoluteSize.X
	if measured and measured > 0 then
		return measured
	end
	return self._contentWidth()
end

-- Widgets call this with a colon, so it must be a method rather than the raw
-- callback: `tab:_notify(text, kind)` passes the tab as the first argument.
function Tab:_notify(text, kind)
	self._pushNotify(text, kind)
end

function Tab:_trackCleanup(fn)
	table.insert(self._cleanups, fn)
end

function Tab:Clear()
	for _, fn in ipairs(self._cleanups) do
		pcall(fn)
	end
	self._cleanups = {}
	Util.clearChildren(self._page)
	self._y = 4
	self._page.CanvasSize = UDim2.new(0, 0, 0, BOTTOM_PADDING)
	self._page.CanvasPosition = Vector2.zero
end

function Tab:destroy()
	self:Clear()
	if self._btn then
		self._btn:Destroy()
		self._btn = nil
	end
	if self._page then
		self._page:Destroy()
		self._page = nil
	end
end

return Tab
