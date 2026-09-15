-- Makes a window movable and resizable.
--
-- Two separate bugs made the old window undraggable and unstable:
--
--  1. The header was a Frame with the default Active = false, so it never sank
--     input and `header.InputBegan` never fired. Only four 8px invisible
--     TextButton strips along the window edges could start a drag.
--  2. Movement did `windowStart.Position + (input.Position - dragStart)`, which
--     is UDim2 + Vector3 arithmetic. Luau has no such operator, so even a drag
--     that started would throw instead of moving the window.
--
-- Both are fixed here: every handle is forced interactive via Builder, and all
-- movement is computed from Vector2 offsets before being handed to UDim2.

local ctx = ...
local Util = ctx.require("core/Util")
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")

local UserInputService = game:GetService("UserInputService")

local KEEP_VISIBLE = 72

local DragController = {}
DragController.__index = DragController

local function offsetsOf(udim2)
	return Vector2.new(udim2.X.Offset, udim2.Y.Offset)
end

local function clampToViewport(position, size, viewport)
	local maxX = math.max(0, viewport.X - KEEP_VISIBLE)
	local minX = math.min(0, KEEP_VISIBLE - size.X)
	local maxY = math.max(0, viewport.Y - Theme.Metrics.HeaderHeight)
	local minY = math.min(0, Theme.Metrics.HeaderHeight - size.Y)

	return Vector2.new(
		math.clamp(position.X, minX, maxX),
		math.clamp(position.Y, minY, maxY)
	)
end

function DragController.new(opts)
	local self = setmetatable({}, DragController)

	self.window = opts.window
	self.canResize = opts.canResize or function()
		return true
	end
	self.onChanged = opts.onChanged
	self.onResizeEnd = opts.onResizeEnd
	self.minSize = opts.minSize or Vector2.new(Theme.Metrics.MinWidth, Theme.Metrics.MinHeight)
	self.maxSize = opts.maxSize or Vector2.new(Theme.Metrics.MaxWidth, Theme.Metrics.MaxHeight)

	self.dragInput = nil
	self.dragOriginMouse = Vector2.zero
	self.dragOriginWindow = Vector2.zero

	self.resizing = false
	self.resizeInput = nil
	self.resizeOriginMouse = Vector2.zero
	self.resizeOriginSize = Vector2.zero

	self.connections = {}

	-- The window may have been positioned with scale components by the caller.
	-- Everything from here on works in pure pixel offsets.
	local current = self.window.Position
	if current.X.Scale ~= 0 or current.Y.Scale ~= 0 then
		local viewport = Util.viewport()
		self.window.Position = UDim2.fromOffset(
			current.X.Scale * viewport.X + current.X.Offset,
			current.Y.Scale * viewport.Y + current.Y.Offset
		)
	end

	self:_bindGlobalInput()
	return self
end

function DragController:_track(connection)
	table.insert(self.connections, connection)
	return connection
end

function DragController:_beginDrag(input)
	self.dragInput = input
	self.dragOriginMouse = Vector2.new(input.Position.X, input.Position.Y)
	self.dragOriginWindow = offsetsOf(self.window.Position)
end

function DragController:_shouldFollow(input)
	if not self.dragInput then
		return false
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		return self.dragInput.UserInputType == Enum.UserInputType.MouseButton1
	end
	if input.UserInputType == Enum.UserInputType.Touch then
		-- Match the exact finger so a second touch cannot hijack the window.
		return input == self.dragInput
	end
	return false
end

function DragController:_moveTo(input)
	local mouse = Vector2.new(input.Position.X, input.Position.Y)
	local target = self.dragOriginWindow + (mouse - self.dragOriginMouse)
	local size = self.window.AbsoluteSize
	target = clampToViewport(target, size, Util.viewport())
	self.window.Position = UDim2.fromOffset(target.X, target.Y)
	self:_reportChange()
end

function DragController:_reportChange()
	if self.onChanged then
		self.onChanged()
	end
end

function DragController:_applyResize(input)
	local mouse = Vector2.new(input.Position.X, input.Position.Y)
	local delta = mouse - self.resizeOriginMouse

	local width = math.clamp(self.resizeOriginSize.X + delta.X, self.minSize.X, self.maxSize.X)
	local height = math.clamp(self.resizeOriginSize.Y + delta.Y, self.minSize.Y, self.maxSize.Y)
	self.window.Size = UDim2.fromOffset(width, height)

	local clamped = clampToViewport(offsetsOf(self.window.Position), Vector2.new(width, height), Util.viewport())
	self.window.Position = UDim2.fromOffset(clamped.X, clamped.Y)
	self:_reportChange()
end

function DragController:_bindGlobalInput()
	self:_track(UserInputService.InputChanged:Connect(function(input)
		if self.resizing then
			if input.UserInputType == Enum.UserInputType.MouseMovement
				or (input.UserInputType == Enum.UserInputType.Touch and input == self.resizeInput)
			then
				self:_applyResize(input)
			end
			return
		end

		if self:_shouldFollow(input) then
			self:_moveTo(input)
		end
	end))

	self:_track(UserInputService.InputEnded:Connect(function(input)
		if self.resizing and Util.isDragInput(input.UserInputType) then
			self.resizing = false
			self.resizeInput = nil
			if self.onResizeEnd then
				self.onResizeEnd(self.window.AbsoluteSize)
			end
		end

		if self.dragInput and Util.isDragInput(input.UserInputType) then
			self.dragInput = nil
		end
	end))
end

-- `handle` is forced interactive, which is what the old Frame header was missing.
function DragController:addHandle(handle)
	Builder.makeInteractive(handle)

	self:_track(handle.InputBegan:Connect(function(input)
		if self.resizing then
			return
		end
		if Util.isDragInput(input.UserInputType) then
			self:_beginDrag(input)
		end
	end))
	return handle
end

function DragController:addResizeHandle(handle)
	if not handle then
		return nil
	end

	self:_track(handle.InputBegan:Connect(function(input)
		if not Util.isDragInput(input.UserInputType) then
			return
		end
		if not self.canResize() then
			return
		end

		self.dragInput = nil
		self.resizing = true
		self.resizeInput = input
		self.resizeOriginMouse = Vector2.new(input.Position.X, input.Position.Y)
		self.resizeOriginSize = self.window.AbsoluteSize
	end))
	return handle
end

function DragController:isResizing()
	return self.resizing
end

function DragController:isDragging()
	return self.dragInput ~= nil
end

function DragController:setBounds(minSize, maxSize)
	if minSize then
		self.minSize = minSize
	end
	if maxSize then
		self.maxSize = maxSize
	end
end

function DragController:snapIntoView()
	local clamped = clampToViewport(offsetsOf(self.window.Position), self.window.AbsoluteSize, Util.viewport())
	self.window.Position = UDim2.fromOffset(clamped.X, clamped.Y)
	self:_reportChange()
end

function DragController:destroy()
	for _, connection in ipairs(self.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	self.connections = {}
	self.dragInput = nil
	self.resizing = false
	self.resizeInput = nil
end

return DragController
