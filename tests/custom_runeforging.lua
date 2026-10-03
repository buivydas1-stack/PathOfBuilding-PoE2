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
assert(button:IsEnabled() and button:GetProperty("label") == "Undo Runeforge")
button.tooltipFunc(button.tooltip)
assert(build.itemsTab.displayItem.baseName == "Runeforged Grinning Mask")
assert(build.itemsTab.items[original.id].baseName == "Grinning Mask", "Preview applied before Save")
button:Click()
assert(build.itemsTab.displayItem:BuildRaw() == before, "Same-button undo did not restore the original item exactly")
assert(button:GetProperty("label") == "Runeforge" and button:IsEnabled())
button:Click()
build.itemsTab:AddDisplayItem(true)
assert(build.itemsTab.items[original.id].baseName == "Runeforged Grinning Mask")
build.buildFlag = true; runCallback("OnFrame")
assert(build.calcsTab.mainOutput.Ward > 0, "Equipped conversion did not reach character calculations")
local reopened = new("Item", build.itemsTab.items[original.id]:BuildRaw())
reopened.id = original.id
build.itemsTab:SetDisplayItem(reopened)
assert(button:IsEnabled(), "Saved/reopened Runeforged item cannot be reversed")
button:Click()
assert(build.itemsTab.displayItem:BuildRaw() == before)
build.itemsTab:AddDisplayItem(true)
build.buildFlag = true; runCallback("OnFrame")
assert(build.calcsTab.mainOutput.Ward == 0, "Reversal left Runic Ward in character calculations")
local uniqueForged = assert(goldrim:Runeforge())
assert(assert(uniqueForged:Runeforge(true)).baseName == goldrim.baseName, "Unique reverse recipe failed")
assert(assert(magicForged:Runeforge(true)).name == magic.name, "Magic name changed during reversal")
assert(not random:Runeforge(true), "Non-Runeforged item reversed")
print("PASS: Runeforge toggle, exact undo, save/reopen reversal, magic and unique reversal, 232/71/305 defences, eligibility and equipped calculations")
