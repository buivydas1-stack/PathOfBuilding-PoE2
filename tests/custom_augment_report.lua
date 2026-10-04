-- Run with tools/Test-CustomPowerReport.ps1 -TestPath tests/custom_augment_report.lua
if not build then arg = { }; dofile("HeadlessWrapper.lua") end
newBuild()
local report = LoadModule("Modules/AugmentReport")
local calcs = LoadModule("Modules/Calcs")
local json = require("dkjson")
local function near(a, b, label)
	assert(a and b and math.abs(a - b) <= math.max(0.000001, math.abs(b) * 0.000001), (label or "Mismatch") .. ": " .. tostring(a) .. " / " .. tostring(b))
end
local function item(base, runes, extra)
	local result = new("Item", "Rarity: Rare\nReport Fixture\n" .. base .. "\n--------\nSockets: S S\n--------\nItem Level: 80\n--------\n" .. (extra or "+200 to maximum Life"))
	result.runes = runes or { }
	result:UpdateRunes(); result:BuildAndParseRaw(); result:BuildModList()
	return result
end
local function equip(value, slot)
	build.itemsTab:AddItem(value, true)
	build.itemsTab.slots[slot]:SetSelItemId(value.id)
end
local function frame()
	build.buildFlag = true; runCallback("OnFrame"); runCallback("OnFrame")
end
local function row(result, name)
	for _, entry in ipairs(result.rows) do if entry.name == name then return entry end end
end
local function oracle(value, slot)
	local override = {repSlotName = slot, repItem = value}
	local env = calcs.initEnv(build, "CALCULATOR", override)
	calcs.perform(env)
	local full = calcs.calcFullDPS(build, "CALCULATOR", override)
	if #full.skills > 0 then env.player.output.FullDPS = full.combinedDPS end
	return report.Snapshot(env.player.output)
end
build.characterLevel = 90
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
build.skillsTab.socketGroupList[1].includeInFullDPS = true
local helmet = item("Rusted Greathelm", {"Perfect Body Rune", "Perfect Body Rune"}, "+200 to maximum Life\n+300 to Armour\n100% increased effect of Socketed Runes")
local bow = item("Crude Bow", {"Greater Storm Rune", "None"}, "Adds 10 to 20 Physical Damage")
equip(helmet, "Helmet"); equip(bow, "Weapon 1"); frame()
local raw = helmet:BuildRaw()
local revision, flag, modified = build.outputRevision, build.buildFlag, build.itemsTab.modFlag
local empty = report.EmptyItem(raw)
assert(empty.runes[1] == "None" and empty.runes[2] == "None")
local names = { ["Perfect Body Rune"] = true, ["Perfect Iron Rune"] = true, ["Jiquani's Thesis"] = true, ["Quipolatl's Soul Core of Flow"] = true }
local result = report.Calculate(build, raw, "Helmet", names)
assert(#result.rows == 4, "Rune, Idol and Soul Core candidates must be present")
local baseline = oracle(empty, "Helmet")
near(result.baseline.Life, baseline.Life, "Empty baseline Life")
near(result.baseline.TotalEHP, baseline.TotalEHP, "Empty baseline EHP")
near(result.baseline.FullDPS, baseline.FullDPS, "Empty baseline Full DPS")
for name in pairs(names) do
	local candidate = new("Item", empty:BuildRaw())
	candidate.runes[1] = name; candidate:UpdateRunes(); candidate:BuildAndParseRaw(); candidate:BuildModList()
	local expected = oracle(candidate, "Helmet")
	for _, stat in ipairs({"Life", "Armour", "Mana", "TotalEHP", "FullDPS"}) do near(row(result, name).values[stat], expected[stat], name .. " " .. stat) end
end
local unscaled = item("Rusted Greathelm", {}, "+200 to maximum Life\n+300 to Armour")
local unscaledResult = report.Calculate(build, unscaled:BuildRaw(), "Helmet", { ["Perfect Body Rune"] = true })
near(row(result, "Perfect Body Rune").values.Life - result.baseline.Life, 2 * (unscaledResult.rows[1].values.Life - unscaledResult.baseline.Life), "Local Rune effect")
local replaced = report.Calculate(build, raw, "Helmet", names, true, 2)
near(replaced.baseline.Life, oracle(helmet, "Helmet").Life, "Existing-augment baseline")
near(row(replaced, "Perfect Body Rune").values.Life, replaced.baseline.Life, "Replacing the same augment changes nothing")
assert(row(replaced, "Perfect Iron Rune").values.Life < replaced.baseline.Life, "Replacement must retain the other Body Rune and lose only one")
assert(helmet:BuildRaw() == raw and helmet.runes[1] == "Perfect Body Rune" and helmet.runes[2] == "Perfect Body Rune")
assert(build.outputRevision == revision and build.buildFlag == flag and build.itemsTab.modFlag == modified, "Report mutated the live build")
local bowResult = report.Calculate(build, bow:BuildRaw(), "Weapon 1", { ["Perfect Storm Rune"] = true, ["Soul Core of Xopec"] = true, ["Jiquani's Thesis"] = true })
assert(row(bowResult, "Perfect Storm Rune") and row(bowResult, "Soul Core of Xopec"))
assert(not row(bowResult, "Jiquani's Thesis"), "Armour Idol must not be suggested for a bow")
assert(row(bowResult, "Perfect Storm Rune").values.FullDPS > bowResult.baseline.FullDPS, "Socketed weapon damage must alter Full DPS")
print("PASS: empty/current baselines, real sockets, local scaling, Idol/Soul Core eligibility, EHP and Full DPS, no mutation")

-- A retained limited augment blocks another copy; replacing that socket frees
-- the limit. Ancient augments share their cap even when their names differ.
local limited = "Quipolatl's Soul Core of Flow"
local limitedHelmet = item("Rusted Greathelm", {limited, "Perfect Body Rune"})
local blocked = report.Calculate(build, limitedHelmet:BuildRaw(), "Helmet", {[limited] = true}, true, 2)
assert(#blocked.rows == 0 and blocked.excluded == 1)
local allowed = report.Calculate(build, limitedHelmet:BuildRaw(), "Helmet", {[limited] = true}, true, 1)
assert(#allowed.rows == 1 and allowed.excluded == 0)
local forgotten = report.Calculate(build, limitedHelmet:BuildRaw(), "Helmet", {[limited] = true})
assert(#forgotten.rows == 1, "Empty mode must release every target-item augment limit")
local ancientHelmet, ancientBoots
for name, slots in pairs(data.itemMods.Runes) do
	for slot, augment in pairs(slots) do
		if augment.limitId == "AncientAugment" then
			if slot == "helmet" then ancientHelmet = name elseif slot == "boots" then ancientBoots = name end
		end
	end
end
assert(ancientHelmet and ancientBoots)
local boots = item("Rawhide Boots", {ancientBoots})
equip(boots, "Boots"); frame()
blocked = report.Calculate(build, helmet:BuildRaw(), "Helmet", {[ancientHelmet] = true}, true, 1)
assert(#blocked.rows == 0 and blocked.excluded == 1, "Another equipped Ancient augment must consume the shared cap")
local invalidHelmet = item("Rusted Greathelm", {limited, limited})
local invalidBoots = item("Rawhide Boots", {"Estazunti's Soul Core of Convalescence", "Estazunti's Soul Core of Convalescence"})
equip(invalidBoots, "Boots"); frame()
local ok, err = pcall(report.Calculate, build, invalidHelmet:BuildRaw(), "Helmet", {["Perfect Body Rune"] = true}, true, 1)
assert(not ok and err:find("Other retained augments", 1, true), "A retained invalid loadout cannot yield legal replacement recommendations")
build.itemsTab.slots.Boots:SetSelItemId(0); frame()
local onlyCores = item("Rusted Greathelm", {}, "Only Soul Cores can be Socketed in this Item")
local eligible = build.itemsTab:GetValidRunesForItem(onlyCores)
assert(onlyCores.baseModList:Flag(nil, "SocketedSoulCoresOnly"), "Fixture restriction was not parsed")
for _, augment in ipairs(eligible) do assert(augment.name == "None" or augment.type == "SoulCore") end
print("PASS: retained-socket limits, replacement releases, shared Ancient cap, restricted socket categories")

local control = build.itemsTab.controls.augmentReport
build.itemsTab:SetDisplayItem(helmet)
assert(control:IsShown() and not control.controls.existing.state)
local function stat(key)
	for _, value in ipairs(control.controls.stat.list) do if value.stat == key then return value end end
end
control.stat = stat("Life"); control.result = result; control:Refresh()
assert(control.list[1].row.name == "Perfect Body Rune")
control:ReSort(2); assert(control.list[#control.list].row.name == "Perfect Body Rune", "Sort must reverse")
control:ReSort(2); assert(control.list[1].row.name == "Perfect Body Rune")
control.controls.search:SetText("armour", true)
for _, entry in ipairs(control.list) do assert((entry.row.name .. table.concat(entry.row.lines, " ")):lower():find("armour", 1, true)) end
control.controls.search:SetText("", true)
control.controls.filter:SetSel(2)
assert(#control.list == 1 and control.list[1].benefit > 0)
control.controls.filter:SetSel(3); assert(#control.list == 0)
control.controls.filter:SetSel(1)
control.stat = stat("PhysicalTakenHit")
control.result = {baseline = {PhysicalTakenHit = 100}, slot = "Helmet", excluded = 0, rows = {
	{name = "Lower", lines = {}, values = {PhysicalTakenHit = 90}},
	{name = "Higher", lines = {}, values = {PhysicalTakenHit = 110}},
	{name = "Invalid", lines = {}, values = {}}
}}
control:Refresh(); assert(control.list[1].row.name == "Lower" and control.list[1].delta == -10)
control:ReSort(3); assert(control.list[1].row.name == "Lower", "Lower taken damage is a benefit")
local delta, benefit, percent = report.Compare({Life = 0}, {Life = 10}, stat("Life"))
assert(delta == 10 and benefit == 10 and percent == nil)
assert(report.Compare({Life = math.huge}, {Life = 10}, stat("Life")) == nil)
local minion = report.Snapshot({Life = 10, Minion = {Life = 20, CombinedDPS = 35}, CombinedDPS = 15})
assert(minion.MinionLife == 20 and minion.FullDPS == 50)
print("PASS: numeric metrics, search, gains/losses, reversible sorting, lower-is-better, minions and undefined percentages")

-- Native delivery is tested separately; mock only scheduling/transport here.
local oldTime, oldLaunch, oldAbort, oldPath = GetTime, LaunchSubScript, AbortSubScript, GetScriptPath
local now, launched, aborted, callbacks = 1000, 0, 0, {}
GetTime = function() return now end
GetScriptPath = function() return "." end
LaunchSubScript = function(script, _, _, root, xml, raw, slot, existing, socketIndex)
	assert(xml:find("<PathOfBuilding2", 1, true) and raw == helmet:BuildRaw() and slot == "Helmet")
	assert(type(existing) == "boolean" and socketIndex == 1)
	launched = launched + 1; return launched
end
AbortSubScript = function() aborted = aborted + 1 end
control.key = nil; control:Update(); assert(launched == 0)
now = now + 10000; control:Update(); assert(launched == 0, "Opening an item must never automatically calculate")
control:Calculate(); assert(launched == 1)
local stale = launch.subScripts[1].callback
for i = 1, 100 do control:Update() end
assert(launched == 1, "Unchanged drawing must not launch another calculation")
control.result = result; control.stat = stat("Life"); control:Refresh()
control.controls.filter:SetSel(2); control:ReSort(1)
assert(launched == 1, "Sorting/filtering must use cached results")
-- Exercise the real rune dropdown path, including raw rebuilding and tooltip
-- updates, for armour and weapons. It must preserve a pending worker as well
-- as the completed rows while existing augments are ignored.
local function changeRune(name)
	local drop = build.itemsTab.controls.displayItemRune1
	for index, value in ipairs(drop.list) do
		if value.name == name then drop.selFunc(index, value); control:Update(); return end
	end
	error("Missing fixture rune: " .. name)
end
local cached, generation, key = control.result, control.generation, control.key
changeRune("Perfect Iron Rune")
assert(control.result == cached and control.worker == 1 and control.generation == generation and control.key == key and aborted == 0,
	"Ignored armour augment edits must retain cached rows and the pending worker")
changeRune("Perfect Body Rune")
control.controls.socket.selIndex = 2; control:Update()
assert(control.result == cached and control.worker == 1, "Unchecked socket selection cannot affect comparisons")
control.controls.socket.selIndex = 1
control.controls.existing.state = true; control:Update()
assert(aborted == 1 and control.result == nil)
stale(json.encode(result)); assert(control.result == nil, "Cancelled results must not replace newer results")
now = now + 10000; control:Update(); assert(launched == 1, "Mode changes must wait for Calculate")
control:Calculate(); assert(launched == 2)
launch:OnSubFinished(2, json.encode(replaced)); assert(control.result.considerExisting)
changeRune("Perfect Iron Rune")
assert(control.result == nil, "Existing-augment mode must invalidate on rune edits")
changeRune("Perfect Body Rune")
build.outputRevision = build.outputRevision + 1; control:Update()
assert(control.result == nil, "Build changes must invalidate cached comparisons")
now = now + 10000; control:Update(); assert(launched == 2, "Build changes must wait for Calculate")
control:Calculate(); assert(launched == 3)
launch:OnSubError(3, "Worker error fixture"); assert(control.failed and control.worker == nil)
control:Cancel(); launch:OnSubFinished(999, "late"); launch:OnSubError(999, "late")
control.controls.existing.state = false
build.itemsTab:SetDisplayItem(bow); control:Update()
control.result = result; control:Refresh()
cached, generation, key = control.result, control.generation, control.key
changeRune("Greater Iron Rune")
assert(control.result == cached and control.generation == generation and control.key == key,
	"Ignored bow augment edits must retain recommendations")
bow.quality = (bow.quality or 0) + 1
bow:BuildAndParseRaw(); build.itemsTab:UpdateDisplayItemTooltip(); control:Update()
assert(control.result == nil and control.key ~= key, "Other item edits must still invalidate recommendations")
control.result = result
bow.itemSocketCount = 1
bow:BuildAndParseRaw(); build.itemsTab:UpdateDisplayItemTooltip(); control:Update()
assert(control.result == nil, "Socket count changes must still invalidate recommendations")
build.itemsTab:SetDisplayItem(nil); control:Update(); assert(not control:IsShown())
GetTime, LaunchSubScript, AbortSubScript, GetScriptPath = oldTime, oldLaunch, oldAbort, oldPath
print("PASS: explicit calculation only, cache reuse, mode/build invalidation, cancellation, stale delivery and worker errors")
