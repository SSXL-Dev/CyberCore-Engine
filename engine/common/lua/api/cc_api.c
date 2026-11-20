#include "common.h"
#include "lua/cc_lua.h"
#include "lua/cc_lua_internal.h"

#if !XASH_DEDICATED
#include "client.h"

#if !XASH_WIN32
#include <sys/stat.h>
#endif

HSPRITE pfnSPR_Load( const char *szPicName );
#endif

static int CC_Log_Print( lua_State *L )
{
	CC_Lua_Log( "INFO", "%s", luaL_checkstring( L, 1 ));
	return 0;
}

static int CC_Log_Error( lua_State *L )
{
	CC_Lua_Log( "ERROR", "%s", luaL_checkstring( L, 1 ));
	return 0;
}

static int CC_Screen_Width( lua_State *L )
{
#if XASH_DEDICATED
	lua_pushinteger( L, 0 );
#else
	lua_pushinteger( L, refState.width );
#endif
	return 1;
}

static int CC_Screen_Height( lua_State *L )
{
#if XASH_DEDICATED
	lua_pushinteger( L, 0 );
#else
	lua_pushinteger( L, refState.height );
#endif
	return 1;
}

#if !XASH_DEDICATED
static struct
{
	qboolean enabled;
	float x0, y0, x1, y1;
} cc_clip;

static qboolean CC_Clip_Rect( float *x, float *y, float *w, float *h )
{
	float x0 = *x, y0 = *y, x1 = *x + *w, y1 = *y + *h;

	if( cc_clip.enabled )
	{
		if( x0 < cc_clip.x0 ) x0 = cc_clip.x0;
		if( y0 < cc_clip.y0 ) y0 = cc_clip.y0;
		if( x1 > cc_clip.x1 ) x1 = cc_clip.x1;
		if( y1 > cc_clip.y1 ) y1 = cc_clip.y1;
	}

	if( x1 <= x0 || y1 <= y0 )
		return false;

	*x = x0;
	*y = y0;
	*w = x1 - x0;
	*h = y1 - y0;
	return true;
}

#define CC_FONT_TEXTURE "*cc_font"

static struct
{
	int texnum;
	qboolean checked;
	qboolean failed;
} cc_font;

static int CC_Font_Texture( void )
{
	rgbdata_t pic;
	const byte *alpha;
	byte *rgba;
	int width = 0, height = 0, count, i;

	if( cc_font.checked )
		return cc_font.texnum;

	cc_font.checked = true;

	if( cc_font.texnum && ref.dllFuncs.GL_FindTexture( CC_FONT_TEXTURE ) == cc_font.texnum )
		return cc_font.texnum;

	cc_font.texnum = 0;

	if( cc_font.failed )
		return 0;

	alpha = CC_Lua_FontPixels( &width, &height );
	count = width * height;

	if( !alpha || count <= 0 )
	{
		cc_font.failed = true;
		return 0;
	}

	rgba = Mem_Malloc( host.mempool, count * 4 );

	for( i = 0; i < count; i++ )
	{
		rgba[i * 4 + 0] = 255;
		rgba[i * 4 + 1] = 255;
		rgba[i * 4 + 2] = 255;
		rgba[i * 4 + 3] = alpha[i];
	}

	memset( &pic, 0, sizeof( pic ));
	pic.width = width;
	pic.height = height;
	pic.depth = 1;
	pic.type = PF_RGBA_32;
	pic.flags = IMAGE_HAS_ALPHA;
	pic.numMips = 1;
	pic.buffer = rgba;
	pic.size = count * 4;

	cc_font.texnum = ref.dllFuncs.GL_LoadTextureFromBuffer( CC_FONT_TEXTURE, &pic, TF_IMAGE | TF_HAS_ALPHA, false );

	if( !cc_font.texnum )
		cc_font.failed = true;

	Mem_Free( rgba );
	return cc_font.texnum;
}

static byte CC_Lua_Byte( lua_State *L, int idx )
{
	lua_Integer value = luaL_optinteger( L, idx, 255 );

	if( value < 0 )
		value = 0;
	else if( value > 255 )
		value = 255;

	return (byte)value;
}
#endif

static int CC_Draw_Rect( lua_State *L )
{
#if !XASH_DEDICATED
	float x = (float)luaL_checknumber( L, 1 );
	float y = (float)luaL_checknumber( L, 2 );
	float w = (float)luaL_checknumber( L, 3 );
	float h = (float)luaL_checknumber( L, 4 );

	if( CC_Lua_IsPainting( ) && CC_Clip_Rect( &x, &y, &w, &h ))
		ref.dllFuncs.FillRGBA( kRenderTransTexture, x, y, w, h, CC_Lua_Byte( L, 5 ), CC_Lua_Byte( L, 6 ), CC_Lua_Byte( L, 7 ), CC_Lua_Byte( L, 8 ));
#else
	(void)L;
#endif
	return 0;
}

static int CC_Draw_Circle( lua_State *L )
{
#if !XASH_DEDICATED
	float cx = (float)luaL_checknumber( L, 1 );
	float cy = (float)luaL_checknumber( L, 2 );
	float radius = (float)luaL_checknumber( L, 3 );
	int segments = (int)luaL_optinteger( L, 4, 32 );
	float thickness = (float)luaL_optnumber( L, 5, 1.0 );
	byte r = CC_Lua_Byte( L, 6 );
	byte g = CC_Lua_Byte( L, 7 );
	byte b = CC_Lua_Byte( L, 8 );
	byte a = CC_Lua_Byte( L, 9 );

	if( !CC_Lua_IsPainting( ))
		return 0;

	if( segments < 3 )
		segments = 3;
	else if( segments > 256 )
		segments = 256;

	for( int i = 0; i < segments; i++ )
	{
		float angle = 6.28318530718f * (float)i / (float)segments;
		float px = cx + cosf( angle ) * radius - thickness * 0.5f;
		float py = cy + sinf( angle ) * radius - thickness * 0.5f;
		float pw = thickness;
		float ph = thickness;

		if( CC_Clip_Rect( &px, &py, &pw, &ph ))
			ref.dllFuncs.FillRGBA( kRenderTransTexture, px, py, pw, ph, r, g, b, a );
	}
#else
	(void)L;
#endif
	return 0;
}

static int CC_Draw_Text( lua_State *L )
{
#if !XASH_DEDICATED
	int x = (int)luaL_checknumber( L, 1 );
	int y = (int)luaL_checknumber( L, 2 );
	const char *text = luaL_checkstring( L, 3 );
	rgba_t color = { CC_Lua_Byte( L, 4 ), CC_Lua_Byte( L, 5 ), CC_Lua_Byte( L, 6 ), CC_Lua_Byte( L, 7 ) };

	if( CC_Lua_IsPainting( ))
	{
		int tw = 0, th = 0;

		Con_DrawStringLen( text, &tw, &th );

		if( !cc_clip.enabled || ( x >= cc_clip.x0 && y >= cc_clip.y0 && x + tw <= cc_clip.x1 && y + th <= cc_clip.y1 ))
			Con_DrawString( x, y, text, color );
	}
#else
	(void)L;
#endif
	return 0;
}

static int CC_Draw_TextSize( lua_State *L )
{
	int width = 0;
	int height = 0;

#if !XASH_DEDICATED
	const char *text = luaL_checkstring( L, 1 );

	if( CC_Lua_IsPainting( ))
		Con_DrawStringLen( text, &width, &height );
#else
	(void)L;
#endif
	lua_pushinteger( L, width );
	lua_pushinteger( L, height );
	return 2;
}

static int CC_Draw_SetClip( lua_State *L )
{
#if !XASH_DEDICATED
	float x = (float)luaL_checknumber( L, 1 );
	float y = (float)luaL_checknumber( L, 2 );
	float w = (float)luaL_checknumber( L, 3 );
	float h = (float)luaL_checknumber( L, 4 );

	cc_clip.enabled = true;
	cc_clip.x0 = x;
	cc_clip.y0 = y;
	cc_clip.x1 = x + w;
	cc_clip.y1 = y + h;
#else
	(void)L;
#endif
	return 0;
}

static int CC_Draw_ClearClip( lua_State *L )
{
	(void)L;
	CC_Lua_ResetClip( );
	return 0;
}

static int CC_Draw_GlyphReady( lua_State *L )
{
#if !XASH_DEDICATED
	lua_pushboolean( L, CC_Lua_IsPainting( ) && CC_Font_Texture( ) != 0 );
#else
	lua_pushboolean( L, 0 );
#endif
	return 1;
}

static int CC_Draw_Glyph( lua_State *L )
{
#if !XASH_DEDICATED
	float sx = (float)luaL_checknumber( L, 1 );
	float sy = (float)luaL_checknumber( L, 2 );
	float sw = (float)luaL_checknumber( L, 3 );
	float sh = (float)luaL_checknumber( L, 4 );
	float x = (float)luaL_checknumber( L, 5 );
	float y = (float)luaL_checknumber( L, 6 );
	float w = (float)luaL_checknumber( L, 7 );
	float h = (float)luaL_checknumber( L, 8 );
	float ox = x, oy = y, ow = w, oh = h;
	int texnum, tw = 0, th = 0;

	if( !CC_Lua_IsPainting( ) || w <= 0.0f || h <= 0.0f )
		return 0;

	texnum = CC_Font_Texture( );

	if( !texnum )
		return 0;

	CC_Lua_FontPixels( &tw, &th );

	if( !CC_Clip_Rect( &x, &y, &w, &h ))
		return 0;

	sx += ( x - ox ) / ow * sw;
	sy += ( y - oy ) / oh * sh;
	sw *= w / ow;
	sh *= h / oh;

	ref.dllFuncs.GL_SetRenderMode( kRenderTransTexture );
	ref.dllFuncs.Color4ub( CC_Lua_Byte( L, 9 ), CC_Lua_Byte( L, 10 ), CC_Lua_Byte( L, 11 ), CC_Lua_Byte( L, 12 ));
	ref.dllFuncs.R_DrawStretchPic( x, y, w, h, sx / tw, sy / th, ( sx + sw ) / tw, ( sy + sh ) / th, texnum );
	ref.dllFuncs.GL_SetRenderMode( kRenderNormal );
#else
	(void)L;
#endif
	return 0;
}

#if !XASH_DEDICATED
#define CC_IMAGE_SLOTS 16

static struct
{
	char path[MAX_QPATH];
	int texnum;
	qboolean failed;
} cc_images[CC_IMAGE_SLOTS];

static int CC_Image_Texture( const char *path )
{
	int free_slot = -1;

	for( int i = 0; i < CC_IMAGE_SLOTS; i++ )
	{
		if( !cc_images[i].path[0] )
		{
			if( free_slot < 0 )
				free_slot = i;

			continue;
		}

		if( Q_stricmp( cc_images[i].path, path ))
			continue;

		if( cc_images[i].failed )
			return 0;

		if( cc_images[i].texnum && ref.dllFuncs.GL_FindTexture( path ) == cc_images[i].texnum )
			return cc_images[i].texnum;

		cc_images[i].texnum = ref.dllFuncs.GL_LoadTexture( path, NULL, 0, TF_IMAGE );
		cc_images[i].failed = cc_images[i].texnum == 0;
		return cc_images[i].texnum;
	}

	if( free_slot < 0 )
		return 0;

	Q_strncpy( cc_images[free_slot].path, path, sizeof( cc_images[free_slot].path ));
	cc_images[free_slot].texnum = ref.dllFuncs.GL_LoadTexture( path, NULL, 0, TF_IMAGE );
	cc_images[free_slot].failed = cc_images[free_slot].texnum == 0;
	return cc_images[free_slot].texnum;
}
#endif

static int CC_Draw_ImageLoad( lua_State *L )
{
	int texnum = 0;

#if !XASH_DEDICATED
	const char *path = luaL_checkstring( L, 1 );

	if( CC_Lua_IsPainting( ) && CC_Lua_PathAllowed( path ))
		texnum = CC_Image_Texture( path );
#else
	(void)L;
#endif
	lua_pushinteger( L, texnum );
	return 1;
}

static int CC_Draw_Image( lua_State *L )
{
#if !XASH_DEDICATED
	int texnum = (int)luaL_checkinteger( L, 1 );
	float x = (float)luaL_checknumber( L, 2 );
	float y = (float)luaL_checknumber( L, 3 );
	float w = (float)luaL_checknumber( L, 4 );
	float h = (float)luaL_checknumber( L, 5 );
	float ox = x, oy = y, ow = w, oh = h;

	if( !CC_Lua_IsPainting( ) || texnum <= 0 || w <= 0.0f || h <= 0.0f )
		return 0;

	if( !CC_Clip_Rect( &x, &y, &w, &h ))
		return 0;

	ref.dllFuncs.GL_SetRenderMode( kRenderTransTexture );
	ref.dllFuncs.Color4ub( CC_Lua_Byte( L, 6 ), CC_Lua_Byte( L, 7 ), CC_Lua_Byte( L, 8 ), CC_Lua_Byte( L, 9 ));
	ref.dllFuncs.R_DrawStretchPic( x, y, w, h, ( x - ox ) / ow, ( y - oy ) / oh, ( x + w - ox ) / ow, ( y + h - oy ) / oh, texnum );
	ref.dllFuncs.GL_SetRenderMode( kRenderNormal );
#else
	(void)L;
#endif
	return 0;
}

static int CC_Draw_SpriteLoad( lua_State *L )
{
	int handle = 0;

#if !XASH_DEDICATED
	const char *path = luaL_checkstring( L, 1 );

	if( CC_Lua_IsPainting( ) && CC_Lua_PathAllowed( path ))
		handle = pfnSPR_Load( path );
#else
	(void)L;
#endif
	lua_pushinteger( L, handle );
	return 1;
}

static int CC_Draw_Sprite( lua_State *L )
{
#if !XASH_DEDICATED
	int handle = (int)luaL_checkinteger( L, 1 );
	int frame = (int)luaL_checkinteger( L, 2 );
	float x = (float)luaL_checknumber( L, 3 );
	float y = (float)luaL_checknumber( L, 4 );
	float w = (float)luaL_checknumber( L, 5 );
	float h = (float)luaL_checknumber( L, 6 );
	float sx = (float)luaL_checknumber( L, 7 );
	float sy = (float)luaL_checknumber( L, 8 );
	float sw = (float)luaL_checknumber( L, 9 );
	float sh = (float)luaL_checknumber( L, 10 );
	const model_t *sprite;
	int fw = 0, fh = 0, texnum;

	if( !CC_Lua_IsPainting( ) || handle < 1 || handle > MAX_CLIENT_SPRITES )
		return 0;

	sprite = &clgame.sprites[handle - 1];

	if( !sprite->mempool )
		return 0;

	texnum = R_GetSpriteTexture( sprite, frame );
	R_GetSpriteParms( &fw, &fh, NULL, frame, sprite );

	if( !texnum || fw <= 0 || fh <= 0 )
		return 0;

	{
		float ox = x, oy = y, ow = w, oh = h;

		if( !CC_Clip_Rect( &x, &y, &w, &h ))
			return 0;

		sx += ( x - ox ) / ow * sw;
		sy += ( y - oy ) / oh * sh;
		sw *= w / ow;
		sh *= h / oh;
	}

	ref.dllFuncs.GL_SetRenderMode( kRenderTransAdd );
	ref.dllFuncs.Color4ub( CC_Lua_Byte( L, 11 ), CC_Lua_Byte( L, 12 ), CC_Lua_Byte( L, 13 ), CC_Lua_Byte( L, 14 ));
	ref.dllFuncs.R_DrawStretchPic( x, y, w, h, sx / fw, sy / fh, ( sx + sw ) / fw, ( sy + sh ) / fh, texnum );
	ref.dllFuncs.GL_SetRenderMode( kRenderNormal );
#else
	(void)L;
#endif
	return 0;
}

static int CC_Give( lua_State *L )
{
	const char *name = luaL_checkstring( L, 1 );
	qboolean ok = false;

#if !XASH_DEDICATED
	size_t length = strlen( name );

	if( length > 0 && length < 48 && Host_IsLocalClient( ) && cls.state == ca_active
		&& ( !Q_strncmp( name, "weapon_", 7 ) || !Q_strncmp( name, "ammo_", 5 ) || !Q_strncmp( name, "item_", 5 )))
	{
		char command[96];

		ok = true;

		for( size_t i = 0; i < length; i++ )
		{
			char c = name[i];

			if( !(( c >= 'a' && c <= 'z' ) || ( c >= 'A' && c <= 'Z' ) || ( c >= '0' && c <= '9' ) || c == '_' ))
				ok = false;
		}

		if( ok )
		{
			Q_snprintf( command, sizeof( command ), "sv_cheats 1\ngive %s\n", name );
			Cbuf_AddText( command );
		}
	}
#else
	(void)name;
#endif
	lua_pushboolean( L, ok );
	return 1;
}

static int CC_Player_Info( lua_State *L )
{
	lua_newtable( L );

#if !XASH_DEDICATED
	if( cls.state == ca_active )
	{
		lua_pushboolean( L, true );
		lua_setfield( L, -2, "active" );

		lua_pushinteger( L, cl.local.health );
		lua_setfield( L, -2, "health" );

		lua_pushinteger( L, cl.local.weapons );
		lua_setfield( L, -2, "weapons" );

		lua_pushboolean( L, !Q_strcmp( Info_ValueForKey( cls.physinfo, "slj" ), "1" ));
		lua_setfield( L, -2, "longjump" );

		lua_pushnumber( L, cl.simorg[0] );
		lua_setfield( L, -2, "x" );

		lua_pushnumber( L, cl.simorg[1] );
		lua_setfield( L, -2, "y" );

		lua_pushnumber( L, cl.simorg[2] );
		lua_setfield( L, -2, "z" );
	}
#endif
	return 1;
}

static int CC_Hd_Available( lua_State *L )
{
	qboolean found = false;

#if !XASH_DEDICATED && !XASH_WIN32
	char path[MAX_SYSPATH];
	struct stat info;

	Q_snprintf( path, sizeof( path ), "%s_hd", GI->gamefolder );
	found = stat( path, &info ) == 0 && S_ISDIR( info.st_mode );
#endif
	lua_pushboolean( L, found );
	return 1;
}

static int CC_Hd_Enabled( lua_State *L )
{
	convar_t *var = Cvar_FindVar( "fs_mount_hd" );

	lua_pushboolean( L, var && var->value != 0.0f );
	return 1;
}

static int CC_Hd_Set( lua_State *L )
{
	convar_t *var = Cvar_FindVar( "fs_mount_hd" );

#if !XASH_DEDICATED
	if( var )
	{
		Cvar_DirectSet( var, lua_toboolean( L, 1 ) ? "1" : "0" );
		FS_SaveVFSConfig( );
		Cbuf_AddText( "fs_rescan\n" );
	}
#else
	(void)L;
#endif
	lua_pushboolean( L, var != NULL );
	return 1;
}

static int CC_Map( lua_State *L )
{
#if !XASH_DEDICATED
	lua_pushstring( L, clgame.mapname );
#else
	lua_pushstring( L, "" );
#endif
	return 1;
}

static int CC_Reload( lua_State *L )
{
	(void)L;
	CC_Lua_RequestReload( );
	return 0;
}

static int CC_Hud_HideDefaultCrosshair( lua_State *L )
{
	CC_Lua_SetHideCrosshair( lua_toboolean( L, 1 ));
	return 0;
}

void CC_Lua_ResetClip( void )
{
#if !XASH_DEDICATED
	cc_clip.enabled = false;
	cc_font.checked = false;
#endif
}

static int CC_Hud_HideTouch( lua_State *L )
{
	CC_Lua_SetHideTouch( lua_toboolean( L, 1 ));
	return 0;
}

static int CC_Fs_Read( lua_State *L )
{
	const char *path = luaL_checkstring( L, 1 );
	fs_offset_t size = 0;
	byte *data;

	if( !CC_Lua_PathAllowed( path ))
		return luaL_error( L, "fs.Read: invalid path '%s'", path );

	data = FS_LoadFile( path, &size, !lua_toboolean( L, 2 ));

	if( !data )
	{
		lua_pushnil( L );
		return 1;
	}

	lua_pushlstring( L, (const char *)data, (size_t)size );
	Mem_Free( data );
	return 1;
}

static int CC_Fs_Write( lua_State *L )
{
	const char *path = luaL_checkstring( L, 1 );
	size_t size;
	const char *data = luaL_checklstring( L, 2, &size );

	if( !CC_Lua_PathAllowed( path ) || ( Q_strcmp( path, "cc_settings.cfg" ) && Q_strncmp( path, "data/", 5 )))
		return luaL_error( L, "fs.Write: path '%s' is not writable", path );

	lua_pushboolean( L, FS_WriteFile( path, data, (fs_offset_t)size ));
	return 1;
}

static int CC_Fs_Exists( lua_State *L )
{
	const char *path = luaL_checkstring( L, 1 );

	if( !CC_Lua_PathAllowed( path ))
		return luaL_error( L, "fs.Exists: invalid path '%s'", path );

	lua_pushboolean( L, FS_FileExists( path, true ));
	return 1;
}

static int CC_Fs_Find( lua_State *L )
{
	const char *pattern = luaL_checkstring( L, 1 );
	search_t *list;

	if( !CC_Lua_PathAllowed( pattern ))
		return luaL_error( L, "fs.Find: invalid pattern '%s'", pattern );

	list = FS_Search( pattern, true, !lua_toboolean( L, 2 ));
	lua_newtable( L );

	if( !list )
		return 1;

	for( int i = 0; i < list->numfilenames; i++ )
	{
		lua_pushstring( L, list->filenames[i] );
		lua_rawseti( L, -2, i + 1 );
	}

	Mem_Free( list );
	return 1;
}

static void CC_Lua_RegisterTable( lua_State *L, const char *name, const luaL_Reg *funcs )
{
	lua_newtable( L );
	luaL_setfuncs( L, funcs, 0 );
	lua_setfield( L, -2, name );
}

void CC_Lua_OpenAPI( lua_State *L )
{
	static const luaL_Reg log_funcs[] = { { "Print", CC_Log_Print }, { "Error", CC_Log_Error }, { NULL, NULL } };
	static const luaL_Reg screen_funcs[] = { { "Width", CC_Screen_Width }, { "Height", CC_Screen_Height }, { NULL, NULL } };
	static const luaL_Reg draw_funcs[] = { { "Rect", CC_Draw_Rect }, { "Circle", CC_Draw_Circle }, { "Text", CC_Draw_Text }, { "TextSize", CC_Draw_TextSize }, { "Glyph", CC_Draw_Glyph }, { "GlyphReady", CC_Draw_GlyphReady }, { "SetClip", CC_Draw_SetClip }, { "ClearClip", CC_Draw_ClearClip }, { "ImageLoad", CC_Draw_ImageLoad }, { "Image", CC_Draw_Image }, { "SpriteLoad", CC_Draw_SpriteLoad }, { "Sprite", CC_Draw_Sprite }, { NULL, NULL } };
	static const luaL_Reg player_funcs[] = { { "Info", CC_Player_Info }, { NULL, NULL } };
	static const luaL_Reg hd_funcs[] = { { "Available", CC_Hd_Available }, { "Enabled", CC_Hd_Enabled }, { "Set", CC_Hd_Set }, { NULL, NULL } };
	static const luaL_Reg hud_funcs[] = { { "HideDefaultCrosshair", CC_Hud_HideDefaultCrosshair }, { "HideTouch", CC_Hud_HideTouch }, { NULL, NULL } };
	static const luaL_Reg fs_funcs[] = { { "Read", CC_Fs_Read }, { "Write", CC_Fs_Write }, { "Exists", CC_Fs_Exists }, { "Find", CC_Fs_Find }, { NULL, NULL } };

	lua_newtable( L );

	CC_Lua_RegisterTable( L, "log", log_funcs );
	CC_Lua_RegisterTable( L, "screen", screen_funcs );
	CC_Lua_RegisterTable( L, "draw", draw_funcs );
	CC_Lua_RegisterTable( L, "hud", hud_funcs );
	CC_Lua_RegisterTable( L, "player", player_funcs );
	CC_Lua_RegisterTable( L, "hd", hd_funcs );
	CC_Lua_RegisterTable( L, "fs", fs_funcs );
	CC_World_Register( L );
	CC_Sv_Register( L );

	lua_pushstring( L, GI->gamefolder );
	lua_setfield( L, -2, "game" );

	lua_pushstring( L, CC_Lua_Version( ));
	lua_setfield( L, -2, "version" );

	lua_newtable( L );
	lua_setfield( L, -2, "scripts" );

	lua_newtable( L );
	lua_setfield( L, -2, "addons" );

	lua_pushcfunction( L, CC_Reload );
	lua_setfield( L, -2, "Reload" );

	lua_pushcfunction( L, CC_Give );
	lua_setfield( L, -2, "Give" );

	lua_pushcfunction( L, CC_Map );
	lua_setfield( L, -2, "Map" );

	lua_setglobal( L, "cc" );

	lua_pushboolean( L, !Host_IsDedicated( ));
	lua_setglobal( L, "CLIENT" );

	lua_pushboolean( L, true );
	lua_setglobal( L, "SERVER" );
}
