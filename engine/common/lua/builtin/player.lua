if not CLIENT then
	return
end

local ammo = {}
local max_ammo = {}
local by_name = {}
local armor = 0
local current = { id = 0, clip = 0 }

local HALF_LIFE_IDS = {
	weapon_crowbar = 1,
	weapon_9mmhandgun = 2,
	weapon_357 = 3,
	weapon_9mmar = 4,
	weapon_crossbow = 6,
	weapon_shotgun = 7,
	weapon_rpg = 8,
	weapon_gauss = 9,
	weapon_egon = 10,
	weapon_hornetgun = 11,
	weapon_handgrenade = 12,
	weapon_tripmine = 13,
	weapon_satchel = 14,
	weapon_snark = 15,
}

if cc.game == "valve" or cc.game == "gearbox" or cc.game == "bshift" then
	for class, id in pairs(HALF_LIFE_IDS) do
		by_name[class] = { id = id, first = -1, second = -1, slot = 0, position = 0 }
	end
end

local function bit_set(mask, index)
	return ((mask >> index) & 1) == 1
end

local function on_message(name, data)
	if name == "Battery" and #data >= 2 then
		armor = string.unpack("<i2", data)
	elseif name == "AmmoX" and #data >= 2 then
		local index, amount = string.unpack("<BB", data)
		ammo[index] = amount
	elseif name == "WeaponList" then
		local stop = data:find("\0", 1, true)

		if stop and #data >= stop + 8 then
			local weapon = data:sub(1, stop - 1):lower()
			local first, first_max, second, second_max, slot, position, id = string.unpack("<bBbBBBB", data, stop + 1)

			by_name[weapon] = { id = id, first = first, second = second, slot = slot, position = position }

			if first >= 0 then
				max_ammo[first] = first_max
			end

			if second >= 0 then
				max_ammo[second] = second_max
			end
		end
	elseif name == "CurWeapon" and #data >= 3 then
		local state, id, clip = string.unpack("<BbB", data)

		if state ~= 0 then
			current.id = id
			current.clip = clip
		end
	end
end

cc.hook.Add("UserMessage", "cc_player", on_message)

function cc.player.Report()
	local info = cc.player.Info()

	cc.log.Print(string.format("player report: game=%s map=%s health=%s armor=%s weapons=0x%x suit=%s longjump=%s weapon_id=%s clip=%s", cc.game, cc.Map(), tostring(info.health), tostring(armor), info.weapons or 0, tostring(info.weapons ~= nil and bit_set(info.weapons, 31)), tostring(info.longjump), tostring(current.id), tostring(current.clip)))

	local names = {}

	for class in pairs(by_name) do
		names[#names + 1] = class
	end

	table.sort(names)

	for i = 1, #names do
		local entry = by_name[names[i]]
		local owned = info.weapons ~= nil and bit_set(info.weapons, entry.id)
		local first, first_max = cc.player.Ammo(names[i])
		local second, second_max = cc.player.Ammo(names[i], true)

		cc.log.Print(string.format("weapon %s id=%d owned=%s ammo=%s/%s ammo2=%s/%s slot=%d", names[i], entry.id, tostring(owned), tostring(first), tostring(first_max), tostring(second), tostring(second_max), entry.slot))
	end
end

function cc.player.Get()
	local info = cc.player.Info()

	info.armor = armor
	info.suit = info.weapons ~= nil and bit_set(info.weapons, 31) or false
	info.weapon = current.id
	info.clip = current.clip

	return info
end

function cc.player.HasWeapon(class)
	local entry = by_name[class:lower()]
	local info = cc.player.Info()

	if not entry or not info.weapons then
		return nil
	end

	return bit_set(info.weapons, entry.id)
end

function cc.player.Ammo(class, second)
	local entry = by_name[class:lower()]

	if not entry then
		return nil
	end

	local index = second and entry.second or entry.first

	if index < 0 then
		return nil
	end

	local limit = max_ammo[index]

	if not limit then
		return nil
	end

	return ammo[index] or 0, limit
end
