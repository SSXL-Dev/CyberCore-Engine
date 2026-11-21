if not CLIENT then
	return
end

local floor = math.floor

local C = {
	panel = { 17, 19, 27, 235 },
	border = { 58, 68, 96, 255 },
	hover = { 42, 48, 68, 245 },
	text = { 236, 240, 248, 255 },
	muted = { 138, 148, 172, 255 },
}

local state = { pressed = false, color = nil, flash = 0 }
local layout = { cards = {} }

local function box(x, y, w, h, fill, border)
	cc.draw.Rect(x, y, w, h, border[1], border[2], border[3], border[4])
	cc.draw.Rect(x + 1, y + 1, w - 2, h - 2, fill[1], fill[2], fill[3], fill[4])
end

local function compute()
	local sw = cc.screen.Width()
	local unit = cc.screen.Height() / 720
	local list = cc.mode.List()
	local gap = floor(8 * unit)
	local card_w = floor(190 * unit)
	local card_h = floor(66 * unit)
	local total = #list * card_w + (#list - 1) * gap
	local x = floor((sw - total) / 2)

	layout.unit = unit
	layout.title = floor(18 * unit)
	layout.small = floor(12 * unit)
	layout.list = list
	layout.cards = {}

	for i = 1, #list do
		layout.cards[i] = { x = x + (i - 1) * (card_w + gap), y = floor(14 * unit), w = card_w, h = card_h, id = list[i].id }
	end
end

local function inside(rect, x, y)
	return x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h
end

local function tint(target)
	if not state.color then
		state.color = { target[1], target[2], target[3] }
	end

	for i = 1, 3 do
		state.color[i] = state.color[i] + (target[i] - state.color[i]) * 0.12
	end

	local sw = cc.screen.Width()
	local sh = cc.screen.Height()
	local r, g, b = floor(state.color[1]), floor(state.color[2]), floor(state.color[3])
	local bands = 24
	local band_h = floor(sh * 0.5 / bands)

	cc.draw.Rect(0, 0, sw, sh, r, g, b, 18)

	for i = 0, bands - 1 do
		local alpha = floor(56 * (1 - i / bands) ^ 2)
		cc.draw.Rect(0, i * band_h, sw, band_h, r, g, b, alpha)
		cc.draw.Rect(0, sh - (i + 1) * band_h, sw, band_h, r, g, b, floor(alpha * 0.6))
	end

	if state.flash > 0.02 then
		cc.draw.Rect(0, 0, sw, sh, 255, 255, 255, floor(state.flash * 46))
		state.flash = state.flash * 0.82
	end
end

cc.hook.Add("MenuPaint", "cc.modemenu", function()
	compute()

	local current = cc.mode.Get()
	local def

	for i = 1, #layout.list do
		if layout.list[i].id == current then
			def = layout.list[i]
		end
	end

	tint(def and def.color or { 0, 170, 255 })

	for i = 1, #layout.cards do
		local rect = layout.cards[i]
		local mode = layout.list[i]
		local active = mode.id == current
		local color = mode.color or { 0, 170, 255 }
		local accent = { color[1], color[2], color[3], 255 }

		box(rect.x, rect.y, rect.w, rect.h, active and C.hover or C.panel, active and accent or C.border)
		cc.draw.Rect(rect.x + 1, rect.y + 1, rect.w - 2, floor(4 * layout.unit), accent[1], accent[2], accent[3], active and 255 or 120)

		local pad = floor(14 * layout.unit)
		local title_y = rect.y + floor(14 * layout.unit)
		cc.font.Draw(rect.x + pad, title_y, mode.name, layout.title, active and accent or C.text, true)

		local short_y = rect.y + rect.h - layout.small - floor(12 * layout.unit)
		cc.font.Draw(rect.x + pad, short_y, mode.short or mode.description or "", layout.small, C.muted, false)
	end
end)

cc.hook.Add("MenuTouch", "cc.modemenu", function(kind, finger, x, y)
	if kind == "down" then
		compute()
		state.pressed = false

		for i = 1, #layout.cards do
			if inside(layout.cards[i], x, y) then
				state.pressed = true

				if layout.cards[i].id ~= cc.mode.Get() then
					cc.mode.Set(layout.cards[i].id)
					state.flash = 1
				end

				return true
			end
		end

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
