#ifndef CC_LUA_H
#define CC_LUA_H

void CC_Lua_Init( void );
void CC_Lua_Shutdown( void );
void CC_Lua_Paint( void );
int CC_Lua_HideCrosshair( void );
int CC_Lua_HideTouch( void );
void CC_Lua_UserMsg( const char *name, int size, const byte *data );
int CC_Lua_BlockFill( float x, float y, float w, float h );
int CC_Lua_Touch( int type, int finger, float x, float y );
int CC_Lua_LoadTouchDefaults( void );
void CC_Lua_ServerActivate( void );
void CC_Lua_ServerFrame( float frametime );

#endif
