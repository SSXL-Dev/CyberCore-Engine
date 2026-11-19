package su.xash.engine.util

import android.content.Context
import java.io.File

object GameFolders {
	private val games = listOf("valve", "gearbox", "cstrike", "czero")

	private val luaFolders = listOf(
		"autorun/client",
		"autorun/server",
		"includes",
		"entities",
		"weapons",
		"effects",
		"vgui",
		"menu"
	)

	fun ensure(context: Context) {
		val base = Prefs.getGamePath(context)

		try {
			for (game in games) {
				File(base, "$game/addons").mkdirs()

				for (folder in luaFolders)
					File(base, "$game/lua/$folder").mkdirs()
			}
		} catch (e: SecurityException) {
			return
		}
	}
}
