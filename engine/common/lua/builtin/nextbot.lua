if not SERVER then
	return
end

local nextbot = {}
cc.nextbot = nextbot

local defs = {}
local order = {}
local bots = {}
local queue = {}
local assets = {}
local now = 0

local CHAN_VOICE = 2
local MODE_TEXTURE = 2

local Bot = {}
Bot.__index = Bot

local function rad(deg)
	return deg * math.pi / 180
end

local function deg(radians)
	return radians * 180 / math.pi
end

local function player()
	local entity = cc.world.Entity(1)

	if entity and entity.kind == "player" then
		return entity
	end

	return nil
end

local function precache_def(def)
	local record = { model = 0, sprites = {}, sounds = {} }

	record.model = cc.sv.Precache(def.model)

	for _, path in ipairs(def.sprites or {}) do
		record.sprites[path] = cc.sv.Precache(path)
	end

	for _, path in ipairs(def.sounds or {}) do
		record.sounds[path] = cc.sv.Precache(path)
	end

	return record
end

function nextbot.Register(id, def)
	if type(id) ~= "string" or type(def) ~= "table" or type(def.model) ~= "string" or type(def.Run) ~= "function" then
		cc.log.Error("nextbot.Register: expected (id, { model = string, Run = function })")
		return
	end

	if not defs[id] then
		order[#order + 1] = id
	end

	def.id = id
	def.name = def.name or id
	defs[id] = def

	if CLIENT and cc.menu then
		cc.menu.AddEntry("nextbots", {
			name = def.name,
			description = def.description,
			icon = def.icon or "nextbots",
			image = def.image,
			image_w = def.image_w,
			image_h = def.image_h,
			onClick = function()
				return nextbot.Spawn(id)
			end,
		})
	end
end

function nextbot.Spawn(id)
	local def = defs[id]

	if not def then
		return "Unknown NextBot: " .. tostring(id)
	end

	if not cc.world.Active() then
		return "Start a map first"
	end

	queue[#queue + 1] = id
	return def.name .. " is coming"
end

function nextbot.Clear()
	cc.sv.RemoveAll()
	bots = {}
	queue = {}
end

function nextbot.Sprite(def, path)
	local record = assets[def.id]
	return record and record.sprites[path] or 0
end

function Bot:Origin()
	local entity = cc.world.Entity(self.index)

	if not entity then
		self.dead = true
		return nil
	end

	return entity.origin
end

function Bot:Wait(seconds)
	local elapsed = 0

	while elapsed < seconds do
		elapsed = elapsed + coroutine.yield()
	end
end

function Bot:Find(patterns)
	if type(patterns) == "string" then
		patterns = { patterns }
	end

	for _, pattern in ipairs(patterns) do
		for _, seq in ipairs(self.sequences) do
			if seq.name:lower() == pattern then
				return seq
			end
		end
	end

	for _, pattern in ipairs(patterns) do
		for _, seq in ipairs(self.sequences) do
			if seq.name:lower():find(pattern, 1, true) then
				return seq
			end
		end
	end

	return nil
end

function Bot:Play(patterns)
	local seq = self:Find(patterns)

	if not seq then
		return 0
	end

	self.seq = seq
	self.frame = 0

	cc.sv.Set(self.index, "sequence", seq.index)
	cc.sv.Set(self.index, "frame", 0)
	cc.sv.Set(self.index, "framerate", 1)
	cc.sv.Set(self.index, "animtime", cc.sv.Time())

	if not seq.loop and seq.fps > 0 and seq.frames > 1 then
		return (seq.frames - 1) / seq.fps
	end

	return 0
end

function Bot:Advance(dt)
	local seq = self.seq

	if not seq or seq.frames < 2 or seq.fps <= 0 then
		return
	end

	local frame = self.frame + dt * 256 * seq.fps / (seq.frames - 1)

	if seq.loop then
		frame = frame % 256
	elseif frame > 255 then
		frame = 255
	end

	self.frame = frame
	cc.sv.Set(self.index, "frame", frame)
	cc.sv.Set(self.index, "animtime", cc.sv.Time())
end

function Bot:Face(x, y)
	local origin = self:Origin()

	if not origin then
		return
	end

	local yaw = deg(math.atan(y - origin.y, x - origin.x))
	cc.sv.Set(self.index, "angles", 0, yaw, 0)
	self.yaw = yaw
end

function Bot:FacePlayer()
	local target = player()

	if target then
		self:Face(target.origin.x, target.origin.y)
	end
end

function Bot:Distance(x, y)
	local origin = self:Origin()

	if not origin then
		return 0
	end

	return math.sqrt((x - origin.x) ^ 2 + (y - origin.y) ^ 2)
end

function Bot:WalkTo(x, y, stop, speed, timeout)
	local started = now
	local stuck = 0

	while not self.dead and now - started < (timeout or 12) do
		if self:Distance(x, y) <= stop then
			return true
		end

		self:Face(x, y)

		local before = self:Origin()
		local dt = coroutine.yield()
		local pace = self.seq and self.seq.speed > 1 and self.seq.speed or speed
		local step = pace * dt

		cc.sv.Walk(self.index, self.yaw, step)

		local after = self:Origin()

		if before and after then
			local moved = math.sqrt((after.x - before.x) ^ 2 + (after.y - before.y) ^ 2)

			if moved < step * 0.25 then
				stuck = stuck + dt
			else
				stuck = 0
			end

			if stuck > 0.6 then
				return false
			end
		end
	end

	return false
end

function Bot:WalkToPlayer(stop, speed)
	local target = player()

	if not target then
		return false
	end

	return self:WalkTo(target.origin.x, target.origin.y, stop, speed)
end

local function wav_length(path)
	local ok, data = pcall(cc.fs.Read, "sound/" .. path, true)

	if not ok or type(data) ~= "string" or #data < 44 then
		return nil
	end

	local rate = string.unpack("<I4", data, 29)
	local position = 13

	while position + 8 <= #data do
		local tag, size = string.unpack("<c4I4", data, position)

		if tag == "data" then
			if rate > 0 then
				return size / rate
			end

			return nil
		end

		position = position + 8 + size + (size % 2)
	end

	return nil
end

function Bot:Say(path)
	if not path then
		return 0
	end

	cc.sv.Sound(self.index, CHAN_VOICE, path, 1.0, 0.7, 100)
	return wav_length(path) or 2.5
end

function Bot:Center()
	local origin = self:Origin()

	if not origin then
		return nil
	end

	return { x = origin.x, y = origin.y, z = origin.z + 36 }
end

function Bot:Lightning(pulses, radius)
	local def = self.def
	local sprite = nextbot.Sprite(def, "sprites/lgtning.spr")

	for pulse = 1, pulses do
		local center = self:Center()

		if not center then
			return
		end

		for _ = 1, 5 do
			local angle = math.random() * math.pi * 2
			local lift = (math.random() - 0.3) * radius
			local reach = radius * (0.5 + math.random() * 0.5)
			cc.sv.Beam(center.x, center.y, center.z, center.x + math.cos(angle) * reach, center.y + math.sin(angle) * reach, center.z + lift, sprite, 3, 9, 60, 255, 210, 40, 255, 0)
		end

		cc.sv.Light(center.x, center.y, center.z, 22, 255, 200, 30, 4, 8)
		cc.sv.Sparks(center.x, center.y, center.z)
		self:Wait(0.1)
	end
end

function Bot:Fade(from, to, seconds)
	local elapsed = 0

	cc.sv.Set(self.index, "rendermode", MODE_TEXTURE)

	while elapsed < seconds do
		local fraction = elapsed / seconds
		cc.sv.Set(self.index, "renderamt", from + (to - from) * fraction)
		elapsed = elapsed + coroutine.yield()
	end

	cc.sv.Set(self.index, "renderamt", to)
end

function Bot:Appear()
	cc.sv.Set(self.index, "rendermode", MODE_TEXTURE)
	cc.sv.Set(self.index, "renderamt", 0)

	if self.def.teleport_sound then
		cc.sv.Sound(self.index, 0, self.def.teleport_sound, 1.0, 0.6, 100)
	end

	self:Lightning(4, 72)
	self:Fade(0, 255, 0.4)
	cc.sv.Set(self.index, "rendermode", 0)
	cc.sv.Set(self.index, "renderamt", 0)
end

function Bot:Vanish()
	if self.def.teleport_sound then
		cc.sv.Sound(self.index, 0, self.def.teleport_sound, 1.0, 0.6, 100)
	end

	self:Lightning(4, 72)
	self:Fade(255, 0, 0.4)
	self:Lightning(2, 90)
	self:Remove()
end

function Bot:Remove()
	if not self.dead then
		cc.sv.Remove(self.index)
		self.dead = true
	end
end

local function sequence_report(def, sequences)
	local names = {}

	for _, seq in ipairs(sequences) do
		names[#names + 1] = seq.index .. "=" .. seq.name
	end

	cc.log.Print("nextbot " .. def.id .. " sequences: " .. table.concat(names, ", "))
end

local function spawn_position()
	local target = player()

	if not target then
		return nil
	end

	local yaw = target.v_angle.y
	local dx = math.cos(rad(yaw))
	local dy = math.sin(rad(yaw))
	local eye = { x = target.origin.x, y = target.origin.y, z = target.origin.z + 17 }
	local distance = 170
	local hit = cc.sv.Trace(eye.x, eye.y, eye.z, eye.x + dx * distance, eye.y + dy * distance, eye.z, 1)

	if hit.fraction < 1 then
		distance = math.max(70, hit.fraction * distance - 24)
	end

	local x = eye.x + dx * distance
	local y = eye.y + dy * distance
	local floor = cc.sv.Trace(x, y, eye.z, x, y, eye.z - 300, 1)

	return x, y, floor.z, yaw + 180
end

local function launch(id)
	local def = defs[id]

	if not assets[id] then
		assets[id] = precache_def(def)
	end

	if assets[id].model == 0 then
		cc.log.Error("nextbot " .. id .. ": model '" .. def.model .. "' is not available in this game")
		return
	end

	local x, y, z, yaw = spawn_position()

	if not x then
		return
	end

	local index = cc.sv.Spawn(x, y, z, yaw)

	if not index then
		cc.log.Error("nextbot " .. id .. ": spawn failed")
		return
	end

	cc.sv.SetModel(index, def.model)
	cc.sv.SetSize(index, -16, -16, 0, 16, 16, 72)
	cc.sv.SetOrigin(index, x, y, z + 2)
	cc.sv.DropToFloor(index)

	local bot = setmetatable({ index = index, def = def, yaw = yaw, sequences = cc.sv.Sequences(index) }, Bot)

	if not def.reported then
		def.reported = true
		sequence_report(def, bot.sequences)
	end

	bot:Play({ "idle", "idle1", "stand" })

	bot.thread = coroutine.create(function()
		def.Run(bot)
	end)

	bots[#bots + 1] = bot
end

local function step(dt)
	for i = #bots, 1, -1 do
		local bot = bots[i]

		if bot.dead or coroutine.status(bot.thread) == "dead" then
			bot:Remove()
			table.remove(bots, i)
		else
			bot:Advance(dt)

			local ok, err = coroutine.resume(bot.thread, dt)

			if not ok then
				cc.log.Error("nextbot " .. bot.def.id .. ": " .. tostring(err))
				bot:Remove()
				table.remove(bots, i)
			end
		end
	end
end

cc.hook.Add("Precache", "cc.nextbot", function()
	bots = {}
	queue = {}
	assets = {}

	for _, id in ipairs(order) do
		assets[id] = precache_def(defs[id])
	end
end)

cc.hook.Add("ServerFrame", "cc.nextbot", function(dt)
	now = now + dt

	while #queue > 0 do
		launch(table.remove(queue, 1))
	end

	step(dt)
end)
