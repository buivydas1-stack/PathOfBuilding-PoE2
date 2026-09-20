-- Exercise real skill activation, quality, damage and buildup calculations.
if not build then arg={};dofile("HeadlessWrapper.lua") end
newBuild()
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
build.skillsTab:PasteSocketGroup("Electrocuting Arrow 20/20 1")
local arrow=build.skillsTab.socketGroupList[2]
local bow=new("Item","Rarity: Rare\nTest Bow\nCrude Bow\nAdds 10 to 100 Lightning Damage")
build.itemsTab:AddItem(bow,true);build.itemsTab.slots["Weapon 1"].selItemId=bow.id
build.mainSocketGroup=1
build.skillsTab.socketGroupList[1].includeInFullDPS=true
local function calc(applied,quality,enabled)
 build.mainSocketGroup=1
 build.configTab.input.electrocutingArrowApplied=applied
 arrow.gemList[1].quality=quality;arrow.enabled=enabled
 build.configTab:BuildModList();build.buildFlag=true;runCallback("OnFrame")
 local env=build.calcsTab.mainEnv;local s=env.player.mainSkill
 return build.calcsTab.mainOutput,s.skillModList:Sum("BASE",s.skillCfg,"DamageGainAsLightning"),env
end
local off,gain=calc(false,20,true)
assert(gain==0 and off.ElectrocuteBuildupAvg==0,"Rod off must give neither effect")
for _,pair in ipairs({{0,0},{10,5},{20,10},{23,11},{28,14}})do
 local on,g=calc(true,pair[1],true)
 assert(g==pair[2],"Quality gain mismatch: "..pair[1].." / "..g)
 assert(on.ElectrocuteBuildupAvg>0,"Rod must enable buildup even at zero quality")
 if pair[1]>0 then assert(on.FullDPS>off.FullDPS,"Gain must increase Full DPS")end
end
local on,g,env=calc(true,20,true)
assert(env.skillsUsed["Electrocuting Arrow"],"Active skill visibility")
local base=on.ElectrocuteBuildupAvg
local calculator,baseline=build.calcsTab:GetMiscCalculator()
local node
for _,n in pairs(build.spec.nodes)do if n.dn=="Emboldened Avatar"then node=n;break end end
assert(node)
local changed=calculator({addNodes={[node]=true}},true,{noEnvReuse=true})
assert(changed.ElectrocuteBuildupAvg>baseline.ElectrocuteBuildupAvg,"Passive comparison must show buildup gain")
arrow.includeInFullDPS=true
local included=calc(true,20,true)
assert(math.abs(included.ElectrocuteBuildupAvg-base)<1e-8,"Include in Full DPS must not control rod")
local disabled,dg,de=calc(true,20,false)
assert(dg==0 and disabled.ElectrocuteBuildupAvg==0,"Inactive gem group must ignore stored checkbox")
assert(not de.skillsUsed["Electrocuting Arrow"],"Inactive skill must hide option")
arrow.enabled=true;arrow.gemList[1].enabled=false
local inactive,ig,ie=calc(true,20,true)
assert(ig==0 and inactive.ElectrocuteBuildupAvg==0 and not ie.skillsUsed["Electrocuting Arrow"],"Inactive gem must disable rod")
print("PASS: rod condition, quality 0/10/20/23/28, Full DPS, passive buildup, and inactive skill")
-- Compare the gem effect against the existing generic gain-as-extra calculation.
arrow.gemList[1].enabled=true;arrow.includeInFullDPS=false
local rod=calc(true,20,true)
build.configTab.input.customMods="Gain 10% of Damage as Extra Lightning Damage"
local equivalent=calc(false,20,true)
assert(math.abs(rod.FullDPS-equivalent.FullDPS)<1e-7,"Rod gain must use generic gain-as-extra semantics")
build.configTab.input.customMods=nil
local unmarked=calc(true,20,true).ElectrocuteBuildupAvg
build.skillsTab:PasteSocketGroup("Voltaic Mark 20/0 1")
local marked=calc(true,20,true).ElectrocuteBuildupAvg
assert(marked>unmarked,"Voltaic Mark must increase rod-enabled buildup")
build.itemsTab.activeItemSet["Weapon 1"].selItemId=bow.id
local saved=build:SaveDB("rod-test")
loadBuildFromXML(saved,"rod-test");runCallback("OnFrame")
assert(build.configTab.input.electrocutingArrowApplied and build.calcsTab.mainEnv.player.modDB:Flag(nil,"LightningCanElectrocute"),"Saved checkbox must survive reload")
print("PASS: generic gain equivalence, Voltaic Mark and saved condition")





