if not CLIENT then
	return
end

local settings = cc.settings

local config = {
	enabled = settings.Get("crosshair_enabled", true),
	shape = settings.Get("crosshair_shape", "cross"),
	size = settings.Get("crosshair_size", 8),
	thickness = settings.Get("crosshair_thickness", 2),
	gap = settings.Get("crosshair_gap", 3),
	color = settings.Get("crosshair_color", { r = 0, g = 255, b = 0, a = 255 }),
}

local shapes = {}

function shapes.dot(cx, cy, c, cfg)
	local t = cfg.thickness
	cc.draw.Rect(cx - t / 2, cy - t / 2, t, t, c.r, c.g, c.b, c.a)
end

function shapes.cross(cx, cy, c, cfg)
	local s, t, g = cfg.size, cfg.thickness, cfg.gap
	local half = t / 2
	cc.draw.Rect(cx - g - s, cy - half, s, t, c.r, c.g, c.b, c.a)
	cc.draw.Rect(cx + g, cy - half, s, t, c.r, c.g, c.b, c.a)
	cc.draw.Rect(cx - half, cy - g - s, t, s, c.r, c.g, c.b, c.a)
	cc.draw.Rect(cx - half, cy + g, t, s, c.r, c.g, c.b, c.a)
end

function shapes.tee(cx, cy, c, cfg)
	local s, t, g = cfg.size, cfg.thickness, cfg.gap
	local half = t / 2
	cc.draw.Rect(cx - g - s, cy - half, s, t, c.r, c.g, c.b, c.a)
	cc.draw.Rect(cx + g, cy - half, s, t, c.r, c.g, c.b, c.a)
	cc.draw.Rect(cx - half, cy + g, t, s, c.r, c.g, c.b, c.a)
end

function shapes.circle(cx, cy, c, cfg)
	cc.draw.Circle(cx, cy, cfg.size, 32, cfg.thickness, c.r, c.g, c.b, c.a)
end

function shapes.square(cx, cy, c, cfg)
	local s, t = cfg.size, cfg.thickness
	cc.draw.Rect(cx - s, cy - s, s * 2, t, c.r, c.g, c.b, c.a)
	cc.draw.Rect(cx - s, cy + s - t, s * 2, t, c.r, c.g, c.b, c.a)
	cc.draw.Rect(cx - s, cy - s + t, t, s * 2 - t * 2, c.r, c.g, c.b, c.a)
	cc.draw.Rect(cx + s - t, cy - s + t, t, s * 2 - t * 2, c.r, c.g, c.b, c.a)
end

function shapes.crossdot(cx, cy, c, cfg)
	shapes.cross(cx, cy, c, cfg)
	shapes.dot(cx, cy, c, cfg)
end

function shapes.circledot(cx, cy, c, cfg)
	shapes.circle(cx, cy, c, cfg)
	shapes.dot(cx, cy, c, cfg)
end

local order = { "dot", "cross", "tee", "circle", "square", "crossdot", "circledot" }

local function apply()
	cc.hud.HideDefaultCrosshair(config.enabled)
end

cc.crosshair = {}

function cc.crosshair.Get(key)
	return config[key]
end

function cc.crosshair.Set(key, value)
	config[key] = value
	settings.Set("crosshair_" .. key, value)

	if key == "enabled" then
		apply()
	end
end

function cc.crosshair.Shapes()
	local names = {}

	for i = 1, #order do
		names[i] = order[i]
	end

	return names
end

function cc.crosshair.Draw(shape, cx, cy, color, cfg)
	local draw = shapes[shape]

	if draw then
		draw(cx, cy, color, cfg)
	end
end

local DEFAULTS = { enabled = true, shape = "cross", size = 8, thickness = 2, gap = 3 }

function cc.crosshair.Reset()
	for key, value in pairs(DEFAULTS) do
		cc.crosshair.Set(key, value)
	end

	cc.crosshair.Set("color", { r = 0, g = 255, b = 0, a = 255 })
end

cc.hook.Add("HUDPaint", "cc_crosshair", function()
	if not config.enabled then
		return
	end

	local draw = shapes[config.shape]

	if not draw then
		return
	end

	draw(cc.screen.Width() / 2, cc.screen.Height() / 2, config.color, config)
end)

apply()
