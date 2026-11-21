#include "common.h"
#include "lua/cc_lua.h"
#include "server.h"
#include "studio.h"
#include "mod_local.h"
#include "lua/cc_lua_internal.h"

#define CC_STR( offset ) ((offset) ? (const char *)( svgame.globals->pStringBase + (offset)) : "")

static const char *CC_World_Parts[] = { "generic", "head", "chest", "stomach", "left_arm", "right_arm", "left_leg", "right_leg", "shield" };

static qboolean CC_World_Active( void )
{
	return sv.state == ss_active && svgame.edicts != NULL && svgame.globals != NULL;
}

static edict_t *CC_World_Edict( int index )
{
	edict_t *e;

	if( !CC_World_Active( ) || index < 1 || index >= svgame.numEntities )
		return NULL;

	e = &svgame.edicts[index];

	if( e->free || !e->v.classname )
		return NULL;

	return e;
}

static sv_client_t *CC_World_Client( int index )
{
	sv_client_t *cl;

	if( index < 1 || index > svs.maxclients )
		return NULL;

	cl = &svs.clients[index - 1];

	if( cl->state < cs_connected || cl->edict == NULL )
		return NULL;

	return cl;
}

static void CC_World_Field( lua_State *L, const char *name, lua_Number value )
{
	lua_pushnumber( L, value );
	lua_setfield( L, -2, name );
}

static void CC_World_Text( lua_State *L, const char *name, const char *value )
{
	lua_pushstring( L, value );
	lua_setfield( L, -2, name );
}

static void CC_World_Flag( lua_State *L, const char *name, qboolean value )
{
	lua_pushboolean( L, value );
	lua_setfield( L, -2, name );
}

static void CC_World_Vector( lua_State *L, const char *name, const vec3_t value )
{
	lua_createtable( L, 0, 3 );
	CC_World_Field( L, "x", value[0] );
	CC_World_Field( L, "y", value[1] );
	CC_World_Field( L, "z", value[2] );
	lua_setfield( L, -2, name );
}

static void CC_World_Push( lua_State *L, int index, edict_t *e, qboolean detail )
{
	sv_client_t *cl = CC_World_Client( index );
	qboolean player = cl != NULL && FBitSet( e->v.flags, FL_CLIENT );

	lua_createtable( L, 0, 24 );
	CC_World_Field( L, "index", index );
	CC_World_Text( L, "classname", CC_STR( e->v.classname ));
	CC_World_Text( L, "name", player ? cl->name : CC_STR( e->v.targetname ));
	CC_World_Text( L, "kind", player ? "player" : FBitSet( e->v.flags, FL_MONSTER ) ? "monster" : "entity" );
	CC_World_Flag( L, "bot", player && FBitSet( e->v.flags, FL_FAKECLIENT ));
	CC_World_Field( L, "flags", e->v.flags );
	CC_World_Field( L, "health", e->v.health );
	CC_World_Field( L, "max_health", e->v.max_health );
	CC_World_Field( L, "armor", e->v.armorvalue );
	CC_World_Field( L, "deadflag", e->v.deadflag );
	CC_World_Flag( L, "alive", e->v.deadflag == DEAD_NO && e->v.health > 0.0f );
	CC_World_Field( L, "takedamage", e->v.takedamage );
	CC_World_Field( L, "team", e->v.team );
	CC_World_Vector( L, "origin", e->v.origin );

	if( !detail )
		return;

	CC_World_Text( L, "model", CC_STR( e->v.model ));
	CC_World_Field( L, "sequence", e->v.sequence );
	CC_World_Field( L, "frame", e->v.frame );
	CC_World_Field( L, "solid", e->v.solid );
	CC_World_Field( L, "movetype", e->v.movetype );
	CC_World_Vector( L, "angles", e->v.angles );
	CC_World_Vector( L, "velocity", e->v.velocity );
	CC_World_Vector( L, "v_angle", e->v.v_angle );
	CC_World_Vector( L, "mins", e->v.mins );
	CC_World_Vector( L, "maxs", e->v.maxs );

	if( player )
	{
		CC_World_Text( L, "player_model", Info_ValueForKey( cl->userinfo, "model" ));
		CC_World_Text( L, "player_team", Info_ValueForKey( cl->userinfo, "team" ));
		CC_World_Field( L, "weapons", e->v.weapons );
	}
}

static int CC_World_IsActive( lua_State *L )
{
	lua_pushboolean( L, CC_World_Active( ));
	return 1;
}

static int CC_World_Info( lua_State *L )
{
	lua_createtable( L, 0, 10 );
	CC_World_Flag( L, "active", CC_World_Active( ));
	CC_World_Text( L, "map", sv.name );
	CC_World_Field( L, "maxplayers", svs.maxclients );
	CC_World_Flag( L, "singleplayer", svs.maxclients <= 1 );
	CC_World_Field( L, "skill", Cvar_VariableValue( "skill" ));
	CC_World_Field( L, "deathmatch", Cvar_VariableValue( "deathmatch" ));
	CC_World_Field( L, "coop", Cvar_VariableValue( "coop" ));
	CC_World_Field( L, "teamplay", Cvar_VariableValue( "teamplay" ));
	CC_World_Field( L, "time", sv.time );
	return 1;
}

static int CC_World_Entities( lua_State *L )
{
	const char *kind = luaL_optstring( L, 1, "" );
	int i, count = 0;

	lua_newtable( L );

	if( !CC_World_Active( ))
		return 1;

	for( i = 1; i < svgame.numEntities; i++ )
	{
		edict_t *e = CC_World_Edict( i );
		sv_client_t *cl = CC_World_Client( i );
		const char *entity_kind;

		if( !e )
			continue;

		if( cl != NULL && FBitSet( e->v.flags, FL_CLIENT ))
			entity_kind = "player";
		else if( FBitSet( e->v.flags, FL_MONSTER ))
			entity_kind = "monster";
		else
			entity_kind = "entity";

		if( kind[0] && Q_strcmp( kind, entity_kind ))
			continue;

		CC_World_Push( L, i, e, false );
		lua_rawseti( L, -2, ++count );
	}

	return 1;
}

static int CC_World_Entity( lua_State *L )
{
	int index = (int)luaL_checkinteger( L, 1 );
	edict_t *e = CC_World_Edict( index );

	if( !e )
	{
		lua_pushnil( L );
		return 1;
	}

	CC_World_Push( L, index, e, true );
	return 1;
}

static int CC_World_Find( lua_State *L )
{
	const char *name = luaL_checkstring( L, 1 );
	int i, count = 0;

	lua_newtable( L );

	if( !CC_World_Active( ))
		return 1;

	for( i = 1; i < svgame.numEntities; i++ )
	{
		edict_t *e = CC_World_Edict( i );

		if( !e || Q_strcmp( CC_STR( e->v.classname ), name ))
			continue;

		lua_createtable( L, 0, 8 );
		CC_World_Field( L, "index", i );
		CC_World_Vector( L, "origin", e->v.origin );
		CC_World_Vector( L, "absmin", e->v.absmin );
		CC_World_Vector( L, "absmax", e->v.absmax );
		CC_World_Text( L, "target", CC_STR( e->v.targetname ));
		lua_rawseti( L, -2, ++count );
	}

	return 1;
}

static int CC_World_Hitboxes( lua_State *L )
{
	int index = (int)luaL_checkinteger( L, 1 );
	edict_t *e = CC_World_Edict( index );
	model_t *mod;
	studiohdr_t *hdr;
	mstudiobbox_t *boxes;
	mstudiobone_t *bones;
	int i;

	lua_newtable( L );

	if( !e )
		return 1;

	mod = SV_ModelHandle( e->v.modelindex );

	if( !mod || mod->type != mod_studio )
		return 1;

	hdr = (studiohdr_t *)Mod_StudioExtradata( mod );

	if( !hdr || hdr->numhitboxes <= 0 || hdr->numbones <= 0 )
		return 1;

	boxes = (mstudiobbox_t *)((byte *)hdr + hdr->hitboxindex );
	bones = (mstudiobone_t *)((byte *)hdr + hdr->boneindex );

	for( i = 0; i < hdr->numhitboxes && i < 128; i++ )
	{
		const mstudiobbox_t *box = &boxes[i];
		const char *part = "generic";
		vec3_t origin, angles, forward, right, up, center, size, world;
		char bone_name[33];
		int j;

		if( box->bone < 0 || box->bone >= hdr->numbones )
			continue;

		Q_strncpy( bone_name, bones[box->bone].name, sizeof( bone_name ));

		if( box->group >= 0 && box->group < (int)ARRAYSIZE( CC_World_Parts ))
			part = CC_World_Parts[box->group];

		for( j = 0; bone_name[j]; j++ )
			bone_name[j] = Q_tolower( bone_name[j] );

		if( Q_strstr( bone_name, "neck" ))
			part = "neck";

		Mod_GetBonePosition( e, box->bone, origin, angles );
		AngleVectors( angles, forward, right, up );

		VectorAverage( box->bbmin, box->bbmax, center );
		VectorSubtract( box->bbmax, box->bbmin, size );

		VectorScale( forward, center[0], world );
		VectorMA( world, -center[1], right, world );
		VectorMA( world, center[2], up, world );
		VectorAdd( world, origin, world );

		lua_createtable( L, 0, 8 );
		CC_World_Text( L, "part", part );
		CC_World_Field( L, "group", box->group );
		CC_World_Field( L, "bone", box->bone );
		CC_World_Text( L, "bone_name", bones[box->bone].name );
		CC_World_Vector( L, "origin", world );
		CC_World_Vector( L, "size", size );
		lua_rawseti( L, -2, i + 1 );
	}

	return 1;
}

static int CC_Cvar_Allowed( const char *name )
{
	char lower[64];
	int i;

	for( i = 0; name[i] && i < (int)sizeof( lower ) - 1; i++ )
		lower[i] = Q_tolower( name[i] );

	lower[i] = '\0';

	return Q_strstr( lower, "password" ) == NULL && Q_strstr( lower, "rcon" ) == NULL;
}

static int CC_Cvar_Get( lua_State *L )
{
	const char *name = luaL_checkstring( L, 1 );
	convar_t *var = CC_Cvar_Allowed( name ) ? Cvar_FindVar( name ) : NULL;

	if( var )
		lua_pushnumber( L, var->value );
	else
		lua_pushnil( L );

	return 1;
}

static int CC_Cvar_Set( lua_State *L )
{
	const char *name = luaL_checkstring( L, 1 );
	const char *value = luaL_checkstring( L, 2 );
	convar_t *var = CC_Cvar_Allowed( name ) ? Cvar_FindVar( name ) : NULL;

	if( !var || FBitSet( var->flags, FCVAR_READ_ONLY | FCVAR_PRIVILEGED ))
	{
		lua_pushboolean( L, false );
		return 1;
	}

	Cvar_Set( name, value );
	lua_pushboolean( L, true );
	return 1;
}

static int CC_Maps_SetEntity( lua_State *L )
{
	CC_Lua_SetMapEntity( lua_isnoneornil( L, 1 ) ? NULL : luaL_checkstring( L, 1 ));
	return 0;
}

static int CC_Maps_SetStory( lua_State *L )
{
	CC_Lua_SetMapStory( lua_toboolean( L, 1 ));
	return 0;
}

static int CC_Maps_Refresh( lua_State *L )
{
	lua_pushboolean( L, Cmd_CheckMapsList( true ));
	return 1;
}

static int CC_Cvar_GetString( lua_State *L )
{
	const char *name = luaL_checkstring( L, 1 );
	convar_t *var = CC_Cvar_Allowed( name ) ? Cvar_FindVar( name ) : NULL;

	if( var )
		lua_pushstring( L, var->string );
	else
		lua_pushnil( L );

	return 1;
}

void CC_World_Register( lua_State *L )
{
	static const luaL_Reg world_funcs[] =
	{
		{ "Active", CC_World_IsActive },
		{ "Info", CC_World_Info },
		{ "Entities", CC_World_Entities },
		{ "Entity", CC_World_Entity },
		{ "Find", CC_World_Find },
		{ "Hitboxes", CC_World_Hitboxes },
		{ NULL, NULL }
	};
	static const luaL_Reg maps_funcs[] = { { "SetEntity", CC_Maps_SetEntity }, { "SetStory", CC_Maps_SetStory }, { "Refresh", CC_Maps_Refresh }, { NULL, NULL } };
	static const luaL_Reg cvar_funcs[] = { { "Get", CC_Cvar_Get }, { "GetString", CC_Cvar_GetString }, { "Set", CC_Cvar_Set }, { NULL, NULL } };

	lua_newtable( L );
	luaL_setfuncs( L, world_funcs, 0 );
	lua_setfield( L, -2, "world" );

	lua_newtable( L );
	luaL_setfuncs( L, cvar_funcs, 0 );
	lua_setfield( L, -2, "cvar" );

	lua_newtable( L );
	luaL_setfuncs( L, maps_funcs, 0 );
	lua_setfield( L, -2, "maps" );
}
