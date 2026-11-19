#include "common.h"
#include "lua/cc_lua.h"
#include "lua/cc_lua_internal.h"
#include "lua/cc_embedded.h"

#if !XASH_DEDICATED
#include "client.h"
#endif

static struct
{
	lua_State *L;
	FILE *log;
	qboolean commands_added;
	qboolean hide_crosshair;
	qboolean hide_touch;
	qboolean painting;
	qboolean reload_pending;
	int loaded;
	int failed;
} cc_lua;

static const char *cc_script_folders[] =
{
	"lua/autorun/",
	"lua/autorun/server/",
	"lua/autorun/client/",
};

static void CC_Lua_OpenLog( void )
{
	const char *basedir = getenv( "XASH3D_BASEDIR" );
	char path[MAX_SYSPATH];

	if( cc_lua.log )
		return;

	if( !COM_StringEmptyOrNULL( basedir ))
	{
		Q_snprintf( path, sizeof( path ), "%s/lua.log", basedir );
		cc_lua.log = fopen( path, "w+" );
	}

	if( !cc_lua.log )
		cc_lua.log = fopen( "lua.log", "w+" );

	if( !cc_lua.log )
		return;

	fputs( "================================================================================\n", cc_lua.log );
	fprintf( cc_lua.log, "CyberCore Lua log, started at %s\n", Q_timestamp( TIME_FULL ));
	fputs( "================================================================================\n", cc_lua.log );
	fflush( cc_lua.log );
}

void CC_Lua_Log( const char *level, const char *fmt, ... )
{
	char message[2048];
	va_list args;

	va_start( args, fmt );
	Q_vsnprintf( message, sizeof( message ), fmt, args );
	va_end( args );

	if( cc_lua.log )
	{
		fprintf( cc_lua.log, "[%s] [%s] %s\n", Q_timestamp( TIME_TIME_ONLY ), level, message );
		fflush( cc_lua.log );
	}

	if( !Q_strcmp( level, "ERROR" ))
		Con_Printf( S_ERROR "[Lua] %s\n", message );
	else Con_Printf( "[Lua] %s\n", message );
}

void CC_Lua_SetPainting( qboolean painting )
{
	cc_lua.painting = painting;
}

int CC_Lua_IsPainting( void )
{
	return cc_lua.painting;
}

void CC_Lua_SetHideCrosshair( qboolean hide )
{
	cc_lua.hide_crosshair = hide;
}

int CC_Lua_GetHideCrosshair( void )
{
	return cc_lua.hide_crosshair;
}

int CC_Lua_HideCrosshair( void )
{
	return cc_lua.hide_crosshair;
}

const char *CC_Lua_Version( void )
{
	return CC_VERSION;
}

const unsigned char *CC_Lua_FontPixels( int *width, int *height )
{
	*width = CC_FONT_WIDTH;
	*height = CC_FONT_HEIGHT;
	return cc_font_pixels;
}

void CC_Lua_SetHideTouch( qboolean hide )
{
	cc_lua.hide_touch = hide;
}

int CC_Lua_HideTouch( void )
{
	return cc_lua.hide_touch;
}

int CC_Lua_BlockFill( float x, float y, float w, float h )
{
#if XASH_DEDICATED
	(void)x;
	(void)y;
	(void)w;
	(void)h;
	return false;
#else
	float cx, cy;

	if( !cc_lua.hide_crosshair || cc_lua.painting || w <= 0.0f || h <= 0.0f || w > 96.0f || h > 96.0f )
		return false;

	cx = refState.width * 0.5f;
	cy = refState.height * 0.5f;

	return x + w >= cx - 110.0f && x <= cx + 110.0f && y + h >= cy - 110.0f && y <= cy + 110.0f;
#endif
}

int CC_Lua_PathAllowed( const char *path )
{
	if( COM_StringEmptyOrNULL( path ))
		return false;

	if( path[0] == '/' || path[0] == '\\' )
		return false;

	if( Q_strstr( path, ".." ) || Q_strchr( path, ':' ))
		return false;

	return true;
}

static int CC_Lua_Traceback( lua_State *L )
{
	const char *msg = lua_tostring( L, 1 );

	if( msg == NULL )
	{
		if( luaL_callmeta( L, 1, "__tostring" ) && lua_type( L, -1 ) == LUA_TSTRING )
			return 1;

		msg = lua_pushfstring( L, "(error object is a %s value)", luaL_typename( L, 1 ));
	}

	luaL_traceback( L, L, msg, 1 );
	return 1;
}

static int CC_Lua_Call( lua_State *L, int nargs, int nresults, const char *what )
{
	int base = lua_gettop( L ) - nargs;
	int status;

	lua_pushcfunction( L, CC_Lua_Traceback );
	lua_insert( L, base );
	status = lua_pcall( L, nargs, nresults, base );
	lua_remove( L, base );

	if( status != LUA_OK )
	{
		CC_Lua_Log( "ERROR", "%s: %s", what, lua_tostring( L, -1 ));
		lua_pop( L, 1 );
	}

	return status;
}

static int CC_Lua_LoadBuffer( lua_State *L, const char *data, size_t size, const char *name )
{
	if( size >= 3 && (byte)data[0] == 0xEF && (byte)data[1] == 0xBB && (byte)data[2] == 0xBF )
	{
		data += 3;
		size -= 3;
	}

	return luaL_loadbufferx( L, data, size, name, "t" );
}

static int CC_Lua_RunBuffer( lua_State *L, const char *data, size_t size, const char *name )
{
	char chunk[MAX_SYSPATH + 2];

	Q_snprintf( chunk, sizeof( chunk ), "@%s", name );

	if( CC_Lua_LoadBuffer( L, data, size, chunk ) != LUA_OK )
	{
		CC_Lua_Log( "ERROR", "%s: %s", name, lua_tostring( L, -1 ));
		lua_pop( L, 1 );
		return false;
	}

	return CC_Lua_Call( L, 0, 0, name ) == LUA_OK;
}

static int CC_Lua_RunFile( lua_State *L, const char *path )
{
	fs_offset_t size = 0;
	byte *data = FS_LoadFile( path, &size, true );
	int ok;

	if( !data )
	{
		CC_Lua_Log( "ERROR", "can't read %s", path );
		return false;
	}

	ok = CC_Lua_RunBuffer( L, (const char *)data, (size_t)size, path );
	Mem_Free( data );
	return ok;
}

static int CC_Lua_Include( lua_State *L )
{
	const char *path = luaL_checkstring( L, 1 );
	fs_offset_t size = 0;
	byte *data;
	char chunk[MAX_SYSPATH + 2];
	int top = lua_gettop( L );
	int status;

	if( !CC_Lua_PathAllowed( path ))
		return luaL_error( L, "include: invalid path '%s'", path );

	data = FS_LoadFile( path, &size, true );

	if( !data )
		return luaL_error( L, "include: can't read '%s'", path );

	Q_snprintf( chunk, sizeof( chunk ), "@%s", path );
	status = CC_Lua_LoadBuffer( L, (const char *)data, (size_t)size, chunk );
	Mem_Free( data );

	if( status != LUA_OK )
		return lua_error( L );

	lua_call( L, 0, LUA_MULTRET );
	return lua_gettop( L ) - top;
}

static int CC_Lua_Print( lua_State *L )
{
	int n = lua_gettop( L );
	luaL_Buffer b;

	luaL_buffinit( L, &b );

	for( int i = 1; i <= n; i++ )
	{
		size_t len;
		const char *s = luaL_tolstring( L, i, &len );

		if( i > 1 )
			luaL_addchar( &b, '\t' );

		lua_pop( L, 1 );
		luaL_addlstring( &b, s, len );
	}

	luaL_pushresult( &b );
	CC_Lua_Log( "INFO", "%s", lua_tostring( L, -1 ));
	return 0;
}

static void CC_Lua_OpenLibs( lua_State *L )
{
	static const luaL_Reg libs[] =
	{
		{ LUA_GNAME, luaopen_base },
		{ LUA_COLIBNAME, luaopen_coroutine },
		{ LUA_TABLIBNAME, luaopen_table },
		{ LUA_STRLIBNAME, luaopen_string },
		{ LUA_MATHLIBNAME, luaopen_math },
		{ LUA_UTF8LIBNAME, luaopen_utf8 },
		{ LUA_OSLIBNAME, luaopen_os },
		{ NULL, NULL }
	};
	static const char *blocked_base[] = { "dofile", "loadfile", NULL };
	static const char *allowed_os[] = { "time", "clock", "date", "difftime", NULL };

	for( const luaL_Reg *lib = libs; lib->func; lib++ )
	{
		luaL_requiref( L, lib->name, lib->func, 1 );
		lua_pop( L, 1 );
	}

	for( int i = 0; blocked_base[i]; i++ )
	{
		lua_pushnil( L );
		lua_setglobal( L, blocked_base[i] );
	}

	lua_getglobal( L, LUA_OSLIBNAME );
	lua_newtable( L );

	for( int i = 0; allowed_os[i]; i++ )
	{
		lua_getfield( L, -2, allowed_os[i] );
		lua_setfield( L, -2, allowed_os[i] );
	}

	lua_setglobal( L, LUA_OSLIBNAME );
	lua_pop( L, 1 );

	lua_pushcfunction( L, CC_Lua_Print );
	lua_setglobal( L, "print" );

	lua_pushcfunction( L, CC_Lua_Include );
	lua_setglobal( L, "include" );
}

static void CC_Lua_RecordScript( lua_State *L, const char *path, const char *addon, int ok )
{
	lua_getglobal( L, "cc" );
	lua_getfield( L, -1, "scripts" );

	if( lua_istable( L, -1 ))
	{
		lua_newtable( L );
		lua_pushstring( L, path );
		lua_setfield( L, -2, "path" );

		if( addon )
		{
			lua_pushstring( L, addon );
			lua_setfield( L, -2, "addon" );
		}

		lua_pushboolean( L, ok );
		lua_setfield( L, -2, "ok" );
		lua_rawseti( L, -2, (lua_Integer)lua_rawlen( L, -2 ) + 1 );
	}

	lua_pop( L, 2 );
}

static void CC_Lua_RecordAddon( lua_State *L, const char *name, int enabled )
{
	lua_getglobal( L, "cc" );
	lua_getfield( L, -1, "addons" );

	if( lua_istable( L, -1 ))
	{
		lua_newtable( L );
		lua_pushstring( L, name );
		lua_setfield( L, -2, "name" );
		lua_pushboolean( L, enabled );
		lua_setfield( L, -2, "enabled" );
		lua_rawseti( L, -2, (lua_Integer)lua_rawlen( L, -2 ) + 1 );
	}

	lua_pop( L, 2 );
}

static int CC_Lua_AddonAllowed( lua_State *L, const char *name )
{
	int allowed = true;

	lua_getglobal( L, "cc" );
	lua_getfield( L, -1, "addon" );
	lua_remove( L, -2 );

	if( !lua_istable( L, -1 ))
	{
		lua_pop( L, 1 );
		return allowed;
	}

	lua_getfield( L, -1, "IsEnabled" );
	lua_remove( L, -2 );

	if( !lua_isfunction( L, -1 ))
	{
		lua_pop( L, 1 );
		return allowed;
	}

	lua_pushstring( L, name );

	if( CC_Lua_Call( L, 1, 1, "addon.IsEnabled" ) == LUA_OK )
	{
		allowed = lua_toboolean( L, -1 );
		lua_pop( L, 1 );
	}

	return allowed;
}

static int CC_Lua_AddonEnabled( const char *root )
{
	char manifest[MAX_SYSPATH];
	fs_offset_t size = 0;
	byte *data;
	char *key;
	int enabled = true;

	Q_snprintf( manifest, sizeof( manifest ), "%saddon.json", root );
	data = FS_LoadFile( manifest, &size, true );

	if( !data )
		return true;

	key = Q_strstr( (char *)data, "\"enabled\"" );

	if( key )
	{
		key += 9;

		while( *key == ' ' || *key == '\t' || *key == '\r' || *key == '\n' || *key == ':' )
			key++;

		if( !Q_strncmp( key, "false", 5 ))
			enabled = false;
	}

	Mem_Free( data );
	return enabled;
}

static void CC_Lua_LoadRoot( lua_State *L, const char *root, const char *addon )
{
	for( size_t i = 0; i < ARRAYSIZE( cc_script_folders ); i++ )
	{
		char pattern[MAX_SYSPATH];
		search_t *list;

		if( Host_IsDedicated( ) && Q_strstr( cc_script_folders[i], "/client/" ))
			continue;

		Q_snprintf( pattern, sizeof( pattern ), "%s%s*.lua", root, cc_script_folders[i] );
		list = FS_Search( pattern, true, true );

		if( !list )
			continue;

		for( int j = 0; j < list->numfilenames; j++ )
		{
			int ok = CC_Lua_RunFile( L, list->filenames[j] );

			if( ok )
				cc_lua.loaded++;
			else cc_lua.failed++;

			CC_Lua_RecordScript( L, list->filenames[j], addon, ok );
		}

		Mem_Free( list );
	}
}

static void CC_Lua_LoadAutorun( lua_State *L )
{
	search_t *addons;

	CC_Lua_LoadRoot( L, "", NULL );

	addons = FS_Search( "addons/*", true, true );

	if( !addons )
		return;

	for( int i = 0; i < addons->numfilenames; i++ )
	{
		const char *name = addons->filenames[i] + 7;
		char root[MAX_SYSPATH];

		if( name[0] == '\0' || name[0] == '.' )
			continue;

		Q_snprintf( root, sizeof( root ), "%s/", addons->filenames[i] );

		if( !CC_Lua_AddonEnabled( root ) || !CC_Lua_AddonAllowed( L, name ))
		{
			CC_Lua_Log( "INFO", "addon '%s' is disabled", name );
			CC_Lua_RecordAddon( L, name, false );
			continue;
		}

		CC_Lua_RecordAddon( L, name, true );
		CC_Lua_LoadRoot( L, root, name );
	}

	Mem_Free( addons );
}

static int CC_Lua_PushHookRun( lua_State *L )
{
	lua_getglobal( L, "cc" );

	if( !lua_istable( L, -1 ))
	{
		lua_pop( L, 1 );
		return false;
	}

	lua_getfield( L, -1, "hook" );
	lua_remove( L, -2 );

	if( !lua_istable( L, -1 ))
	{
		lua_pop( L, 1 );
		return false;
	}

	lua_getfield( L, -1, "Run" );
	lua_remove( L, -2 );

	if( !lua_isfunction( L, -1 ))
	{
		lua_pop( L, 1 );
		return false;
	}

	return true;
}

static void CC_Lua_RunHook( lua_State *L, const char *event )
{
	if( !CC_Lua_PushHookRun( L ))
		return;

	lua_pushstring( L, event );
	CC_Lua_Call( L, 1, 0, event );
}

static void CC_Lua_Start( void );
static void CC_Lua_Stop( void );

void CC_Lua_RequestReload( void )
{
	cc_lua.reload_pending = true;
}

static void CC_Lua_FlushReload( void )
{
	if( !cc_lua.reload_pending )
		return;

	cc_lua.reload_pending = false;
	CC_Lua_Stop();
	CC_Lua_Start();
}

static void CC_Lua_Start( void )
{
	lua_State *L = luaL_newstate();

	if( !L )
	{
		CC_Lua_Log( "ERROR", "can't create Lua state" );
		return;
	}

	cc_lua.L = L;
	cc_lua.loaded = 0;
	cc_lua.failed = 0;
	cc_lua.hide_crosshair = false;
	cc_lua.hide_touch = false;
	cc_lua.painting = false;
	cc_lua.reload_pending = false;

	CC_Lua_OpenLibs( L );
	CC_Lua_OpenAPI( L );

	if( !CC_Lua_RunBuffer( L, (const char *)cc_embedded_prelude.data, cc_embedded_prelude.size, cc_embedded_prelude.name ))
	{
		CC_Lua_Log( "ERROR", "engine prelude failed, Lua disabled" );
		lua_close( L );
		cc_lua.L = NULL;
		return;
	}

	for( size_t i = 0; i < ARRAYSIZE( cc_embedded_builtin ); i++ )
		CC_Lua_RunBuffer( L, (const char *)cc_embedded_builtin[i].data, cc_embedded_builtin[i].size, cc_embedded_builtin[i].name );

	CC_Lua_LoadAutorun( L );
	CC_Lua_RunHook( L, "Initialize" );
	CC_Lua_Log( "INFO", "%s, game '%s': %d scripts loaded, %d failed", LUA_RELEASE, GI->gamefolder, cc_lua.loaded, cc_lua.failed );
}

static void CC_Lua_Stop( void )
{
	if( !cc_lua.L )
		return;

	CC_Lua_RunHook( cc_lua.L, "Shutdown" );
	lua_close( cc_lua.L );
	cc_lua.L = NULL;
	cc_lua.hide_crosshair = false;
	cc_lua.hide_touch = false;
	cc_lua.painting = false;
}

static void CC_Lua_Reload_f( void )
{
	CC_Lua_Stop();
	CC_Lua_Start();
}

static void CC_Lua_Run_f( void )
{
	const char *code = Cmd_Args();

	if( !cc_lua.L )
	{
		Con_Printf( S_ERROR "Lua is not running\n" );
		return;
	}

	CC_Lua_RunBuffer( cc_lua.L, code, Q_strlen( code ), "lua_run" );
}

void CC_Lua_Init( void )
{
	CC_Lua_OpenLog();

	if( !cc_lua.commands_added )
	{
		Cmd_AddRestrictedCommand( "lua_reload", CC_Lua_Reload_f, "reload all Lua scripts" );
		Cmd_AddRestrictedCommand( "lua_run", CC_Lua_Run_f, "run a Lua string" );
		cc_lua.commands_added = true;
	}

	CC_Lua_Start();
}

void CC_Lua_Shutdown( void )
{
	CC_Lua_Stop();

	if( cc_lua.log )
	{
		fclose( cc_lua.log );
		cc_lua.log = NULL;
	}
}

void CC_Lua_Paint( void )
{
	if( !cc_lua.L )
		return;

	cc_lua.painting = true;
	CC_Lua_ResetClip( );
	CC_Lua_RunHook( cc_lua.L, "HUDPaint" );
	cc_lua.painting = false;
	CC_Lua_FlushReload();
}

void CC_Lua_UserMsg( const char *name, int size, const byte *data )
{
	lua_State *L = cc_lua.L;

	if( !L || size < 0 || !CC_Lua_PushHookRun( L ))
		return;

	lua_pushliteral( L, "UserMessage" );
	lua_pushstring( L, name );
	lua_pushlstring( L, (const char *)data, (size_t)size );
	CC_Lua_Call( L, 3, 0, "UserMessage" );
	CC_Lua_FlushReload();
}

#if !XASH_DEDICATED
static int CC_Lua_MenuVisible( void )
{
	return cls.key_dest == key_menu && UI_IsVisible( ) && ( cls.state == ca_disconnected || cl.background );
}

void CC_Lua_MenuPaint( void )
{
	if( !cc_lua.L || !CC_Lua_MenuVisible( ))
		return;

	cc_lua.painting = true;
	CC_Lua_ResetClip( );
	CC_Lua_RunHook( cc_lua.L, "MenuPaint" );
	cc_lua.painting = false;
}

int CC_Lua_Touch( int type, int finger, float x, float y )
{
	static const char *names[] = { "down", "up", "motion" };
	lua_State *L = cc_lua.L;
	const char *hook;
	int consumed = false;

	if( !L || type < 0 || type > 2 )
		return false;

	if( cls.state == ca_active && cls.key_dest == key_game )
		hook = "Touch";
	else if( CC_Lua_MenuVisible( ))
		hook = "MenuTouch";
	else
		return false;

	if( !CC_Lua_PushHookRun( L ))
		return false;

	lua_pushstring( L, hook );
	lua_pushstring( L, names[type] );
	lua_pushinteger( L, finger );
	lua_pushnumber( L, x * refState.width );
	lua_pushnumber( L, y * refState.height );

	if( CC_Lua_Call( L, 5, 1, "Touch" ) == LUA_OK )
	{
		consumed = lua_toboolean( L, -1 );
		lua_pop( L, 1 );
	}

	CC_Lua_FlushReload();
	return consumed;
}
#else
void CC_Lua_MenuPaint( void )
{
}

int CC_Lua_Touch( int type, int finger, float x, float y )
{
	(void)type;
	(void)finger;
	(void)x;
	(void)y;
	return false;
}
#endif

int CC_Lua_LoadTouchDefaults( void )
{
	const char *cursor = (const char *)cc_touch_profile;

	while( *cursor )
	{
		char line[1024];
		size_t length = 0;

		while( cursor[length] && cursor[length] != '\n' )
			length++;

		if( length > 0 && length < sizeof( line ))
		{
			memcpy( line, cursor, length );
			line[length] = '\0';
			Cmd_ExecuteString( line );
		}

		cursor += length;

		if( *cursor == '\n' )
			cursor++;
	}

	return true;
}

void CC_Lua_ServerActivate( void )
{
	if( !cc_lua.L )
		return;

	CC_Lua_RunHook( cc_lua.L, "Precache" );
}

void CC_Lua_ServerFrame( float frametime )
{
	lua_State *L = cc_lua.L;

	if( !L || !CC_Lua_PushHookRun( L ))
		return;

	lua_pushstring( L, "ServerFrame" );
	lua_pushnumber( L, frametime );
	CC_Lua_Call( L, 2, 0, "ServerFrame" );
}

void CC_Lua_MapStart( int stage, int skip )
{
	lua_State *L = cc_lua.L;

	if( !L || skip || !CC_Lua_PushHookRun( L ))
		return;

	lua_pushliteral( L, "MapStart" );
	lua_pushinteger( L, stage );
	CC_Lua_Call( L, 2, 0, "MapStart" );
}
