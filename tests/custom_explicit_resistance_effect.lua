local open = io.open
io.open = function(path, mode)
	local normalized = path:gsub("\\", "/"):lower()
	assert(not (mode or "r"):find("[wa+]"), "Resistance effect tests cannot write files")
	if normalized:match("settings%.xml$") or normalized:match("first%.run$") or normalized:find("/builds/", 1, true) then return nil end
	return open(path, mode)
end
arg = { }; dofile("HeadlessWrapper.lua"); newBuild()
local report = LoadModule("Modules/CatalystReport")
local raw = [[Item Class: Amulets
Rarity: Rare
Miracle Noose
Gold Amulet
--------
Requires: Level 65
--------
Item Level: 82
--------
14% increased Rarity of Items found (implicit)
--------
+20% to all Elemental Resistances (fractured)
6% increased maximum Mana
+50 to Spirit
+54% to Cold Resistance
21% increased Explicit Resistance Modifier magnitudes (crafted)
17% increased Rarity of Items found (desecrated)
--------
Fractured Item
--------
Note: ~b/o 50 divine]]
local function line(item, text)
	for _, field in ipairs({ "explicitModLines", "implicitModLines" }) do
		for _, value in ipairs(item[field]) do if value.line:find(text, 1, true) then return value end end
	end
	error("Missing line " .. text)
end
local function sum(item, name)
	if not item.modList then item:BuildModList() end
	local result = 0
	for _, mod in ipairs(item.modList or item.slotModList[1]) do
		if (mod.name == name or mod.name == "ElementalResist") and mod.type == "BASE" then result = result + mod.value end
	end
	return result
end
local function check(item, fire, cold, lightning)
	assert(sum(item, "FireResist") == fire and sum(item, "ColdResist") == cold and sum(item, "LightningResist") == lightning,
		"Wrong resistance totals: " .. sum(item, "FireResist") .. "/" .. sum(item, "ColdResist") .. "/" .. sum(item, "LightningResist"))
	for _, mod in ipairs(item.modList) do assert(mod.name ~= "LocalExplicitResistanceEffect", "Local modifier leaked into global stats") end
end
local function near(actual, expected, name)
	assert(actual and expected and math.abs(actual - expected) < math.max(1, math.abs(expected)) * 1e-7, name .. ": " .. tostring(actual) .. "/" .. tostring(expected))
end
local item = new("Item", raw)
assert(not line(item, "Explicit Resistance").extra and line(item, "Explicit Resistance").crafted)
assert(line(item, "all Elemental Resistances").fractured and line(item, "17% increased Rarity").desecrated)
check(item, 20, 74, 20)
check(new("Item", item:BuildRaw()), 20, 74, 20)
local plain = new("Item", raw:gsub("21%% increased Explicit Resistance Modifier magnitudes %(crafted%)\n", ""))
check(plain, 20, 74, 20)
local calculator = build.calcsTab:GetMiscCalculator()
local actual = calculator({ repSlotName = "Amulet", repItem = item }, true, { noEnvReuse = true })
local expected = calculator({ repSlotName = "Amulet", repItem = plain }, true, { noEnvReuse = true })
for _, stat in ipairs({ "FireResistTotal", "ColdResistTotal", "LightningResistTotal", "TotalEHP", "Mana", "Spirit" }) do near(actual[stat], expected[stat], "No double scaling: " .. stat) end
print("PASS: exact Miracle Noose paste is supported, flags/round trip preserved, 20/74/20 resistance and independent-engine parity without double scaling")

local function craft(effect, quality)
	local text = "Rarity: Rare\nCrafted Resistance Amulet\nGold Amulet\nCrafted: true\nImplicits: 1\n14% increased Rarity of Items found\nSuffix: {range:0}AllResistances6\nSuffix: {range:1}ColdResist8"
	if effect then text = text .. "\nPrefix: {range:0.1}{crafted}AlloyEffectOfResistanceMods1" end
	if quality then text = text .. "\nCatalyst: Tul's\nCatalystQuality: " .. quality end
	local value = new("Item", text); value:Craft(); return value
end
local base, affected = craft(false), craft(true)
check(base, 17, 62, 17); check(affected, 20, 74, 20)
assert(line(affected, "Explicit Resistance").line == "21% increased Explicit Resistance Modifier magnitudes")
assert(line(affected, "Rarity").line == line(base, "Rarity").line, "Implicit unaffected by explicit magnitude")
local first = affected:BuildRaw(); affected:Craft(); assert(affected:BuildRaw() == first, "Recrafting must not compound")
local quality = craft(true, 20)
check(quality, 23, 86, 23)
assert(line(quality, "Cold Resistance").line == "+63% to Cold Resistance", "Cold quality and resistance effect add to 41%")
check(new("Item", quality:BuildRaw()), 23, 86, 23)
-- Adding the modifier as a custom line to a crafted item uses the same base rolls.
local custom = craft(false)
local parsed = new("Item", "Rarity: Rare\nCustom\nGold Amulet\n21% increased Explicit Resistance Modifier magnitudes")
local effectLine = copyTable(line(parsed, "Explicit Resistance")); effectLine.custom = true
table.insert(custom.explicitModLines, effectLine); custom:Craft(); check(custom, 20, 74, 20)
print("PASS: crafting from base rolls, implicit isolation, additive catalyst quality, local custom line, repeated crafting and round trips")

local result, neutral = report.ItemResult(raw, 20)
check(neutral, 20, 74, 20)
local tul = report.Prepare(raw, 6, 20)
check(tul, 23, 86, 23)
assert(line(tul, "Explicit Resistance").line == "21% increased Explicit Resistance Modifier magnitudes" and not line(tul, "Explicit Resistance").extra)
assert(line(tul, "all Elemental Resistances").fractured and line(tul, "17% increased Rarity").desecrated)
local removed = report.Prepare(tul:BuildRaw())
check(removed, 20, 74, 20)
assert(line(removed, "Rarity").line == "17% increased Rarity of Items found")
local forty = report.Prepare(raw, 6, 40)
check(forty, 27, 99, 27)
local esh = report.Prepare(tul:BuildRaw(), 7, 20)
check(esh, 23, 77, 23)
-- The supplied game values imply base rolls 17 and 45 at 21% increased magnitude.
local found
for _, row in ipairs(result.rows) do
	if row.name == "Tul's Catalyst" then
		found = true; assert(not row.unsupported)
		near(row.score, 3 / 20 * 100 + 9 / 54 * 100, "Actual modifier gains")
	end
end
assert(found)
local direct = craft(true, 20)
for _, stat in ipairs({ "FireResist", "ColdResist", "LightningResist" }) do assert(sum(tul, stat) == sum(direct, stat), "Report/crafting parity: " .. stat) end
print("PASS: all catalyst rows, 20/40 quality, catalyst switching/removal, exact roll recovery and independent crafted resistance parity")

-- An implicit resistance on a ring remains outside the explicit-effect scope.
local ring = "Item Class: Rings\nRarity: Rare\nEffect Ring\nTopaz Ring\n--------\n+27% to Lightning Resistance (implicit)\n--------\n+20% to Fire Resistance\n21% increased Explicit Resistance Modifier magnitudes (crafted)"
local ringQuality = report.Prepare(ring, 7, 20)
assert(sum(ringQuality, "LightningResist") == 32, "Only quality scales the implicit")
assert(line(ringQuality, "Fire Resistance").line == "+20% to Fire Resistance")
local tab = build.itemsTab
tab:CreateDisplayItemFromRaw(raw, true, true)
tab.controls.displayItemCatalyst:SetSel(7)
check(tab.displayItem, 23, 86, 23)
tab.controls.displayItemCatalyst:SetSel(1)
check(tab.displayItem, 20, 74, 20)
local saved = build:SaveDB("Explicit resistance effect fixture")
loadBuildFromXML(saved, "Explicit resistance effect round trip")
print("PASS: implicit resistance scope, real item catalyst controls and in-memory build round trip")
