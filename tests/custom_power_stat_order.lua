-- Run from src with tools/Test-CustomPowerReport.ps1 -TestPath tests/custom_power_stat_order.lua.
arg = { }
dofile("HeadlessWrapper.lua")
assert(build and main, "Upstream headless startup failed")

local function indexOf(list, id)
	for index, stat in ipairs(list) do
		if stat.stat == id then return index end
	end
end

local savedSettings = main.SaveSettings
local saveCount = 0
main.SaveSettings = function() saveCount = saveCount + 1 end
main.powerStatOrder = { }
newBuild()
local tree = build.treeTab
local control = tree.controls.treeHeatMapStatSelect
local selected = control.list[control.selIndex]
assert(control.reorderFunc and not tree.controls.nodePowerMaxDepthSelect.reorderFunc)
assert(control:ReorderRow(indexOf(control.list, "ManaRegenRecovery"), 1))
assert(tree.normalPowerStatList[1].stat == "ManaRegenRecovery")
assert(tree.notablePowerStatList[1].stat == "ManaRegenRecovery")
assert(control.list[control.selIndex] == selected, "Reordering changed the selected metric")
assert(main.powerStatOrder[1] == "ManaRegenRecovery" and saveCount == 1)

control.searchTerm = "mana"
control:UpdateSearch()
assert(not control:ReorderRow(1, 2), "Filtered list must not reorder")
assert(main.powerStatOrder[1] == "ManaRegenRecovery" and saveCount == 1)
control:ResetSearch()

tree.controls.nodePowerMaxDepthSelect:SetSel(1)
control.list = tree.powerStatList
assert(control:ReorderRow(indexOf(control.list, "FullDPSAndEHP"), 1))
assert(tree.notablePowerStatList[1].stat == "FullDPSAndEHP")
assert(tree.normalPowerStatList[1].stat == "ManaRegenRecovery", "Notables-only option leaked into normal mode")
tree.controls.nodePowerMaxDepthSelect:SetSel(2)
control.list = tree.powerStatList
assert(control.list[1].stat == "ManaRegenRecovery")

main.SaveSettings = savedSettings
local oldSave, oldLoad = common.xml.SaveXMLFile, common.xml.LoadXMLFile
local savedXML
common.xml.SaveXMLFile = function(xml)
	savedXML = xml
	return true
end
main:SaveSettings()
common.xml.SaveXMLFile = oldSave
assert(savedXML, "Settings serialization did not run")
local orderNode
for _, node in ipairs(savedXML) do
	if type(node) == "table" and node.elem == "PowerStatOrder" then orderNode = node; break end
end
assert(orderNode and orderNode[1].attrib.id == "FullDPSAndEHP" and orderNode[2].attrib.id == "ManaRegenRecovery")
main.powerStatOrder = { }
common.xml.LoadXMLFile = function() return { savedXML } end
main:LoadSettings(true)
common.xml.LoadXMLFile = oldLoad
assert(main.powerStatOrder[1] == "FullDPSAndEHP" and main.powerStatOrder[2] == "ManaRegenRecovery")
newBuild()
assert(build.treeTab.notablePowerStatList[1].stat == "FullDPSAndEHP")
assert(build.treeTab.normalPowerStatList[1].stat == "ManaRegenRecovery")

main.powerStatOrder = { "RemovedMetric", "ManaRegenRecovery", "ManaRegenRecovery", "TotalEHP" }
newBuild()
assert(build.treeTab.normalPowerStatList[1].stat == "ManaRegenRecovery")
assert(build.treeTab.normalPowerStatList[2].stat == "TotalEHP")
print("PASS: metric order, selection, mode-specific entry, filter guard, and settings round-trip")

main.powerStatOrder = { }
newBuild()
local dragControl = build.treeTab.controls.treeHeatMapStatSelect
dragControl.shown = true
dragControl.dropped = true
dragControl.dropUp = false
dragControl.dropHeight = (dragControl.height - 4) * 3
dragControl.droppedWidth = dragControl.width
dragControl.controls.scrollBar.enabled = false
local x, y = dragControl:GetPos()
local cursorX, cursorY = x + 8, y + dragControl.height + 2 + (dragControl.height - 4) + 5
local oldCursor = GetCursorPos
GetCursorPos = function() return cursorX, cursorY end
main.SaveSettings = function() saveCount = saveCount + 1 end
dragControl:OnKeyDown("LEFTBUTTON")
assert(dragControl.reorderStartIndex == 2, "Mouse-down did not start a row drag")
cursorY = cursorY - (dragControl.height - 4)
dragControl:OnKeyUp("LEFTBUTTON")
assert(dragControl.list[1].stat == "TotalEHP" and dragControl.dropped,
	"Dragging inside the open dropdown must move the row without selecting or closing it")
dragControl.searchTerm = "ehp"
dragControl:UpdateSearch()
dragControl:OnKeyDown("LEFTBUTTON")
assert(not dragControl.reorderStartIndex, "Filtered dropdown must not start a drag")
GetCursorPos = oldCursor
main.SaveSettings = savedSettings
print("PASS: direct dropdown drag and filtered drag suppression")

local list = build.treeTab.controls.powerReportList
local metric = { stat = "ManaRegenRecovery", label = "Mana recovery" }
local rows = {
	{ id = 1, type = "Notable", power = 10, pathPower = 10 },
	{ id = 2, type = "Notable", power = -5, pathPower = -5 },
	{ id = 3, type = "Notable", power = 0, pathPower = 0 },
}
list:SetReport(metric, rows, true)
assert(#list.list == 2 and list.list[1].id == 1 and list.list[2].id == 2,
	"Notables must include positive and negative nonzero ordinary-metric changes")
list:SetReport(metric, rows, false)
assert(#list.list == 1 and list.list[1].id == 1, "Range mode must retain its existing filter")
print("PASS: signed ordinary-metric notables and unchanged range filtering")
