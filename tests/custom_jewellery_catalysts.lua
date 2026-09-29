arg = {}
dofile("HeadlessWrapper.lua")
newBuild()

local raw = table.concat({
	"Item Class: Rings", "Rarity: Rare", "Storm Knuckle", "Topaz Ring",
	"--------", "Requires: Level 65", "--------", "Item Level: 82",
	"--------", "+27% to Lightning Resistance (implicit)", "--------",
	"Adds 1 to 41 Lightning damage to Attacks", "+81 to maximum Mana",
	"10% increased Rarity of Items found", "+31 to Strength",
	"+37% to Fire Resistance", "+45% to Cold Resistance",
	"--------", "Note: ~b/o 3 divine",
}, "\n")

build.itemsTab:CreateDisplayItemFromRaw(raw, true)
local tab = build.itemsTab
local item = tab.displayItem
local catalyst = tab.controls.displayItemCatalyst
assert(item and item.base and item.base.type == "Ring", "Pasted Topaz Ring must import")
assert(catalyst:IsShown() and catalyst.selIndex == 1, "Uncatalyzed ring must show Add Catalyst")
local originalRaw = item:BuildRaw()
local tooltip = new("Tooltip")
catalyst.tooltipFunc(tooltip, "HOVER", 8, catalyst.list[8])
assert(item:BuildRaw() == originalRaw, "Hover preview must not edit the pasted item")
assert(#tooltip.lines > 1, "Catalyst hover must show calculated stat changes")
catalyst.tooltipFunc(tooltip, "HOVER", 3, catalyst.list[3])
assert(tab.catalystPreview.after.Mana > tab.catalystPreview.before.Mana, "Mana catalyst hover must preview a mana gain")
assert(item:BuildRaw() == originalRaw, "Switching hovered catalyst must remain non-destructive")

catalyst:SetSel(3)
assert(item.explicitModLines[2].valueScalar == 1.2 and item.implicitModLines[1].valueScalar == 1, "Neural catalyst must scale only mana")
catalyst:SetSel(13)
assert(item.explicitModLines[4].valueScalar == 1.2 and item.explicitModLines[2].valueScalar == 1, "Adaptive catalyst must scale only attribute")

catalyst:SetSel(8)
assert(item.catalyst == 7 and item.catalystQuality == 20, "Esh's must set lightning quality to 20%")
assert(tab.controls.displayItemCatalystQualitySlider:IsShown(), "Ring quality slider must appear")
assert(tab.controls.displayItemCatalystQualitySlider.maxQuality == 40, "Ordinary jewellery editor must allow 40%")
assert(item.implicitModLines[1].valueScalar == 1.2 and item.explicitModLines[1].valueScalar == 1.2, "Lightning lines must scale")
assert(item.explicitModLines[2].valueScalar == 1 and item.explicitModLines[3].valueScalar == 1, "Other lines must not scale")
assert(itemLib.formatModLine(item.implicitModLines[1]):find("+32%% to Lightning Resistance"), "Tooltip must show scaled implicit")
assert(itemLib.formatModLine(item.explicitModLines[1]):find("1 to 49 Lightning damage", 1, true), "Tooltip must show scaled attack damage")

local slider = tab.controls.displayItemCatalystQualitySlider
slider:SetVal(1)
assert(item.catalystQuality == 40 and item.implicitModLines[1].valueScalar == 1.4, "Slider must apply 40%")
assert(tonumber(tab.controls.displayItemCatalystQualityEdit.buf) == 40, "Numeric quality field must follow slider")
tab.controls.displayItemCatalystQualityEdit.changeFunc("25")
assert(item.catalystQuality == 25 and slider.val == 25 / 40, "Numeric quality field must update slider and item")

local restored = new("Item", item:BuildRaw())
assert(restored.catalyst == 7 and restored.catalystQuality == 25, "Catalyst and quality must survive item save/load")
assert(restored.explicitModLines[1].valueScalar == 1.25, "Inferred tags must survive item save/load")
tab:SetDisplayItem(restored)
assert(restored.catalystQuality == 25, "Opening an existing catalyzed item must retain its quality")
assert(tab.controls.displayItemCatalystQualitySlider.val == 25 / 40, "Editor must show saved quality")

restored.catalystQuality = 45
restored:BuildAndParseRaw()
tab:SetDisplayItem(restored)
assert(tab.controls.displayItemCatalystQualitySlider.maxQuality == 45, "Higher imported quality must not be reduced")
catalyst:SetSel(1)
assert(not restored.catalyst or restored.catalyst == 0, "Removing catalyst must clear the selection")
assert(restored.catalystQuality == nil and not tab.controls.displayItemCatalystQualitySlider:IsShown(), "Removing catalyst must hide quality controls")
tab:CreateDisplayItemFromRaw("Item Class: Amulets\nRarity: Rare\nTest Charm\nGold Amulet\n--------\nItem Level: 82\n--------\n+20 to maximum Mana", true)
assert(tab.displayItem.base and tab.displayItem.base.type == "Amulet" and catalyst:IsShown(), "Uncatalyzed amulet must offer catalyst selector")
print("PASS: pasted ring catalyst preview, scaling, quality editing, removal and save/load")
