if not SERVER then
	return
end

local coop = {}
cc.coop = coop

local floor = math.floor
local SUIT = 0x80000000
local ALL = 0xFFFFFFFF
local STEP = 0.2
local EXIT_RANGE = 160
local WARN_RANGE = 120
local FIELD_RANGE = 380

coop.Weapons = {
	{ 1, "weapon_crowbar", "Crowbar" },
	{ 2, "weapon_9mmhandgun", "Glock" },
	{ 3, "weapon_357", ".357" },
	{ 4, "weapon_9mmAR", "MP5" },
	{ 6, "weapon_crossbow", "Crossbow" },
	{ 7, "weapon_shotgun", "Shotgun" },
	{ 8, "weapon_rpg", "RPG" },
	{ 9, "weapon_gauss", "Gauss" },
	{ 10, "weapon_egon", "Egon" },
	{ 11, "weapon_hornetgun", "Hivehand" },
	{ 12, "weapon_handgrenade", "Grenades" },
	{ 13, "weapon_tripmine", "Tripmines" },
	{ 14, "weapon_satchel", "Satchels" },
	{ 15, "weapon_snark", "Snarks" },
}

coop.Items = {
	{ "item_suit", "HEV suit" },
	{ "item_battery", "Battery" },
	{ "item_healthkit", "Medkit" },
}

local MOCKS = {
	"Forgot something back there? Say hi to it for us. lol",
	"Nostalgia is not a level exit.",
	"The way back is closed. Stop looking.",
	"Whatever you left behind is not coming with you.",
}

local run = { visited = {}, kits = {}, expected = nil, current = nil }
local session = { on = false, players = {}, back = {} }
local last = {}
local sprite = 0

local function mask_of(value)
	return (math.tointeger(value) or 0) & ALL
end

local function throttle(key, gap)
	local now = cc.sv.Time()

	if (last[key] or -1000) + gap > now then
		return false
	end

	last[key] = now
	return true
end

local function box_distance(box, o)
	local a, b = box.absmin, box.absmax
	local dx = math.max(a.x - o.x, 0, o.x - b.x)
	local dy = math.max(a.y - o.y, 0, o.y - b.y)
	local dz = math.max(a.z - o.z, 0, o.z - b.z)

	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function surface_point(box)
	local a, b = box.absmin, box.absmax
	local x = a.x + (b.x - a.x) * math.random()
	local y = a.y + (b.y - a.y) * math.random()
	local z = a.z + (b.z - a.z) * math.random()
	local face = math.random(6)

	if face == 1 then
		x = a.x
	elseif face == 2 then
		x = b.x
	elseif face == 3 then
		y = a.y
	elseif face == 4 then
		y = b.y
	elseif face == 5 then
		z = a.z
	else
		z = b.z
	end

	return x, y, z
end

local function electrify(box, count)
	if sprite == 0 then
		return
	end

	for _ = 1, count do
		local x1, y1, z1 = surface_point(box)
		local x2, y2, z2 = surface_point(box)

		cc.sv.Beam(x1, y1, z1, x2, y2, z2, sprite, 3, 9, 45, 110, 190, 255, 255)
	end

	local x, y, z = surface_point(box)
	cc.sv.Sparks(x, y, z)
end

local function triggers()
	if not session.triggers then
		session.triggers = cc.world.Find("trigger_changelevel")
	end

	return session.triggers
end

local function nearest_trigger(origin)
	local best, best_distance = nil, math.huge

	for _, box in ipairs(triggers()) do
		local distance = box_distance(box, origin)

		if distance < best_distance then
			best, best_distance = box, distance
		end
	end

	return best, best_distance
end

local function alive_players()
	local out = {}

	for _, p in ipairs(cc.world.Entities("player")) do
		if p.alive then
			out[#out + 1] = p
		end
	end

	return out
end

local function give_missing(index, want, have)
	for _, w in ipairs(coop.Weapons) do
		local bit = 1 << w[1]

		if (want & bit) ~= 0 and (have & bit) == 0 then
			cc.sv.Give(index, w[2])
		end
	end

	if (want & SUIT) ~= 0 and (have & SUIT) == 0 then
		cc.sv.Give(index, "item_suit")
	end
end

coop.GiveAll = function(index)
	for _, w in ipairs(coop.Weapons) do
		cc.sv.Give(index, w[2])
	end

	cc.sv.Give(index, "item_suit")
end

local function spot_near(origin)
	local offsets = { { 56, 0 }, { -56, 0 }, { 0, 56 }, { 0, -56 } }

	for _, o in ipairs(offsets) do
		local tr = cc.sv.Trace(origin.x, origin.y, origin.z + 8, origin.x + o[1], origin.y + o[2], origin.z + 8)

		if tr.fraction >= 1 and not tr.startsolid then
			return origin.x + o[1], origin.y + o[2], origin.z + 8
		end
	end

	return origin.x, origin.y, origin.z + 24
end

local function rejoin(p, alive)
	for _, other in ipairs(alive) do
		local rec = session.players[other.name]

		if other.index ~= p.index and rec and not rec.pending then
			local x, y, z = spot_near(other.origin)

			cc.sv.Teleport(p.index, x, y, z)
			return true
		end
	end

	if session.checkpoint then
		local c = session.checkpoint

		cc.sv.Teleport(p.index, c.x, c.y, c.z + 24)
		return true
	end

	return false
end

local function save_kits(list)
	local kits = {}

	for _, p in ipairs(list) do
		local rec = session.players[p.name]
		local weapons = rec and rec.weapons or 0

		kits[p.name] = { weapons = weapons, health = p.health, armor = p.armor }
	end

	for name, rec in pairs(session.players) do
		if not kits[name] then
			kits[name] = { weapons = rec.lastweapons or 0, health = 100, armor = 0 }
		end
	end

	run.kits = kits
end

local function step()
	local now = cc.sv.Time()
	local list = cc.world.Entities("player")
	local alive = {}

	for _, p in ipairs(list) do
		local rec = session.players[p.name]

		if not rec then
			rec = { weapons = 0 }
			session.players[p.name] = rec
		end

		if p.alive then
			local detail = cc.world.Entity(p.index)

			alive[#alive + 1] = p
			rec.weapons = detail and mask_of(detail.weapons) or 0
			rec.ground = ((math.tointeger(p.flags) or 0) & 512) ~= 0

			if not rec.live then
				rec.live = true
				rec.pending = true
				rec.spawned_at = now
				rec.respawn = rec.ever == true
				rec.ever = true
			end

			if not rec.pending and rec.weapons ~= 0 then
				rec.lastweapons = rec.weapons
			end
		else
			rec.live = false
		end
	end

	for _, p in ipairs(alive) do
		local rec = session.players[p.name]

		if rec.pending and now - rec.spawned_at >= 0.8 then
			rec.pending = false
			rec.share_at = now + 2.5

			if rec.respawn then
				give_missing(p.index, rec.lastweapons or 0, rec.weapons)
				rejoin(p, alive)
			else
				local kit = run.kits[p.name]

				if kit then
					give_missing(p.index, kit.weapons, rec.weapons)
					cc.sv.SetPlayer(p.index, "health", kit.health)
					cc.sv.SetPlayer(p.index, "armor", kit.armor)
				end

				if session.arrival and not session.marked then
					local box, distance = nearest_trigger(p.origin)

					session.marked = true

					if box and distance < 600 then
						session.back[box.index] = true
					end
				end
			end
		end

		if rec.ground and now - (session.checkpoint_at or -100) >= 5 and not rec.pending then
			session.checkpoint = { x = p.origin.x, y = p.origin.y, z = p.origin.z }
			session.checkpoint_at = now
		end
	end

	if cc.settings.Get("coop_share", true) and #alive >= 2 then
		local union = 0

		for _, p in ipairs(alive) do
			local rec = session.players[p.name]

			if not rec.pending then
				union = union | rec.weapons
			end
		end

		for _, p in ipairs(alive) do
			local rec = session.players[p.name]

			if not rec.pending and (rec.share_at or 0) <= now and (union & ~rec.weapons & ALL) ~= 0 then
				give_missing(p.index, union, rec.weapons)
				rec.share_at = now + 3
			end
		end
	end

	for index in pairs(session.back) do
		for _, box in ipairs(triggers()) do
			if box.index == index then
				local closest = math.huge
				local nearby

				for _, p in ipairs(alive) do
					local distance = box_distance(box, p.origin)

					if distance < closest then
						closest, nearby = distance, p
					end
				end

				if nearby and closest < FIELD_RANGE then
					electrify(box, 4)
				end

				if nearby and closest < WARN_RANGE and throttle("warn" .. index, 4) then
					cc.sv.Print(nearby.index, "Going back is not allowed.\nForward only.")
				end
			end
		end
	end
end

local function on_change(level)
	if not session.on then
		return
	end

	local dest = tostring(level):lower()
	local alive = alive_players()
	local best, best_count = nil, -1

	for _, box in ipairs(triggers()) do
		local count = 0

		for _, p in ipairs(alive) do
			if box_distance(box, p.origin) <= EXIT_RANGE then
				count = count + 1
			end
		end

		if count > best_count then
			best, best_count = box, count
		end
	end

	if run.visited[dest] then
		if best then
			session.back[best.index] = true
			electrify(best, 10)

			for _, p in ipairs(alive) do
				if box_distance(best, p.origin) <= EXIT_RANGE then
					local cx = (best.absmin.x + best.absmax.x) / 2
					local cy = (best.absmin.y + best.absmax.y) / 2
					local dx, dy = p.origin.x - cx, p.origin.y - cy
					local length = math.sqrt(dx * dx + dy * dy)

					if length < 1 then
						dx, dy, length = 1, 0, 1
					end

					cc.sv.Push(p.index, dx / length * 320, dy / length * 320, 140)
				end
			end
		end

		if throttle("back", 3) then
			cc.sv.Print(0, "Going back is not allowed. Forward only.\n" .. MOCKS[math.random(#MOCKS)])
		end

		return false
	end

	local total = #alive

	if total == 0 then
		run.expected = dest
		return true
	end

	local required = floor(total / 2) + 1

	if best_count >= required then
		save_kits(alive)
		run.expected = dest

		if best then
			session.back[best.index] = nil
		end

		cc.sv.Print(0, "Exit confirmed. Moving on...")
		return true
	end

	if throttle("vote", 1.5) then
		cc.sv.Print(0, string.format("Players at the exit: %d/%d\nAt least %d needed to continue", math.max(best_count, 0), total, required))
	end

	return false
end

cc.hook.Add("MapStart", "cc.coop", function(stage, fresh)
	if stage ~= 2 then
		return
	end

	local info = cc.world.Info()
	local map = tostring(info.map or ""):lower()
	local arrival = run.expected == map

	last = {}
	session = { on = cc.game == "valve" and info.coop == 1 and map ~= "", players = {}, back = {}, arrival = arrival }

	if not session.on then
		run = { visited = {}, kits = {}, expected = nil, current = nil }
		return
	end

	if fresh and not arrival then
		run = { visited = {}, kits = {}, expected = nil, current = nil }
	end

	run.visited[map] = true
	run.current = map
	run.expected = nil

	cc.log.Print(string.format("coop: map=%s fresh=%s arrival=%s maxplayers=%s visited=%d", map, tostring(fresh), tostring(arrival), tostring(info.maxplayers), (function() local n = 0 for _ in pairs(run.visited) do n = n + 1 end return n end)()))

	for _, name in ipairs({ "mp_friendlyfire", "mp_weaponstay" }) do
		local saved = cc.settings.Get("cvar_" .. name, nil)

		if saved ~= nil then
			cc.cvar.Set(name, tostring(saved))
		end
	end
end)

cc.hook.Add("Precache", "cc.coop", function()
	sprite = cc.sv.Precache("sprites/lgtning.spr")
end)

cc.hook.Add("ServerFrame", "cc.coop", function(dt)
	if not session.on then
		return
	end

	session.acc = (session.acc or 0) + dt

	if session.acc < STEP then
		return
	end

	session.acc = 0

	local ok, err = pcall(step)

	if not ok and throttle("error", 30) then
		cc.log.Error("coop: " .. tostring(err))
	end
end)

cc.hook.Add("ChangeLevel", "cc.coop", function(level, landmark)
	local ok, result = pcall(on_change, level, landmark)

	if session.on and throttle("log", 5) then
		cc.log.Print("coop: changelevel " .. tostring(level) .. " -> " .. tostring(result))
	end

	if not ok then
		cc.log.Error("coop: " .. tostring(result))
		return nil
	end

	return result
end)
