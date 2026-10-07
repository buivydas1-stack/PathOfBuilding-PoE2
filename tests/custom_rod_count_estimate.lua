arg = {}
dofile("HeadlessWrapper.lua")
local estimate = LoadModule("Modules/RodCountEstimate")
newBuild()
build.characterLevel = 90
build.skillsTab:PasteSocketGroup("Lightning Rod 20/20 1")
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1\nRapid Attacks II 1/0 1\nDominus' Grasp 1/0 1")
build.skillsTab:PasteSocketGroup("Mirage Archer 20/0 1\nLightning Arrow 10/0 1\nRapid Attacks III 1/0 1")
local bow = new("Item", "Rarity: Rare\nRod Estimate Bow\nCrude Bow\nAdds 20 to 100 Lightning Damage\n+1000 to Accuracy Rating")
build.itemsTab:AddItem(bow, true)
build.itemsTab.slots["Weapon 1"].selItemId = bow.id
local rods, player, mirage = unpack(build.skillsTab.socketGroupList)
build.mainSocketGroup = 2
rods.includeInFullDPS, player.includeInFullDPS, mirage.includeInFullDPS = true, true, true
local gem = rods.gemList[1]
local function frame()
	build.configTab:BuildModList(); build.buildFlag = true; runCallback("OnFrame")
end
local function get()
	return estimate.calculate(build, build.calcsTab.calcs, gem)
end
frame()
local initial, input = get()
assert(initial and initial > 0, "Enabled setup must offer estimate")
assert(input.cap == 10 and input.charges == 8, "Read Rod cap and activations from skill data")
assert(input.impactBursts == 1.2, "Quality applies only to impact bursts")
assert(input.player.contacts == 10, "Four beams + Dominus reach ten distinct rods")
assert(input.mirage.contacts == 9, "Mirage uses its own LA level/beam count and supports")
assert(math.abs(input.player.rate - input.mirage.rate) > 1e-5, "Nested supports affect clone speed independently")
assert(gem.count == 1 and not player.gemList[1].statSet, "Recommendation must not alter Count or selected LA part")
local fullBefore = build.calcsTab.calcs.calcFullDPS(build, "CALCULATOR").combinedDPS
get()
assert(build.calcsTab.calcs.calcFullDPS(build, "CALCULATOR").combinedDPS == fullBefore, "Viewing estimate cannot change DPS")

build.configTab.input.mirageArcherUptime = 0; frame()
local without, noClone = get()
assert(not noClone.mirage and without < initial, "Zero Mirage uptime must lower recommendation")
build.configTab.input.mirageArcherUptime = 90; mirage.enabled = false; frame()
assert(get() == without, "Disabled Mirage equals zero uptime")
mirage.enabled = true; frame()
assert(get() == initial, "Restored Mirage restores recommendation")
player.gemList[3].enabled = false; build.skillsTab:ProcessSocketGroup(player); frame()
local noDominus, noDominusInput = get()
assert(noDominusInput.player.contacts == 10 and noDominus == initial, "Dominus adds no ideal contacts past ten-rod cap")
player.gemList[1].level = 1; build.skillsTab:ProcessSocketGroup(player); frame()
local low, lowInput = get()
assert(lowInput.player.contacts == 6, "Low-level LA uses two beams and two additional chains")
player.gemList[3].enabled = true; build.skillsTab:ProcessSocketGroup(player); frame()
local more, moreInput = get()
assert(moreInput.player.contacts == 10, "Extra chains reach additional rods when base contacts are limited")
player.enabled = false; mirage.enabled = false; frame()
assert(not get(), "No enabled LA makes estimate unavailable")
player.enabled = true; rods.enabled = false; frame()
assert(not get(), "Disabled Rod group cannot offer a live estimate")
rods.enabled = true; gem.enabled = false; frame()
assert(not get(), "Disabled Rod gem cannot offer estimate")
gem.enabled = true; frame()

build.skillsTab:SetDisplayGroup(rods)
local button = build.skillsTab.controls.gemSlot1RodEstimate
assert(button:IsShown() and button:IsEnabled(), "Rod estimate button is offered")
assert(button:GetProperty("tooltipText") == estimate.tooltip, "Concise assumptions stay static")
local offered = build.skillsTab:GetRodCountEstimate(1)
local cached = build.skillsTab.rodEstimateCache
assert(build.skillsTab:GetRodCountEstimate(1) == offered and cached == build.skillsTab.rodEstimateCache, "Reuse recommendation until output changes")
button:Click()
assert(gem.count == offered and tonumber(build.skillsTab.gemSlots[1].count.buf) == offered, "Click applies offered count")
frame()
local fullAfter = build.calcsTab.calcs.calcFullDPS(build, "CALCULATOR")
local rodContribution
for _, entry in ipairs(fullAfter.skills) do if entry.name == "Lightning Rod" then rodContribution = entry end end
assert(rodContribution and rodContribution.count == offered, "Full DPS uses applied scalar")
build.skillsTab:SetDisplayGroup(player)
assert(not button:IsShown(), "Other skills retain ordinary Count UI")
print("PASS: Rod recommendation reads beams/chains, supports, rate, quality and Mirage uptime; respects disabled skills; caches and applies optional Count without modifying LA")

local model = { rodSpeed = 2.94816, cap = 10, charges = 8, projectiles = 3, duration = 20,
	impactBursts = 1.2, interval = 0.1, player = { rate = 2.54412, contacts = 10 }, mirage = { rate = 2.54412 * 0.9, contacts = 10 } }
local withClone = estimate.simulate(model)
model.mirage = nil
local solo = estimate.simulate(model)
assert(withClone > solo and withClone >= 8 and withClone <= 11, "Representative model remains in prior sustained range")
model.duration = 0.5
assert(estimate.simulate(model) < solo, "Short-lived rods expire and require replacement before charges run out")
print(string.format("Representative sustained Count: %.1f with 90%% Mirage; %.1f without", withClone, solo))
