-- The hub window: shadow, frame, header, tab rail, content panel, resize grip.
--
-- Behaviour changes from the original window:
--  * the header is a real drag handle (see DragController) and the four 8px
--    invisible edge strips that used to swallow clicks near the content edges
--    are gone;
--  * the full-screen translucent green wash over the game is removed - only the
--    key prompt dims the screen now, because it is a modal;
--  * resize is blocked while minimised, where it used to corrupt the stored
--    normal size and leave the grip floating over a 52px window;
--  * the drop shadow is a sibling placed behind the window instead of a child
--    drawn on top of the window's own background;
--  * the first tab added is selected automatically.

local ctx = ...
local Util = ctx.require("core/Util")
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")
local DragController = ctx.require("ui/DragController")
local Notify = ctx.require("ui/Notify")
local Header = ctx.require("ui/Header")
local Tab = ctx.require("ui/Tab")

local UserInputService = game:GetService("UserInputService")

local M = Theme.Metrics

local RESIZE_HANDLE_SIZE = 22
local SHADOW_PADDING = 12

local Window = {}
Window.__index = Window

function Window.new(opts)
	opts = opts or {}
	local self = setmetatable({}, Window)

	self.accent = opts.Accent or Theme.Accent
	self.tabs = {}
	self.tabCount = 0
	self.destroyed = false
	self.minimized = false
	self.destroyCallbacks = Util.newCleanupList()
	self.bindings = Util.newCleanupList()

	local width = (opts.Size and opts.Size.X) or 460
	local height = (opts.Size and opts.Size.Y) or 380
	self.normalSize = Vector2.new(width, height)

	self.screenGui = Util.newScreenGui(opts.Name or "FrostGui", opts.DisplayOrder or 100)

	self:_buildShadow()
	self:_buildWindow(width, height)
	self:_buildHeader(opts)
	self:_buildBody()
	self:_buildResizeHandle()

	self.toasts = Notify.new(self.screenGui, { accent = self.accent })

	self:_buildFloatingToggle()

	self.drag = DragController.new({
		window = self.window,
		canResize = function()
			return not self.minimized
		end,
		onChanged = function()
			self:_syncShadow()
		end,
		onResizeEnd = function(size)
			self.normalSize = size
		end,
	})
	self.drag:addHandle(self.header.frame)
	self.drag:addResizeHandle(self.resizeHandle)

	if opts.ToggleKey then
		self:bindToggleKey(opts.ToggleKey)
	end

	self:_watchViewport()
	self:_syncShadow()
	self.drag:snapIntoView()

	return self
end

function Window:_buildShadow()
	self.shadow = Builder.imageLabel({
		Name = "Shadow",
		Image = "rbxassetid://131604521",
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.72,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(10, 10, 118, 118),
		Size = UDim2.fromOffset(100, 100),
		ZIndex = 3,
		Parent = self.screenGui,
	})
end

function Window:_buildWindow(width, height)
	local viewport = Util.viewport()
	self.window = Builder.frame({
		Name = "Window",
		Size = UDim2.fromOffset(width, height),
		Position = UDim2.fromOffset(
			math.max(16, (viewport.X - width) / 2),
			math.max(16, (viewport.Y - height) / 2)
		),
		BackgroundColor3 = Theme.Window,
		ZIndex = 4,
		Parent = self.screenGui,
	})
	Builder.corner(self.window, M.CornerWindow)
	Builder.stroke(self.window, {
		Color = Color3.fromRGB(120, 130, 138),
		Thickness = 1.2,
		Transparency = 0.25,
	})
end

function Window:_buildHeader(opts)
	self.header = Header.new({
		parent = self.window,
		title = opts.Title or "Frost",
		subtitle = opts.Subtitle or "",
		accent = self.accent,
		onClose = function()
			self:destroy()
		end,
		onMinimize = function()
			self:setMinimized(not self.minimized)
		end,
	})
end

function Window:_buildBody()
	local Config = ctx.require("core/Config")
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer

	self.tabList = Builder.new("ScrollingFrame", {
		Name = "Tabs",
		Size = UDim2.new(0, M.TabRailWidth - 4, 1, -(M.ContentTop + 72)),
		Position = UDim2.fromOffset(6, M.ContentTop + 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ZIndex = 5,
		Parent = self.window,
	})

	local tabListLayout = Builder.new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = self.tabList,
	})
	tabListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self.tabList.CanvasSize = UDim2.new(0, 0, 0, tabListLayout.AbsoluteContentSize.Y + 8)
	end)

	-- Bottom User Session Profile Card (OMG HUB style)
	local profileCard = Builder.button({
		Name = "UserProfileCard",
		Size = UDim2.new(0, M.TabRailWidth - 8, 0, 52),
		Position = UDim2.new(0, 6, 1, -58),
		BackgroundColor3 = Theme.Surface,
		ZIndex = 6,
		Parent = self.window,
	})
	Builder.corner(profileCard, 8)
	Builder.stroke(profileCard, {
		Color = Theme.Border,
		Thickness = 1,
		Transparency = 0.45,
	})

	local avatarImg = Builder.imageLabel({
		Name = "Avatar",
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromOffset(8, 9),
		Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=100&h=100",
		ZIndex = 7,
		Parent = profileCard,
	})
	Builder.corner(avatarImg, 6)

	Builder.label({
		Size = UDim2.new(1, -50, 0, 16),
		Position = UDim2.fromOffset(48, 7),
		Font = Theme.FontBold,
		TextSize = 11,
		Text = LocalPlayer.DisplayName,
		TextColor3 = Theme.TextMain,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 7,
		Parent = profileCard,
	})

	Builder.label({
		Size = UDim2.new(1, -50, 0, 12),
		Position = UDim2.fromOffset(48, 22),
		Font = Theme.FontRegular,
		TextSize = 9,
		Text = "Local session",
		TextColor3 = Theme.TextDim,
		ZIndex = 7,
		Parent = profileCard,
	})

	Builder.label({
		Size = UDim2.new(1, -50, 0, 12),
		Position = UDim2.fromOffset(48, 34),
		Font = Theme.FontMedium,
		TextSize = 8,
		Text = "🟢 Connected",
		TextColor3 = Theme.Success,
		ZIndex = 7,
		Parent = profileCard,
	})

	profileCard.MouseButton1Click:Connect(function()
		local setclip = setclipboard or toclipboard or writeclipboard
		if setclip then
			setclip(Config.DiscordInvite)
			self:notify("Discord link copied to clipboard!", "success")
		else
			self:notify("Discord: " .. Config.DiscordInvite, "info")
		end
	end)

	self.profileCard = profileCard

	self.content = Builder.frame({
		Name = "Content",
		Size = UDim2.new(1, -(M.ContentInset + 12), 1, -(M.ContentTop + 12)),
		Position = UDim2.fromOffset(M.ContentInset, M.ContentTop),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = self.window,
	})

	local panel = Builder.frame({
		Name = "Panel",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Theme.Surface,
		ZIndex = 1,
		Parent = self.content,
	})
	Builder.corner(panel, 12)
	Builder.stroke(panel, {
		Color = Theme.Border,
		Thickness = 1,
		Transparency = 0.6,
	})
end

function Window:_buildFloatingToggle()
	local floatBtn = Builder.new("TextButton", {
		Name = "FloatingToggle",
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(0, 16, 0.45, 0),
		BackgroundColor3 = Theme.Window,
		BackgroundTransparency = 0.15,
		Text = "❄️",
		TextSize = 20,
		Font = Theme.FontBold,
		TextColor3 = Theme.White,
		AutoButtonColor = false,
		Active = true,
		Draggable = true,
		ZIndex = 50,
		Parent = self.screenGui,
	})
	Builder.pillCorner(floatBtn)
	Builder.stroke(floatBtn, {
		Color = self.accent,
		Thickness = 2,
		Transparency = 0.25,
	})

	floatBtn.MouseButton1Click:Connect(function()
		self:toggleVisible()
	end)
	self.floatingToggle = floatBtn
end

function Window:_buildResizeHandle()
	self.resizeHandle = Builder.button({
		Name = "ResizeHandle",
		Size = UDim2.fromOffset(RESIZE_HANDLE_SIZE, RESIZE_HANDLE_SIZE),
		Position = UDim2.new(1, -RESIZE_HANDLE_SIZE, 1, -RESIZE_HANDLE_SIZE),
		ZIndex = 9,
		Parent = self.window,
	})

	for index = 1, 3 do
		local inset = 5 + index * 5
		local dot = Builder.frame({
			Size = UDim2.fromOffset(3, 3),
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -inset, 1, -inset),
			BackgroundColor3 = self.accent,
			BackgroundTransparency = 0.35,
			ZIndex = 9,
			Parent = self.resizeHandle,
		})
		Builder.pillCorner(dot)
	end
end

function Window:_syncShadow()
	if not self.shadow or not self.window then
		return
	end
	local position = self.window.Position
	local size = self.window.Size
	self.shadow.Position = UDim2.new(
		position.X.Scale,
		position.X.Offset - SHADOW_PADDING,
		position.Y.Scale,
		position.Y.Offset - SHADOW_PADDING
	)
	self.shadow.Size = UDim2.new(
		size.X.Scale,
		size.X.Offset + SHADOW_PADDING * 2,
		size.Y.Scale,
		size.Y.Offset + SHADOW_PADDING * 2
	)
end

function Window:_watchViewport()
	local function bind(camera)
		if not camera then
			return
		end
		self.bindings:track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self:_syncShadow()
			if self.drag then
				self.drag:snapIntoView()
			end
		end))
	end

	bind(workspace.CurrentCamera)
	self.bindings:track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		bind(workspace.CurrentCamera)
	end))
end

function Window:addTab(name)
	self.tabCount = self.tabCount + 1

	local tab = Tab.new({
		name = name,
		index = self.tabCount,
		buttonParent = self.tabList,
		pageParent = self.content,
		accent = self.accent,
		notify = function(text, kind)
			self:notify(text, kind)
		end,
		contentWidth = function()
			return self:contentWidth()
		end,
		onSelect = function(selected)
			self:select(selected)
		end,
	})

	table.insert(self.tabs, tab)
	self.tabList.CanvasSize = UDim2.new(0, 0, 0, self.tabCount * 36)

	if self.tabCount == 1 then
		self:select(name)
	end
	return tab
end

function Window:getTab(name)
	for _, tab in ipairs(self.tabs) do
		if tab:getName() == name then
			return tab
		end
	end
	return nil
end

function Window:select(name)
	for _, tab in ipairs(self.tabs) do
		tab:setActive(tab:getName() == name)
	end
	self.activeTabName = name
end

function Window:contentWidth()
	local measured = self.content.AbsoluteSize.X
	if measured and measured > 0 then
		return measured
	end

	local windowWidth = self.window.AbsoluteSize.X
	if windowWidth and windowWidth > 0 then
		return math.max(160, windowWidth - (M.ContentInset + 12))
	end

	return math.max(160, self.normalSize.X - (M.ContentInset + 12))
end

function Window:setMinimized(minimized)
	minimized = minimized == true
	if self.minimized == minimized then
		return
	end
	self.minimized = minimized

	self.tabList.Visible = not minimized
	self.content.Visible = not minimized
	if self.profileCard then self.profileCard.Visible = not minimized end
	self.resizeHandle.Visible = not minimized
	self.header.setMinimized(minimized)

	if minimized then
		self.window.Size = UDim2.fromOffset(self.normalSize.X, M.HeaderHeight)
	else
		self.window.Size = UDim2.fromOffset(self.normalSize.X, self.normalSize.Y)
	end

	self:_syncShadow()
	if self.drag then
		self.drag:snapIntoView()
	end
end

function Window:isMinimized()
	return self.minimized
end

function Window:setVisible(visible)
	self.screenGui.Enabled = visible == true
end

function Window:toggleVisible()
	self:setVisible(not self.screenGui.Enabled)
end

function Window:bindToggleKey(keyCode, onToggle)
	self.bindings:track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode ~= keyCode then
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end

		self:toggleVisible()
		if onToggle then
			pcall(onToggle, self.screenGui.Enabled)
		end
	end))
end

function Window:notify(text, kind)
	if self.toasts then
		self.toasts:push(text, kind)
	end
end

function Window:setTitle(text)
	self.header.titleLabel.Text = tostring(text)
end

function Window:setSubtitle(text)
	self.header.subtitleLabel.Text = tostring(text)
end

function Window:onDestroy(fn)
	self.destroyCallbacks:track(fn)
end

function Window:destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true

	self.destroyCallbacks:run()

	for _, tab in ipairs(self.tabs) do
		tab:destroy()
	end
	self.tabs = {}

	if self.drag then
		self.drag:destroy()
		self.drag = nil
	end
	if self.toasts then
		self.toasts:destroy()
		self.toasts = nil
	end

	if self.header and self.header.destroy then
		self.header.destroy()
	end
	if self.floatingToggle then
		self.floatingToggle:Destroy()
		self.floatingToggle = nil
	end

	self.bindings:run()

	if self.screenGui then
		self.screenGui:Destroy()
		self.screenGui = nil
	end
end

return Window
