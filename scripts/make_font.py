import os
import sys
from PIL import Image, ImageDraw, ImageFont

EM = 32
PAD = 2
WIDTH = 512
STYLES = (
	("regular", "/usr/share/fonts/opentype/inter/Inter-Medium.otf"),
	("bold", "/usr/share/fonts/opentype/inter/Inter-Bold.otf"),
)
CHARS = [chr(c) for c in range(32, 127)] + ["·", "•", "…", "×", "→", "✓"]


def render(font, char, ascent):
	canvas = Image.new("L", (EM * 3, EM * 3), 0)
	ImageDraw.Draw(canvas).text((EM, EM + ascent), char, font=font, fill=255, anchor="ls")
	box = canvas.getbbox()
	advance = font.getlength(char)

	if not box:
		return None, 0, 0, advance

	return canvas.crop(box), box[0] - EM, box[1] - EM, advance


def build(out_dir):
	glyphs = []
	metrics = {}

	for style, path in STYLES:
		font = ImageFont.truetype(path, EM)
		ascent, descent = font.getmetrics()
		metrics[style] = {"ascent": ascent, "height": ascent + descent}

		for char in CHARS:
			image, ox, oy, advance = render(font, char, ascent)
			glyphs.append((style, char, image, ox, oy, advance))

	order = sorted(range(len(glyphs)), key=lambda i: -(glyphs[i][2].height if glyphs[i][2] else 0))
	x = PAD
	y = PAD
	row = 0
	placed = {}

	for i in order:
		image = glyphs[i][2]

		if image is None:
			placed[i] = (0, 0)
			continue

		if x + image.width + PAD > WIDTH:
			x = PAD
			y += row + PAD
			row = 0

		placed[i] = (x, y)
		x += image.width + PAD
		row = max(row, image.height)

	needed = y + row + PAD
	height = 1

	while height < needed:
		height *= 2

	atlas = Image.new("L", (WIDTH, height), 0)

	for i, (px, py) in placed.items():
		image = glyphs[i][2]

		if image is not None:
			atlas.paste(image, (px, py))

	with open(os.path.join(out_dir, "assets", "font.pgm"), "wb") as f:
		f.write(b"P5\n%d %d\n255\n" % (WIDTH, height))
		f.write(atlas.tobytes())

	lines = ["cc.fontdata = {\n", "\tem = %d,\n" % EM, "\twidth = %d,\n" % WIDTH, "\theight = %d,\n" % height]

	for style, _ in STYLES:
		lines.append("\t%s = {\n\t\tascent = %d,\n\t\theight = %d,\n\t\tglyphs = {\n" % (style, metrics[style]["ascent"], metrics[style]["height"]))

		for i, (name, char, image, ox, oy, advance) in enumerate(glyphs):
			if name != style:
				continue

			px, py = placed[i]
			w = image.width if image else 0
			h = image.height if image else 0
			lines.append("\t\t\t[%d] = { %d, %d, %d, %d, %d, %d, %.2f },\n" % (ord(char), px, py, w, h, ox, oy, advance))

		lines.append("\t\t},\n\t},\n")

	lines.append("}\n")

	with open(os.path.join(out_dir, "builtin", "fontdata.lua"), "w", newline="\n") as f:
		f.write("".join(lines))

	print(WIDTH, height, len(glyphs))


if __name__ == "__main__":
	build(sys.argv[1])
