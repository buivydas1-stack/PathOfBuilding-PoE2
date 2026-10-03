-- Run with tools/Test-CustomPowerReport.ps1 -TestPath tests/custom_augment_tooltips.lua
arg = {}; dofile("HeadlessWrapper.lua")
newBuild()
local report = LoadModule("Modules/AugmentReport")
local json = require("dkjson")
local function equip(raw, slot)
	local item = new("Item", raw)
	build.itemsTab:AddItem(item, true); build.itemsTab.slots[slot]:SetSelItemId(item.id)
	return item
end
build.characterLevel = 90
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
build.skillsTab.socketGroupList[1].includeInFullDPS = true
equip("Rarity: Rare\nTooltip Bow\nCrude Bow\n--------\nAdds 100 to 200 Physical Damage", "Weapon 1")
local helmet = equip("Rarity: Rare\nTooltip Helmet\nRusted Greathelm\n--------\nSockets: S S\n--------\n+100 to maximum Life", "Helmet")
build.configTab.input.enemyEvasion = 2000
build.configTab.input.enemyBlockChance = 3
build.configTab:BuildModList(); build.buildFlag = true
runCallback("OnFrame"); runCallback("OnFrame")
local raw = helmet:BuildRaw()
local result = json.decode(json.encode(report.Calculate(build, raw, "Helmet", {["Legacy of Greymake"] = true})))
local row = result.rows[1]
local comparison = report.ComparisonOutput(result.baselineComparison, row.comparison)
assert(row.values.HitChance > result.baseline.HitChance, "Dexterity must improve the fixture's hit chance")
assert(row.values.FullDPS > result.baseline.FullDPS)
assert(comparison.HitChance == row.values.HitChance)
assert(comparison.PreEffectiveCritChance == result.baselineComparison.PreEffectiveCritChance)
assert(comparison.CritChance > result.baselineComparison.CritChance, "Accuracy must affect effective rather than base crit chance")
assert(not row.comparison.PreEffectiveCritChance, "Unchanged comparison fields must not be repeated per row")
local found
for _, stat in ipairs(report.GetStats()) do if stat.stat == "HitChance" then found = true end end
assert(found, "Hit Chance must be a sortable report metric")
local empty = report.EmptyItem(raw)
local candidate = new("Item", empty:BuildRaw()); candidate.runes[1] = row.name
candidate:UpdateRunes(); candidate:BuildAndParseRaw(); candidate:BuildModList()
local calculator = build.calcsTab:GetMiscCalculator()
local before = calculator({repSlotName="Helmet",repItem=empty},true,{noEnvReuse=true})
local after = calculator({repSlotName="Helmet",repItem=candidate},true,{noEnvReuse=true})
local control = build.itemsTab.controls.augmentReport
build.viewMode = "ITEMS"; build.itemsTab:SetDisplayItem(helmet); control:Update()
control.result = result; control:Refresh()
local entry = control.list[1]
local oldReveal, reveal = main.IsComparisonRevealHeld, false
main.IsComparisonRevealHeld = function() return reveal end
local function text(tooltip)
	local lines = {}; for _, line in ipairs(tooltip.lines) do lines[#lines+1] = line.text end
	return table.concat(lines, "\n")
end
local tooltip = new("Tooltip")
local generation = control.generation
for _, value in ipairs({false, true, false}) do
	reveal = value
	control:AddValueTooltip(tooltip, 1, entry) -- Same entry: Alt must invalidate its tooltip cache.
	local rendered = text(tooltip)
	build.viewMode = "TREE"
	local tree = new("Tooltip")
	build:AddStatComparesToTooltip(tree, before, after, "^7Stat changes:")
	build.viewMode = "ITEMS"
	local start = assert(rendered:find("^7Stat changes:", 1, true))
	assert(rendered:sub(start) == text(tree), "Cached augment tooltip must match the direct tree comparison exactly")
	assert((rendered:find(" Hit Chance (", 1, true) ~= nil) == reveal)
	assert((rendered:find("Effective Crit Chance", 1, true) ~= nil) == reveal)
	assert(control.result == result and not control.worker and control.generation == generation, "Hover and reveal must use cached results")
end
main.IsComparisonRevealHeld = oldReveal
local scalar = report.ComparisonSnapshot({Life=100, TotalEHP=math.huge, ManaHasCost=true, Minion={Life=50}, mainSkill={cycle=true}})
assert(scalar.Life == 100 and scalar.ManaHasCost and scalar.Minion.Life == 50 and not scalar.mainSkill)
assert(scalar.unavailableStats.TotalEHP and not scalar.TotalEHP)
local changed = {Life=120,ManaHasCost=false,Minion={Life=60,HitChance=80}}
local patch = json.decode(json.encode(report.ComparisonChanges(scalar,changed)))
local restored = report.ComparisonOutput(scalar,patch)
assert(restored.Life==120 and restored.ManaHasCost==false and restored.Minion.Life==60 and restored.Minion.HitChance==80 and not restored.unavailableStats)
assert(scalar.Life==100 and scalar.Minion.Life==50, "Restoring comparison values must not mutate the baseline")
local undefined = new("Tooltip")
build:AddStatComparesToTooltip(undefined, scalar, {Life=110,TotalEHP=10}, "Changes")
assert(not text(undefined):find("Effective Hit Pool", 1, true), "Unavailable values must not be displayed as zero")
print("PASS: Accuracy-driven Hit Chance/effective crit gains, sortable metric, JSON snapshots, exact tree tooltip parity, cached Alt transitions and unavailable values")
