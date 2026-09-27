arg = {}
dofile("HeadlessWrapper.lua")
newBuild()

local raw = table.concat({
	"Item Class: Jewels", "Rarity: Rare", "Loath Eye", "Emerald",
	"--------", "Quality (Attack Modifiers): +10% (augmented)",
	"--------", "Item Level: 81", "--------",
	"13% increased Critical Damage Bonus for Attack Damage",
	"14% increased Attack Damage", "17% increased Damage with Bows",
	"22% increased Elemental Damage", "51% increased Effect of Prefixes",
}, "\n")

local item = new("Item", raw)
assert(item.base, "Jewel should be recognized")
assert(not item.crafted and #item.explicitModLines == 5, "Ordinary item text must retain all five already-scaled modifiers")

local advanced = table.concat({
	"Item Class: Jewels", "Rarity: Rare", "Loath Eye", "Emerald",
	"--------", "Quality (Attack Modifiers): +10% (augmented)",
	"--------", "Item Level: 81", "--------",
	'{ Prefix Modifier "Perforating" (Tier: 1) — Damage, Attack — 61% Increased }', "11(6-16)% increased Damage with Bows",
	'{ Prefix Modifier "Combat" (Tier: 1) — Damage, Attack — 61% Increased }', "9(5-15)% increased Attack Damage",
	'{ Desecrated Prefix Modifier "Prismatic" (Tier: 1) — Damage, Elemental, Fire, Cold, Lightning — 51% Increased }', "15(5-15)% increased Elemental Damage",
	'{ Suffix Modifier "of Demolishing" (Tier: 1) — Damage, Attack, Critical — 10% Increased }', "12(10-20)% increased Critical Damage Bonus for Attack Damage",
	'{ Crafted Suffix Modifier "" }', "51(40-60)% increased Effect of Prefixes — Unscalable Value",
	"--------", "Place into an allocated Jewel Socket on the Passive Skill Tree. Right click to remove from the Socket.",
}, "\n")
local adv = new("Item", advanced)
assert(adv.crafted and adv.affixLimit == 5, "Desecrated jewel must expose all five affixes")
assert(#adv.prefixes == 3 and #adv.suffixes == 2, "Advanced copy must retain the third prefix and crafted suffix")
assert(adv.suffixes[2].modId == "CraftedJewelPrefixEffect", "Empty-name crafted suffix must resolve to prefix effect")
assert(adv.prefixes[3].desecrated and adv.suffixes[2].crafted and adv.suffixes[2].unscalable, "Imported affix flags must survive")
local beforeCraft = adv:BuildRaw()
assert(beforeCraft:find("{desecrated}JewelElementalDamage", 1, true) and beforeCraft:find("{crafted}{unscalable}CraftedJewelPrefixEffect", 1, true), "Saved item must retain affix flags")
build.itemsTab:CreateDisplayItemFromRaw(advanced, true)
local pasted = build.itemsTab.displayItem
assert(pasted and pasted.affixLimit == 5 and pasted.suffixes[2].modId == "CraftedJewelPrefixEffect", "Items tab paste must retain all affixes")
assert(pasted.prefixes[3].desecrated, "Items tab paste must retain the desecrated prefix")
local thirdPrefix = build.itemsTab.controls.displayItemAffix3
local craftedSuffix = build.itemsTab.controls.displayItemAffix5
assert(thirdPrefix.list[thirdPrefix.selIndex].modId == "JewelElementalDamage", "Editor must select the desecrated third prefix")
assert(craftedSuffix.list[craftedSuffix.selIndex].modId == "CraftedJewelPrefixEffect", "Editor must select the crafted effect suffix")
adv:Craft()
local expected = {
	["13% increased Critical Damage Bonus for Attack Damage"] = true,
	["14% increased Attack Damage"] = true,
	["17% increased Damage with Bows"] = true,
	["22% increased Elemental Damage"] = true,
	["51% increased Effect of Prefixes"] = true,
}
for _, modLine in ipairs(adv.explicitModLines) do
	assert(expected[modLine.line], "Unexpected crafted line: " .. modLine.line)
	expected[modLine.line] = nil
end
assert(next(expected) == nil, "Crafted values must match the in-game tooltip")
local pastedValues = {}
for _, modLine in ipairs(pasted.explicitModLines) do
	pastedValues[modLine.line] = true
end
for _, modLine in ipairs(adv.explicitModLines) do
	assert(pastedValues[modLine.line], "Items tab must display the in-game value: " .. modLine.line)
end
assert(adv.prefixes[3].desecrated and adv.suffixes[2].crafted, "Flags must survive displayed-value reconstruction")
local restored = new("Item", adv:BuildRaw())
assert(restored.affixLimit == 5 and restored.suffixes[2].modId == "CraftedJewelPrefixEffect", "Saved advanced jewel must retain all affixes")
assert(restored.explicitModLines[4].desecrated or restored.explicitModLines[3].desecrated, "Desecrated display flag must survive save and load")
restored:Craft()
assert(restored.affixLimit == 5 and #restored.suffixes == 2, "Recrafting must not duplicate the effect affix")
print("PASS: pasted desecrated jewel retains five affixes and matches in-game modifier values")
