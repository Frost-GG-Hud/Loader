print("loadstring:", type(loadstring))
print("load:", type(load))
print("_G:", type(_G))
print("getfenv:", type(getfenv))
print("setfenv:", type(setfenv))
print("getgenv:", type(getgenv))
print("typeof:", type(typeof))
print("task:", type(task))
print("math.clamp:", type(math.clamp))
print("math.round:", type(math.round))
print("table.clone:", type(table.clone))
print("os.clock:", type(os.clock))
print("coroutine:", type(coroutine.create), type(coroutine.yield))

globalAssignProbe = 41
print("global assign:", globalAssignProbe)

local function setter()
	globalFromFunctionProbe = 42
end
setter()
print("global from function:", globalFromFunctionProbe)

if _G then
	_G.viaG = 43
	print("via _G:", viaG)
end
