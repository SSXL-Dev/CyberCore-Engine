import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def read(path):
	with open(path, "r", encoding="utf-8", newline="") as f:
		return f.read()


def write(path, text):
	with open(path, "w", encoding="utf-8", newline="") as f:
		f.write(text)


def replace_once(path, old, new):
	text = read(path)

	if text.count(old) != 1:
		sys.exit("%s: expected exactly one match for %r, found %d" % (path, old, text.count(old)))

	write(path, text.replace(old, new))


def copy_tree(src, dst):
	for root, _, files in os.walk(src):
		rel = os.path.relpath(root, src)
		target = dst if rel == "." else os.path.join(dst, rel)
		os.makedirs(target, exist_ok=True)

		for name in files:
			shutil.copy2(os.path.join(root, name), os.path.join(target, name))


def main(engine, project):
	with open(os.path.join(project, "VERSION")) as f:
		version = f.read().strip()

	copy_tree(os.path.join(project, "engine"), os.path.join(engine, "engine"))
	copy_tree(os.path.join(project, "3rdparty"), os.path.join(engine, "3rdparty"))
	copy_tree(os.path.join(project, "android"), os.path.join(engine, "android"))

	subprocess.check_call([
		sys.executable,
		os.path.join(HERE, "embed_lua.py"),
		os.path.join(engine, "engine", "common", "lua"),
		os.path.join(engine, "engine", "common", "lua", "cc_embedded.h"),
		version,
	])

	replace_once(
		os.path.join(engine, "wscript"),
		"\tSubproject('3rdparty/miniz', lambda x: not x.env.HAVE_SYSTEM_ZLIB),\n",
		"\tSubproject('3rdparty/miniz', lambda x: not x.env.HAVE_SYSTEM_ZLIB),\n\tSubproject('3rdparty/lua'),\n",
	)

	engine_wscript = os.path.join(engine, "engine", "wscript")

	replace_once(
		engine_wscript,
		"libs = ['engine_includes', 'public', 'zlib', 'werror',",
		"libs = ['engine_includes', 'public', 'zlib', 'lua', 'werror',",
	)

	replace_once(
		engine_wscript,
		"'server/*.c', 'common/http/*.c'])",
		"'server/*.c', 'common/http/*.c', 'common/lua/**/*.c'])",
	)

	host = os.path.join(engine, "engine", "common", "host.c")

	replace_once(host, '#include "common.h"\n', '#include "common.h"\n#include "lua/cc_lua.h"\n')
	replace_once(host, "\tSV_Init();\n\tCL_Init();\n", "\tSV_Init();\n\tCL_Init();\n\tCC_Lua_Init();\n")
	replace_once(host, "static void Host_FreeCommon( void )\n{\n", "static void Host_FreeCommon( void )\n{\n\tCC_Lua_Shutdown();\n")

	view = os.path.join(engine, "engine", "client", "cl_view.c")

	replace_once(view, '#include "client.h"\n', '#include "client.h"\n#include "lua/cc_lua.h"\n')
	replace_once(view, "\t\tCL_DrawHUD( CL_ACTIVE );\n\t\tVGui_Paint();\n", "\t\tCL_DrawHUD( CL_ACTIVE );\n\t\tCC_Lua_Paint();\n\t\tVGui_Paint();\n")
	replace_once(view, "\t\tUI_UpdateMenu( host.realtime );\n", "\t\tUI_UpdateMenu( host.realtime );\n\t\tCC_Lua_MenuPaint();\n")

	touch = os.path.join(engine, "engine", "client", "input", "in_touch.c")

	replace_once(touch, '#include "common.h"\n#include "input.h"\n', '#include "common.h"\n#include "lua/cc_lua.h"\n#include "input.h"\n')
	replace_once(
		touch,
		"\tif( cls.key_dest == key_game && cls.state == ca_cinematic )\n",
		"\tif( CC_Lua_Touch( type, fingerID, x, y ))\n\t\treturn true;\n\n\tif( cls.key_dest == key_game && cls.state == ca_cinematic )\n",
	)

	parse = os.path.join(engine, "engine", "client", "parse", "cl_parse.c")

	replace_once(parse, '#include "client.h"\n', '#include "client.h"\n#include "lua/cc_lua.h"\n')
	replace_once(
		parse,
		"\tif( clgame.msg[i].func )\n\t{\n\t\tclgame.msg[i].func( clgame.msg[i].name, iSize, pbuf );\n",
		"\tCC_Lua_UserMsg( clgame.msg[i].name, iSize, pbuf );\n\n\tif( clgame.msg[i].func )\n\t{\n\t\tclgame.msg[i].func( clgame.msg[i].name, iSize, pbuf );\n",
	)

	game = os.path.join(engine, "engine", "client", "dll_int", "cl_game.c")

	replace_once(game, '#include "client.h"\n', '#include "client.h"\n#include "lua/cc_lua.h"\n')
	replace_once(
		game,
		"\tif( !clgame.ds.pCrosshair || !cl_crosshair.value )\n\t\treturn;\n",
		"\tif( !clgame.ds.pCrosshair || !cl_crosshair.value || CC_Lua_HideCrosshair( ))\n\t\treturn;\n",
	)

	replace_once(
		game,
		"\tref.dllFuncs.FillRGBA( kRenderTransAdd, x_, y_, w_, h_, r, g, b, a );\n",
		"\tif( CC_Lua_BlockFill( x_, y_, w_, h_ ))\n\t\treturn;\n\n\tref.dllFuncs.FillRGBA( kRenderTransAdd, x_, y_, w_, h_, r, g, b, a );\n",
	)
	replace_once(
		game,
		"\tref.dllFuncs.FillRGBA( kRenderTransTexture, x_, y_, w_, h_, r, g, b, a );\n",
		"\tif( CC_Lua_BlockFill( x_, y_, w_, h_ ))\n\t\treturn;\n\n\tref.dllFuncs.FillRGBA( kRenderTransTexture, x_, y_, w_, h_, r, g, b, a );\n",
	)
	replace_once(
		touch,
		"\tif( cls.state == ca_cinematic )\n\t\treturn;\n\n\tTouch_UpdateViewport();\n",
		"\tif( cls.state == ca_cinematic || CC_Lua_HideTouch( ))\n\t\treturn;\n\n\tTouch_UpdateViewport();\n",
	)

	replace_once(
		touch,
		"static void Touch_LoadDefaults_f( void )\n{\n",
		"static void Touch_LoadDefaults_f( void )\n{\n\tif( CC_Lua_LoadTouchDefaults( ))\n\t\treturn;\n\n",
	)

	colors = os.path.join(engine, "android", "app", "src", "main", "res", "values", "colors.xml")

	replace_once(colors, '<color name="hl_orange">#FB7E14</color>', '<color name="hl_orange">#3DB7FF</color>')

	sv_init = os.path.join(engine, "engine", "server", "sv_init.c")

	replace_once(
		sv_init,
		"\tSV_SetupClients();\n\n\tif( !SV_InitGame( false ))\n\t\treturn false;\n",
		"\tCC_Lua_MapStart( 1, background || svs.initialized || GameState->loadGame );\n\tSV_SetupClients();\n\n\tif( !SV_InitGame( false ))\n\t\treturn false;\n",
	)
	replace_once(
		sv_init,
		"\tClearBits( sv_cheats.flags, FCVAR_READ_ONLY );\n",
		"\tClearBits( sv_cheats.flags, FCVAR_READ_ONLY );\n\tCC_Lua_MapStart( 2, background || svs.initialized || GameState->loadGame );\n",
	)
	replace_once(sv_init, '#include "pm_local.h"\n', '#include "pm_local.h"\n#include "lua/cc_lua.h"\n')
	replace_once(
		sv_init,
		"\tsvgame.dllFuncs.pfnServerActivate( svgame.edicts, svgame.numEntities, svs.maxclients );\n",
		"\tsvgame.dllFuncs.pfnServerActivate( svgame.edicts, svgame.numEntities, svs.maxclients );\n\tCC_Lua_ServerActivate();\n",
	)

	sv_phys = os.path.join(engine, "engine", "server", "sv_phys.c")

	replace_once(sv_phys, '#include "ref_common.h"\n', '#include "ref_common.h"\n#include "lua/cc_lua.h"\n')
	replace_once(
		sv_phys,
		"\tsvgame.dllFuncs.pfnStartFrame();\n",
		"\tsvgame.dllFuncs.pfnStartFrame();\n\tCC_Lua_ServerFrame( sv.frametime );\n",
	)

	sv_game = os.path.join(engine, "engine", "server", "sv_game.c")

	with open(sv_game, "a", newline="\n") as f:
		f.write("\nenginefuncs_t *CC_SV_Engine( void );\n\nenginefuncs_t *CC_SV_Engine( void )\n{\n\treturn &gEngfuncs;\n}\n")

	res = os.path.join(engine, "android", "app", "src", "main", "res")

	for stale in ("ic_launcher_foreground.xml", "ic_launcher_monochrome.xml"):
		stale_path = os.path.join(res, "mipmap-anydpi-v26", stale)

		if not os.path.isfile(stale_path):
			sys.exit("missing upstream icon file: " + stale_path)

		os.remove(stale_path)

	gradle = os.path.join(engine, "android", "app", "build.gradle.kts")

	replace_once(gradle, 'applicationId = "su.xash.engine"', 'applicationId = "com.cybercore.engine"')
	replace_once(gradle, 'versionName = "0.21-" + getGitHash()', 'versionName = "%s"' % version)
	replace_once(gradle, 'setOf("armeabi-v7a", "arm64-v8a", "x86")', 'setOf("arm64-v8a")')
	replace_once(
		gradle,
		'\t\t\tapplicationIdSuffix = ".test"\n\t\t\tbuildConfigField("boolean", "ENABLE_AUTO_UPDATE", "true")\n',
		'\t\t\tbuildConfigField("boolean", "ENABLE_AUTO_UPDATE", "false")\n',
	)

	activity = os.path.join(engine, "android", "app", "src", "main", "java", "su", "xash", "engine", "MainActivity.kt")

	replace_once(activity, "import su.xash.engine.util.CrashReports\n", "import su.xash.engine.util.CrashReports\nimport su.xash.engine.util.GameFolders\n")
	replace_once(
		activity,
		"\tprivate fun checkForEngineUpdate() {\n",
		"\toverride fun onResume() {\n\t\tsuper.onResume()\n\t\tGameFolders.ensure(this)\n\t}\n\n\tprivate fun checkForEngineUpdate() {\n",
	)


if __name__ == "__main__":
	if len(sys.argv) != 3:
		sys.exit("usage: prepare.py <engine-root> <project-root>")

	main(sys.argv[1], sys.argv[2])
