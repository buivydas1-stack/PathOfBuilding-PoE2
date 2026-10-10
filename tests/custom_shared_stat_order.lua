-- Shared UI ordering must not change a calculation, selected metric or cache.
local open = io.open
function io.open(path, mode)
	local p = path:gsub("\\", "/"):lower()
	if p:match("settings%.xml$") or p:match("first%.run$") or p:find("/builds/", 1, true) then return nil end
	assert(not (mode or "r"):find("[wa+]"), "No writes during shared-order checks")
	return open(path, mode)
end
if not build then arg = { }; dofile("HeadlessWrapper.lua") end
local savedSettings, saveCount = main.SaveSettings, 0
main.SaveSettings = function() saveCount = saveCount + 1 end
main.powerStatOrder = { }
newBuild()
local order = LoadModule("Modules/PowerStatOrder")
local function indexOf(control, id)
	for index, entry in ipairs(control.list) do if order.Id(entry) == id then return index end end
end
local tree = build.treeTab
local tab = build.itemsTab
local augment, catalyst = tab.controls.augmentReport, tab.controls.catalystReport
local support = build.skillsTab.controls.supportReport
local controls = {
	tree.controls.treeHeatMapStatSelect, augment.controls.stat, catalyst.controls.stat,
	support.controls.stat, build.compareTab.controls.comparePowerStatSelect, tab.controls.uniqueDB.controls.sort,
}
local selections = { }
local function assertSharedOrder()
	local reference = controls[2]
	for _, control in ipairs(controls) do
		local previous = 0
		for _, entry in ipairs(control.list) do
			local index = indexOf(reference, order.Id(entry))
			if index then assert(index > previous, "Shared metric order differs between menus"); previous = index end
		end
	end
end
assertSharedOrder()
for _, control in ipairs(controls) do
	assert(control.reorderFunc and indexOf(control, "TotalEHP"))
	control:SelByValue("TotalEHP", "stat")
	selections[control] = control:GetSelValue()
end
local caches = { }
for _, report in ipairs({ augment, catalyst, support }) do
	report.result = { rows = { } }; caches[report] = report.result
end
assert(catalyst.controls.stat:ReorderRow(indexOf(catalyst.controls.stat, "ManaRegenRecovery"), 1))
assert(saveCount == 1)
assertSharedOrder()
for _, control in ipairs(controls) do
	local firstMetric
	for _, entry in ipairs(control.list) do if order.Id(entry) then firstMetric = entry; break end end
	assert(firstMetric.stat == "ManaRegenRecovery", "Existing selector did not synchronize")
	assert(control:GetSelValue() == selections[control], "Synchronization changed selection")
end
for report, result in pairs(caches) do assert(report.result == result, "Reordering invalidated a calculation") end
local compare = build.compareTab.controls.comparePowerStatSelect
local db = tab.controls.uniqueDB
assert(compare.list[1].stat == nil and db.controls.sort.list[1].itemField == "Name")
assert(not compare:ReorderRow(1, 2) and not compare:ReorderRow(2, 1), "Placeholder moved")
assert(not db.controls.sort:ReorderRow(1, 2), "Name entry moved into shared metrics")
db:SetSortMode("TotalEHP")
assert(db.controls.sort:GetSelValue().stat == "TotalEHP" and indexOf(db.controls.sort, "ManaRegenRecovery") == 2)

-- Support-only stats retain their own selection while shared stats synchronize.
support.controls.stat:SelByValue("ManaCost", "stat")
assert(support.controls.stat:ReorderRow(indexOf(support.controls.stat, "ManaCost"), 1))
assert(support.controls.stat:GetSelValue().stat == "ManaCost")
assertSharedOrder()
assert(not indexOf(catalyst.controls.stat, "ManaCost") and not indexOf(controls[1], "ManaCost"))
tree.controls.nodePowerMaxDepthSelect:SetSel(1)
controls[1].list = tree.powerStatList
assert(controls[1]:ReorderRow(indexOf(controls[1], "FullDPSAndEHP"), 1))
assert(tree.notablePowerStatList[1].stat == "FullDPSAndEHP")
assert(not indexOf(catalyst.controls.stat, "FullDPSAndEHP"))
tree.controls.nodePowerMaxDepthSelect:SetSel(2)
controls[1].list = tree.powerStatList

-- Menus opened after a reorder use it immediately, including both modifier
-- dialogs and the anoint database; their Default/Name entries stay fixed.
tab:CreateDisplayItemFromRaw("Rarity: Rare\nOrder Fixture\nGold Amulet\n--------\n+50 to maximum Life", true)
tab:AnointDisplayItem()
local anoints = main.popups[1].controls.notableDB.controls.sort
assert(anoints.reorderFunc and indexOf(anoints, "ManaRegenRecovery") == 2)
assert(anoints:ReorderRow(indexOf(anoints, "Life"), 2))
assert(indexOf(catalyst.controls.stat, "Life") == 1)
main:ClosePopup()
tab:AddCustomModifierToDisplayItem()
local mods = main.popups[1].controls.sort
assert(mods.reorderFunc and mods.list[1].label == "Default" and mods.list[2].stat == "Life")
assert(mods:ReorderRow(indexOf(mods, "EnergyShield"), 2))
assert(catalyst.controls.stat.list[1].stat == "EnergyShield")
main:ClosePopup()
tab:CorruptDisplayItem()
local corruption = main.popups[1].controls.sort
assert(corruption.reorderFunc and corruption.list[1].label == "Default" and corruption.list[2].stat == "EnergyShield")
main:ClosePopup()

-- Real captured press/release dispatch uses the tree's existing drag behavior.
build.viewMode = "ITEMS"
local drag = catalyst.controls.stat
drag.shown, drag.dropped, drag.dropUp = true, true, false
drag.dropHeight, drag.droppedWidth = (drag.height - 4) * 3, drag.width
drag.controls.scrollBar.enabled = false
local x, y = drag:GetPos()
local cursorX, startY = x + 8, y + drag.height + 2 + drag.height - 4 + 5
local savedCursor = GetCursorPos
GetCursorPos = function() return cursorX, startY end
local moved = drag.list[2]
drag:OnKeyDown("LEFTBUTTON", nil, cursorX, startY)
assert(drag.reorderStartIndex == 2)
drag:OnKeyUp("LEFTBUTTON", cursorX, startY - (drag.height - 4))
assert(drag.list[1] == moved and drag.dropped)
assertSharedOrder()
assert(augment.controls.stat.list[1].stat == moved.stat and controls[1].list[1].stat == moved.stat)
drag.searchTerm = "mana"; drag:UpdateSearch()
local saves = saveCount
assert(not drag:ReorderRow(1, 2) and saveCount == saves)
drag:ResetSearch()
GetCursorPos = savedCursor
local persisted = copyTable(main.powerStatOrder)
newBuild()
assert(build.itemsTab.controls.catalystReport.controls.stat.list[1].stat == moved.stat)
assert(table.concat(main.powerStatOrder, ",") == table.concat(persisted, ","))
assert(LoadModule("Modules/SupportReport").GetStats()[1].stat == "FullDPSAndEHP" or
	LoadModule("Modules/SupportReport").GetStats()[1].stat == "ManaCost", "Support order did not survive rebuilding")
main.SaveSettings = savedSettings
print("PASS: shared live drag order, cached results, selected metrics, menu-specific entries, late-opened dialogs, and rebuild persistence")
