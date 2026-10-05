arg = {}
dofile("HeadlessWrapper.lua")
newBuild()
local raw = [[Item Class: Jewels
Rarity: Rare
Oblivion Ornament
Emerald
--------
Item Level: 79
--------
14% increased Critical Damage Bonus for Attack Damage
22% increased Attack Damage
19% increased Damage with Bows
16% increased Elemental Damage (desecrated)
50% increased Effect of Prefixes (crafted)
--------
Place into an allocated Jewel Socket on the Passive Skill Tree. Right click to remove from the Socket.
--------
Note: ~b/o 135 divine]]
local function values(item)
	local lines = {}
	for _, line in ipairs(item.explicitModLines) do lines[#lines + 1] = line.line end
	table.sort(lines)
	return table.concat(lines, "\n")
end
local item = new("Item", raw)
assert(item.crafted and item.affixLimit == 5 and #item.prefixes == 3 and #item.suffixes == 2, "Market jewel must recover all five affixes")
assert(item.prefixes[3].desecrated and item.suffixes[2].crafted, "Market affix flags must survive")
local before = values(item)
item:Craft()
assert(values(item) == before, "First editor rebuild must preserve every printed value")
local roundTrip = new("Item", item:BuildRaw())
roundTrip:Craft()
assert(values(roundTrip) == before, "Saved item round trip must preserve values")
build.itemsTab:CreateDisplayItemFromRaw(raw, true)
local displayed = build.itemsTab.displayItem
assert(values(displayed) == before, "Pasting into editor must preserve values")
for index = 1, 5 do
	assert(build.itemsTab.controls["displayItemAffixRange" .. index]:IsShown(), "All market affix sliders must appear")
end
displayed.prefixes[1].range = 0
displayed:Craft()
assert(values(displayed) ~= before, "Editing a recovered roll must change the item")
assert(not new("Item", raw:gsub("22%% increased Attack Damage", "99%% increased Attack Damage")).crafted, "Impossible roll must not be guessed")
assert(not new("Item", raw:gsub("16%% increased Elemental Damage %(desecrated%)", "16% unknown modifier")).crafted, "Unknown modifier must keep the original item")
assert(not new("Item", raw:gsub("Emerald", "Ruby")).crafted, "Ineligible base must not infer bow affix")
print("PASS: market jewel sliders, exact rolls, prefix effects, flags, round trips and conservative fallback")
