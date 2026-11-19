if not CLIENT then
	return
end

local floor = math.floor

local C = {
	panel = { 17, 19, 27, 235 },
	border = { 58, 68, 96, 255 },
	card = { 31, 35, 49, 255 },
	hover = { 42, 48, 68, 255 },
	accent = { 0, 170, 255, 255 },
	text = { 236, 240, 248, 255 },
	muted = { 138, 148, 172, 255 },
}

local state = { open = false, pressed = false }
local layout = { x = 0, y = 0, w = 0, h = 0, rows = {} }

local function box(x, y, w, h, fill, border)
	cc.draw.Rect(x, y, w, h, border[1], border[2], border[3], border[4])
	cc.draw.Rect(x + 1, y + 1, w - 2, h - 2, fill[1], fill[2], fill[3], fill[4])
end

local function compute()
	local sh = cc.screen.Height()
	local unit = sh / 720
	local pad = floor(16 * unit)
	local row = floor(40 * unit)
	local text = floor(18 * unit)
	local list = cc.mode.List()
	local width = 0

	for i = 1, #list do
		width = math.max(width, cc.font.Width(list[i].name, text, false))
	end

	width = math.max(width + floor(48 * unit), floor(210 * unit))

	layout.unit = unit
	layout.text = text
	layout.small = floor(12 * unit)
	layout.pad = pad
	layout.row = row
	layout.w = width
	layout.x = pad
	layout.y = sh - pad - row
	layout.h = row
	layout.list = list
	layout.rows = {}

	if state.open then
		for i = 1, #list do
			layout.rows[i] = { x = pad, y = layout.y - i * row, w = width, h = row, id = list[i].id }
		end
	end
end

local function inside(rect, x, y)
	return x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h
end

cc.hook.Add("MenuPaint", "cc.modemenu", function()
	compute()

	local current = cc.mode.Get()
	local label_y = layout.y - floor(layout.small * 1.6)

	if not state.open then
		cc.font.Draw(layout.x, label_y, "GAME MODE", layout.small, C.muted, true, 1)
	end

	for i = 1, #layout.rows do
		local rect = layout.rows[i]
		local active = rect.id == current

		box(rect.x, rect.y, rect.w, rect.h, active and C.hover or C.card, C.border)

		if active then
			cc.draw.Rect(rect.x + 1, rect.y + 1, floor(4 * layout.unit), rect.h - 2, C.accent[1], C.accent[2], C.accent[3], 255)
		end

		local name = layout.list[i].name
		local ty = rect.y + floor((rect.h - cc.font.Height(layout.text, false)) / 2)
		cc.font.Draw(rect.x + floor(16 * layout.unit), ty, name, layout.text, active and C.accent or C.text, false)
	end

	box(layout.x, layout.y, layout.w, layout.h, state.open and C.hover or C.panel, state.open and C.accent or C.border)

	local ty = layout.y + floor((layout.h - cc.font.Height(layout.text, true)) / 2)
	cc.font.Draw(layout.x + floor(16 * layout.unit), ty, cc.mode.Name(), layout.text, C.text, true)

	local arrow = state.open and "v" or "^"
	local aw = cc.font.Width(arrow, layout.text, true)
	cc.font.Draw(layout.x + layout.w - aw - floor(14 * layout.unit), ty, arrow, layout.text, C.accent, true)
end)

cc.hook.Add("MenuTouch", "cc.modemenu", function(kind, finger, x, y)
	if kind == "down" then
		compute()
		state.pressed = false

		if inside(layout, x, y) then
			state.pressed = true
			state.open = not state.open
			return true
		end

		for i = 1, #layout.rows do
			if inside(layout.rows[i], x, y) then
				cc.mode.Set(layout.rows[i].id)
				state.open = false
				state.pressed = true
				return true
			end
		end

		state.open = false
		return nil
	end

	if state.pressed then
		if kind == "up" then
			state.pressed = false
		end

		return true
	end

	return nil
end)
