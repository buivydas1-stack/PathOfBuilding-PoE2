arg={};dofile("HeadlessWrapper.lua")
newBuild()
build.skillsTab:PasteSocketGroup("Spark 20/0 1\nLightning Exposure 1/0 1")
build.configTab.input.conditionEnemyLightningExposure=true
build.configTab.input.enemyIsBoss="Pinnacle"
build.configTab:BuildModList();build.buildFlag=true;runCallback("OnFrame")
local env=build.calcsTab.calcs.buildOutput(build,"CALCS")
build.calcsTab.calcsEnv=env
local display=new("CalcBreakdownControl",build.calcsTab)
display.sectionList={}
display:AddModSection({modName={"LightningResist","ElementalResist"},enemy=true,cfg="skill"})
local exposure,base
for _,row in ipairs(display.sectionList[1].rowList)do
 if row.mod.displaySourceName then exposure=row end
 if row.mod.source=="EnemyConfig" then base=row end
end
assert(exposure and exposure.mod.value==-10)
assert(exposure.source=="Configuration" and exposure.sourceName=="Lightning Exposure (Configuration)")
local lines={};exposure.sourceNameTooltip({AddLine=function(_,_,s)table.insert(lines,s)end})
assert(lines[1]:find("20%% base") and lines[1]:find("50%% enemy effectiveness") and lines[1]:find("10%% reduction"))
assert(base and base.source=="Enemy settings" and base.sourceName:find("preset or override",1,true))
assert(exposure.mod.source=="Config","Internal source identity must remain unchanged")
print("PASS: displayed source names, Exposure formula, unchanged -10 modifier and internal source")
