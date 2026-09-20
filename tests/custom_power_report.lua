-- Run from src via tools/Test-CustomPowerReport.ps1, or with LuaJIT and runtime/lua on LUA_PATH.
arg = { }
dofile("HeadlessWrapper.lua")
assert(build and main, "Upstream headless startup failed")
local xml = require("xml")
local passed = 0
local function check(name, callback)
	callback()
	passed = passed + 1
	print("PASS: "..name)
end
local function setup()
	newBuild()
	local tree = build.treeTab
	local list = tree.controls.powerReportList
	list.shown = true
	list:SetReport({ stat = "Life", label = "Life" }, {
		{ id = 100, name = "Same name", power = 30, pathPower = 3, pathDist = 10 },
		{ id = 200, name = "Same name", power = 20, pathPower = 10, pathDist = 2 },
		{ id = 300, name = "Next best", power = 10, pathPower = 5, pathDist = 2 },
	})
	return tree, list
end

check("right-click ignores the actual row and immediately reveals the next best", function()
	local tree, list = setup()
	local oldCursor = GetCursorPos
	local x, y = list:GetPos()
	local region = list:GetRowRegion()
	GetCursorPos = function() return x + region.x + 5, y + region.y + 5 end
	list:OnKeyDown("RIGHTBUTTON")
	GetCursorPos = oldCursor
	assert(tree.ignoredPowerNodes[100] == "Same name")
	assert(#list.list == 2 and list.list[1].id == 200)
	assert(tree.modFlag and tree:GetIgnoredPowerNodeCount() == 1)
	assert(#list.originalList == 3, "Full candidate cache must remain intact")
end)

check("same names stay distinct; restore and restore all preserve sort and filters", function()
	local tree, list = setup()
	list:ReSort(5)
	tree:IgnorePowerNode(list.list[1])
	assert(list.list[1].id == 300 and not tree.ignoredPowerNodes[100])
	tree:RestorePowerNode(200)
	assert(list.list[1].id == 200)
	tree:IgnorePowerNode({ id = 100, name = "Same name" })
	tree:IgnorePowerNode({ id = 200, name = "Same name" })
	assert(#list.list == 1)
	tree:RestoreAllPowerNodes()
	assert(#list.list == 3 and list.list[1].id == 200 and tree:GetIgnoredPowerNodeCount() == 0)
	list.allocated = true
	list.originalList[1].allocated = true
	tree:IgnorePowerNode(list.originalList[1])
	assert(#list.list == 0)
	tree:RestorePowerNode(100)
	assert(#list.list == 1 and list.list[1].id == 100)
end)

check("new calculation results still exclude ignored IDs", function()
	local tree, list = setup()
	tree:IgnorePowerNode(list.list[1])
	local report = list.originalList
	list:SetReport({ stat = "Life", label = "Life" }, nil)
	list:SetReport({ stat = "Life", label = "Life" }, report)
	assert(#list.list == 2 and list.list[1].id == 200)
	tree:RestorePowerNode(100)
	assert(#list.list == 3 and list.list[1].id == 100)
end)

check("build XML round-trip keeps IDs, fallback names, and tree variants; other builds are isolated", function()
	local tree = setup()
	tree:IgnorePowerNode({ id = 100, name = 'Name & "quoted"' })
	tree:IgnorePowerNode({ id = 200, name = "Same name" })
	tree:CopyTree(1, "Second tree")
	tree:SetActiveSpec(2)
	assert(tree:GetIgnoredPowerNodeCount() == 2)
	local text = build:SaveDB("custom feature test")
	assert(type(text) == "string" and text:find("IgnoredPowerNodes"))
	newBuild()
	assert(build.treeTab:GetIgnoredPowerNodeCount() == 0)
	loadBuildFromXML(text, "Round trip")
	assert(build.treeTab.ignoredPowerNodes[100] == 'Name & "quoted"')
	assert(build.treeTab:GetIgnoredPowerNodeCount() == 2 and #build.treeTab.specList == 2)
	assert(build.treeTab.controls.powerReportList.ignoredNodes == build.treeTab.ignoredPowerNodes)
	build.treeTab:RestoreAllPowerNodes()
	local restored = build:SaveDB("restored")
	assert(not restored:find("IgnoredPowerNodes"))
	loadBuildFromXML(restored, "Restored")
	assert(build.treeTab:GetIgnoredPowerNodeCount() == 0)
end)

check("popup restores entries and safely handles IDs absent from the active tree", function()
	local tree = setup()
	tree:IgnorePowerNode({ id = 4294967295, name = "Unavailable passive" })
	tree:OpenIgnoredPowerNodes()
	local popup = main.popups[1]
	assert(popup, "Ignored popup did not open")
	popup:Draw({ x = 0, y = 0, width = 1920, height = 1080 })
	local px, py = popup:GetPos()
	for _, name in ipairs({ "list", "focus", "restore", "restoreAll", "close" }) do
		local control = popup.controls[name]
		local x, y = control:GetPos()
		local width, height = control:GetSize()
		assert(x >= px and x + width <= px + 600 and y >= py and y + height <= py + 340, "Popup control outside bounds: "..name)
	end
	assert(not tree:FocusIgnoredPowerNode(4294967295))
	assert(tree:GetIgnoredPowerNodeList()[1].name == "Unavailable passive")
	popup.controls.restore:Click()
	assert(tree:GetIgnoredPowerNodeCount() == 0 and #popup.controls.list.list == 0)
	assert(not popup.controls.restore:IsEnabled() and not popup.controls.restoreAll:IsEnabled())
	main:ClosePopup()
	local id, node
	for candidateId, candidate in pairs(build.spec.nodes) do
		if candidate.x then id, node = candidateId, candidate; break end
	end
	assert(tree:FocusIgnoredPowerNode(id))
	assert(tree.jumpToNode and tree.jumpToX == node.x and tree.viewer.powerReportHighlight == id)
	tree:RestoreAllPowerNodes()
end)

check("right-click on header, empty space and hidden list cannot ignore a node", function()
	local tree, list = setup()
	local oldCursor = GetCursorPos
	local x, y = list:GetPos()
	GetCursorPos = function() return x + 10, y + 3 end
	list:OnKeyDown("RIGHTBUTTON")
	GetCursorPos = function() return x + 10, y + 140 end
	list:OnKeyDown("RIGHTBUTTON")
	list.shown = false
	GetCursorPos = function() return x + 10, y + 25 end
	list:OnKeyDown("RIGHTBUTTON")
	GetCursorPos = oldCursor
	assert(tree:GetIgnoredPowerNodeCount() == 0)
end)

check("scrolled rows and left-click focus use the correct node", function()
	local tree, list = setup()
	local oldCursor = GetCursorPos
	local x, y = list:GetPos()
	local region = list:GetRowRegion()
	GetCursorPos = function() return x + region.x + 5, y + region.y + 5 end
	local selected
	list.nodeSelectCallback = function(node) selected = node.id end
	list:OnKeyDown("LEFTBUTTON")
	assert(selected == 100 and tree:GetIgnoredPowerNodeCount() == 0)
	list.controls.scrollBarV.offset = list.rowHeight
	list:OnKeyDown("RIGHTBUTTON")
	GetCursorPos = oldCursor
	assert(tree.ignoredPowerNodes[200] and not tree.ignoredPowerNodes[100])
end)

check("malformed IDs are rejected and absent nodes remain restorable after loading", function()
	local tree = setup()
	local document = { elem = "Tree", attrib = { }, { elem = "IgnoredPowerNodes",
		{ elem = "Node", attrib = { id = "invalid" } },
		{ elem = "Node", attrib = { id = "-1" } },
		{ elem = "Node", attrib = { id = "1.5" } },
		{ elem = "Node", attrib = { id = "4294967296" } },
		{ elem = "Node", attrib = { id = "4294967295", name = "Old tree node" } },
	} }
	tree:Load(assert(xml.ParseXML(assert(xml.ComposeXML(document))))[1], "test")
	assert(tree:GetIgnoredPowerNodeCount() == 1)
	assert(tree:GetIgnoredPowerNodeList()[1].name == "Old tree node")
	tree:RestorePowerNode(4294967295)
	assert(tree:GetIgnoredPowerNodeCount() == 0)
end)

check("custom portable update checks cannot overwrite the feature", function()
	local oldCustom, oldOpenURL = launch.customBuild, OpenURL
	local opened
	OpenURL = function(url) opened = url end
	launch.customBuild = true
	launch:CheckForUpdate(true)
	assert(not opened and not launch.updateCheckRunning)
	launch:CheckForUpdate(false)
	assert(opened == "https://github.com/buivydas1-stack/PathOfBuilding-PoE2/releases")
	launch.customBuild, OpenURL = oldCustom, oldOpenURL
end)

check("Lavianga exposes flask configuration before allocating flask passives", function()
	newBuild()
	local config = build.configTab
	local control = config.varControls.conditionUsingFlask
	local input = config.configSets[config.activeConfigSetId].input
	assert(not control:IsShown(), "Unused flask condition should normally be hidden")
	local item = new("Item", "Rarity: UNIQUE\nLavianga's Spirits\nGargantuan Mana Flask\nThis Flask cannot be Used but applies its Effect constantly\n75% reduced Amount Recovered")
	build.itemsTab:AddItem(item, true)
	assert(not control:IsShown(), "An unequipped item must not expose the option")
	local slot = build.itemsTab.slots["Flask 2"]
	slot.selItemId = item.id
	assert(control:IsShown(), "Equipped Lavianga must expose the unchecked option")
	assert(not input.conditionUsingFlask, "Visibility must not change the user's setting")
	input.conditionUsingFlask = true
	assert(not control.label():find(colorCodes.NEGATIVE, 1, true), "Equipped Lavianga must not show an invalid warning")
	slot.selItemId = 0
	assert(control.label():find(colorCodes.NEGATIVE, 1, true), "Removing Lavianga should restore normal validation")
	input.conditionUsingFlask = false
	assert(not control:IsShown())
	build.calcsTab.mainEnv.conditionsUsed.UsingFlask = { }
	assert(control:IsShown(), "Existing flask-dependent modifiers still expose the option")
end)

print(string.format("%d custom functional scenarios passed", passed))

dofile("../tests/custom_power_calcs.lua")
dofile("../tests/custom_single_notables.lua")
dofile("../tests/custom_path_report.lua")
dofile("../tests/custom_hit_details.lua")
dofile("../tests/custom_shock_tooltip.lua")
