#include "common.h"
#include "server.h"
#include "studio.h"
#include "mod_local.h"
#include "lua/cc_lua_internal.h"

#define CC_BOT_CLASS "cc_nextbot"

enum
{
	CC_MSG_PVS = 4,
	CC_SVC_TEMPENTITY = 23,
	CC_TE_BEAMPOINTS = 0,
	CC_TE_SPARKS = 9,
	CC_TE_DLIGHT = 27
};

enginefuncs_t *CC_SV_Engine( void );

static qboolean CC_Sv_Running( void )
{
	return sv.state != ss_dead && svgame.edicts != NULL && svgame.globals != NULL;
}

static edict_t *CC_Sv_Bot( int index )
{
	edict_t *e;

	if( !CC_Sv_Running( ) || index < 1 || index >= svgame.numEntities )
		return NULL;

	e = &svgame.edicts[index];

	if( e->free || !e->v.classname )
		return NULL;

	if( Q_strcmp((const char *)( svgame.globals->pStringBase + e->v.classname ), CC_BOT_CLASS ))
		return NULL;

	return e;
}

static void CC_Sv_ReadVector( lua_State *L, int first, vec3_t out )
{
	out[0] = (float)luaL_checknumber( L, first );
	out[1] = (float)luaL_checknumber( L, first + 1 );
	out[2] = (float)luaL_checknumber( L, first + 2 );
}

static int CC_Sv_Precache( lua_State *L )
{
	const char *path = luaL_checkstring( L, 1 );
	const char *ext = COM_FileExtension( path );
	enginefuncs_t *eng = CC_SV_Engine();
	int index = 0;

	if( CC_Sv_Running( ))
	{
		if( !Q_stricmp( ext, "mdl" ) || !Q_stricmp( ext, "spr" ))
			index = eng->pfnPrecacheModel( path );
		else if( !Q_stricmp( ext, "wav" ) || !Q_stricmp( ext, "mp3" ))
			index = eng->pfnPrecacheSound( path );
	}

	lua_pushinteger( L, index );
	return 1;
}

static int CC_Sv_Spawn( lua_State *L )
{
	enginefuncs_t *eng = CC_SV_Engine();
	vec3_t origin, angles;
	edict_t *e;

	if( !CC_Sv_Running( ) || sv.state != ss_active )
	{
		lua_pushnil( L );
		return 1;
	}

	CC_Sv_ReadVector( L, 1, origin );
	VectorSet( angles, 0.0f, (float)luaL_checknumber( L, 4 ), 0.0f );

	e = eng->pfnCreateEntity();

	if( !e )
	{
		lua_pushnil( L );
		return 1;
	}

	e->v.classname = eng->pfnAllocString( CC_BOT_CLASS );
	e->v.movetype = MOVETYPE_STEP;
	e->v.solid = SOLID_SLIDEBOX;
	e->v.takedamage = DAMAGE_NO;
	e->v.health = 100.0f;
	VectorCopy( angles, e->v.angles );
	eng->pfnSetOrigin( e, origin );

	lua_pushinteger( L, NUM_FOR_EDICT( e ));
	return 1;
}

static int CC_Sv_SetModel( lua_State *L )
{
	edict_t *e = CC_Sv_Bot( (int)luaL_checkinteger( L, 1 ));

	if( e )
		CC_SV_Engine()->pfnSetModel( e, luaL_checkstring( L, 2 ));

	lua_pushboolean( L, e != NULL );
	return 1;
}

static int CC_Sv_SetSize( lua_State *L )
{
	edict_t *e = CC_Sv_Bot( (int)luaL_checkinteger( L, 1 ));
	vec3_t mins, maxs;

	CC_Sv_ReadVector( L, 2, mins );
	CC_Sv_ReadVector( L, 5, maxs );

	if( e )
		CC_SV_Engine()->pfnSetSize( e, mins, maxs );

	lua_pushboolean( L, e != NULL );
	return 1;
}

static int CC_Sv_SetOrigin( lua_State *L )
{
	edict_t *e = CC_Sv_Bot( (int)luaL_checkinteger( L, 1 ));
	vec3_t origin;

	CC_Sv_ReadVector( L, 2, origin );

	if( e )
		CC_SV_Engine()->pfnSetOrigin( e, origin );

	lua_pushboolean( L, e != NULL );
	return 1;
}

static int CC_Sv_Set( lua_State *L )
{
	edict_t *e = CC_Sv_Bot( (int)luaL_checkinteger( L, 1 ));
	const char *name = luaL_checkstring( L, 2 );
	float a = (float)luaL_optnumber( L, 3, 0.0 );
	float b = (float)luaL_optnumber( L, 4, 0.0 );
	float c = (float)luaL_optnumber( L, 5, 0.0 );
	qboolean ok = e != NULL;

	if( !e )
		ok = false;
	else if( !Q_strcmp( name, "angles" )) VectorSet( e->v.angles, a, b, c );
	else if( !Q_strcmp( name, "velocity" )) VectorSet( e->v.velocity, a, b, c );
	else if( !Q_strcmp( name, "rendercolor" )) VectorSet( e->v.rendercolor, a, b, c );
	else if( !Q_strcmp( name, "sequence" )) e->v.sequence = (int)a;
	else if( !Q_strcmp( name, "frame" )) e->v.frame = a;
	else if( !Q_strcmp( name, "framerate" )) e->v.framerate = a;
	else if( !Q_strcmp( name, "animtime" )) e->v.animtime = a;
	else if( !Q_strcmp( name, "rendermode" )) e->v.rendermode = (int)a;
	else if( !Q_strcmp( name, "renderamt" )) e->v.renderamt = a;
	else if( !Q_strcmp( name, "renderfx" )) e->v.renderfx = (int)a;
	else if( !Q_strcmp( name, "effects" )) e->v.effects = (int)a;
	else if( !Q_strcmp( name, "scale" )) e->v.scale = a;
	else if( !Q_strcmp( name, "skin" )) e->v.skin = (int)a;
	else if( !Q_strcmp( name, "body" )) e->v.body = (int)a;
	else if( !Q_strcmp( name, "health" )) e->v.health = a;
	else if( !Q_strcmp( name, "takedamage" )) e->v.takedamage = a;
	else ok = false;

	lua_pushboolean( L, ok );
	return 1;
}

static int CC_Sv_Walk( lua_State *L )
{
	edict_t *e = CC_Sv_Bot( (int)luaL_checkinteger( L, 1 ));
	float yaw = (float)luaL_checknumber( L, 2 );
	float dist = (float)luaL_checknumber( L, 3 );
	int moved = 0;

	if( e )
	{
		e->v.angles[YAW] = yaw;
		e->v.ideal_yaw = yaw;
		moved = CC_SV_Engine()->pfnWalkMove( e, yaw, dist, 0 );
	}

	lua_pushboolean( L, moved );
	return 1;
}

static int CC_Sv_DropToFloor( lua_State *L )
{
	edict_t *e = CC_Sv_Bot( (int)luaL_checkinteger( L, 1 ));

	lua_pushboolean( L, e != NULL && CC_SV_Engine()->pfnDropToFloor( e ) > 0 );
	return 1;
}

static int CC_Sv_Remove( lua_State *L )
{
	edict_t *e = CC_Sv_Bot( (int)luaL_checkinteger( L, 1 ));

	if( e )
		CC_SV_Engine()->pfnRemoveEntity( e );

	lua_pushboolean( L, e != NULL );
	return 1;
}

static int CC_Sv_RemoveAll( lua_State *L )
{
	int i, count = 0;

	for( i = 1; i < svgame.numEntities && CC_Sv_Running( ); i++ )
	{
		edict_t *e = CC_Sv_Bot( i );

		if( e )
		{
			CC_SV_Engine()->pfnRemoveEntity( e );
			count++;
		}
	}

	lua_pushinteger( L, count );
	return 1;
}

static int CC_Sv_Sound( lua_State *L )
{
	edict_t *e = CC_Sv_Bot( (int)luaL_checkinteger( L, 1 ));
	int channel = (int)luaL_checkinteger( L, 2 );
	const char *sample = luaL_checkstring( L, 3 );
	float volume = (float)luaL_optnumber( L, 4, 1.0 );
	float attenuation = (float)luaL_optnumber( L, 5, 0.8 );
	int pitch = (int)luaL_optinteger( L, 6, 100 );

	if( e )
		CC_SV_Engine()->pfnEmitSound( e, channel, sample, volume, attenuation, 0, pitch );

	lua_pushboolean( L, e != NULL );
	return 1;
}

static void CC_Sv_BeginTemp( int code, const vec3_t origin )
{
	enginefuncs_t *eng = CC_SV_Engine();

	eng->pfnMessageBegin( CC_MSG_PVS, CC_SVC_TEMPENTITY, origin, NULL );
	eng->pfnWriteByte( code );
}

static void CC_Sv_WriteCoords( const vec3_t v )
{
	enginefuncs_t *eng = CC_SV_Engine();

	eng->pfnWriteCoord( v[0] );
	eng->pfnWriteCoord( v[1] );
	eng->pfnWriteCoord( v[2] );
}

static int CC_Sv_Beam( lua_State *L )
{
	enginefuncs_t *eng = CC_SV_Engine();
	vec3_t start, end;

	if( !CC_Sv_Running( ))
		return 0;

	CC_Sv_ReadVector( L, 1, start );
	CC_Sv_ReadVector( L, 4, end );

	CC_Sv_BeginTemp( CC_TE_BEAMPOINTS, start );
	CC_Sv_WriteCoords( start );
	CC_Sv_WriteCoords( end );
	eng->pfnWriteShort( (int)luaL_checkinteger( L, 7 ));
	eng->pfnWriteByte( 0 );
	eng->pfnWriteByte( 0 );
	eng->pfnWriteByte( (int)luaL_optinteger( L, 8, 4 ));
	eng->pfnWriteByte( (int)luaL_optinteger( L, 9, 8 ));
	eng->pfnWriteByte( (int)luaL_optinteger( L, 10, 40 ));
	eng->pfnWriteByte( (int)luaL_optinteger( L, 11, 255 ));
	eng->pfnWriteByte( (int)luaL_optinteger( L, 12, 255 ));
	eng->pfnWriteByte( (int)luaL_optinteger( L, 13, 255 ));
	eng->pfnWriteByte( (int)luaL_optinteger( L, 14, 255 ));
	eng->pfnWriteByte( (int)luaL_optinteger( L, 15, 0 ));
	eng->pfnMessageEnd();
	return 0;
}

static int CC_Sv_Light( lua_State *L )
{
	enginefuncs_t *eng = CC_SV_Engine();
	vec3_t origin;

	if( !CC_Sv_Running( ))
		return 0;

	CC_Sv_ReadVector( L, 1, origin );
	CC_Sv_BeginTemp( CC_TE_DLIGHT, origin );
	CC_Sv_WriteCoords( origin );
	eng->pfnWriteByte( (int)luaL_optinteger( L, 4, 20 ));
	eng->pfnWriteByte( (int)luaL_optinteger( L, 5, 255 ));
	eng->pfnWriteByte( (int)luaL_optinteger( L, 6, 255 ));
	eng->pfnWriteByte( (int)luaL_optinteger( L, 7, 255 ));
	eng->pfnWriteByte( (int)luaL_optinteger( L, 8, 8 ));
	eng->pfnWriteByte( (int)luaL_optinteger( L, 9, 20 ));
	eng->pfnMessageEnd();
	return 0;
}

static int CC_Sv_Sparks( lua_State *L )
{
	vec3_t origin;

	if( !CC_Sv_Running( ))
		return 0;

	CC_Sv_ReadVector( L, 1, origin );
	CC_Sv_BeginTemp( CC_TE_SPARKS, origin );
	CC_Sv_WriteCoords( origin );
	CC_SV_Engine()->pfnMessageEnd();
	return 0;
}

static int CC_Sv_Trace( lua_State *L )
{
	TraceResult tr;
	vec3_t start, end;
	int skip = (int)luaL_optinteger( L, 7, 0 );

	lua_createtable( L, 0, 8 );

	if( !CC_Sv_Running( ))
		return 1;

	CC_Sv_ReadVector( L, 1, start );
	CC_Sv_ReadVector( L, 4, end );
	CC_SV_Engine()->pfnTraceLine( start, end, 1, skip > 0 && skip < svgame.numEntities ? &svgame.edicts[skip] : NULL, &tr );

	lua_pushnumber( L, tr.flFraction );
	lua_setfield( L, -2, "fraction" );
	lua_pushnumber( L, tr.vecEndPos[0] );
	lua_setfield( L, -2, "x" );
	lua_pushnumber( L, tr.vecEndPos[1] );
	lua_setfield( L, -2, "y" );
	lua_pushnumber( L, tr.vecEndPos[2] );
	lua_setfield( L, -2, "z" );
	lua_pushboolean( L, tr.fStartSolid );
	lua_setfield( L, -2, "startsolid" );
	lua_pushboolean( L, tr.fAllSolid );
	lua_setfield( L, -2, "allsolid" );
	lua_pushnumber( L, tr.vecPlaneNormal[2] );
	lua_setfield( L, -2, "normal_z" );
	return 1;
}

static int CC_Sv_Sequences( lua_State *L )
{
	model_t *mod = NULL;
	studiohdr_t *hdr;
	mstudioseqdesc_t *seqs;
	int i;

	lua_newtable( L );

	if( !CC_Sv_Running( ))
		return 1;

	if( lua_type( L, 1 ) == LUA_TSTRING )
		mod = SV_ModelHandle( CC_SV_Engine()->pfnModelIndex( lua_tostring( L, 1 )));
	else
	{
		edict_t *e = CC_Sv_Bot( (int)luaL_checkinteger( L, 1 ));

		if( e )
			mod = SV_ModelHandle( e->v.modelindex );
	}

	if( !mod || mod->type != mod_studio )
		return 1;

	hdr = (studiohdr_t *)Mod_StudioExtradata( mod );

	if( !hdr || hdr->numseq <= 0 )
		return 1;

	seqs = (mstudioseqdesc_t *)((byte *)hdr + hdr->seqindex );

	for( i = 0; i < hdr->numseq && i < 512; i++ )
	{
		lua_createtable( L, 0, 5 );
		lua_pushinteger( L, i );
		lua_setfield( L, -2, "index" );
		lua_pushstring( L, seqs[i].label );
		lua_setfield( L, -2, "name" );
		lua_pushnumber( L, seqs[i].fps );
		lua_setfield( L, -2, "fps" );
		lua_pushinteger( L, seqs[i].numframes );
		lua_setfield( L, -2, "frames" );
		lua_pushboolean( L, FBitSet( seqs[i].flags, STUDIO_LOOPING ));
		lua_setfield( L, -2, "loop" );
		lua_rawseti( L, -2, i + 1 );
	}

	return 1;
}

void CC_Sv_Register( lua_State *L )
{
	static const luaL_Reg sv_funcs[] =
	{
		{ "Precache", CC_Sv_Precache },
		{ "Spawn", CC_Sv_Spawn },
		{ "SetModel", CC_Sv_SetModel },
		{ "SetSize", CC_Sv_SetSize },
		{ "SetOrigin", CC_Sv_SetOrigin },
		{ "Set", CC_Sv_Set },
		{ "Walk", CC_Sv_Walk },
		{ "DropToFloor", CC_Sv_DropToFloor },
		{ "Remove", CC_Sv_Remove },
		{ "RemoveAll", CC_Sv_RemoveAll },
		{ "Sound", CC_Sv_Sound },
		{ "Beam", CC_Sv_Beam },
		{ "Light", CC_Sv_Light },
		{ "Sparks", CC_Sv_Sparks },
		{ "Trace", CC_Sv_Trace },
		{ "Sequences", CC_Sv_Sequences },
		{ NULL, NULL }
	};

	lua_newtable( L );
	luaL_setfuncs( L, sv_funcs, 0 );
	lua_setfield( L, -2, "sv" );
}
