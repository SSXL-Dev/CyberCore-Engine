#ifndef CC_LUA_INTERNAL_H
#define CC_LUA_INTERNAL_H

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

void CC_Lua_Log( const char *level, const char *fmt, ... ) FORMAT_CHECK( 2 );
void CC_Lua_OpenAPI( lua_State *L );
void CC_Lua_SetPainting( qboolean painting );
int CC_Lua_IsPainting( void );
void CC_Lua_SetHideCrosshair( qboolean hide );
void CC_Lua_SetHideTouch( qboolean hide );
void CC_Lua_ResetClip( void );
void CC_World_Register( lua_State *L );
void CC_Sv_Register( lua_State *L );
const char *CC_Lua_Version( void );
const unsigned char *CC_Lua_FontPixels( int *width, int *height );
int CC_Lua_GetHideCrosshair( void );
int CC_Lua_PathAllowed( const char *path );
void CC_Lua_RequestReload( void );

#endif
