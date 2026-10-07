-- Optional sustained Lightning Arrow / player-created Lightning Rod estimate.
-- This is an ideal stationary-target model, not a game or mana simulation.
local estimate = { }
estimate.tooltip = "Uses enabled LA beam/chain counts, attack rates and Mirage uptime to estimate sustained Rod bursts.\nAssumes one stationary boss in range of all rods; includes rod limits, expiry, placement bursts and replacement with 20% extra time.\nCount is an approximate damage multiplier, not physical rods. Full DPS still assumes continuous player LA; mana limits are excluded."

-- Average several firing phases rather than making the answer depend on one
-- accidental alignment of player and Mirage attacks at the 0.1s burst interval.
function estimate.simulate(input)
	local speed, cap, charges = input.rodSpeed, input.cap, input.charges
	if not speed or speed <= 0 or cap <= 0 or charges <= 0 then return end
	local player, mirage = input.player, input.mirage
	if not player and not mirage then return end
	local total = 0
	for phase = 1, 6 do
		local rods, time, bursts, carry = { }, 0, 0, 0
		local nextPlayer = math.huge
		local nextMirage = mirage and (phase - 0.5) / 6 / mirage.rate or math.huge
		local refillUses, nextPlacement = math.ceil(cap / input.projectiles), 0
		local placementTime = 1.2 / speed
		local function expire()
			for i = #rods, 1, -1 do
				if rods[i].expires <= time or rods[i].charges <= 0 then table.remove(rods, i) end
			end
		end
		local function trigger(source)
			local remaining = source.contacts
			for _, rod in ipairs(rods) do
				if remaining <= 0 then break end
				-- A beam impact can visit each rod at most once, across all beams.
				if time - rod.last >= input.interval - 1e-9 then
					local amount = math.min(1, remaining, rod.charges)
					rod.charges = rod.charges - amount
					rod.last = time
					bursts = bursts + amount
					remaining = remaining - amount
				end
			end
		end
		-- Bound both the simulated duration and work for extreme custom attack rates.
		local events = 0
		while time < 180 and events < 20000 do
			local nextExpiry = rods[1] and rods[1].expires or math.huge
			time = math.min(nextPlayer, nextMirage, nextPlacement, nextExpiry)
			if time >= 180 then break end
			events = events + 1
			expire()
			if time == nextPlacement then
				carry = carry + input.projectiles
				local placed = math.floor(carry + 1e-9)
				carry = carry - placed
				bursts = bursts + placed * input.impactBursts
				for i = 1, placed do
					if #rods >= cap then table.remove(rods, 1) end
					rods[#rods + 1] = { charges = charges, last = -math.huge, expires = time + input.duration }
				end
				refillUses = refillUses - 1
				nextPlacement = refillUses > 0 and time + placementTime or math.huge
				if refillUses == 0 and player then nextPlayer = time + placementTime + 1 / player.rate end
			elseif time == nextMirage then
				trigger(mirage)
				nextMirage = time + 1 / mirage.rate
			elseif time == nextPlayer then
				trigger(player)
				nextPlayer = time + 1 / player.rate
			end
			expire()
			if #rods == 0 and refillUses == 0 then
				refillUses = math.ceil(cap / input.projectiles)
				nextPlacement = time + placementTime
				nextPlayer = math.huge
			end
			-- Mirage-only expiry still needs to start another replacement batch.
			if nextPlayer == math.huge and nextMirage == math.huge and nextPlacement == math.huge then break end
		end
		if events >= 20000 then return end
		total = total + bursts / 180 / speed
	end
	return math.floor(total / 6 * 10 + 0.5) / 10
end

local function usable(skill)
	local group = skill.socketGroup
	return group and group.enabled and group.slotEnabled and skill.activeEffect.srcInstance.enabled
end

local function skillOutput(build, calcs, original, beam)
	local env = calcs.initEnv(build, "CALCULATOR")
	for i, skill in ipairs(env.player.activeSkillList) do
		if skill.socketGroup == original.socketGroup and skill.activeEffect.srcInstance == original.activeEffect.srcInstance
			and skill.activeEffect.grantedEffect.id == original.activeEffect.grantedEffect.id then
			if beam then
				local effect = copyTable(skill.activeEffect, true)
				effect.statSet = { index = 2 }
				skill = calcs.createActiveSkill(effect, skill.supportList, env, env.player, skill.socketGroup, skill.summonSkill)
				calcs.buildActiveSkillModList(env, skill)
				env.player.activeSkillList[i] = skill
			end
			env.player.mainSkill = skill
			calcs.perform(env, true)
			return env.player.output, skill, env
		end
	end
end

function estimate.calculate(build, calcs, gem)
	local env = calcs.initEnv(build, "CALCULATOR")
	local rod, candidates = nil, { }
	for _, skill in ipairs(env.player.activeSkillList) do
		if usable(skill) then
			local id = skill.activeEffect.grantedEffect.id
			if id == "LightningRodPlayer" and skill.activeEffect.srcInstance == gem then rod = skill end
			if id == "LightningArrowPlayer" then candidates[#candidates + 1] = skill end
		end
	end
	if not rod or rod.skillTypes[SkillType.SupportedByMirageArcher] then return end
	local out, skill, rodEnv = skillOutput(build, calcs, rod)
	if not out or not out.Speed or out.Speed <= 0 then return end
	local effect = skill.activeEffect
	local stats = calcLib.buildSkillInstanceStats(effect, effect.grantedEffect, effect.grantedEffect.statSets[1], rodEnv.useAltGemQualityStats)
	local input = {
		rodSpeed = out.Speed,
		cap = stats.number_of_lightning_rods_allowed or 10,
		charges = stats.lightning_rod_number_of_chains_allowed or 8,
		projectiles = math.max(1, math.min(100, out.ProjectileCount or 1)),
		duration = math.max(0.1, out.Duration or skill.skillData.duration or 20),
		impactBursts = 1 + math.min(100, stats["lightning_rod_%_chance_for_additional_burst_on_landing"] or 0) / 100,
		interval = 0.1,
	}
	for _, candidate in ipairs(candidates) do
		local arrowOut, arrow, arrowEnv = skillOutput(build, calcs, candidate, true)
		if arrowOut and arrowOut.Speed and arrowOut.Speed > 0 and not arrow.triggeredBy then
			local arrowEffect = arrow.activeEffect
			local arrowStats = calcLib.buildSkillInstanceStats(arrowEffect, arrowEffect.grantedEffect, arrowEffect.grantedEffect.statSets[1], arrowEnv.useAltGemQualityStats)
			local beams = arrowStats.lightning_arrow_maximum_number_of_extra_targets or 0
			local contacts = math.min(input.cap, beams * (1 + (arrowOut.ChainMax or 0)))
			local rate = arrowOut.Speed * (arrowOut.HitChance or 100) / 100
			local key = arrow.skillTypes[SkillType.SupportedByMirageArcher] and "mirage" or "player"
			if key == "mirage" then rate = rate * (arrowEnv.modDB:Override(nil, "MirageArcherUptime") or 100) / 100 end
			if rate > 0 and contacts > 0 and (not input[key] or rate * contacts > input[key].rate * input[key].contacts) then
				-- One player skill and one effective Mirage; alternative groups aren't simultaneous attacks.
				input[key] = { rate = rate, contacts = contacts }
			end
		end
	end
	return estimate.simulate(input), input
end

return estimate
