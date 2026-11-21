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

local sync_maps

function mode.Get()
	local id = cc.settings.Get(key(), "sandbox")

	if not modes[id] then
		return "sandbox"
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
	sync_maps()
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
		local value = settings[name]

		if type(value) == "function" then
			value = value(cc.cvar.Get(name) or 0)
		end

		cc.cvar.Set(name, tostring(value))
	end
end

function sync_maps()
	local def = modes[mode.Get()]
	local entity = def and def.map_entity or ""
	local story = def and def.story == true
	local saved_key = "maps_entity_" .. tostring(cc.game)
	local signature = entity .. (story and "+story" or "")

	cc.maps.SetEntity(entity ~= "" and entity or nil)
	cc.maps.SetStory(story)

	if cc.settings.Get(saved_key, "") ~= signature then
		cc.maps.Refresh()
		cc.settings.Set(saved_key, signature)
	end
end

mode.SyncMaps = sync_maps

cc.hook.Add("Initialize", "cc.mode", function()
	sync_maps()
end)

cc.hook.Add("MapStart", "cc.mode", function(stage, fresh)
	if fresh then
		mode.Apply()
	end
end)

mode.Register("sandbox", {
	name = "Sandbox",
	short = "Free play, cheats on",
	color = { 0, 170, 255 },
	description = "Single player, cheats on, free play",
	settings = { maxplayers = 1, coop = 0, sv_cheats = 1 },
	games = {
		cstrike = { maxplayers = 8 },
		czero = { maxplayers = 8 },
	},
})

mode.Register("deathmatch", {
	name = "Deathmatch",
	short = "Fight other players",
	color = { 245, 95, 95 },
	description = "Multiplayer rules, up to 16 players",
	settings = {
		maxplayers = function(current)
			return current >= 2 and current or 16
		end,
		coop = 0,
		sv_cheats = 0,
	},
})

mode.Register("coop", {
	name = "Co-op",
	short = "Campaign with friends",
	color = { 80, 225, 130 },
	description = "Play the campaign levels together",
	map_entity = "info_player_start",
	story = true,
	settings = {
		maxplayers = function(current)
			return current >= 2 and current or 4
		end,
		coop = 1,
		sv_cheats = 0,
	},
})
