local mode = {}
cc.mode = mode

local modes = {}
local order = {}

local function key()
	return "mode_" .. tostring(cc.game)
end

local function merged(def)
	local result = {}

	for name, value in pairs(def.settings or {}) do
		result[name] = value
	end

	local extra = def.games and def.games[cc.game]

	if extra then
		for name, value in pairs(extra) do
			result[name] = value
		end
	end

	return result
end

function mode.Register(id, def)
	if type(id) ~= "string" or type(def) ~= "table" then
		cc.log.Error("mode.Register: expected (id, { name = string, settings = table })")
		return
	end

	if not modes[id] then
		order[#order + 1] = id
	end

	def.id = id
	def.name = def.name or id
	modes[id] = def

	if CLIENT and cc.menu then
		cc.menu.AddEntry("modes", {
			name = def.name,
			description = def.description,
			icon = def.icon or "modes",
			onClick = function()
				mode.Set(id)
				return "Mode: " .. def.name .. " (applies when a new game starts)"
			end,
		})
	end
end

function mode.List()
	local list = {}

	for i = 1, #order do
		list[i] = modes[order[i]]
	end

	return list
end

function mode.Get()
	local id = cc.settings.Get(key(), "default")

	if not modes[id] then
		return "default"
	end

	return id
end

function mode.Name()
	local def = modes[mode.Get()]
	return def and def.name or "Default"
end

function mode.Set(id)
	if not modes[id] then
		return false
	end

	cc.settings.Set(key(), id)
	return true
end

function mode.Apply()
	local def = modes[mode.Get()]

	if not def then
		return
	end

	local settings = merged(def)
	local names = {}

	for name in pairs(settings) do
		names[#names + 1] = name
	end

	table.sort(names)

	for _, name in ipairs(names) do
		cc.cvar.Set(name, tostring(settings[name]))
	end
end

cc.hook.Add("MapStart", "cc.mode", function()
	mode.Apply()
end)

mode.Register("default", {
	name = "Default",
	description = "The game decides, nothing is changed",
	settings = {},
})

mode.Register("sandbox", {
	name = "Sandbox",
	description = "Single player, cheats on, free play",
	settings = { maxplayers = 1, coop = 0, sv_cheats = 1 },
	games = {
		cstrike = { maxplayers = 8 },
		czero = { maxplayers = 8 },
	},
})

mode.Register("deathmatch", {
	name = "Deathmatch",
	description = "Multiplayer rules, up to 16 players",
	settings = { maxplayers = 16, coop = 0, sv_cheats = 0 },
})
