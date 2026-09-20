arg={};dofile("HeadlessWrapper.lua")
newBuild()
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
local bow=new("Item","Rarity: Rare\nTest Bow\nCrude Bow\nAdds 10 to 100 Lightning Damage")
build.itemsTab:AddItem(bow,true);build.itemsTab.slots["Weapon 1"].selItemId=bow.id
local function calc(chance)
 build.configTab.input.customMods="Bow Attacks fire an additional Arrow\n+"..chance.."% Surpassing chance to fire an additional Arrow"
 build.configTab:BuildModList();build.buildFlag=true;runCallback("OnFrame")
 local out={};for k,v in pairs(build.calcsTab.mainOutput)do if type(v)=="number" then out[k]=v end end;return out
end
local before=calc(0)
local after=calc(50)
assert(before.ProjectileCount==2 and after.ProjectileCount==2.5)
assert(after.SurpassingProjectileChance==50)
assert(before.TotalDPS==after.TotalDPS,"Display must not multiply hit DPS by projectile count")
local tip={lines={},AddLine=function(self,_,line)table.insert(self.lines,line)end}
build:CompareStatList(tip,build.displayStats,build.calcsTab.mainEnv.player,before,after,"Item swap")
local text=table.concat(tip.lines,"\n")
assert(text:find("+0.50 Average Projectile Count (2 > 2.5)",1,true),text)
assert(text:find("+50.00% Surpassing Projectile Chance (0% > 50%)",1,true),text)
local above=calc(150)
assert(above.ProjectileCount==3.5 and above.SurpassingProjectileChance==150)
print("PASS: fractional count, surpassing totals above 100, comparison endpoints and unchanged hit DPS")

