-- Real editor/import paths and calculation checks; no saved user builds.
if not build then arg = {}; dofile("HeadlessWrapper.lua") end
newBuild()
local report = LoadModule("Modules/AugmentReport")
local function make(base, names, extra)
	local item = new("Item", "Rarity: Rare\nIdol Fixture\n" .. base .. "\n--------\nSockets: S S\n--------\nItem Level: 80\n--------\n" .. (extra or "+100 to maximum Life"))
	assert(item.base, base)
	item.runes = names or { }; item:UpdateRunes(); item:BuildAndParseRaw(); item:BuildModList()
	return item
end
local bases = { weapon = "Crude Bow", wand = "Withered Wand", staff = "Ashen Staff", sceptre = "Rattling Sceptre",
	helmet = "Rusted Greathelm", ["body armour"] = "Rusted Cuirass", gloves = "Stocky Mitts", boots = "Rawhide Boots",
	shield = "Splintered Tower Shield", buckler = "Splintered Tower Shield", focus = "Twig Focus", quiver = "Crude Quiver" }
-- Select a matching base from the actual registry for specialised armour slots.
for _, slot in ipairs({ "buckler", "focus" }) do
	for base, info in pairs(data.itemBases) do
		local probe = new("Item", "Rarity: Normal\n" .. base)
		if probe.base and select(2, probe:GetSocketedAugmentTypes()) == slot then bases[slot] = base; break end
	end
end
local checked = 0
for name, effects in pairs(data.itemMods.Runes) do
	for slot, effect in pairs(effects) do
		if effect.type == "Idol" then
			local base = assert(bases[slot], "No fixture for " .. slot)
			local item = make(base)
			local found
			for _, choice in ipairs(build.itemsTab:GetValidRunesForItem(item)) do if choice.name == name then found = choice end end
			assert(found, name .. " missing on " .. slot)
			item = make(base, { name })
			assert(item.runes[1] == name, name .. " lost on import: " .. slot)
			build.itemsTab:SetDisplayItem(item)
			local drop = build.itemsTab.controls.displayItemRune1
			assert(drop.list[drop.selIndex].name == name, name .. " missing from editor")
			assert(new("Item", item:BuildRaw()).runes[1] == name, name .. " lost on round trip")
			checked = checked + 1
		end
	end
end
print("PASS: " .. checked .. " idol slot entries survive eligibility, import, editor and round trip")

build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
build.skillsTab.socketGroupList[1].includeInFullDPS = true
local bow = make("Crude Bow", {}, "Adds 100 to 100 Physical Damage")
build.itemsTab:AddItem(bow, true); build.itemsTab.slots["Weapon 1"]:SetSelItemId(bow.id)
build.buildFlag = true; runCallback("OnFrame"); runCallback("OnFrame")
local result = report.Calculate(build, bow:BuildRaw(), "Weapon 1", {["Idol of the Sycophant"] = true})
assert(#result.rows == 1 and result.rows[1].values.FullDPS > result.baseline.FullDPS)
local output = report.ComparisonOutput(result.baselineComparison, result.rows[1].comparison)
assert(output.FireResist == result.baselineComparison.FireResist - 20)
local idolBow = make("Crude Bow", {"Idol of the Sycophant"}, "Adds 100 to 100 Physical Damage")
assert(idolBow.baseModList:Sum("BASE", nil, "DamageGainAsRandom") == 20)
assert(idolBow.baseModList:Sum("BASE", nil, "DamageGainAsChaos") == 0)
local cfg = { skillCond = { CanUseBondedModifiers = true } }
assert(idolBow.baseModList:Sum("BASE", cfg, "DamageGainAsChaos") == 20)
assert(idolBow.baseModList:Sum("BASE", cfg, "ChaosResist") == -20)
local direct = build.calcsTab:GetMiscCalculator()({repSlotName = "Weapon 1", repItem = idolBow}, true, {noEnvReuse = true})
assert(math.abs(direct.FullDPS - result.rows[1].values.FullDPS) < 0.00001)
local replaced = report.Calculate(build, idolBow:BuildRaw(), "Weapon 1", {["Idol of the Sycophant"] = true}, true, 1)
assert(#replaced.rows == 1, "Replacing Sycophant releases its limit")
build.itemsTab:AddItem(idolBow, true); build.itemsTab.slots["Weapon 1"]:SetSelItemId(idolBow.id)
build.buildFlag = true; runCallback("OnFrame"); runCallback("OnFrame")
local blocked = report.Calculate(build, idolBow:BuildRaw(), "Weapon 1", {["Idol of the Sycophant"] = true}, true, 2)
assert(#blocked.rows == 0 and blocked.excluded == 1, "Retaining Sycophant consumes its one-copy limit")
print("PASS: Sycophant real DPS/resistance gains, Bonded gating, direct calculation parity and replacement limits")

local sceptre = make("Rattling Sceptre", {"Idol of the Sycophant"})
for _, line in ipairs(sceptre.runeModLines) do assert(not line.extra and #line.modList > 0, line.line) end
assert(#sceptre.baseModList:List({skillTypes = {[SkillType.CreatesCompanion] = true}}, "MinionModifier") > 0)
assert(#sceptre.baseModList:List(nil, "ExtraAura") == 0, "Bonded aura must stay inactive without Bonded")
assert(#sceptre.baseModList:List(cfg, "ExtraAura") > 0)
local chest = make("Rusted Cuirass", {"Fox Idol", "Perfect Body Rune"})
assert(chest.baseModList:Flag(nil, "LocalBondedIdols"))
assert(#chest.baseModList:List(nil, "GemProperty") > 0, "Fox must enable its own Bonded quality")
assert(chest.baseModList:Sum("INC", nil, "Life") == 0, "Fox cannot enable a Rune's Bonded Life")
local withoutFox = make("Rusted Cuirass", {"Perfect Body Rune"})
assert(#withoutFox.baseModList:List(nil, "GemProperty") == 0)
local majesty = make("Rusted Cuirass", {"Fox Idol", "Carved Majesty"})
assert(majesty.baseModList:Sum("INC", nil, "Spirit") == 5, "Fox must enable another Idol in the same item")
local loneMajesty = make("Rusted Cuirass", {"Carved Majesty"})
assert(loneMajesty.baseModList:Sum("INC", nil, "Spirit") == 0, "Local Bonded must not leak through cached modifiers")
assert(not majesty.baseModList:Flag(nil, "Condition:CanUseBondedModifiers"), "Fox cannot grant global Bonded")
local companionMods, extra = modLib.parseMod("Bonded: Companions have 30% increased Area of Effect")
assert(not extra and companionMods[1].name == "MinionModifier")
assert(companionMods[1][#companionMods[1]].var == "CanUseBondedModifiers", "Bonded must gate the owner-side companion modifier")
print("PASS: Sycophant companion/aura parsing, owner-side Bonded gate and item-local Fox Idol activation")

-- Widths and tall previews exercise actual drawing/layout with mocked text
-- measurements, without interacting with the live application.
build.itemsTab:SetDisplayItem(bow)
local oldWidth = DrawStringWidth
DrawStringWidth = function(_, _, text) return #text * 9 end
local viewport = {x = 0, y = 0, width = 1200, height = 900}
build.itemsTab.displayItemTooltip:AddLine(16, string.rep("Wide item ", 16))
build.itemsTab:Draw(viewport, {})
local x = build.itemsTab.controls.displayItemTooltipAnchor:GetPos()
local width = build.itemsTab.displayItemTooltip:GetDynamicSize(viewport)
assert(build.itemsTab.controls.augmentReport:GetPos() >= x + width + 12, "Wide item overlaps recommendations")
for i = 1, 80 do build.itemsTab.displayItemTooltip:AddLine(16, "Tall item line") end
build.itemsTab:Draw(viewport, {})
x = build.itemsTab.controls.displayItemTooltipAnchor:GetPos()
width = build.itemsTab.displayItemTooltip:GetDynamicSize(viewport)
assert(build.itemsTab.controls.augmentReport:GetPos() >= x + width + 12, "Multicolumn item overlaps recommendations")
DrawStringWidth = oldWidth
print("PASS: wide and multicolumn item previews remain separate from recommendations")
