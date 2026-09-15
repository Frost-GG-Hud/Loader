-- Small framework-agnostic helpers shared by the UI and the feature modules.

local ctx = ...

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Util = {}

function Util.wait(seconds)
	if task and task.wait then
		task.wait(seconds)
	else
		wait(seconds)
	end
end

function Util.spawn(fn)
	if task and task.spawn then
		return task.spawn(fn)
	end
	return coroutine.wrap(fn)()
end

function Util.delay(seconds, fn)
	if task and task.delay then
		return task.delay(seconds, fn)
	end
	return (function()
		Util.wait(seconds)
		fn()
	end)()
end

function Util.viewport()
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1920, 1080)
end

function Util.getCharacter()
	local character = LocalPlayer.Character
	if not character then
		pcall(function()
			LocalPlayer.CharacterAdded:Wait()
		end)
		character = LocalPlayer.Character
	end
	return character
end

function Util.getHumanoid(character)
	character = character or Util.getCharacter()
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

function Util.getRootPart(character)
	character = character or Util.getCharacter()
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

-- Keys are compared case-insensitively and with all whitespace stripped, so a
-- key copied out of Discord with a stray space or newline still unlocks.
function Util.normalizeKey(key)
	local text = string.lower(tostring(key or ""))
	return (string.gsub(text, "%s+", ""))
end

function Util.isDragInput(inputType)
	return inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.Touch
end

function Util.isMoveInput(inputType)
	return inputType == Enum.UserInputType.MouseMovement
		or inputType == Enum.UserInputType.Touch
end

-- Every hide/show, toggle and background loop registers its teardown here so a
-- closed window never leaves a stray connection or loop running.
function Util.newCleanupList()
	local entries = {}
	local list = {}

	function list.track(fn)
		if type(fn) == "function" then
			table.insert(entries, fn)
		end
		return fn
	end

	function list.run()
		local pending = entries
		entries = {}
		for _, fn in ipairs(pending) do
			pcall(fn)
		end
	end

	function list.isEmpty()
		return #entries == 0
	end

	return list
end

function Util.newScreenGui(name, displayOrder)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = name
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = displayOrder or 100

	if gethui then
		pcall(function()
			screenGui.Parent = gethui()
		end)
	end
	if not screenGui.Parent then
		pcall(function()
			screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui", 10)
		end)
	end
	return screenGui
end

function Util.clearChildren(instance)
	for _, child in ipairs(instance:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
			child:Destroy()
		end
	end
end

Util.Services = {
	Players = Players,
	UserInputService = UserInputService,
	RunService = RunService,
	LocalPlayer = LocalPlayer,
}

return Util
