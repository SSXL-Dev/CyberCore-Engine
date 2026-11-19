local cc = cc

local hooks = {}

cc.hook = {}

function cc.hook.Add(event, id, fn)
	if type(event) ~= "string" or type(fn) ~= "function" then
		cc.log.Error("hook.Add: invalid arguments")
		return
	end

	local list = hooks[event]

	if not list then
		list = {}
		hooks[event] = list
	end

	for i = 1, #list do
		if list[i].id == id then
			list[i].fn = fn
			return
		end
	end

	list[#list + 1] = { id = id, fn = fn }
end

function cc.hook.Remove(event, id)
	local list = hooks[event]

	if not list then
		return
	end

	for i = #list, 1, -1 do
		if list[i].id == id then
			table.remove(list, i)
		end
	end
end

function cc.hook.Run(event, ...)
	local list = hooks[event]

	if not list then
		return
	end

	local i = 1

	while i <= #list do
		local entry = list[i]
		local ok, result = pcall(entry.fn, ...)

		if ok then
			if result ~= nil then
				return result
			end

			i = i + 1
		else
			cc.log.Error("hook " .. event .. " / " .. tostring(entry.id) .. " removed: " .. tostring(result))
			table.remove(list, i)
		end
	end
end

local SETTINGS_FILE = "cc_settings.cfg"
local values = {}

local function encode(value)
	local kind = type(value)

	if kind == "table" then
		local keys = {}

		for key in pairs(value) do
			if type(key) == "string" then
				keys[#keys + 1] = key
			end
		end

		table.sort(keys)

		local parts = {}

		for i = 1, #keys do
			parts[i] = "[" .. string.format("%q", keys[i]) .. "]=" .. encode(value[keys[i]])
		end

		return "{" .. table.concat(parts, ",") .. "}"
	elseif kind == "string" then
		return string.format("%q", value)
	elseif kind == "number" then
		if math.type(value) == "integer" then
			return string.format("%d", value)
		end

		return string.format("%.14g", value)
	elseif kind == "boolean" then
		return tostring(value)
	end

	return "nil"
end

local function save()
	local parts = {}
	local keys = {}

	for key in pairs(values) do
		keys[#keys + 1] = key
	end

	table.sort(keys)

	for i = 1, #keys do
		parts[i] = "[" .. string.format("%q", keys[i]) .. "]=" .. encode(values[keys[i]])
	end

	cc.fs.Write(SETTINGS_FILE, "return {" .. table.concat(parts, ",\n") .. "}\n")
end

local function load_settings()
	local text = cc.fs.Read(SETTINGS_FILE)

	if not text then
		return
	end

	local chunk, err = load(text, "=" .. SETTINGS_FILE, "t", {})

	if not chunk then
		cc.log.Error("settings: " .. tostring(err))
		return
	end

	local ok, data = pcall(chunk)

	if ok and type(data) == "table" then
		values = data
	end
end

cc.settings = {}

function cc.settings.Get(key, default)
	local value = values[key]

	if value == nil then
		return default
	end

	return value
end

function cc.settings.Set(key, value)
	if type(key) ~= "string" then
		cc.log.Error("settings.Set: key must be a string")
		return
	end

	if encode(values[key]) == encode(value) then
		return
	end

	values[key] = value
	save()
end

load_settings()

cc.addon = {}

local disabled_addons = cc.settings.Get("disabled_addons", {})

function cc.addon.IsEnabled(name)
	return not disabled_addons[name]
end

function cc.addon.SetEnabled(name, enabled)
	local copy = {}

	for key, value in pairs(disabled_addons) do
		copy[key] = value
	end

	copy[name] = (not enabled) or nil
	disabled_addons = copy
	cc.settings.Set("disabled_addons", copy)
end
