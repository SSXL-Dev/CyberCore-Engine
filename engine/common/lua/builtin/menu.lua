if not CLIENT then
	return
end

local settings = cc.settings

cc.menu = {}

local C = {
	dim = { 0, 0, 0, 175 },
	shadow = { 0, 0, 0, 110 },
	panel = { 17, 19, 27, 255 },
	border = { 58, 68, 96, 255 },
	headtop = { 34, 39, 56, 255 },
	headbot = { 22, 25, 36, 255 },
	card = { 31, 35, 49, 255 },
	cardhi = { 42, 48, 68, 255 },
	press = { 56, 66, 94, 255 },
	accent = { 0, 170, 255, 255 },
	accentdk = { 0, 105, 165, 255 },
	text = { 236, 240, 248, 255 },
	muted = { 138, 148, 172, 255 },
	good = { 80, 225, 130, 255 },
	bad = { 245, 95, 95, 255 },
	track = { 66, 73, 96, 255 },
	white = { 255, 255, 255, 255 },
	black = { 0, 0, 0, 255 },
}

local POSITIONS = { "left", "center", "right" }
local POSITION_LABELS = { "Left", "Center", "Right" }

local state = {
	open = false,
	tab = 1,
	scroll = 0,
	tab_scroll = 0,
	content_height = 0,
	position = settings.Get("menu_position", "center"),
	reload_hint = false,
}

local pointer = {
	finger = nil,
	down = false,
	released = false,
	x = 0,
	y = 0,
	start_x = 0,
	start_y = 0,
	moved = 0,
	dragging = false,
	dx = 0,
	dy = 0,
	captured = false,
}

local layout = {}
local tabs = {}
local entries = {}
local category_count = 0

local function in_list(list, value)
	for i = 1, #list do
		if list[i] == value then
			return true
		end
	end

	return false
end

if not in_list(POSITIONS, state.position) then
	state.position = "center"
end

local function clamp(value, low, high)
	if value < low then
		return low
	elseif value > high then
		return high
	end

	return value
end

local function floor(v)
	return math.floor(v)
end

local function hit(r, x, y)
	return r ~= nil and x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

local function fill(x, y, w, h, c, alpha)
	if w <= 0 or h <= 0 then
		return
	end

	cc.draw.Rect(floor(x), floor(y), floor(w), floor(h), c[1], c[2], c[3], alpha or c[4] or 255)
end

local function rr(x, y, w, h, c)
	fill(floor(x), floor(y), floor(w), floor(h), c)
end

local function card(x, y, w, h, body, edge, r)
	rr(x, y, w, h, edge, r)
	rr(x + 1, y + 1, w - 2, h - 2, body, math.max(0, (r or 0) - 1))
end

local function gradient(x, y, w, h, top, bottom)
	local steps = 8
	local step_h = h / steps

	for i = 0, steps - 1 do
		local t = i / (steps - 1)
		local c = {
			top[1] + (bottom[1] - top[1]) * t,
			top[2] + (bottom[2] - top[2]) * t,
			top[3] + (bottom[3] - top[3]) * t,
			255,
		}

		fill(x, y + floor(i * step_h), w, floor(step_h) + 1, { floor(c[1]), floor(c[2]), floor(c[3]), 255 })
	end
end

local font = { size = 16, line = 16, shift = 0 }

local STYLES = {
	regular = { scale = 1 },
	bold = { scale = 1, bold = true },
	small = { scale = 0.86 },
	title = { scale = 0.84, bold = true, spacing = 1.2 },
}

local function write(x, y, s, c, kind)
	local style = STYLES[kind or "regular"]

	if style.scale ~= 1 then
		y = y + (1 - style.scale) * font.size * 0.3
	end

	cc.font.Draw(floor(x), floor(y - font.shift), s, font.size * style.scale, c, style.bold, style.spacing)
end

local function text_width(s, kind)
	local style = STYLES[kind or "regular"]

	return cc.font.Width(s, font.size * style.scale, style.bold, style.spacing)
end

local function wrap(s, max_width)
	local lines = {}

	for paragraph in (s .. "\n"):gmatch("(.-)\n") do
		local line = ""

		for word in paragraph:gmatch("%S+") do
			local candidate = line == "" and word or (line .. " " .. word)

			if text_width(candidate) > max_width and line ~= "" then
				lines[#lines + 1] = line
				line = word
			else
				line = candidate
			end
		end

		lines[#lines + 1] = line
	end

	return lines
end

local function clicked(r)
	return pointer.released and not pointer.dragging and hit(r, pointer.start_x, pointer.start_y) and hit(r, pointer.x, pointer.y)
end

local function held(r)
	return pointer.down and not pointer.dragging and hit(r, pointer.start_x, pointer.start_y) and hit(r, pointer.x, pointer.y)
end

local function uclicked(r)
	return clicked(r) and hit(layout.content, pointer.start_x, pointer.start_y)
end

local function uheld(r)
	return held(r) and hit(layout.content, pointer.start_x, pointer.start_y)
end

local function make_ui(content, panel, line, row)
	local ui = {
		x = content.x,
		y = content.y,
		w = content.w,
		h = content.h,
		line = line,
		row = row,
		radius = math.max(3, floor(line * 0.45)),
		pad = floor(line * 0.9),
		gap = floor(line * 0.55),
		cursor = content.y - state.scroll,
	}

	function ui:visible(top, height)
		return top + height > content.y and top < content.y + content.h
	end

	function ui:Text(x, y, s, color, kind)
		write(x, y, s, color or C.text, kind)
	end

	function ui:TextWidth(s, kind)
		return text_width(s, kind)
	end

	function ui:Spacer(height)
		self.cursor = self.cursor + (height or self.gap)
	end

	function ui:Icon(name, r, color)
		if not name or not cc.icon or not cc.icon.Exists(name) then
			return 0
		end

		local size = floor(self.line * 1.7)

		cc.icon.Draw(name, r.x + self.pad, r.y + (r.h - size) / 2, size, color or C.accent)
		return size + floor(self.pad * 0.7)
	end

	function ui:Sub(x, w)
		local child = setmetatable({ x = x, w = w, cursor = self.cursor }, { __index = self })
		return child
	end

	function ui:Section(title, icon)
		local h = self.line * 1.4

		if self:visible(self.cursor, h) then
			fill(self.x, self.cursor + self.line * 0.15, 3, self.line * 0.95, C.accent)

			local shift = 10

			if icon and cc.icon and cc.icon.Exists(icon) then
				cc.icon.Draw(icon, self.x + 10, self.cursor + self.line * 0.05, floor(self.line * 1.2), C.accent)
				shift = 10 + floor(self.line * 1.2) + 6
			end

			write(self.x + shift, self.cursor + self.line * 0.1, title:upper(), C.muted, "title")
		end

		self.cursor = self.cursor + h + floor(self.gap * 0.5)
	end

	function ui:Label(s, color)
		local lines = wrap(s, self.w)
		local step = floor(self.line * 1.25)

		for i = 1, #lines do
			if self:visible(self.cursor, self.line) then
				write(self.x, self.cursor, lines[i], color or C.text)
			end

			self.cursor = self.cursor + step
		end

		self.cursor = self.cursor + self.gap
	end

	function ui:Empty(s)
		local lines = wrap(s, self.w - self.pad * 2)
		local h = #lines * floor(self.line * 1.25) + self.pad * 2

		if self:visible(self.cursor, h) then
			card(self.x, self.cursor, self.w, h, C.card, C.card, self.radius)

			for i = 1, #lines do
				local width = text_width(lines[i])
				write(self.x + (self.w - width) / 2, self.cursor + self.pad + (i - 1) * floor(self.line * 1.25), lines[i], C.muted)
			end
		end

		self.cursor = self.cursor + h + self.gap
	end

	function ui:Button(label, sub, primary, icon)
		local r = { x = self.x, y = self.cursor, w = self.w, h = sub and self.row * 1.15 or self.row }
		local result = false

		if self:visible(r.y, r.h) then
			local pressed = uheld(r)
			local body = primary and (pressed and C.accentdk or C.accent) or (pressed and C.press or C.card)
			local edge = primary and C.accent or (pressed and C.accent or C.border)

			card(r.x, r.y, r.w, r.h, body, edge, self.radius)

			local color = primary and C.black or C.text
			local lead = self:Icon(icon, r, primary and C.black or C.accent)

			if sub then
				write(r.x + self.pad + lead, r.y + self.line * 0.5, label, color)
				write(r.x + self.pad + lead, r.y + self.line * 0.5 + self.line * 1.25, sub, primary and C.black or C.muted, "small")
			else
				local kind = primary and "bold" or "regular"
				local width = primary and text_width(label, kind) or 0
				local tx = primary and r.x + (r.w - width) / 2 or r.x + self.pad + lead
				write(tx, r.y + (r.h - self.line) / 2, label, color, kind)
			end

			if not primary then
				write(r.x + r.w - self.pad - text_width(">"), r.y + (r.h - self.line) / 2, ">", C.muted)
			end

			result = uclicked(r)
		end

		self.cursor = self.cursor + r.h + self.gap
		return result
	end

	function ui:Choice(options, current)
		local count = #options
		local total_h = self.row * 0.9
		local cell = self.w / count
		local picked = nil
		local top = self.cursor

		if self:visible(top, total_h) then
			rr(self.x, top, self.w, total_h, C.card, self.radius)

			for i = 1, count do
				local r = { x = self.x + (i - 1) * cell, y = top, w = cell, h = total_h }
				local active = options[i] == current
				local inner = { x = r.x + 3, y = r.y + 3, w = r.w - 6, h = r.h - 6 }

				if active then
					rr(inner.x, inner.y, inner.w, inner.h, C.accent, self.radius)
				elseif uheld(r) then
					rr(inner.x, inner.y, inner.w, inner.h, C.press, self.radius)
				end

				local kind = active and "bold" or "regular"
				local width = text_width(options[i], kind)
				write(r.x + (r.w - width) / 2, r.y + (r.h - self.line) / 2, options[i], active and C.black or C.text, kind)

				if uclicked(r) then
					picked = i
				end
			end
		end

		self.cursor = self.cursor + total_h + self.gap
		return picked
	end

	function ui:Toggle(label, value, sub, icon)
		local r = { x = self.x, y = self.cursor, w = self.w, h = sub and self.row * 1.15 or self.row }
		local result = value

		if self:visible(r.y, r.h) then
			card(r.x, r.y, r.w, r.h, uheld(r) and C.cardhi or C.card, C.border, self.radius)

			local lead = self:Icon(icon, r, value and C.accent or C.muted)

			if sub then
				write(r.x + self.pad + lead, r.y + self.line * 0.5, label, C.text)
				write(r.x + self.pad + lead, r.y + self.line * 0.5 + self.line * 1.25, sub, C.muted, "small")
			else
				write(r.x + self.pad + lead, r.y + (r.h - self.line) / 2, label, C.text)
			end

			local sw = self.line * 2.8
			local sh = self.line * 1.5
			local sx = r.x + r.w - sw - self.pad
			local sy = r.y + (r.h - sh) / 2
			local knob = sh - 6

			rr(sx, sy, sw, sh, value and C.accent or C.track, self.radius)
			rr(value and (sx + sw - knob - 3) or (sx + 3), sy + 3, knob, knob, C.white, self.radius)

			if uclicked(r) then
				result = not value
			end
		end

		self.cursor = self.cursor + r.h + self.gap
		return result
	end

	function ui:Slider(label, value, low, high)
		local compact = self.compact
		local r = { x = self.x, y = self.cursor, w = self.w, h = compact and self.row or self.row * 1.05 }
		local result = value

		if self:visible(r.y, r.h) then
			card(r.x, r.y, r.w, r.h, C.card, C.border, self.radius)

			local shown = tostring(value)
			local tx, tw, ty
			local th = math.max(4, floor(self.line * 0.3))

			if compact then
				local label_w = floor(self.line * 6)
				local value_w = text_width("0000") + floor(self.line * 0.8)

				write(r.x + self.pad, r.y + (r.h - self.line) / 2, label, C.text)
				write(r.x + r.w - self.pad - text_width(shown), r.y + (r.h - self.line) / 2, shown, C.accent)

				tx = r.x + self.pad + label_w
				tw = r.w - self.pad * 2 - label_w - value_w
				ty = r.y + (r.h - th) / 2
			else
				write(r.x + self.pad, r.y + self.line * 0.45, label, C.text)
				write(r.x + r.w - self.pad - text_width(shown), r.y + self.line * 0.45, shown, C.accent)

				tx = r.x + self.pad
				tw = r.w - self.pad * 2
				ty = r.y + r.h - self.line * 0.9 - th / 2
			end

			local fraction = clamp((value - low) / (high - low), 0, 1)

			rr(tx, ty, tw, th, C.track, 2)
			rr(tx, ty, tw * fraction, th, C.accent, 2)

			local kw = math.max(10, floor(self.line * 0.9))
			local kh = floor(self.line * 1.3)
			card(tx + tw * fraction - kw / 2, ty + th / 2 - kh / 2, kw, kh, C.white, C.accent, 3)

			if pointer.down and hit(r, pointer.start_x, pointer.start_y) and hit(layout.content, pointer.start_x, pointer.start_y) then
				pointer.captured = true
				local t = clamp((pointer.x - tx) / tw, 0, 1)
				result = floor(low + t * (high - low) + 0.5)
			end
		end

		self.cursor = self.cursor + r.h + self.gap
		return result
	end

	function ui:Row(label, button_label)
		local button_w = text_width(button_label) + self.line * 2
		local r = { x = self.x + self.w - button_w, y = self.cursor, w = button_w, h = self.row }
		local result = false

		if self:visible(r.y, r.h) then
			write(self.x, r.y + (r.h - self.line) / 2, label, C.text)
			card(r.x, r.y, r.w, r.h, uheld(r) and C.press or C.card, C.border, self.radius)
			write(r.x + self.line, r.y + (r.h - self.line) / 2, button_label, C.text)
			result = uclicked(r)
		end

		self.cursor = self.cursor + self.row + self.gap
		return result
	end

	function ui:Preview(height, draw)
		local r = { x = self.x, y = self.cursor, w = self.w, h = height }

		if self:visible(r.y, r.h) then
			card(r.x, r.y, r.w, r.h, { 12, 14, 20, 255 }, C.border, self.radius)

			local cx = r.x + r.w / 2
			local cy = r.y + r.h / 2
			local grid = { 24, 28, 40, 255 }

			local step = self.line * 2
			local gx = floor((r.w / 2 - 3) / step)
			local gy = floor((r.h / 2 - 3) / step)

			for i = -gx, gx do
				fill(cx + i * step, r.y + 2, 1, r.h - 4, grid)
			end

			for i = -gy, gy do
				fill(r.x + 2, cy + i * step, r.w - 4, 1, grid)
			end

			draw(cx, cy)
		end

		self.cursor = self.cursor + height + self.gap
	end

	function ui:Grid(count, columns, tile_h, selected, draw)
		local gap = self.gap
		local tile_w = (self.w - gap * (columns - 1)) / columns

		if tile_h == "square" then
			tile_h = floor(tile_w)
		end

		local picked = nil
		local rows = math.ceil(count / columns)

		for index = 1, count do
			local col = (index - 1) % columns
			local line_index = floor((index - 1) / columns)
			local r = {
				x = self.x + col * (tile_w + gap),
				y = self.cursor + line_index * (tile_h + gap),
				w = tile_w,
				h = tile_h,
			}

			if self:visible(r.y, r.h) then
				local active = index == selected
				local body = active and C.cardhi or (uheld(r) and C.press or C.card)

				card(r.x, r.y, r.w, r.h, body, active and C.accent or C.border, self.radius)

				if active then
					fill(r.x + 4, r.y + r.h - 4, r.w - 8, 3, C.accent)
				end

				draw(index, r.x, r.y, r.w, r.h, active)

				if uclicked(r) then
					picked = index
				end
			end
		end

		self.cursor = self.cursor + rows * (tile_h + gap)
		return picked
	end

	return ui
end

local function find_tab(id)
	for i = 1, #tabs do
		if tabs[i].id == id then
			return i
		end
	end

	return nil
end

function cc.menu.AddTab(id, title, draw, icon)
	local index = find_tab(id)

	if index then
		tabs[index].title = title
		tabs[index].draw = draw
		tabs[index].icon = icon or tabs[index].icon
		return
	end

	tabs[#tabs + 1] = { id = id, title = title, draw = draw, icon = icon or id }
end

function cc.menu.RemoveTab(id)
	local index = find_tab(id)

	if index then
		table.remove(tabs, index)
	end
end

local notice = nil

local function run_entry(category, entry)
	if type(entry.onClick) == "function" then
		local ok, result = pcall(entry.onClick, entry)

		if not ok then
			cc.log.Error("menu entry '" .. tostring(entry.name) .. "': " .. tostring(result))
		elseif type(result) == "string" then
			notice = { category = category, text = result }
		end
	end

	cc.hook.Run("MenuEntry", category, entry)
end

local function draw_tiles(category)
	return function(ui)
		local list = entries[category] or {}

		if #list == 0 then
			ui:Empty("Nothing here yet.\nScripts add items with cc.menu.AddEntry(\"" .. category .. "\", { name = ..., description = ..., onClick = ... })")
			return
		end

		if notice and notice.category == category then
			ui:Label(notice.text, C.muted)
		end

		local columns = clamp(floor(ui.w / (ui.row * 3)), 2, 4)

		local picked = ui:Grid(#list, columns, "square", 0, function(i, x, y, w, h)
			local entry = list[i]
			local size = floor(math.min(w, h) * 0.42)
			local icon = entry.icon or category
			local texture = entry.image and cc.draw.ImageLoad and cc.draw.ImageLoad(entry.image) or 0

			if texture > 0 then
				local box_h = floor(h - ui.line * 3.4)
				local box_w = floor(box_h * (entry.image_w or 164) / (entry.image_h or 200))

				if box_w > w - 8 then
					box_w = w - 8
					box_h = floor(box_w * (entry.image_h or 200) / (entry.image_w or 164))
				end

				cc.draw.Image(texture, x + floor((w - box_w) / 2), y + 6, box_w, box_h, 255, 255, 255, 255)
			elseif cc.icon and cc.icon.Exists(icon) then
				cc.icon.Draw(icon, x + floor((w - size) / 2), y + floor(h * 0.14), size, C.accent)
			end

			local kind = ui:TextWidth(entry.name) > w - 12 and "small" or "regular"
			local name_w = ui:TextWidth(entry.name, kind)
			ui:Text(x + floor((w - name_w) / 2), y + h - floor(ui.line * 2.5), entry.name, C.text, kind)
		end)

		if picked then
			run_entry(category, list[picked])
		end
	end
end

local function draw_entries(category)
	if category == "nextbots" then
		return draw_tiles(category)
	end

	return function(ui)
		local list = entries[category] or {}

		if #list == 0 then
			ui:Empty("Nothing here yet.\nScripts add items with cc.menu.AddEntry(\"" .. category .. "\", { name = ..., description = ..., onClick = ... })")
			return
		end

		if notice and notice.category == category then
			ui:Label(notice.text, C.muted)
		end

		for i = 1, #list do
			local entry = list[i]

			if ui:Button(entry.name, entry.description, false, entry.icon or category) then
				run_entry(category, entry)
			end
		end
	end
end

local function ensure_category(category, title)
	if find_tab(category) then
		return
	end

	category_count = category_count + 1
	table.insert(tabs, category_count, { id = category, title = title or category, draw = draw_entries(category), icon = category })
end

function cc.menu.AddEntry(category, entry)
	if type(category) ~= "string" or type(entry) ~= "table" or type(entry.name) ~= "string" then
		cc.log.Error("menu.AddEntry: expected (category, { name = string })")
		return
	end

	ensure_category(category)

	local list = entries[category]

	if not list then
		list = {}
		entries[category] = list
	end

	list[#list + 1] = entry
end

local function switch_tab(index)
	local old = tabs[state.tab]

	if old then
		old.scroll = state.scroll
	end

	state.tab = index
	state.reveal = true
	state.scroll = tabs[index].scroll or 0
	settings.Set("menu_tab", tabs[index].id)
end

function cc.menu.SelectTab(id)
	local index = find_tab(id)

	if index then
		switch_tab(index)
	end
end

function cc.menu.GetEntries(category)
	return entries[category] or {}
end

function cc.menu.Open()
	state.open = true
end

function cc.menu.Close()
	state.open = false
end

function cc.menu.Toggle()
	state.open = not state.open
end

function cc.menu.IsOpen()
	return state.open
end

ensure_category("weapons", "Weapons")
ensure_category("entities", "Entities")
ensure_category("modes", "Modes")
ensure_category("nextbots", "NextBots")

local function request_reload()
	state.reload_hint = false
	cc.Reload()
end

cc.menu.AddTab("addons", "Addons", function(ui)
	local list = cc.addons

	if #list == 0 then
		ui:Empty("No addons found in " .. cc.game .. "/addons")
	end

	for i = 1, #list do
		local addon = list[i]
		local value = ui:Toggle(addon.name, addon.enabled, addon.enabled and "Enabled" or "Disabled", "addons")

		if value ~= addon.enabled then
			cc.addon.SetEnabled(addon.name, value)
			state.reload_hint = true
		end
	end

	if state.reload_hint then
		ui:Label("Changes apply after reloading scripts.", C.accent)
	end

	if ui:Button("Reload scripts", nil, true) then
		request_reload()
	end
end)

cc.menu.AddTab("scripts", "Scripts", function(ui)
	local list = cc.scripts
	local failed = 0

	for i = 1, #list do
		if not list[i].ok then
			failed = failed + 1
		end
	end

	ui:Section(#list .. " scripts, " .. failed .. " failed", "scripts")

	if #list == 0 then
		ui:Empty("No scripts loaded.")
	end

	for i = 1, #list do
		local script = list[i]
		local r = { x = ui.x, y = ui.cursor, w = ui.w, h = floor(ui.line * 1.9) }

		if ui:visible(r.y, r.h) then
			card(r.x, r.y, r.w, r.h, C.card, C.card, ui.radius)
			rr(r.x + ui.pad, r.y + (r.h - ui.line * 0.6) / 2, ui.line * 0.6, ui.line * 0.6, script.ok and C.good or C.bad, 2)
			write(r.x + ui.pad * 2.2, r.y + (r.h - ui.line) / 2, script.path, script.ok and C.text or C.bad)
		end

		ui.cursor = ui.cursor + r.h + floor(ui.gap * 0.5)
	end

	ui:Spacer()

	if failed > 0 then
		ui:Label("Failed scripts are explained in lua.log.", C.muted)
	end

	if ui:Button("Reload scripts", nil, true) then
		request_reload()
	end
end)

local SHAPE_LABELS = {
	dot = "Dot",
	cross = "Cross",
	tee = "T",
	circle = "Ring",
	square = "Box",
	crossdot = "Cross+Dot",
	circledot = "Ring+Dot",
}

local PRESETS = {
	{ r = 0, g = 255, b = 0 },
	{ r = 255, g = 40, b = 40 },
	{ r = 255, g = 255, b = 255 },
	{ r = 0, g = 220, b = 255 },
	{ r = 255, g = 230, b = 0 },
	{ r = 255, g = 80, b = 200 },
	{ r = 255, g = 140, b = 0 },
	{ r = 170, g = 90, b = 255 },
}

local function preset_index(color)
	for i = 1, #PRESETS do
		local p = PRESETS[i]

		if p.r == color.r and p.g == color.g and p.b == color.b then
			return i
		end
	end

	return nil
end

local function live_config(crosshair)
	return {
		size = crosshair.Get("size"),
		thickness = crosshair.Get("thickness"),
		gap = crosshair.Get("gap"),
	}
end

local function crosshair_left(ui, crosshair, color)
	local enabled = ui:Toggle("Crosshair", crosshair.Get("enabled"), "Replaces the game crosshair", "crosshair")

	if enabled ~= crosshair.Get("enabled") then
		crosshair.Set("enabled", enabled)
	end

	ui:Section("Shape")

	local shapes = crosshair.Shapes()
	local selected = 1

	for i = 1, #shapes do
		if shapes[i] == crosshair.Get("shape") then
			selected = i
		end
	end

	local columns = clamp(floor(ui.w / (ui.row * 1.5)), 3, 5)

	local picked = ui:Grid(#shapes, columns, "square", selected, function(i, x, y, w, h, active)
		local icon = {
			size = math.min(crosshair.Get("size"), floor(h * 0.2)),
			thickness = math.min(crosshair.Get("thickness"), 3),
			gap = math.min(crosshair.Get("gap"), 4),
		}
		local tint = active and { r = color.r, g = color.g, b = color.b, a = 255 } or { r = 200, g = 205, b = 220, a = 255 }

		crosshair.Draw(shapes[i], x + w / 2, y + h * 0.42, tint, icon)

		local label = SHAPE_LABELS[shapes[i]] or shapes[i]
		local kind = text_width(label) > w - 8 and "small" or "regular"
		write(x + (w - text_width(label, kind)) / 2, y + h - ui.line * 1.45, label, active and C.text or C.muted, kind)
	end)

	if picked then
		crosshair.Set("shape", shapes[picked])
	end

	ui:Section("Size")
	ui.row = floor(ui.row * 0.78)
	ui.compact = true

	local size = ui:Slider("Size", crosshair.Get("size"), 1, 40)

	if size ~= crosshair.Get("size") then
		crosshair.Set("size", size)
	end

	local thickness = ui:Slider("Thickness", crosshair.Get("thickness"), 1, 10)

	if thickness ~= crosshair.Get("thickness") then
		crosshair.Set("thickness", thickness)
	end

	local gap = ui:Slider("Gap", crosshair.Get("gap"), 0, 20)

	if gap ~= crosshair.Get("gap") then
		crosshair.Set("gap", gap)
	end

	ui.compact = false
	ui.row = floor(ui.row / 0.78)

	if ui:Button("Reset to default", nil, false, "settings") then
		crosshair.Reset()
	end
end

local function crosshair_right(ui, crosshair, color)
	ui:Preview(floor(ui.row * 2.4), function(cx, cy)
		crosshair.Draw(crosshair.Get("shape"), cx, cy, color, live_config(crosshair))
	end)

	ui:Section("Color")

	local swatch = ui:Grid(#PRESETS, 8, "square", preset_index(color) or 0, function(i, x, y, w, h)
		local p = PRESETS[i]
		rr(x + 5, y + 5, w - 10, h - 10, { p.r, p.g, p.b, 255 }, 4)
	end)

	if swatch then
		local p = PRESETS[swatch]
		crosshair.Set("color", { r = p.r, g = p.g, b = p.b, a = color.a })
		color = crosshair.Get("color")
	end

	ui.row = floor(ui.row * 0.78)
	ui.compact = true

	local r = ui:Slider("Red", color.r, 0, 255)
	local g = ui:Slider("Green", color.g, 0, 255)
	local b = ui:Slider("Blue", color.b, 0, 255)
	local a = ui:Slider("Opacity", color.a, 20, 255)

	if r ~= color.r or g ~= color.g or b ~= color.b or a ~= color.a then
		crosshair.Set("color", { r = r, g = g, b = b, a = a })
	end
end

cc.menu.AddTab("crosshair", "Crosshair", function(ui)
	local crosshair = cc.crosshair

	if not crosshair then
		ui:Empty("The crosshair script is not available.")
		return
	end

	local color = crosshair.Get("color")

	if ui.w < ui.line * 36 then
		crosshair_left(ui, crosshair, color)
		ui:Spacer()
		crosshair_right(ui, crosshair, crosshair.Get("color"))
		return
	end

	local gap = ui.pad
	local half = floor((ui.w - gap) / 2)
	local left = ui:Sub(ui.x, half)
	local right = ui:Sub(ui.x + half + gap, half)

	crosshair_left(left, crosshair, color)
	crosshair_right(right, crosshair, color)

	ui.cursor = math.max(left.cursor, right.cursor)
end)

cc.menu.AddTab("settings", "Settings", function(ui)
	ui:Section("Menu button position", "settings")

	local current = POSITION_LABELS[2]

	for i = 1, #POSITIONS do
		if POSITIONS[i] == state.position then
			current = POSITION_LABELS[i]
		end
	end

	local picked = ui:Choice(POSITION_LABELS, current)

	if picked then
		state.position = POSITIONS[picked]
		settings.Set("menu_position", state.position)
	end

	ui:Section("High definition content", "settings")

	if cc.hd.Available() then
		local enabled = cc.hd.Enabled()
		local value = ui:Toggle("HD content", enabled, cc.game .. "_hd", "settings")

		if value ~= enabled then
			cc.hd.Set(value)
			state.hd_notice = true
		end

		if state.hd_notice then
			ui:Label("To apply it, leave the current game and enter again: start a new local game or single player, or load a save.", C.accent)
		end
	else
		ui:Empty("No " .. cc.game .. "_hd folder was found next to the game folder.")
	end

	ui:Section("Defaults", "settings")

	if ui:Button("Restore menu defaults", "Button position and remembered tab", false, "settings") then
		state.position = "center"
		settings.Set("menu_position", "center")
		settings.Set("menu_tab", "")
	end

	if ui:Button("Restore crosshair defaults", nil, false, "crosshair") and cc.crosshair then
		cc.crosshair.Reset()
	end

	ui:Section("Scripts", "scripts")
	ui:Label("CyberCore Engine " .. cc.version, C.muted)
	ui:Label("Game folder: " .. cc.game, C.muted)
	ui:Label("Script errors are written to lua.log next to engine.log.", C.muted)

	if cc.player.Report and ui:Button("Write player report", "Weapons, ammo and ownership are saved to lua.log", false, "tool") then
		cc.player.Report()
	end

	if ui:Button("Reload scripts", nil, true) then
		request_reload()
	end
end)

local function metrics()
	local width = cc.screen.Width()
	local height = cc.screen.Height()
	local _, line = cc.draw.TextSize("Ag")

	if line <= 0 then
		line = 16
	end

	font.size = math.max(10, floor(line * 1.08 + 0.5))
	font.line = line
	font.shift = floor((cc.font.Height(font.size) - line) / 2)

	return width, height, line
end

local function toggle_rect(width, line)
	local w = math.max(text_width("MENU"), text_width("CLOSE")) + line * 4.6
	local h = line * 2.5
	local margin = line * 0.8
	local x

	if state.position == "left" then
		x = margin
	elseif state.position == "right" then
		x = width - w - margin
	else
		x = (width - w) / 2
	end

	return { x = floor(x), y = floor(margin), w = floor(w), h = floor(h) }
end

local function draw_bar(bar, line, radius)
	gradient(bar.x, bar.y, bar.w, bar.h, C.headtop, C.headbot)
	fill(bar.x, bar.y + bar.h - 1, bar.w, 1, C.border)

	local title = "CYBERCORE"
	local title_w = text_width(title, "title") + line * 1.6

	write(bar.x + line * 0.8, bar.y + (bar.h - line) / 2, title, C.accent, "title")
	fill(bar.x + title_w, bar.y + bar.h * 0.2, 1, bar.h * 0.6, C.border)

	local area = { x = bar.x + title_w + 1, y = bar.y, w = bar.w - title_w - 1, h = bar.h }

	layout.tabarea = area

	local icon_size = floor(line * 1.5)
	local gap = floor(line * 0.5)
	local full = {}
	local small = {}
	local compact = {}
	local full_total = 0
	local small_total = 0
	local compact_total = 0

	for i = 1, #tabs do
		local has_icon = tabs[i].icon and cc.icon and cc.icon.Exists(tabs[i].icon)
		tabs[i].has_icon = has_icon and true or false
		local lead = has_icon and icon_size + gap or 0
		local active_kind = i == state.tab and "bold" or nil
		full[i] = text_width(tabs[i].title, active_kind) + line * 1.8 + lead
		small[i] = text_width(tabs[i].title, active_kind or "small") + line * 1.4 + lead
		compact[i] = has_icon and i ~= state.tab and icon_size + line * 1.8 or full[i]
		full_total = full_total + full[i]
		small_total = small_total + small[i]
		compact_total = compact_total + compact[i]
	end

	local widths, total, label_kind = compact, compact_total, "regular"

	if full_total <= area.w then
		widths, total = full, full_total
	elseif small_total <= area.w then
		widths, total, label_kind = small, small_total, "small"
	end

	state.tab_scroll = clamp(state.tab_scroll, 0, math.max(0, total - area.w))

	if state.reveal and total > area.w then
		local left = 0

		for i = 1, state.tab - 1 do
			left = left + widths[i]
		end

		local right = left + widths[state.tab]

		if left < state.tab_scroll then
			state.tab_scroll = left
		elseif right > state.tab_scroll + area.w then
			state.tab_scroll = right - area.w
		end
	end

	state.reveal = false

	cc.draw.SetClip(area.x, area.y, area.w, area.h)

	local tx = area.x - state.tab_scroll

	for i = 1, #tabs do
		local r = { x = tx, y = area.y, w = widths[i], h = area.h }

		if r.x < area.x + area.w and r.x + r.w > area.x then
			local active = i == state.tab
			local labeled = widths ~= compact or widths[i] == full[i]

			if active then
				fill(r.x, r.y + r.h - 4, r.w, 3, C.accent)
			elseif held(r) then
				fill(r.x, r.y, r.w, r.h - 1, C.press, 90)
			end

			local lead = labeled and line * 0.9 or (r.w - icon_size) / 2

			if tabs[i].has_icon then
				cc.icon.Draw(tabs[i].icon, r.x + lead, r.y + (r.h - icon_size) / 2 - 1, icon_size, active and C.accent or C.muted)
				lead = lead + icon_size + gap
			end

			if labeled then
				local kind = active and "bold" or label_kind
				write(r.x + lead, r.y + (r.h - line) / 2, tabs[i].title, active and C.text or C.muted, kind)
			end

			if clicked(r) and hit(area, pointer.start_x, pointer.start_y) and i ~= state.tab then
				switch_tab(i)
			end
		end

		tx = tx + widths[i]
	end

	cc.draw.ClearClip()

	state.tab = clamp(state.tab, 1, #tabs)
end

local function draw_panel(width, height, line)
	if not state.restored then
		state.restored = true

		local saved = find_tab(settings.Get("menu_tab", ""))

		if saved then
			state.tab = saved
			state.reveal = true
		end
	end

	local top = layout.toggle.y + layout.toggle.h + line * 0.6
	local panel_w = math.min(width * 0.7, line * 54)
	local panel_h = math.min(height - top - line * 1.6, line * 38)
	local panel = { x = floor((width - panel_w) / 2), y = floor(top), w = floor(panel_w), h = floor(panel_h) }
	local radius = math.max(4, floor(line * 0.6))
	local pad = floor(line * 1.1)
	local bar = { x = panel.x + 2, y = panel.y + 2, w = panel.w - 4, h = floor(line * 2.7) }
	local content = {
		x = panel.x + pad,
		y = bar.y + bar.h + pad,
		w = panel.w - pad * 2 - 6,
		h = panel.h - (bar.y + bar.h - panel.y) - pad * 2,
	}

	layout.panel = panel
	layout.bar = bar
	layout.content = content

	fill(0, 0, width, height, C.dim)
	rr(panel.x + 4, panel.y + 6, panel.w, panel.h, C.shadow, radius + 2)
	card(panel.x, panel.y, panel.w, panel.h, C.panel, C.border, radius + 1)

	local ui = make_ui(content, panel, line, math.max(floor(line * 2.5), floor(height * 0.07)))
	local tab = tabs[clamp(state.tab, 1, #tabs)]
	cc.draw.SetClip(content.x, content.y, content.w, content.h)
	local ok, err = pcall(tab.draw, ui)
	cc.draw.ClearClip()

	if not ok then
		cc.log.Error("menu tab '" .. tostring(tab.id) .. "': " .. tostring(err))
		cc.menu.RemoveTab(tab.id)
	end

	fill(panel.x + 2, bar.y + bar.h, panel.w - 4, content.y - (bar.y + bar.h), C.panel)
	fill(panel.x + 2, content.y + content.h, panel.w - 4, panel.y + panel.h - 2 - (content.y + content.h), C.panel)

	draw_bar(bar, line, radius)

	state.content_height = ui.cursor - (content.y - state.scroll)
	state.scroll = clamp(state.scroll, 0, math.max(0, state.content_height - content.h))

	if state.content_height > content.h then
		local track_x = panel.x + panel.w - 7
		local thumb_h = math.max(line * 2, content.h * content.h / state.content_height)
		local thumb_y = content.y + (content.h - thumb_h) * state.scroll / (state.content_height - content.h)

		rr(track_x, content.y, 3, content.h, C.card, 1)
		rr(track_x, thumb_y, 3, thumb_h, C.accent, 1)
	end
end

local function draw_toggle(line)
	local t = layout.toggle
	local label = state.open and "CLOSE" or "MENU"
	local pressed = held(t)
	local radius = floor(t.h / 2)

	rr(t.x - 3, t.y - 3, t.w + 6, t.h + 6, { 0, 170, 255, state.open and 70 or 38 }, radius + 3)
	rr(t.x + 2, t.y + 4, t.w, t.h, C.shadow, radius)
	rr(t.x, t.y, t.w, t.h, C.accent, radius)
	rr(t.x + 2, t.y + 2, t.w - 4, t.h - 4, pressed and C.press or C.headtop, radius - 2)

	local d = t.h - 10
	local bx = t.x + 5
	local by = t.y + 5
	local cx = bx + d / 2
	local cy = by + d / 2

	rr(bx, by, d, d, C.accent, floor(d / 2))

	if state.open then
		local n = floor(d * 0.2)

		for k = -n, n do
			fill(cx + k - 1, cy + k - 1, 3, 3, C.black)
			fill(cx + k - 1, cy - k - 1, 3, 3, C.black)
		end
	else
		local bw = floor(d * 0.46)

		for i = -1, 1 do
			fill(cx - bw / 2, cy + i * d * 0.2 - 1, bw, 3, C.black)
		end
	end

	local label_w = text_width(label)
	local area_x = t.x + d + 10

	write(area_x + (t.x + t.w - 8 - area_x - label_w) / 2, t.y + (t.h - line) / 2, label, C.text)
end

cc.hook.Add("HUDPaint", "cc_menu", function()
	local width, height, line = metrics()
	layout.toggle = toggle_rect(width, line)
	pointer.captured = false
	cc.hud.HideTouch(state.open)

	if state.open then
		draw_panel(width, height, line)
	else
		layout.panel = nil
		layout.bar = nil
		layout.content = nil
	end

	draw_toggle(line)

	if clicked(layout.toggle) then
		state.open = not state.open
	end

	if pointer.dragging and pointer.down and not pointer.captured and state.open then
		if hit(layout.tabarea, pointer.start_x, pointer.start_y) then
			state.tab_scroll = state.tab_scroll - pointer.dx
		elseif hit(layout.content, pointer.start_x, pointer.start_y) then
			state.scroll = state.scroll - pointer.dy
		end
	end

	pointer.dx = 0
	pointer.dy = 0

	if pointer.released then
		pointer.released = false
		pointer.dragging = false
		pointer.finger = nil
	end
end)

cc.hook.Add("Touch", "cc_menu", function(kind, finger, x, y)
	if pointer.finger ~= nil and pointer.finger ~= finger then
		return state.open
	end

	if kind == "down" then
		if not state.open and not hit(layout.toggle, x, y) then
			return false
		end

		pointer.finger = finger
		pointer.down = true
		pointer.released = false
		pointer.dragging = false
		pointer.start_x = x
		pointer.start_y = y
		pointer.x = x
		pointer.y = y
		pointer.moved = 0
		pointer.dx = 0
		pointer.dy = 0
		return true
	end

	if pointer.finger ~= finger then
		return state.open
	end

	if kind == "motion" then
		pointer.dx = pointer.dx + (x - pointer.x)
		pointer.dy = pointer.dy + (y - pointer.y)
		pointer.moved = pointer.moved + math.abs(x - pointer.x) + math.abs(y - pointer.y)
		pointer.x = x
		pointer.y = y

		if pointer.moved > 24 then
			pointer.dragging = true
		end

		return true
	end

	pointer.x = x
	pointer.y = y
	pointer.down = false
	pointer.released = true
	return true
end)
