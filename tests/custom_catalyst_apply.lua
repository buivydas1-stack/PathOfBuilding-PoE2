-- Run with tools/Test-CustomPowerReport.ps1 -TestPath tests/custom_catalyst_apply.lua
local open = io.open
function io.open(path, mode)
	local p = path:gsub("\\", "/"):lower()
	if p:match("settings%.xml$") or p:match("first%.run$") or p:find("/builds/", 1, true) then return nil end
	assert(not (mode or "r"):find("[wa+]"), "No writes during catalyst checks")
	return open(path, mode)
end
if not build then arg = { }; dofile("HeadlessWrapper.lua") end
newBuild()
local report = LoadModule("Modules/CatalystReport")
local tab = build.itemsTab
local control = tab.controls.catalystReport
build.viewMode = "ITEMS"
local raw = "Rarity: Rare\nApply Fixture\nGold Ring\n--------\n+100 to maximum Life\n+25% to Lightning Resistance"
local function rows(quality)
	control.controls.quality:SetText(tostring(quality), true)
	control:Update()
	control.result = report.ItemResult(control.itemRaw, quality)
	control.controls.search.buf = ""; control:Refresh()
	return control.list
end
local function entry(id)
	for _, value in ipairs(control.list) do if value.row.id == id then return value end end
	error("Missing catalyst")
end
tab:CreateDisplayItemFromRaw(raw, true)
local equipped = tab.slots["Ring 1"].selItemId
rows(40)
local selected = entry(1)
local before = tab.displayItem:BuildRaw()
control:OnSelClick(1, selected, false)
assert(tab.displayItem:BuildRaw() == before, "Single-click must only select")
control:OnSelClick(1, selected, true)
assert(tab.displayItem.catalyst == 1 and tab.displayItem.catalystQuality == 40)
assert(tab.displayItem.baseModList:Sum("BASE", nil, "Life") == 140)
assert(tab.slots["Ring 1"].selItemId == equipped, "Application is an item-editor preview")
assert(not control.result and #control.list == 0, "Applied item must invalidate the completed calculation")
-- Use the real list input dispatcher, including sorting/filtering and scrolling.
rows(20); control.controls.search.buf = "Esh"; control:Refresh()
local cursor = GetCursorPos
local x,y = control:GetPos(); local region=control:GetRowRegion()
GetCursorPos = function() return x+region.x+10, y+region.y+control.rowHeight/2 end
control:OnKeyDown("LEFTBUTTON", true)
assert(tab.displayItem.catalyst == 7 and tab.displayItem.catalystQuality == 20)
assert(tab.displayItem.baseModList:Sum("BASE", nil, "Life") == 100 and tab.displayItem.baseModList:Sum("BASE", nil, "LightningResist") == 30)
-- The right-click menu must name the action and apply the row under the cursor.
rows(100); control.controls.search.buf = "Flesh"; control:Refresh()
x,y = control:GetPos(); region=control:GetRowRegion()
assert(control:OnKeyDown("RIGHTBUTTON") == control)
local menu = assert(main.popups[1])
assert(menu.controls.apply.label == "Apply to item")
menu.controls.apply:Click()
assert(not main.popups[1] and tab.displayItem.catalyst == 1 and tab.displayItem.catalystQuality == 100)
assert(tab.displayItem.baseModList:Sum("BASE", nil, "Life") == 200, "Apply the calculated quality exactly")
-- Opening a menu cannot apply an old result after a new item is pasted.
rows(20); control.controls.search.buf = "Esh"; control:Refresh()
local stale = control:OpenApplyMenu(control.list[1])
tab:CreateDisplayItemFromRaw(raw, true)
local newRaw = tab.displayItem:BuildRaw()
stale.controls.apply:Click()
assert(tab.displayItem:BuildRaw() == newRaw and not main.popups[1])
rows(20); local cancelled = control:OpenApplyMenu(control.list[1])
GetCursorPos = function() return -100, -100 end
cancelled:ProcessInput({{type="KeyDown",key="LEFTBUTTON"}}, main.viewPort)
assert(not main.popups[1], "Outside click must dismiss the menu")
local popupCount = #main.popups
control:OnKeyDown("RIGHTBUTTON")
assert(#main.popups == popupCount, "Empty space must not open a menu")
GetCursorPos = cursor
print("PASS: catalyst double-click, real list dispatch, right-click Apply to item, exact target quality, scaling/removal, editor-only changes, cache invalidation, stale menu rejection and outside dismissal")
