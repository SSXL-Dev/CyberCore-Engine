if not CLIENT then
	return
end

local state = { give = nil, notice = nil }

local function cvar_toggle(ui, name, label, on_text, off_text, icon)
	local current = (cc.cvar.Get(name) or 0) ~= 0
	local value = ui:Toggle(label, current, current and on_text or off_text, icon)

	if value ~= current then
		cc.cvar.Set(name, value and "1" or "0")
		cc.settings.Set("cvar_" .. name, value and 1 or 0)
	end
end

local function give_picker(ui, index, name)
	local options = {}
	local classes = {}

	for _, w in ipairs(cc.coop.Weapons) do
		options[#options + 1] = w[3]
		classes[#classes + 1] = w[2]
	end

	for _, item in ipairs(cc.coop.Items) do
		options[#options + 1] = item[2]
		classes[#classes + 1] = item[1]
	end

	ui:Section("Give to " .. name, "weapons")

	local picked = ui:Grid(#options, 3, ui.row, nil, function(i, x, y, w, h)
		local width = ui:TextWidth(options[i])

		ui:Text(x + (w - width) / 2, y + (h - ui.line) / 2, options[i])
	end)

	if picked then
		cc.sv.Give(index, classes[picked])
		state.notice = "Gave " .. options[picked] .. " to " .. name
		state.give = nil
	end

	if ui:Row("Everything", "Give all") then
		cc.coop.GiveAll(index)
		state.notice = "Gave everything to " .. name
		state.give = nil
	end

	if ui:Row("Back to the player list", "Back") then
		state.give = nil
	end
end

local function players_panel(ui, info)
	ui:Section("Players", "modes")

	if state.notice then
		ui:Label(state.notice)
	end

	local list = cc.world.Entities("player")

	if #list == 0 then
		ui:Empty("No players in this match yet.")
		return
	end

	if state.give then
		for _, p in ipairs(list) do
			if p.index == state.give then
				give_picker(ui, p.index, p.name)
				return
			end
		end

		state.give = nil
	end

	for _, p in ipairs(list) do
		local status = p.alive and string.format("HP %d   Armor %d", p.health, p.armor) or "Dead"

		ui:Label(p.name .. "   " .. status)

		local pick = ui:Choice({ "Give", "Kill", "Kick" }, nil)

		if pick == 1 then
			state.give = p.index
		elseif pick == 2 then
			state.notice = cc.sv.Kill(p.index) and ("Killed " .. p.name) or (p.name .. " is not alive")
		elseif pick == 3 then
			state.notice = cc.sv.Kick(p.index) and ("Kicked " .. p.name) or "The host cannot be kicked"
		end
	end
end

cc.menu.AddTab("modes", "Modes", function(ui)
	local list = cc.mode.List()
	local names = {}
	local current = cc.mode.Get()
	local selected = nil

	for i, def in ipairs(list) do
		names[i] = def.name

		if def.id == current then
			selected = def.name
		end
	end

	ui:Section("Game mode", "modes")

	local picked = ui:Choice(names, selected)

	if picked then
		cc.mode.Set(list[picked].id)
		state.notice = "Mode set to " .. list[picked].name .. ". It applies when a new game starts."
	end

	for _, def in ipairs(list) do
		if def.id == current then
			ui:Label(def.description or def.short or "")
		end
	end

	local info = cc.world.Info()

	if not info.active then
		if state.notice then
			ui:Label(state.notice)
		end

		ui:Empty("Start a map to see match settings and player controls.")
		return
	end

	ui:Spacer()
	ui:Section("Match settings", "settings")
	cvar_toggle(ui, "mp_weaponstay", "Keep weapons", "Weapons stay on the ground after pickup", "Weapons disappear after pickup", "weapons")
	cvar_toggle(ui, "mp_friendlyfire", "Friendly fire", "Teammates can hurt each other", "Teammates are safe", "settings")

	if info.coop == 1 then
		local share = cc.settings.Get("coop_share", true)
		local value = ui:Toggle("Share weapons", share, share and "Every player gets what anyone picks up" or "Each player keeps their own", "weapons")

		if value ~= share then
			cc.settings.Set("coop_share", value)
		end
	end

	players_panel(ui, info)
end, "modes")
