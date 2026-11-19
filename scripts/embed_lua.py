import os
import sys


def array(name, data):
	rows = []

	for i in range(0, len(data), 16):
		rows.append("\t" + ", ".join("0x%02x" % b for b in data[i:i + 16]))

	body = ",\n".join(rows) if rows else "\t0x00"
	return "static const unsigned char %s[] =\n{\n%s\n};\n\n" % (name, body)


def main(lua_dir, out_path, version):
	prelude_path = os.path.join(lua_dir, "core", "prelude.lua")
	builtin_dir = os.path.join(lua_dir, "builtin")
	builtins = sorted(f for f in os.listdir(builtin_dir) if f.endswith(".lua"))

	out = []
	out.append("#ifndef CC_EMBEDDED_H\n#define CC_EMBEDDED_H\n\n")
	out.append("#define CC_VERSION \"%s\"\n\n" % version)
	out.append("typedef struct\n{\n\tconst char *name;\n\tconst unsigned char *data;\n\tsize_t size;\n} cc_embedded_t;\n\n")

	with open(prelude_path, "rb") as f:
		data = f.read()

	out.append(array("cc_prelude_data", data))
	out.append("static const cc_embedded_t cc_embedded_prelude = { \"engine/prelude.lua\", cc_prelude_data, sizeof( cc_prelude_data ) };\n\n")

	with open(os.path.join(lua_dir, "assets", "font.pgm"), "rb") as f:
		pgm = f.read()

	header_end = 0
	fields = []
	cursor = 0

	while len(fields) < 4:
		while pgm[cursor:cursor + 1].isspace():
			cursor += 1

		start = cursor

		while not pgm[cursor:cursor + 1].isspace():
			cursor += 1

		fields.append(pgm[start:cursor])

	header_end = cursor + 1
	font_width = int(fields[1])
	font_height = int(fields[2])
	out.append("#define CC_FONT_WIDTH %d\n#define CC_FONT_HEIGHT %d\n\n" % (font_width, font_height))
	out.append(array("cc_font_pixels", pgm[header_end:header_end + font_width * font_height]))

	entries = []

	for index, name in enumerate(builtins):
		with open(os.path.join(builtin_dir, name), "rb") as f:
			data = f.read()

		symbol = "cc_builtin_%d" % index
		out.append(array(symbol, data))
		entries.append("\t{ \"engine/builtin/%s\", %s, sizeof( %s ) }" % (name, symbol, symbol))

	out.append("static const cc_embedded_t cc_embedded_builtin[] =\n{\n%s\n};\n\n" % ",\n".join(entries))
	out.append("#endif\n")

	with open(out_path, "w", newline="\n") as f:
		f.write("".join(out))


if __name__ == "__main__":
	if len(sys.argv) != 4:
		sys.exit("usage: embed_lua.py <lua-dir> <output-header> <version>")

	main(sys.argv[1], sys.argv[2], sys.argv[3])
