-- Uses disposable in-memory builds only, including persistence round trips.
local open = io.open
io.open = function(path, mode)
	local normalized = path:gsub("\\", "/"):lower()
	assert(not (mode or "r"):find("[wa+]"), "Sticky anoint tests cannot write files")
	if normalized:match("settings%.xml$") or normalized:match("first%.run$") or normalized:find("/builds/", 1, true) then return nil end
	return open(path, mode)
end
arg = { }; dofile("HeadlessWrapper.lua")
newBuild()
build.characterLevel = 90
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
build.skillsTab.socketGroupList[1].includeInFullDPS = true
local bow = new("Item", "Rarity: Rare\nTest Bow\nCrude Bow\nAdds 20 to 100 Lightning Damage\n+1000 to Accuracy Rating")
build.itemsTab:AddItem(bow, true)
build.itemsTab.slots["Weapon 1"]:SetSelItemId(bow.id)
build.mainSocketGroup = 1
build.buildFlag = true; runCallback("OnFrame")

local raw = [[Item Class: Amulets
Rarity: Rare
Bramble Clasp
Lapis Amulet
--------
Requires: Level 56
--------
Item Level: 82
--------
Allocates Serrated Edges (enchant)
--------
+14 to Intelligence (implicit)
--------
30% increased Evasion Rating
+157 to maximum Mana
+47 to Spirit
15% increased Rarity of Items found
+2 to Level of all Projectile Skills
+15% to Cold and Chaos Resistances (desecrated)
--------
Note: ~b/o 20 divine]]
local bare = raw:gsub("Allocates Serrated Edges %(enchant%)\n%-%-%-%-%-%-%-%-\n", "")
local tab = build.itemsTab
local function select(name)
	local control = tab.controls.displayItemStickyAnoint
	control:ResetSearch()
	for index, value in ipairs(control.list) do
		if value.label == name then control:SetSel(index); return end
	end
	error("Missing anoint: " .. name)
end
local function anoint(item)
	return tab:getAnoint(item)[1]
end
local function paste(text)
	tab:CreateDisplayItemFromRaw(text or raw, true, true)
	return tab.displayItem
end
local function near(actual, expected, name)
	assert(actual and expected and math.abs(actual - expected) < math.max(1, math.abs(expected)) * 1e-7, name .. ": " .. tostring(actual) .. " / " .. tostring(expected))
end
assert(not tab.stickyAnointNodeId and tab.controls.displayItemStickyAnoint:GetSelValue().label == "Off")
local original = paste():BuildRaw()
assert(anoint(tab.displayItem) == "Serrated Edges")
tab:ResetUndo()
select("Grace of the Ancestors")
assert(anoint(tab.displayItem) == "Grace of the Ancestors" and tab.modFlag)
assert(tab.displayItem:BuildRaw() == original:gsub("Allocates Serrated Edges", "Allocates Grace of the Ancestors"), "Only the anoint changes")
assert(tab.controls.displayItemStickyAnoint:IsShown() and not tab.controls.displayItemStickyAnointStatus:IsShown())
local independent = new("Item", raw:gsub("Allocates Serrated Edges", "Allocates Grace of the Ancestors"))
independent:NormaliseQuality(); independent:BuildModList()
local calculator = build.calcsTab:GetMiscCalculator()
local actual = calculator({ repSlotName = "Amulet", repItem = tab.displayItem }, true, { noEnvReuse = true })
local expected = calculator({ repSlotName = "Amulet", repItem = independent }, true, { noEnvReuse = true })
for _, name in ipairs({ "TotalDPS", "TotalEHP", "Mana", "Spirit", "Int" }) do near(actual[name], expected[name], "Independent comparison " .. name) end
local sourceOutput = calculator({ repSlotName = "Amulet", repItem = new("Item", raw) }, true, { noEnvReuse = true })
assert(actual.TotalDPS ~= sourceOutput.TotalDPS, "Anoint must affect the comparison")
tab:Undo(); assert(not tab.stickyAnointNodeId and anoint(tab.displayItem) == "Serrated Edges")
tab:Redo(); assert(anoint(tab.displayItem) == "Grace of the Ancestors")
select("Off"); assert(tab.displayItem:BuildRaw() == original)
print("PASS: exact market paste, immediate change, independent engine parity, Off restoration and undo/redo")

select("Grace of the Ancestors")
paste(bare); assert(anoint(tab.displayItem) == "Grace of the Ancestors", "Anoint added with no equipped amulet")
paste(); assert(anoint(tab.displayItem) == "Grace of the Ancestors")
local applied = tab.displayItem
tab:AddDisplayItem(true)
assert(tab.items[applied.id] == applied and anoint(applied) == "Grace of the Ancestors")
assert(tab.stickyAnointName == "Grace of the Ancestors" and not tab.pastedAnointLines)
paste(); assert(anoint(tab.displayItem) == "Grace of the Ancestors", "Selection survives Add to build")

for _, state in ipairs({ "Corrupted", "Mirrored", "Sanctified" }) do
	local item = paste(raw .. "\n--------\n" .. state)
	assert(item[state:lower()], "Missing parsed state " .. state)
	assert(anoint(item) == "Serrated Edges" and tab:GetStickyAnointIgnoreReason() == "Ignored: " .. state:lower())
	assert(tab.controls.displayItemStickyAnointStatus:IsShown() and tab.controls.displayItemStickyAnoint:IsEnabled())
	local unchanged = item:BuildRaw()
	select("Serrated Edges"); select("Grace of the Ancestors")
	assert(item:BuildRaw() == unchanged, state .. " must retain all original modifiers")
	paste(bare .. "\n--------\n" .. state); assert(not anoint(tab.displayItem), state .. " cannot gain an anoint")
end
paste(); assert(anoint(tab.displayItem) == "Grace of the Ancestors", "Ignored items do not clear the choice")
print("PASS: next paste and Add to build; corrupted/mirrored/sanctified with existing or missing anoints stay unchanged")

tab:CreateDisplayItemFromRaw(raw, true)
assert(anoint(tab.displayItem) == "Serrated Edges" and not tab.pastedAnointLines, "Manual text and database imports do not opt in")
select("Serrated Edges"); select("Grace of the Ancestors")
assert(anoint(tab.displayItem) == "Serrated Edges")
local equipped = new("Item", raw)
tab:AddItem(equipped, true); tab.slots.Amulet:SetSelItemId(equipped.id)
local equippedRaw = equipped:BuildRaw()
tab:SetDisplayItem(new("Item", equippedRaw))
select("Serrated Edges"); select("Grace of the Ancestors")
assert(anoint(tab.displayItem) == "Serrated Edges" and equipped:BuildRaw() == equippedRaw)
paste(bare); assert(anoint(tab.displayItem) == "Grace of the Ancestors")
select("Off"); assert(anoint(tab.displayItem) == "Serrated Edges", "Off retains normal equipped-anoint fallback")
assert(equipped:BuildRaw() == equippedRaw, "Pastes cannot mutate equipped enchantments")
select("Grace of the Ancestors")
tab:CreateDisplayItemFromRaw("Rarity: Rare\nTest Ring\nGold Ring\n--------\n+50 to maximum Life", true, true)
assert(not tab.controls.displayItemStickyAnoint:IsShown() and not anoint(tab.displayItem))
print("PASS: manual/database/equipped previews, normal Off fallback, no equipped mutations and non-amulet isolation")

paste()
tab.controls.displayItemCatalyst:SetSel(8)
local quality, catalyst = tab.displayItem.catalystQuality, tab.displayItem.catalyst
select("Off")
assert(anoint(tab.displayItem) == "Serrated Edges" and tab.displayItem.catalystQuality == quality and tab.displayItem.catalyst == catalyst)
select("Grace of the Ancestors")
assert(anoint(tab.displayItem) == "Grace of the Ancestors" and tab.displayItem.catalystQuality == quality)
local otherEnchant = raw:gsub("Allocates Serrated Edges %(enchant%)", "5%% increased Movement Speed (enchant)\nAllocates Serrated Edges (enchant)")
paste(otherEnchant)
assert(tab.displayItem.enchantModLines[1].line == "5% increased Movement Speed" and anoint(tab.displayItem) == "Grace of the Ancestors")
select("Off"); assert(anoint(tab.displayItem) == "Serrated Edges" and #tab.displayItem.enchantModLines == 2)
print("PASS: changing the sticky choice preserves catalyst edits and unrelated enchantments")

-- Dispatch the real Ctrl+V path with fixture clipboard/key state, without desktop input.
select("Grace of the Ancestors")
local oldPaste, oldIsKeyDown = Paste, IsKeyDown
Paste = function() return raw end
IsKeyDown = function(key) return key == "CTRL" end
tab:Draw({ x = 0, y = 100, width = 1800, height = 800 }, { { type = "KeyDown", key = "v" } })
Paste, IsKeyDown = oldPaste, oldIsKeyDown
assert(anoint(tab.displayItem) == "Grace of the Ancestors", "Ctrl+V must opt in")
local saved = build:SaveDB("Sticky anoint fixture")
assert(saved:find('stickyAnointName="Grace of the Ancestors"', 1, true))
loadBuildFromXML(saved, "Sticky anoint round trip")
tab = build.itemsTab
assert(tab.stickyAnointName == "Grace of the Ancestors" and tab.controls.displayItemStickyAnoint:GetSelValue().label == "Grace of the Ancestors")
paste(); assert(anoint(tab.displayItem) == "Grace of the Ancestors")
select("Off")
local offSaved = build:SaveDB("Sticky anoint Off fixture")
assert(not offSaved:find("stickyAnointNodeId", 1, true))
loadBuildFromXML(offSaved, "Sticky anoint Off round trip"); tab = build.itemsTab
assert(not tab.stickyAnointNodeId and tab.controls.displayItemStickyAnoint:GetSelValue().label == "Off")
tab.stickyAnointNodeId, tab.stickyAnointName = -1, "Missing notable"
tab:RefreshStickyAnointList(); paste()
assert(anoint(tab.displayItem) == "Serrated Edges" and tab.controls.displayItemStickyAnoint:GetSelValue().label == "Unavailable: Missing notable")
assert(tab:GetStickyAnointIgnoreReason() == "Ignored: anoint unavailable on this tree")
select("Off")
newBuild(); tab = build.itemsTab
assert(not tab.stickyAnointNodeId, "Preference must not leak into another build")
print("PASS: real paste dispatch, per-build persistence, Off/legacy default, missing notable fallback and build isolation")
