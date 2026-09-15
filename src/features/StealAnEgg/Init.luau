-- Wires the Steal An Egg modules into the game tab.
--
-- The game tab is rebuilt every time "Load Steal An Egg Features" is pressed, so
-- everything created here registers a teardown with both the tab and the hub.
-- Without that, each reload left another ESP loop and another highlight set
-- running against the previous (now destroyed) tab.

local ctx = ...
local EggData = ctx.require("features/StealAnEgg/EggData")
local Esp = ctx.require("features/StealAnEgg/Esp")
local Movement = ctx.require("features/StealAnEgg/Movement")

local DEFAULT_RANGE = 150
local MIN_RANGE = 10
local MAX_RANGE = 400

return function(hub, tab, cleanup)
	local function notify(text, kind)
		hub:notify(text, kind)
	end

	local esp = Esp.new({ notify = notify, range = DEFAULT_RANGE })
	local movement = Movement.new({ notify = notify })

	-- Runs when the tab is cleared AND when the hub closes, so no highlight,
	-- marker or walking loop can outlive the feature that created it.
	local function teardown()
		esp:destroy()
		movement:stop()
		EggData.invalidate()
	end
	tab:_trackCleanup(teardown)
	cleanup.track(teardown)

	tab:AddLabel("Steal An Egg - eggs, ESP and movement", true)

	tab:AddToggle("Egg ESP", false, function(on)
		esp:setEggs(on)
	end)

	tab:AddSlider("ESP Range (studs)", MIN_RANGE, MAX_RANGE, DEFAULT_RANGE, function(value)
		esp:setRange(value)
	end)

	tab:AddToggle("Player ESP", false, function(on)
		esp:setPlayers(on)
	end)

	tab:AddToggle("Auto Collect (walk to eggs)", false, function(on)
		movement:toggleAutoCollect(on)
	end)

	tab:AddButton("Teleport to Closest Egg", function()
		movement:teleportToClosestEgg()
	end)

	tab:AddButton("Teleport to Closest Player", function()
		movement:teleportToClosestPlayer()
	end)

	tab:AddButton("Mark Nearby Eggs (5s)", function()
		local marked = esp:predict()
		if marked > 0 then
			notify("Marked " .. marked .. " egg(s)", "success")
		else
			notify("No eggs within range", "error")
		end
	end)

	tab:AddButton("Walk to Best Value Egg", function()
		movement:walkToBestEgg()
	end)

	tab:AddButton("Scan Egg Attributes (debug)", function()
		local sample = nil
		for _, instance in ipairs(EggData.scan()) do
			sample = instance
			break
		end

		if not sample then
			notify("No egg objects found in workspace", "error")
			return
		end

		local attributes, children = EggData.describe(sample)
		print("[Frost] Sample egg:", sample:GetFullName())
		print("[Frost] Attributes:", attributes)
		print("[Frost] Children:", children)
		notify("Printed a sample egg to the console (F9) - use it to fix the value/owner attribute names", "info")
	end)

	tab:AddButton("Clear All ESP", function()
		esp:clear()
		notify("Cleared all ESP and markers", "info")
	end, true)

	tab:AddLabel("Tip: 'Scan Egg Attributes' prints the attribute names a live egg uses. If auto-walk cannot read values, copy those names into VALUE_ATTRIBUTES in EggData.luau.", true)
end
