local FRIENDS = {
	monster_scientist = true,
	monster_sitting_scientist = true,
	monster_cleansuit_scientist = true,
	monster_barney = true,
	monster_otis = true,
	monster_human_medic_ally = true,
	monster_human_torch_ally = true,
	monster_human_grunt_ally = true,
	monster_barniel = true,
	monster_gman = true,
}

local CREATURES = {
	monster_cockroach = true,
	monster_rat = true,
	monster_leech = true,
	monster_bigmomma_egg = true,
	monster_flyer_flock = true,
}

local VEHICLE_PATTERNS = { "vehicle", "tracktrain", "func_tank", "func_train" }

local GROUPS = {
	[1] = "head",
	[2] = "chest",
	[3] = "stomach",
	[4] = "arm",
	[5] = "arm",
	[6] = "leg",
	[7] = "leg",
}

local PART_GROUPS = {
	head = "head",
	neck = "head",
	chest = "chest",
	stomach = "stomach",
	left_arm = "arm",
	right_arm = "arm",
	left_leg = "leg",
	right_leg = "leg",
}

function cc.world.Classify(entity)
	if entity.kind == "player" then
		return "player"
	end

	local class = entity.classname

	if FRIENDS[class] or class:find("_ally$") then
		return "friend"
	end

	if CREATURES[class] then
		return "creature"
	end

	for i = 1, #VEHICLE_PATTERNS do
		if class:find(VEHICLE_PATTERNS[i], 1, true) then
			return "vehicle"
		end
	end

	if entity.kind == "monster" then
		return "enemy"
	end

	return "entity"
end

function cc.world.HitMultiplier(kind, hit)
	local group

	if type(hit) == "table" then
		group = GROUPS[hit.group] or PART_GROUPS[hit.part]
	elseif type(hit) == "number" then
		group = GROUPS[hit]
	else
		group = PART_GROUPS[hit]
	end

	if not group then
		return nil
	end

	local skill = math.max(1, math.min(3, math.floor(cc.cvar.Get("skill") or 1)))

	return cc.cvar.Get("sk_" .. kind .. "_" .. group .. skill) or cc.cvar.Get("sk_" .. kind .. "_" .. group)
end

function cc.world.Players()
	return cc.world.Entities("player")
end

function cc.world.Monsters()
	return cc.world.Entities("monster")
end

function cc.world.Describe(index)
	local entity = cc.world.Entity(index)

	if not entity then
		return nil
	end

	entity.category = cc.world.Classify(entity)

	local kind = entity.kind == "player" and "player" or "monster"
	entity.hitboxes = cc.world.Hitboxes(index)

	for i = 1, #entity.hitboxes do
		entity.hitboxes[i].multiplier = cc.world.HitMultiplier(kind, entity.hitboxes[i])
	end

	return entity
end
