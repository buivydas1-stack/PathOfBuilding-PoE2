-- Real item-editor conversion, calculation and persistence checks.
arg = {}; dofile("HeadlessWrapper.lua"); newBuild()
local original = new("Item", table.concat({
 "Rarity: Rare", "Corpse Cowl", "Grinning Mask", "Quality: 20", "Item Level: 82",
 "Sockets: S", "Rune: Greater Iron Rune", "Implicits: 1",
 "{rune}18% increased Armour, Evasion and Energy Shield",
 "130% increased Evasion and Energy Shield", "+30 to maximum Mana",
 "35% increased Rarity of Items found", "+25% to Chaos Resistance",
 "{desecrated}+24% to Chaos Resistance",
}, "\n"))
original:BuildModList()
local before = original:BuildRaw()
local forged = assert(original:Runeforge())
assert(original:BuildRaw() == before, "Preview mutated the original item")
assert(forged.baseName == "Runeforged Grinning Mask" and forged.title == original.title)
assert(forged.armourData.Evasion == 232 and forged.armourData.EnergyShield == 71 and forged.armourData.Ward == 305, "Base, quality and local augment defence scaling: " .. forged:BuildRaw())
assert(forged.quality == 20 and forged.itemLevel == 82 and forged.itemSocketCount == 1)
assert(forged.runes[1] == original.runes[1] and #forged.explicitModLines == #original.explicitModLines)
assert(forged.explicitModLines[5].desecrated, "Desecrated marker lost")
for i,line in ipairs(original.explicitModLines) do assert(forged.explicitModLines[i].line == line.line, "Affix changed") end
local restored = new("Item", forged:BuildRaw()); restored:BuildModList()
assert(restored.runicItem and restored.armourData.Ward == 305 and restored.armourData.Evasion == 232)
assert(not restored:Runeforge(), "Double conversion allowed")
for _,flag in ipairs({"corrupted", "mirrored", "sanctified"}) do
 original[flag] = true; assert(not original:Runeforge(), "Ineligible item converted: " .. flag); original[flag] = false
end
local goldrim = new("Item", "Rarity: Unique\nGoldrim\nFelt Cap\nQuality: 20\nImplicits: 0\n+30% to all Elemental Resistances")
assert(assert(goldrim:Runeforge()).baseName == "Runemastered Felt Cap", "Unique recipe must use its own base")
local random = new("Item", "Rarity: Unique\nEyes of the Runefather\nVenerable Defender\nQuality: 20\nImplicits: 0")
assert(not random:Runeforge(), "Conflicting unique base variants must be rejected")
local highBow = new("Item", "Rarity: Rare\nTest\nWarmonger Bow\nQuality: 20\nImplicits: 0")
assert(not highBow:Runeforge(), "Non-recipe item converted")
local magic = new("Item", "Rarity: Magic\nGrinning Mask of the Storm\nQuality: 20\nImplicits: 0\n+25% to Lightning Resistance")
local magicForged = assert(magic:Runeforge())
assert(magicForged.baseName == "Runeforged Grinning Mask" and magicForged.nameSuffix == magic.nameSuffix)
build.itemsTab:AddItem(original, true)
build.itemsTab.slots.Helmet.selItemId = original.id
build.itemsTab:SetDisplayItem(new("Item", original:BuildRaw()))
build.itemsTab.displayItem.id = original.id
local button = build.itemsTab.controls.displayItemRuneforge
assert(button:IsShown() and button:IsEnabled())
button.tooltipFunc(button.tooltip)
button:Click()
assert(not button:IsEnabled())
button.tooltipFunc(button.tooltip)
assert(build.itemsTab.displayItem.baseName == "Runeforged Grinning Mask")
assert(build.itemsTab.items[original.id].baseName == "Grinning Mask", "Preview applied before Save")
build.itemsTab:AddDisplayItem(true)
assert(build.itemsTab.items[original.id].baseName == "Runeforged Grinning Mask")
build.buildFlag = true; runCallback("OnFrame")
assert(build.calcsTab.mainOutput.Ward > 0, "Equipped conversion did not reach character calculations")
print("PASS: Runeforge preview, item preservation, 232/71/305 defences, persistence, eligibility, unique recipes, editor button and equipped calculations")
