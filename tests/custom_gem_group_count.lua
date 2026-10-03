-- Skill-slot warnings must follow current group/gem Enabled states.
arg={}; dofile('HeadlessWrapper.lua'); newBuild()
for i=1,8 do build.skillsTab:PasteSocketGroup('Lightning Arrow 20/0 1') end
build.skillsTab:PasteSocketGroup('Mirage Archer 20/0 1\nLightning Arrow 20/0 1')
local mirage=build.skillsTab.socketGroupList[9]
local function check(count)
 build.buildFlag=true; runCallback('OnFrame')
 assert(GlobalGemAssignments.GemGroupCount==count,'Current skill count: '..tostring(GlobalGemAssignments.GemGroupCount)..' ~= '..count)
 local warnings=build.calcsTab.mainEnv.itemWarnings.gemGroupCountWarning
 assert((warnings~=nil)==(count>9),'Slot warning must match current enabled groups')
 if warnings then assert(warnings[1][1]==9 and warnings[1][2]==count) end
end
check(9)
assert(#mirage.gemList==2,'Meta skill and socketed attack must remain in the same group')
build.skillsTab:PasteSocketGroup('Trinity 16/20 1')
local trinity=build.skillsTab.socketGroupList[10]
check(10)
build.skillsTab:SetDisplayGroup(trinity)
build.skillsTab.controls.groupEnabled.changeFunc(false)
check(9)
build.skillsTab.controls.groupEnabled.changeFunc(true)
check(10)
build.skillsTab.gemSlots[1].enabled.changeFunc(false)
check(9)
build.skillsTab.gemSlots[1].enabled.changeFunc(true)
check(10)
table.remove(build.skillsTab.socketGroupList,10)
check(9)
print('PASS: Mirage Archer counts once; group/gem disable, re-enable and removal refresh skill-slot warnings')
