local shared = LoadModule("Modules/AugmentReport")
local report = LoadModule("Modules/SupportReport")
local gemTooltip = LoadModule("Classes/GemTooltip")
local json = require("dkjson")
local ReportClass = newClass("SupportReportControl", "AugmentReportControl", function(self, anchor, rect, skillsTab)
	self.AugmentReportControl(anchor, rect, { build = skillsTab.build })
	self.skillsTab = skillsTab
	self.colList = {
		{ width = 340, label = "Support", sortable = true },
		{ width = 125, label = "Change", sortable = true, textHeight = 17 },
		{ width = 115, label = "Change %", sortable = true, textHeight = 17 },
		{ width = 160, label = "Result", sortable = true, textHeight = 17 },
	}
	self.controls.title.y, self.controls.title.label = -126, "^7Support recommendations"
	self.controls.existing.x, self.controls.existing.y = 230, -102
	self.controls.existing.label, self.controls.existing.state = "Consider existing supports", true
	self.controls.existing.labelWidth = DrawStringWidth(12, "VAR", self.controls.existing.label) + 5
	self.controls.existing.tooltipText = "Checked: replace the selected support or add one to an empty slot, retaining the other supports. Changes compare against the current setup.\nUnchecked: compare one candidate against this group without its other supports.\nOther socket groups and configured Count/uptime values are retained."
	self.controls.existing.changeFunc = function() self:Update() end
	self.controls.socket.x, self.controls.socket.y, self.controls.socket.width = 266, -102, 494
	self.controls.socket.selFunc = function() self:Update() end
	self.controls.socket.tooltipText = "Support to replace. Candidates are enabled and use the existing default gem level/quality options. Other gems retain their current settings."
	self.controls.targetLabel = new("LabelControl", {"TOPLEFT", self, "TOPLEFT"}, {0, -74, 0, 16}, "^7Skill:")
	self.controls.target = new("DropDownControl", {"TOPLEFT", self, "TOPLEFT"}, {45, -78, 715, 20}, { }, function() self:Update() end)
	self.controls.target.enabled = function() return #self.controls.target.list > 1 end
	self.controls.stat:SetList(report.GetStats())
	self.controls.stat:SelByValue("FullDPS", "stat")
	self.stat = self.controls.stat:GetSelValue()
	self.controls.stat.selFunc = function(_, stat) self.stat = stat; self.sortColumn, self.descending = 2, true; self:Refresh() end
	self.controls.stat.tooltipText = "Full DPS uses all currently included skills and their configured components, Count and uptime. Other metrics describe the selected skill/component. Lower mana cost is a gain."
	self.controls.filter:SetList({ "All changes", "Gains only", "Losses only", "Unchanged" })
	self.controls.filter.selFunc = function() self:Refresh() end
	self.controls.search.width = 363
	self.controls.search.changeFunc = function() self:Refresh() end
	self.controls.calculate.label = "Calculate support recommendations"
	self.controls.calculate.onClick = function() self:Calculate() end
	self.controls.calculate.enabled = function() return self.key and not self.worker and not self.skillsTab.build.buildFlag end
	self.controls.cancel = new("ButtonControl", {"TOPLEFT", self, "BOTTOMLEFT"}, {278, 4, 80, 20}, "Cancel", function()
		self:Cancel(); self.result, self.failed = nil, nil; self:Refresh()
	end)
	self.controls.cancel.enabled = function() return self.worker ~= nil end
	self.shown = function() return self.skillsTab.displayGroup and not self.skillsTab.displayGroup.source end
	self:Refresh()
end)

function ReportClass:UpdateSelectors(group)
	local selected = self.controls.target:GetSelValue()
	local targets = report.GetTargets(group)
	local preferred
	if self.group == group then preferred = selected and selected.key else
		for _, target in ipairs(targets) do
			local gem = group.gemList[target.gemIndex]
			if target.skillIndex == (group.mainActiveSkill or 1) and target.statSetIndex == (gem.statSet and gem.statSet[target.effectId] or 1) then preferred = target.key; break end
		end
	end
	self.controls.target:SetList(targets)
	self.controls.target.selIndex = 1
	if preferred then self.controls.target:SelByValue(preferred, "key") end
	local slots, supportCount = { }, 0
	local oldSlot = self.group == group and self.controls.socket:GetSelValue()
	for index, gem in ipairs(group and group.gemList or { }) do
		if gem.gemData and gem.gemData.grantedEffect.support then
			table.insert(slots, { label = "Replace: " .. gem.nameSpec .. (gem.enabled and "" or " (disabled)"), index = index })
			if gem.enabled then supportCount = supportCount + 1 end
		end
	end
	if supportCount < 5 then table.insert(slots, { label = "Add to empty slot", index = #group.gemList + 1 }) end
	self.controls.socket:SetList(slots)
	self.controls.socket.selIndex = 1
	if oldSlot then self.controls.socket:SelByValue(oldSlot.index, "index") end
	self.group, self.selectorRevision = group, self.skillsTab.build.outputRevision
end

function ReportClass:Update()
	local tab, build = self.skillsTab, self.skillsTab.build
	local group = tab.displayGroup
	if group and (self.group ~= group or self.selectorRevision ~= build.outputRevision) then self:UpdateSelectors(group) end
	local target, slot = self.controls.target:GetSelValue(), self.controls.socket:GetSelValue()
	local groupIndex
	for index, other in ipairs(tab.socketGroupList) do if other == group then groupIndex = index; break end end
	local options = groupIndex and target and { groupIndex = groupIndex, target = target,
		considerExisting = self.controls.existing.state, slotIndex = slot and slot.index }
	local available = options and group.enabled and group.slotEnabled ~= false and not group.source and not group.noSupports and
		group.gemList[target.gemIndex].enabled and (not options.considerExisting or slot)
	local key = available and (build.outputRevision .. "\n" .. json.encode(options) .. "\n" .. tab.defaultGemLevel .. "\n" ..
		tostring(tab.defaultGemQuality or 0) .. "\n" .. tab.showSupportGemTypes .. "\n" .. tostring(tab.showLegacyGems)) or nil
	self.options = options
	if key ~= self.key or self.revisionGroup ~= group then
		self:Cancel(); self.key, self.result, self.failed, self.revisionGroup = key, nil, nil, group; self:Refresh()
	end
end

function ReportClass:Calculate()
	self:Update()
	if not self.key or self.worker or self.skillsTab.build.buildFlag then return end
	self.result, self.failed = nil, nil
	local xml = self.skillsTab.build:SaveDB("support comparison")
	if not xml then self:Fail("Could not read the current build."); return end
	local script = [[
		local root, xml, options = ...
		local ok, result = pcall(function()
			return assert(loadfile(root .. "/Modules/AugmentReportWorker.lua"))(root, xml, nil, nil, nil, nil, nil, "support", options)
		end)
		if ok then return result else return nil, tostring(result) end
	]]
	self:StartWorker(script, xml, json.encode(self.options))
	self:Refresh()
end

function ReportClass:Fail(err)
	self.AugmentReportControl.Fail(self, err)
	self:Refresh()
end

function ReportClass:Refresh()
	self.tooltip:Clear()
	if not self.failed then self.controls.calculate.tooltipText = nil end
	self.list = { }; self.selIndex, self.selValue = nil, nil
	if self.result then
		local search = (self.controls.search.buf or ""):lower()
		local filter = self.controls.filter.selIndex
		for _, row in ipairs(self.result.rows) do
			local delta, benefit, percent, value = shared.Compare(self.result.baseline, row.values, self.stat)
			local unchanged = benefit and math.abs(benefit) < 0.000001
			if (search == "" or (row.name .. " " .. table.concat(row.lines, " ")):lower():find(search, 1, true)) and
				(filter == 1 or filter == 2 and benefit and benefit > 0.000001 or filter == 3 and benefit and benefit < -0.000001 or filter == 4 and unchanged) then
				table.insert(self.list, { row = row, delta = delta, benefit = benefit, percent = percent, value = value })
			end
		end
		self.status = (self.result.considerExisting and "Baseline: current supports" or "Baseline: no supports in this group") .. " | " .. #self.list .. " / " .. #self.result.rows
		if self.result.excluded > 0 then self.status = self.status .. " | " .. self.result.excluded .. " conflicting" end
	else
		self.status = self.failed and "Comparison unavailable (hover Calculate for reason)" or self.worker and "Calculating in background..." or
			self.key and "Click Calculate to compare compatible supports" or "Select an enabled skill with an available support slot"
	end
	self.label = "^7" .. self.status
	self:Sort()
	self.controls.scrollBarV:SetContentDimension(#self.list * self.rowHeight, self:GetRowRegion().height)
end

function ReportClass:AddValueTooltip(tooltip, _, entry)
	if tooltip:CheckForUpdate(entry, main:IsComparisonRevealHeld(), self.stat) then
		local instance = copyTable(entry.row.gem)
		instance.gemData = self.skillsTab.build.data.gems[instance.gemId]
		gemTooltip.AddGemTooltip(tooltip, self.skillsTab.build, instance)
		tooltip:AddSeparator(8)
		tooltip:AddLine(14, "^7" .. self.result.target .. " | " .. self.result.group)
		tooltip:AddLine(14, self.result.considerExisting and "^7Compare against the current supports; keep the other gems." or "^7Compare one candidate against this group without its other supports.")
		tooltip:AddLine(14, "^7Uses the open build's Configuration, Count and uptime. This is a preview.")
		if entry.benefit and math.abs(entry.benefit) < 0.000001 then tooltip:AddLine(14, "^7No modelled change for " .. self.stat.label .. ". This does not establish the gem's usefulness.") end
		if entry.row.unsupported then tooltip:AddLine(14, colorCodes.UNSUPPORTED .. "Some gem effects are not modelled by PoB; see the highlighted effects above.") end
		local comparison = shared.ComparisonOutput(self.result.baselineComparison, entry.row.comparison)
		local priority = { "FullDPS", "TotalEHP" }
		if self.stat.stat == "HarmonicMaximumHitTaken" then table.insert(priority, "HarmonicMaximumHitTaken") end
		self.skillsTab.build:AddStatComparesToTooltip(tooltip, self.result.baselineComparison, comparison, "^7Stat changes:", nil, priority)
	end
end

-- Include optional controls such as the Rod estimate button when positioning
-- beside the editor. Narrow windows place the pane below the last gem row.
function ReportClass:Layout(viewPort)
	local tab = self.skillsTab
	local x, y = tab.anchorGroupDetail:GetPos()
	local right, bottom = x, y + 72
	for _, slot in ipairs(tab.gemSlots) do
		for _, control in pairs(slot) do
			if type(control) == "table" and control.GetPos and control:IsShown() then
				local cx, cy = control:GetPos(); local w, h = control:GetSize()
				right, bottom = math.max(right, cx + w), math.max(bottom, cy + h)
			end
		end
	end
	if not main.portraitMode and right + 24 + self.width <= viewPort.x + viewPort.width then
		self.x, self.y = right - x + 24, 128
	else
		self.x, self.y = 0, bottom - y + 150
	end
	local _, top = self:GetPos()
	self.height = math.max(140, math.min(420, viewPort.y + viewPort.height - top - 50))
end
