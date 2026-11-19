if not CLIENT then
	return
end

cc.font = {}

local floor = math.floor
local decoded = {}
local decoded_count = 0

local function codes(text)
	local list = decoded[text]

	if list then
		return list
	end

	list = {}

	if utf8.len(text) then
		for _, code in utf8.codes(text) do
			list[#list + 1] = code
		end
	else
		for i = 1, #text do
			list[i] = text:byte(i)
		end
	end

	if decoded_count > 2000 then
		decoded = {}
		decoded_count = 0
	end

	decoded[text] = list
	decoded_count = decoded_count + 1

	return list
end

local function style(bold)
	local data = cc.fontdata

	if not data then
		return nil
	end

	return bold and data.bold or data.regular, data.em
end

local function glyph_for(set, code)
	return set.glyphs[code] or set.glyphs[63]
end

function cc.font.Height(size, bold)
	local set, em = style(bold)

	if not set then
		return size
	end

	return set.height * size / em
end

function cc.font.Width(text, size, bold, spacing)
	local set, em = style(bold)

	if not set then
		return (cc.draw.TextSize(text))
	end

	local list = codes(text)
	local total = 0

	for i = 1, #list do
		total = total + glyph_for(set, list[i])[7]
	end

	return total * size / em + (spacing or 0) * #list
end

function cc.font.Draw(x, y, text, size, color, bold, spacing)
	local set, em = style(bold)
	local r, g, b, a = color[1], color[2], color[3], color[4] or 255

	if not set or not cc.draw.GlyphReady() then
		cc.draw.Text(floor(x), floor(y), text, r, g, b, a)
		return
	end

	local scale = size / em
	local list = codes(text)
	local pen = x
	local top = y
	local extra = spacing or 0
	local glyphs = set.glyphs
	local fallback = glyphs[63]
	local draw = cc.draw.Glyph

	for i = 1, #list do
		local glyph = glyphs[list[i]] or fallback

		if glyph[3] > 0 then
			draw(glyph[1], glyph[2], glyph[3], glyph[4], floor(pen + glyph[5] * scale + 0.5), floor(top + glyph[6] * scale + 0.5), glyph[3] * scale, glyph[4] * scale, r, g, b, a)
		end

		pen = pen + glyph[7] * scale + extra
	end
end
