if not CLIENT then
	return
end

local HL_WEAPONS = {
	{ "weapon_crowbar", "Crowbar" },
	{ "weapon_9mmhandgun", "9mm Pistol", "ammo_9mmclip" },
	{ "weapon_357", ".357 Python", "ammo_357" },
	{ "weapon_9mmAR", "MP5", "ammo_9mmAR" },
	{ "weapon_shotgun", "Shotgun", "ammo_buckshot" },
	{ "weapon_crossbow", "Crossbow", "ammo_crossbow" },
	{ "weapon_rpg", "RPG", "ammo_rpgclip" },
	{ "weapon_gauss", "Tau Cannon", "ammo_gaussclip" },
	{ "weapon_egon", "Gluon Gun", "ammo_gaussclip" },
	{ "weapon_hornetgun", "Hivehand" },
	{ "weapon_handgrenade", "Grenade" },
	{ "weapon_satchel", "Satchel Charge" },
	{ "weapon_tripmine", "Trip Mine" },
	{ "weapon_snark", "Snarks" },
}

local HL_AMMO = {
	{ "ammo_9mmclip", "9mm Clip" },
	{ "ammo_9mmbox", "9mm Box" },
	{ "ammo_9mmAR", "MP5 Clip" },
	{ "ammo_ARgrenades", "MP5 Grenades" },
	{ "ammo_buckshot", "Buckshot" },
	{ "ammo_357", ".357 Rounds" },
	{ "ammo_crossbow", "Crossbow Bolts" },
	{ "ammo_rpgclip", "RPG Rockets" },
	{ "ammo_gaussclip", "Uranium" },
}

local HL_ITEMS = {
	{ "item_suit", "HEV Suit", nil, "suit" },
	{ "item_battery", "Armor Battery", nil, "battery" },
	{ "item_healthkit", "Health Kit", nil, "health" },
	{ "item_longjump", "Long Jump Module", nil, "boots" },
	{ "item_antidote", "Antidote", nil, "health" },
}

local OF_WEAPONS = {
	{ "weapon_pipewrench", "Pipe Wrench" },
	{ "weapon_knife", "Combat Knife" },
	{ "weapon_eagle", "Desert Eagle", "ammo_357" },
	{ "weapon_m249", "M249 SAW", "ammo_556" },
	{ "weapon_sniperrifle", "Sniper Rifle", "ammo_762" },
	{ "weapon_sporelauncher", "Spore Launcher", "ammo_spore" },
	{ "weapon_shockrifle", "Shock Roach" },
	{ "weapon_displacer", "Displacer", "ammo_gaussclip" },
	{ "weapon_grapple", "Barnacle Grapple" },
	{ "weapon_penguin", "Penguin" },
}

local OF_AMMO = {
	{ "ammo_556", "5.56 Box" },
	{ "ammo_762", "7.62 Rounds" },
	{ "ammo_spore", "Spore Pod" },
}

local CS_WEAPONS = {
	{ "weapon_knife", "Knife" },
	{ "weapon_usp", "USP", "ammo_45acp" },
	{ "weapon_glock18", "Glock 18", "ammo_9mm" },
	{ "weapon_deagle", "Desert Eagle", "ammo_50ae" },
	{ "weapon_p228", "P228", "ammo_357sig" },
	{ "weapon_elite", "Dual Elites", "ammo_9mm" },
	{ "weapon_fiveseven", "Five-SeveN", "ammo_57mm" },
	{ "weapon_m3", "M3 Shotgun", "ammo_buckshot" },
	{ "weapon_xm1014", "XM1014", "ammo_buckshot" },
	{ "weapon_mp5navy", "MP5 Navy", "ammo_9mm" },
	{ "weapon_tmp", "TMP", "ammo_9mm" },
	{ "weapon_p90", "P90", "ammo_57mm" },
	{ "weapon_mac10", "MAC-10", "ammo_45acp" },
	{ "weapon_ump45", "UMP45", "ammo_45acp" },
	{ "weapon_famas", "FAMAS", "ammo_556nato" },
	{ "weapon_galil", "Galil", "ammo_556nato" },
	{ "weapon_ak47", "AK-47", "ammo_762nato" },
	{ "weapon_sg552", "SG 552", "ammo_556nato" },
	{ "weapon_m4a1", "M4A1", "ammo_556nato" },
	{ "weapon_aug", "AUG", "ammo_556nato" },
	{ "weapon_scout", "Scout", "ammo_762nato" },
	{ "weapon_awp", "AWP", "ammo_338magnum" },
	{ "weapon_g3sg1", "G3SG1", "ammo_762nato" },
	{ "weapon_sg550", "SG 550", "ammo_556nato" },
	{ "weapon_m249", "M249", "ammo_556natobox" },
	{ "weapon_flashbang", "Flashbang" },
	{ "weapon_hegrenade", "HE Grenade" },
	{ "weapon_smokegrenade", "Smoke Grenade" },
	{ "weapon_c4", "C4" },
	{ "weapon_shield", "Tactical Shield" },
}

local CS_AMMO = {
	{ "ammo_9mm", "9mm" },
	{ "ammo_45acp", ".45 ACP" },
	{ "ammo_50ae", ".50 AE" },
	{ "ammo_357sig", ".357 SIG" },
	{ "ammo_57mm", "5.7x28mm" },
	{ "ammo_762nato", "7.62mm NATO" },
	{ "ammo_556nato", "5.56mm NATO" },
	{ "ammo_556natobox", "5.56mm Box" },
	{ "ammo_338magnum", ".338 Magnum" },
	{ "ammo_buckshot", "12 Gauge" },
}

local CS_ITEMS = {
	{ "item_kevlar", "Kevlar Vest", nil, "armor" },
	{ "item_assaultsuit", "Kevlar + Helmet", nil, "armor" },
	{ "item_thighpack", "Defuse Kit", nil, "tool" },
}

local HALF_LIFE = {
	title = "Half-Life",
	sections = {
		{ "Weapons", "weapon", HL_WEAPONS },
		{ "Ammo", "ammo", HL_AMMO },
		{ "Equipment", "item", HL_ITEMS },
	},
}

local OPPOSING_FORCE = {
	title = "Opposing Force",
	sections = {
		{ "Weapons", "weapon", OF_WEAPONS },
		{ "Ammo", "ammo", OF_AMMO },
	},
}

local COUNTER_STRIKE = {
	title = "Counter-Strike",
	sections = {
		{ "Weapons", "weapon", CS_WEAPONS },
		{ "Ammo", "ammo", CS_AMMO },
		{ "Equipment", "item", CS_ITEMS },
	},
}

local GAMES = {
	valve = { HALF_LIFE },
	bshift = { HALF_LIFE },
	gearbox = { HALF_LIFE, OPPOSING_FORCE },
	cstrike = { COUNTER_STRIKE },
	czero = { COUNTER_STRIKE },
}

local AMMO_SOURCE = {
	ammo_9mmclip = { "weapon_9mmhandgun", "ammo" },
	ammo_9mmbox = { "weapon_9mmAR", "ammo" },
	ammo_9mmAR = { "weapon_9mmAR", "ammo" },
	ammo_ARgrenades = { "weapon_9mmAR", "ammo2" },
	ammo_buckshot = { "weapon_shotgun", "ammo" },
	ammo_357 = { "weapon_357", "ammo" },
	ammo_crossbow = { "weapon_crossbow", "ammo" },
	ammo_rpgclip = { "weapon_rpg", "ammo" },
	ammo_gaussclip = { "weapon_gauss", "ammo" },
	ammo_556 = { "weapon_m249", "ammo" },
	ammo_762 = { "weapon_sniperrifle", "ammo" },
	ammo_spore = { "weapon_sporelauncher", "ammo" },
}

local ITEM_SOURCE = {
	item_suit = { "hud", "suit_full" },
	item_healthkit = { "hud", "item_healthkit" },
	item_battery = { "hud", "item_battery" },
	item_longjump = { "hud", "item_longjump" },
	item_antidote = { "hud", "dmg_poison" },
	item_kevlar = { "hud", "suit_full" },
	item_assaultsuit = { "hud", "suithelmet_full" },
	item_thighpack = { "hud", "defuser" },
}

local AMMO_USERS = {
	ammo_9mmclip = { { "weapon_9mmhandgun" }, { "weapon_9mmAR" } },
	ammo_9mmbox = { { "weapon_9mmhandgun" }, { "weapon_9mmAR" } },
	ammo_9mmAR = { { "weapon_9mmAR" }, { "weapon_9mmhandgun" } },
	ammo_ARgrenades = { { "weapon_9mmAR", true } },
	ammo_buckshot = { { "weapon_shotgun" } },
	ammo_357 = { { "weapon_357" }, { "weapon_eagle" } },
	ammo_crossbow = { { "weapon_crossbow" } },
	ammo_rpgclip = { { "weapon_rpg" } },
	ammo_gaussclip = { { "weapon_gauss" }, { "weapon_egon" }, { "weapon_displacer" } },
	ammo_556 = { { "weapon_m249" } },
	ammo_762 = { { "weapon_sniperrifle" } },
	ammo_spore = { { "weapon_sporelauncher" } },
}

if cc.game == "cstrike" or cc.game == "czero" then
	AMMO_SOURCE = {
		ammo_9mm = { "weapon_glock18", "ammo" },
		ammo_45acp = { "weapon_usp", "ammo" },
		ammo_50ae = { "weapon_deagle", "ammo" },
		ammo_357sig = { "weapon_p228", "ammo" },
		ammo_57mm = { "weapon_p90", "ammo" },
		ammo_762nato = { "weapon_ak47", "ammo" },
		ammo_556nato = { "weapon_m4a1", "ammo" },
		ammo_556natobox = { "weapon_m249", "ammo" },
		ammo_338magnum = { "weapon_awp", "ammo" },
		ammo_buckshot = { "weapon_m3", "ammo" },
	}

	AMMO_USERS = {
		ammo_9mm = { { "weapon_glock18" }, { "weapon_elite" }, { "weapon_mp5navy" }, { "weapon_tmp" } },
		ammo_45acp = { { "weapon_usp" }, { "weapon_mac10" }, { "weapon_ump45" } },
		ammo_50ae = { { "weapon_deagle" } },
		ammo_357sig = { { "weapon_p228" } },
		ammo_57mm = { { "weapon_fiveseven" }, { "weapon_p90" } },
		ammo_762nato = { { "weapon_ak47" }, { "weapon_g3sg1" }, { "weapon_scout" } },
		ammo_556nato = { { "weapon_m4a1" }, { "weapon_sg552" }, { "weapon_aug" }, { "weapon_famas" }, { "weapon_galil" }, { "weapon_sg550" } },
		ammo_556natobox = { { "weapon_m249" } },
		ammo_338magnum = { { "weapon_awp" } },
		ammo_buckshot = { { "weapon_m3" }, { "weapon_xm1014" } },
	}
end

local HALF_LIFE_GAMES = { valve = true, gearbox = true, bshift = true }

local SECTION_ICONS = { weapon = "weapons", ammo = "ammo", item = "armor" }

local TEXT = { 236, 240, 248, 255 }
local MUTED = { 138, 148, 172, 255 }
local GOOD = { 80, 225, 130, 255 }
local BAD = { 245, 95, 95, 255 }
local ACCENT = { 0, 170, 255, 255 }

local function pretty(class)
	local name = class:gsub("^weapon_", ""):gsub("_", " ")
	return (name:gsub("(%a)([%w]*)", function(first, rest)
		return first:upper() .. rest
	end))
end

local function guess_icon(class, kind)
	if kind == "ammo" then
		return "ammo"
	end

	local name = class:lower()

	if name:find("knife") or name:find("crowbar") or name:find("wrench") then
		return "melee"
	elseif name:find("grenade") or name:find("flash") or name:find("satchel") or name:find("mine") or name:find("c4") then
		return "grenade"
	elseif name:find("handgun") or name:find("usp") or name:find("glock") or name:find("deagle") or name:find("eagle") or name:find("p228") or name:find("elite") or name:find("seven") or name:find("357") then
		return "weapons"
	end

	return "rifle"
end

local function build()
	local groups = GAMES[cc.game] or {}
	local sections = {}
	local known = {}

	for g = 1, #groups do
		local group = groups[g]

		for s = 1, #group.sections do
			local def = group.sections[s]
			local items = {}

			for i = 1, #def[3] do
				local entry = def[3][i]

				items[i] = {
					class = entry[1],
					name = entry[2],
					ammo = entry[3],
					icon = entry[4] or guess_icon(entry[1], def[2]),
					kind = def[2],
				}

				local item = items[i]

				if def[2] == "weapon" then
					item.file = "sprites/" .. entry[1] .. ".txt"
					item.entry = "weapon"
				elseif def[2] == "ammo" and AMMO_SOURCE[entry[1]] then
					item.file = "sprites/" .. AMMO_SOURCE[entry[1]][1] .. ".txt"
					item.entry = AMMO_SOURCE[entry[1]][2]
				elseif def[2] == "item" and ITEM_SOURCE[entry[1]] then
					item.file = "sprites/" .. ITEM_SOURCE[entry[1]][1] .. ".txt"
					item.entry = ITEM_SOURCE[entry[1]][2]
				end

				known[entry[1]:lower()] = true
			end

			sections[#sections + 1] = { title = group.title .. " - " .. def[1], kind = def[2], icon = SECTION_ICONS[def[2]], items = items }
		end
	end

	local extra = {}
	local files = cc.fs.Find("sprites/weapon_*.txt")

	for i = 1, #files do
		local name = files[i]:match("([^/]+)%.[Tt][Xx][Tt]$")

		if name and not known[name:lower()] then
			extra[#extra + 1] = name
		end
	end

	table.sort(extra)

	if #extra > 0 then
		local items = {}

		for i = 1, #extra do
			items[i] = { class = extra[i], name = pretty(extra[i]), icon = guess_icon(extra[i], "weapon"), kind = "weapon", file = "sprites/" .. extra[i] .. ".txt", entry = "weapon" }
		end

		sections[#sections + 1] = { title = "Other weapons", kind = "weapon", icon = "weapons", items = items }
	end

	return sections
end

local function parse_icon(file, entry)
	local text = cc.fs.Read(file, true)

	if not text then
		return nil
	end

	local best

	for line in text:gmatch("[^\r\n]+") do
		local tokens = {}

		for token in line:gmatch("%S+") do
			tokens[#tokens + 1] = token
		end

		if #tokens >= 7 and tokens[1] == entry then
			local res = tonumber(tokens[2])
			local x, y, w, h = tonumber(tokens[4]), tonumber(tokens[5]), tonumber(tokens[6]), tonumber(tokens[7])

			if res and x and y and w and h and w > 0 and h > 0 and (not best or math.abs(res - 640) < math.abs(best.res - 640)) then
				best = { res = res, sprite = "sprites/" .. tokens[3]:gsub("%.spr$", "") .. ".spr", x = x, y = y, w = w, h = h }
			end
		end
	end

	return best
end

local function draw_sprite(item, x, y, w, h, tint)
	if item.sprite == nil then
		item.sprite = item.file and parse_icon(item.file, item.entry) or false
	end

	local icon = item.sprite

	if not icon then
		return false
	end

	if icon.handle == nil then
		local handle = cc.draw.SpriteLoad(icon.sprite)
		icon.handle = handle > 0 and handle or false
	end

	if not icon.handle then
		return false
	end

	local scale = math.min(w / icon.w, h / icon.h)
	local dw = icon.w * scale
	local dh = icon.h * scale

	cc.draw.Sprite(icon.handle, 0, x + (w - dw) / 2, y + (h - dh) / 2, dw, dh, icon.x, icon.y, icon.w, icon.h, tint[1], tint[2], tint[3], tint[4])
	return true
end

local sections = build()
local owned = {}
local last_map = nil
local status = nil
local status_color = MUTED

local given_once = {}

local function users_state(class)
	local users = AMMO_USERS[class]

	if not users then
		return "unknown"
	end

	local owned_any = false
	local owned_unknown = false
	local all_full = true

	for i = 1, #users do
		local weapon = users[i][1]
		local has = cc.player.HasWeapon(weapon)

		if has == nil then
			owned_unknown = true
		elseif has then
			owned_any = true

			local current, limit = cc.player.Ammo(weapon, users[i][2])

			if not current or current < limit then
				all_full = false
			end
		end
	end

	if owned_any then
		return all_full and "full" or "ok"
	elseif owned_unknown then
		return "unknown"
	end

	return "none"
end

local function check(item)
	local info = cc.player.Get()
	local class = item.class

	if info.active and info.health and info.health <= 0 then
		return false, "You are dead."
	end

	if item.kind == "item" then
		if class == "item_suit" and info.suit then
			return false, "You already have the HEV suit."
		elseif class == "item_battery" then
			if info.armor >= 100 then
				return false, "Armor is already full."
			elseif HALF_LIFE_GAMES[cc.game] and info.active and not info.suit then
				return false, "You need the HEV suit first."
			end
		elseif class == "item_healthkit" and info.health and info.health >= 100 then
			return false, "Health is already full."
		elseif class == "item_longjump" and info.longjump then
			return false, "You already have the long jump module."
		elseif (class == "item_kevlar" or class == "item_assaultsuit") and info.armor >= 100 then
			return false, "Armor is already full."
		elseif class == "item_thighpack" and given_once[class] then
			return false, "You already have a defuse kit."
		end

		return true, class
	end

	if item.kind == "ammo" then
		local state = users_state(class)

		if state == "none" then
			return false, "You have no weapon that uses this ammo."
		elseif state == "full" then
			return false, "Ammo is already full."
		end

		return true, class
	end

	local has = cc.player.HasWeapon(class)

	if not has then
		return true, class
	end

	local current, limit = cc.player.Ammo(class)

	if item.ammo then
		if current and current >= limit then
			return false, "Ammo is already full."
		end

		return true, item.ammo
	end

	if current then
		if current >= limit then
			return false, "Ammo is already full."
		end

		return true, class
	end

	return false, "You already have this weapon."
end

local function press(item)
	local allowed, target = check(item)

	if not allowed then
		status = target
		status_color = BAD
		return
	end

	if cc.Give(target) then
		given_once[item.class] = true
		owned[item.class] = true
		status = target == item.class and ("Received " .. item.name) or ("Ammo for " .. item.name)
		status_color = GOOD
	else
		status = "Giving items needs a local game (single-player or a listen server)."
		status_color = BAD
	end
end

local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

local function draw_tile(ui, item, x, y, w, h)
	local ready = item.kind == "weapon" and cc.player.HasWeapon(item.class) or false
	local pad = math.floor(ui.line * 0.7)
	local area_h = h - ui.line * 3.3
	local tint = ready and { 255, 255, 255, 255 } or { 205, 212, 230, 255 }

	local drawn = draw_sprite(item, x + pad, y + pad, w - pad * 2, area_h - pad, tint)

	if not drawn then
		local size = math.floor(math.min(w - pad * 2, area_h - pad) * 0.8)
		cc.icon.Draw(item.icon, x + (w - size) / 2, y + pad + (area_h - pad - size) / 2, size, ready and ACCENT or MUTED)
	end

	local name_kind = ui:TextWidth(item.name) > w - pad and "small" or "regular"
	local name_w = ui:TextWidth(item.name, name_kind)
	ui:Text(x + (w - name_w) / 2, y + h - ui.line * 2.5, item.name, TEXT, name_kind)

	local hint = "get"

	if ready then
		local current, limit = cc.player.Ammo(item.class)

		if item.ammo or current then
			hint = current and current >= limit and "ammo full" or "+ ammo"
		else
			hint = "owned"
		end
	end

	local hint_w = ui:TextWidth(hint, "small")
	ui:Text(x + (w - hint_w) / 2, y + h - ui.line * 1.35, hint, ready and ACCENT or MUTED, "small")

	if ready then
		cc.draw.Rect(x + 8, y + h - 4, w - 16, 3, ACCENT[1], ACCENT[2], ACCENT[3], 255)
	end
end

cc.menu.AddTab("weapons", "Weapons", function(ui)
	local map = cc.Map()

	if map ~= last_map then
		last_map = map
		owned = {}
		given_once = {}
	end

	ui:Label(status or "Tap an item to get it. Tap a weapon again for ammo.", status and status_color or MUTED)

	if #sections == 0 then
		ui:Empty("No weapon definitions were found in " .. cc.game .. ".")
	end

	local columns = clamp(math.floor(ui.w / (ui.row * 3.0)), 2, 5)
	local tile_w = (ui.w - ui.gap * (columns - 1)) / columns

	for s = 1, #sections do
		local section = sections[s]
		local tile_h = section.kind == "weapon" and math.floor(tile_w * 0.78) or math.floor(tile_w * 0.68)

		ui:Section(section.title, section.icon)

		local picked = ui:Grid(#section.items, columns, tile_h, 0, function(i, x, y, w, h)
			draw_tile(ui, section.items[i], x, y, w, h)
		end)

		if picked then
			press(section.items[picked])
		end
	end

	local extra = cc.menu.GetEntries("weapons")

	if #extra > 0 then
		ui:Section("Addons", "addons")

		for i = 1, #extra do
			local entry = extra[i]

			if ui:Button(entry.name, entry.description, false, entry.icon or "weapons") then
				if type(entry.onClick) == "function" then
					local ok, err = pcall(entry.onClick, entry)

					if not ok then
						cc.log.Error("menu entry '" .. tostring(entry.name) .. "': " .. tostring(err))
					end
				end

				cc.hook.Run("MenuEntry", "weapons", entry)
			end
		end
	end
end, "weapons")

cc.weapons = {
	Check = check,
	Sections = function()
		return sections
	end,
}
