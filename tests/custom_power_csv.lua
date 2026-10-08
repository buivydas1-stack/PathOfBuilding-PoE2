arg = { }
dofile("HeadlessWrapper.lua")
newBuild()
local tree = build.treeTab
local list = tree.controls.powerReportList
local export = tree.controls.powerReportExport
local rows = {
	{ id=1, type="Notable", action="Add", name='First, "quoted"', power=10, powerStr="^2+10.00%", pathDist=1, pathPower=10, pathPowerStr="^2+10.00%", ehpPower=3, ehpPowerStr="^x00FF00+3.00%" },
	{ id=2, type="Normal", action="Remove", name="Second\nline", allocated=true, power=-2, powerStr="^1-2.00%", pathDist=2, pathPower=-1, pathPowerStr="^1-1.00%", ehpPower=-4, ehpPowerStr="^1-4.00%" },
	{ id=3, type="Notable", action="Add", name="Ignored", power=20, powerStr="20", pathDist=1000, pathPower=20, pathPowerStr="20" },
}
list.ignoredNodes[3] = "Ignored"
for _, mode in ipairs({
	{stat="FullDPS",label="Full DPS"}, {stat="TotalEHP",label="EHP"},
	{stat="FullDPSAndEHP",label="Full DPS / EHP",combinedReport=true}, {stat="Life",label="Life"},
}) do
	for _, single in ipairs({false,true}) do
		list:SetReport(mode, rows, single)
		for filter=1,4 do
			list.controls.filterSelect:SetSel(filter)
			for _, column in ipairs({1,3,4,5}) do
				list:ReSort(column)
				local csv = list:GetCSV()
				assert(not csv:find("Ignored",1,true) and not csv:find("^",1,true))
				local pos=1
				for _, row in ipairs(list.list) do
					local name = '"'..row.name:gsub('"','""')..'"'
					local found=assert(csv:find(name,pos,true),"Missing or reordered row")
					pos=found+#name
				end
				assert(csv:sub(-2)=="\r\n")
				assert(csv:match("^[^\r]+") == table.concat({list.colList[1].label,"Node Name",list.powerColumn.label,"Points",list.colList[5].label},","))
			end
		end
	end
end
list:SetReport({stat="FullDPS",label="Full DPS"}, nil)
assert(not list.reportReady)
list:SetReport({stat="FullDPS",label="Full DPS"}, rows, true)
build.calcsTab.powerBuildFlag=false
assert(export:IsEnabled())
build.calcsTab.powerBuildFlag=true
assert(not export:IsEnabled())
build.calcsTab.powerBuildFlag=false
list.shown=false; assert(not export:IsShown())
list.shown=true; assert(export:IsShown())
for _, width in ipairs({400,640,800,1280,2560}) do
	tree:ResizePowerReport(width)
	local x,y=list:GetPos(); local ex,ey=export:GetPos()
	assert(ex==x+list.width+8 and ey+export.height==y+list.height)
	assert(ex+export.width <= x+width-10)
	local ix= list.controls.ignored:GetPos()
	assert(ix>=x, "Report filters escaped the viewport")
end
-- Exercise saving, extension, cancellation, overwrite confirmation and errors through the actual popup.
local opened, message, confirm, closed
main.OpenPopup=function(_,_,_,_,controls) opened=controls end
main.OpenMessagePopup=function(_,_,msg) message=msg end
main.OpenConfirmPopup=function(_,_,_,_,callback) confirm=callback end
main.ClosePopup=function() closed=true end
local originalOpen=io.open
local content, writtenPath, exists, fail, closeFail
io.open=function(path,mode)
	if mode=="rb" then return exists and {close=function() end} or nil end
	assert(mode=="wb")
	writtenPath=path
	if fail then return nil,"denied" end
	return {write=function(_,value) content=value; return true end, close=function() if closeFail then return nil,"disk full" end; return true end}
end
tree:ExportPowerReport()
opened.path:SetText("report")
opened.save.onClick()
assert(writtenPath=="report.csv" and content==list:GetCSV() and closed and message:find("Saved CSV",1,true))
exists=true; content=nil; closed=false; confirm=nil
tree:ExportPowerReport(); opened.path:SetText("other.CSV"); opened.save.onClick()
assert(confirm and not content and not closed)
confirm(); assert(writtenPath=="other.CSV" and content)
exists=false; fail=true; closed=false
tree:ExportPowerReport(); opened.save.onClick()
assert(not closed and message:find("denied",1,true))
fail=false; closeFail=true
opened.save.onClick(); assert(not closed and message:find("disk full",1,true))
io.open=originalOpen
print("PASS: CSV modes, filters, sort order, ignored nodes, escaping, resizing, save and error handling")
