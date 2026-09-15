-- Part 1 of the mock Roblox runtime: signals, datatypes, Enums, class hierarchy.
-- Test-only scaffolding; it is concatenated inside a function by build_smoke.py.

local function newSignal()
	local handlers = {}
	local signal = {}

	function signal:Connect(handler)
		table.insert(handlers, handler)
		local connection = { Connected = true }
		function connection:Disconnect()
			self.Connected = false
			for index, existing in ipairs(handlers) do
				if existing == handler then
					table.remove(handlers, index)
					break
				end
			end
		end
		return connection
	end

	function signal:Fire(...)
		local snapshot = table.clone(handlers)
		for _, handler in ipairs(snapshot) do
			handler(...)
		end
	end

	function signal:Wait()
		return nil
	end

	return signal
end

--------------------------------------------------------------------- datatypes

local Color3 = {}
local Color3Meta = {}
Color3Meta.__index = Color3Meta
Color3Meta.__tostring = function(self)
	return string.format("Color3(%.3f, %.3f, %.3f)", self.R, self.G, self.B)
end
Color3Meta.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end

local function color3(r, g, b)
	return setmetatable({ R = r, G = g, B = b }, Color3Meta)
end

function Color3.new(r, g, b)
	return color3(r or 0, g or 0, b or 0)
end
function Color3.fromRGB(r, g, b)
	return color3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHSV(h, s, v)
	return color3(h or 0, s or 0, v or 0)
end

local Vector3 = {}
local Vector3Meta = {}
Vector3Meta.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif key == "Unit" then
		local magnitude = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		if magnitude == 0 then
			return Vector3.new(0, 0, 0)
		end
		return Vector3.new(self.X / magnitude, self.Y / magnitude, self.Z / magnitude)
	end
	return nil
end
Vector3Meta.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3Meta.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3Meta.__mul = function(a, b)
	if type(a) == "number" then
		return Vector3.new(a * b.X, a * b.Y, a * b.Z)
	end
	if type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3Meta.__tostring = function(self)
	return string.format("(%.1f, %.1f, %.1f)", self.X, self.Y, self.Z)
end

function Vector3.new(x, y, z)
	if type(x) == "table" then
		return setmetatable({ X = x.X or 0, Y = x.Y or 0, Z = x.Z or 0 }, Vector3Meta)
	end
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3Meta)
end
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)

local Vector2 = {}
local Vector2Meta = {}
Vector2Meta.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y)
	end
	return nil
end
Vector2Meta.__add = function(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end
Vector2Meta.__sub = function(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end
function Vector2.new(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, Vector2Meta)
end
Vector2.zero = Vector2.new(0, 0)

local UDim = {}
function UDim.new(scale, offset)
	return { Scale = scale or 0, Offset = offset or 0 }
end

local UDim2 = {}
local function udim2(xScale, xOffset, yScale, yOffset)
	return {
		X = { Scale = xScale, Offset = xOffset },
		Y = { Scale = yScale, Offset = yOffset },
	}
end
function UDim2.new(xScale, xOffset, yScale, yOffset)
	return udim2(xScale or 0, xOffset or 0, yScale or 0, yOffset or 0)
end
function UDim2.fromOffset(x, y)
	return udim2(0, x or 0, 0, y or 0)
end
function UDim2.fromScale(x, y)
	return udim2(x or 0, 0, y or 0, 0)
end

local CFrame = {}
CFrame.__index = CFrame
function CFrame.new(x, y, z)
	if type(x) == "table" then
		return setmetatable({
			p = x,
			Position = x,
			LookVector = Vector3.new(0, 0, -1),
			RightVector = Vector3.new(1, 0, 0),
		}, CFrame)
	end
	local position = Vector3.new(x or 0, y or 0, z or 0)
	return setmetatable({
		p = position,
		Position = position,
		LookVector = Vector3.new(0, 0, -1),
		RightVector = Vector3.new(1, 0, 0),
	}, CFrame)
end
function CFrame.lookAt(from, to)
	local delta = to - from
	local magnitude = delta.Magnitude
	local look = magnitude > 0 and delta.Unit or Vector3.new(0, 0, -1)
	return setmetatable({
		p = from,
		Position = from,
		LookVector = look,
		RightVector = Vector3.new(1, 0, 0),
	}, CFrame)
end
CFrame.__add = function(a, b)
	return setmetatable({
		p = a.p + b,
		Position = a.p + b,
		LookVector = a.LookVector,
		RightVector = a.RightVector,
	}, CFrame)
end
CFrame.__mul = function(a, b)
	if type(b) == "table" and b.p then
		return setmetatable({
			p = a.p + b.p,
			Position = a.p + b.p,
			LookVector = a.LookVector,
			RightVector = a.RightVector,
		}, CFrame)
	end
	return a.p + b
end

local Rect = {}
function Rect.new(minX, minY, maxX, maxY)
	return { Min = Vector2.new(minX, minY), Max = Vector2.new(maxX, maxY) }
end

local ColorSequence = {}
function ColorSequence.new(colors)
	return { Keypoints = colors }
end

local ColorSequenceKeypoint = {}
function ColorSequenceKeypoint.new(time, color)
	return { Time = time, Value = color }
end

local TweenInfo = {}
function TweenInfo.new(time, style, direction, repeatCount, reverses, delayTime)
	return {
		Time = time or 1,
		EasingStyle = style,
		EasingDirection = direction,
		RepeatCount = repeatCount or 0,
		Reverses = reverses or false,
		DelayTime = delayTime or 0,
	}
end

local BrickColor = {}
function BrickColor.new(value)
	return { Name = tostring(value), Color = Color3.fromRGB(200, 60, 60) }
end

------------------------------------------------------------------------ enum

local enumItemCache = {}
local enumTypeCache = {}

local Enum = setmetatable({}, {
	__index = function(_, enumName)
		local existing = enumTypeCache[enumName]
		if existing then
			return existing
		end

		local enumType = setmetatable({}, {
			__index = function(_, itemName)
				local key = enumName .. "." .. itemName
				local item = enumItemCache[key]
				if not item then
					item = setmetatable({
						Name = itemName,
						EnumType = enumName,
						Value = 0,
					}, {
						__tostring = function(self)
							return "Enum." .. self.EnumType .. "." .. self.Name
						end,
					})
					enumItemCache[key] = item
				end
				return item
			end,
		})

		enumTypeCache[enumName] = enumType
		return enumType
	end,
})

-------------------------------------------------------------- class hierarchy

local ClassParents = {
	Instance = nil,
	GuiBase2d = "Instance",
	GuiObject = "GuiBase2d",
	GuiLabel = "GuiObject",
	GuiButton = "GuiObject",
	Frame = "GuiObject",
	ScrollingFrame = "GuiObject",
	TextLabel = "GuiLabel",
	ImageLabel = "GuiLabel",
	TextButton = "GuiButton",
	ImageButton = "GuiButton",
	TextBox = "GuiObject",
	CanvasGroup = "GuiObject",
	ScreenGui = "Instance",
	LayerCollector = "Instance",
	BillboardGui = "LayerCollector",
	BasePart = "Instance",
	Part = "BasePart",
	SpawnLocation = "Part",
	MeshPart = "BasePart",
	Model = "Instance",
	PVInstance = "Instance",
	Humanoid = "Instance",
	Highlight = "Instance",
	Adornment = "Instance",
	HandleAdornment = "Adornment",
	BoxHandleAdornment = "HandleAdornment",
	NumberValue = "Instance",
	IntValue = "Instance",
	StringValue = "Instance",
	BoolValue = "Instance",
	UIBase = "Instance",
	UIComponent = "UIBase",
	UICorner = "UIComponent",
	UIStroke = "UIComponent",
	UIGradient = "UIComponent",
	UIPadding = "UIComponent",
	UILayout = "UIComponent",
	UIListLayout = "UILayout",
	UIGridLayout = "UILayout",
	UIScale = "UIComponent",
	Attachment = "Instance",
	BodyVelocity = "Instance",
	LinearVelocity = "Instance",
	Folder = "Instance",
	Camera = "Instance",
	Player = "Instance",
	Players = "Instance",
	Workspace = "Instance",
	Lighting = "Instance",
	RunService = "Instance",
	TeleportOptions = "Instance",
}

local function classIsA(className, wanted)
	local current = className
	while current do
		if current == wanted then
			return true
		end
		current = ClassParents[current]
	end
	return false
end

local SignalNames = {
	InputBegan = true,
	InputChanged = true,
	InputEnded = true,
	MouseButton1Click = true,
	MouseButton1Down = true,
	MouseButton1Up = true,
	MouseEnter = true,
	MouseLeave = true,
	FocusLost = true,
	Focused = true,
	Activated = true,
	Changed = true,
	CharacterAdded = true,
	CharacterRemoving = true,
	Heartbeat = true,
	Stepped = true,
	RenderStepped = true,
	Completed = true,
	MoveToFinished = true,
	Touched = true,
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
}
