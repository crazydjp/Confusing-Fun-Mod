#include <amxmodx> 
#include <amxmisc>
#include <cstrike>
#include <fun>
#include <fakemeta>
#include <engine>
#include <hamsandwich>
#if AMXX_VERSION_NUM < 183
	#include <dhudmessage>
#endif

#define PLUGIN "Confusing_Fun_Mod"
#define VERSION "2.0"
#define AUTHOR "CrAzY MaN"

#define WBOX "models/w_weaponbox.mdl"
#define BOMB "models/w_backpack.mdl"
#define SHLD "models/w_shield.mdl"

#define keys MENU_KEY_0 | MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_4 | MENU_KEY_5 | MENU_KEY_6 | MENU_KEY_7 | MENU_KEY_8 | MENU_KEY_9

#define MAX_PLAYERS 32

enum _:Settings
{
	bool:WELCOME_MSG,
	bool:WELCOME_SOUND,
	WELCOME_SOUND_PATH[128],
	bool:SWAP_WEAPONS,
	bool:SWAP_TEAMS,
	SWAP_TEAMS_MSG,
	bool:RESPAWN_PLAYER, 
	RESPAWN_TIME,
	bool:REMEMBER_WEAPONS,
	bool:SPAWN_MONEY,
	bool:SPAWN_MONEY_AMOUNT,
	bool:SPAWN_MONEY_MSG,
	bool:BLOCK_WPNS_DROP_DEATH,
	bool:BLOCK_BUYZONE,
	bool:BUYZONE_LOCKED_MSG,
	bool:BLOCK_WPN_PICKUP,
	bool:KILL_SOUND,
	KILL_SOUND_PATH[128]
}

new g_Settings[Settings];

enum WeaponsData
{
	WEAPONS[32],
	W_NUM
}

new const MAXBPAMMO[31] = { -1, 52, -1, 90, 1, 32, 1, 100, 90, 1, 120, 100, 100, 90, 90, 90, 100, 120,
				30, 120, 200, 32, 90, 120, 90, 2, 35, 90, 90, -1, 100 };

const GRENADES_WEAPONS_BIT_SUM = (1<<CSW_HEGRENADE)|(1<<CSW_FLASHBANG)|(1<<CSW_SMOKEGRENADE);

const XO_CWEAPONBOX = 4; 
new const m_rgpPlayerItems_CWeaponBox[6] = {34,35,...}; 

new g_entid[MAX_PLAYERS + 1];
new g_maxents;
new gMsgStatusIcon;
new bool:gBlockBuyZone;
new g_WeaponsData[MAX_PLAYERS + 1][WeaponsData];
new g_iSayText;

public plugin_init() 
{ 
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_cvar(PLUGIN, VERSION, FCVAR_SERVER|FCVAR_SPONLY);
	
	register_dictionary("confusing_fun_mod.txt");
	
	register_event("DeathMsg", "Death", "a");
	register_logevent("logevent_round_start", 2, "1=Round_Start");
	
	RegisterHam(Ham_Killed, "player", "Ham_KilledPre", 0);
	RegisterHam(Ham_Spawn, "player", "Ham_SpawnPost", 1);
	
	register_forward(FM_SetModel, "forward_block_weapons_drop", 1);
	g_maxents = get_global_int(GL_maxEntities);
	
	gMsgStatusIcon = get_user_msgid("StatusIcon");
	register_message(gMsgStatusIcon, "MessageStatusIcon");
	
	register_touch("armoury_entity", "player", "OnPlayerTouchArmoury"); 
	register_touch("weaponbox", "player", "OnPlayerTouchWeaponBox"); 
	register_touch("weapon_shield", "player", "OnPlayerTouchShield"); 
	
	g_iSayText = get_user_msgid("SayText");
}

public plugin_precache()
{
	ReadFile();
	
	if(g_Settings[KILL_SOUND])
		precache_sound(g_Settings[KILL_SOUND_PATH]);
		
	if(g_Settings[WELCOME_SOUND])
		precache_sound(g_Settings[WELCOME_SOUND_PATH]);
		
	if(g_Settings[RESPAWN_PLAYER] && !g_Settings[BLOCK_BUYZONE])
		server_cmd("mp_buytime 99999999");
}

public client_connect(id)
{
	g_WeaponsData[id][W_NUM] = 0;
	
	if(gBlockBuyZone == true && g_Settings[RESPAWN_PLAYER])
		UnblockBuyZones();
		
	if(g_Settings[WELCOME_MSG])
		set_task(2.0, "welcome_menu", id);
		
	if(g_Settings[WELCOME_SOUND])
		set_task(2.0, "welcome_sound", id);	
}

public welcome_sound(id)
	client_cmd(id, "spk %s", g_Settings[WELCOME_SOUND_PATH]);


public Ham_KilledPre(id)
{
	if(!g_Settings[REMEMBER_WEAPONS])
		return HAM_IGNORED;
	
	new weapons[32];
	get_user_weapons(id, weapons, g_WeaponsData[id][W_NUM]);
	
	g_WeaponsData[id][WEAPONS] = weapons;
	
	return HAM_IGNORED;
}

public Death()
{
	new killer = read_data(1);
	new victim = read_data(2);
	
	static weapon[16]; 
	read_data(4, weapon, sizeof(weapon) - 1);
	
	if(g_Settings[RESPAWN_PLAYER])
	{
		if((killer == victim && (equal(weapon, "world", 5) || equal(weapon, "grenade"))) //suicide, self grenade kill
		|| (!killer && (equal(weapon, "world", 5) || equal(weapon, "door", 4) || equal(weapon, "trigger_hurt", 12)))) //fall, door, trigger
		{	
			set_dhudmessage(255, 255, 255, -1.0, 0.25, 0, 6.0, 12.0);
			show_dhudmessage(victim, "%L", LANG_PLAYER, "h_RESPAWN_PLAYER", floatround(Float:g_Settings[RESPAWN_TIME]));	
		}
	}
}


public client_death(killer, victim)
{	
	if((!killer || !victim) || (killer == victim))
		return PLUGIN_HANDLED;
	
	/*------------------SWAP WEAPONS------------------*/
	if(g_Settings[SWAP_WEAPONS])
	{
		swap_weapons(killer, victim);
		ColorChat(killer, "%L", LANG_PLAYER, "c_WEAPONS_SWAPPED", get_weapons_name(victim));
	}
	
	/*------------------SWAP TEAMS------------------*/			
	if(g_Settings[SWAP_TEAMS])
	{
		new CsTeams:team_message = cs_get_user_team(victim);
		swap_teams(killer, victim);
		switch(team_message)
		{
			case CS_TEAM_T : {	
				if(g_Settings[SWAP_TEAMS_MSG] == 1)
					ColorChat(killer, "%L", LANG_PLAYER, "c_SWAP_TEAMS_MSG_T");
				
				if(g_Settings[SWAP_TEAMS_MSG] == 2)
				{
					set_dhudmessage(255, 0, 0, -1.0, 0.70, 0, 6.0, 2.0);
					show_dhudmessage(killer, "%L", LANG_PLAYER, "h_SWAP_TEAMS_MSG_T");
				}
			}
			case CS_TEAM_CT : {
				if(g_Settings[SWAP_TEAMS_MSG] == 1)
					ColorChat(killer, "%L", LANG_PLAYER, "c_SWAP_TEAMS_MSG_CT");
				
				if(g_Settings[SWAP_TEAMS_MSG] == 2)
				{
					set_dhudmessage(0, 250, 250, -1.0, 0.70, 0, 6.0, 2.0);
					show_dhudmessage(killer, "%L", LANG_PLAYER, "h_SWAP_TEAMS_MSG_CT");
				}
			}
		}
		/*---------------CHECK TEAMS----------------*/
		check_teams(); //For GOD's sake, don't remove this!
	}
	
	/*------------------RESPAWN PLAYER------------------*/
	if(g_Settings[RESPAWN_PLAYER])
	{	
		set_task(Float:g_Settings[RESPAWN_TIME], "respawn_player", victim);
		
		set_dhudmessage(255, 255, 255, -1.0, 0.25, 0, 6.0, 12.0);
		show_dhudmessage(victim, "%L", LANG_PLAYER, "h_RESPAWN_PLAYER", floatround(Float:g_Settings[RESPAWN_TIME]));	
	}
	
	/*------------------KILL SOUND------------------*/
	if(g_Settings[KILL_SOUND])
		client_cmd(killer, "spk ^"%s^"", g_Settings[KILL_SOUND_PATH]);
	
	return PLUGIN_HANDLED;
}
	
public logevent_round_start()
{
	if((g_Settings[RESPAWN_PLAYER]) && (gBlockBuyZone == true))
	{
		ColorChat(0, "%L", LANG_PLAYER, "c_BUYZONE_UNLOCKED");
		UnblockBuyZones(); 
	}
	
	else if((!g_Settings[RESPAWN_PLAYER]) && (g_Settings[BLOCK_BUYZONE]))
	{
		if(g_Settings[BUYZONE_LOCKED_MSG])
		{
			ColorChat(0, "%L", LANG_PLAYER, "c_BUYZONE_LOCKED");
		}
		BlockBuyZones();
	}	
		
	new players[MAX_PLAYERS], iPlayers, i;
	get_players(players, iPlayers)
	if(g_Settings[SPAWN_MONEY] && !g_Settings[BLOCK_BUYZONE])
	{
		for(i=0; i<=iPlayers; i++)
		{	
			if(is_user_alive(players[i]))
			{
				if(g_Settings[SPAWN_MONEY_MSG])
					ColorChat(players[i], "%L", LANG_PLAYER, "c_SPAWN_MONEY", g_Settings[SPAWN_MONEY_AMOUNT]);
				cs_set_user_money(players[i], g_Settings[SPAWN_MONEY_AMOUNT]);
			}
		}
	}
}

//----------------------------------------------------------------//
/*------------------------WELCOME MSG-----------------------------*/
//----------------------------------------------------------------//

public welcome_menu(id)
{
	new menubody[512] = "\w[\rCFM\w] \yCONFUSING FUN MOD \rv2.0^n";
	new len = strlen(menubody);
	
	len += formatex(menubody[len], charsmax(menubody) - len, "%L", LANG_PLAYER, "m_EXTENDER");
	
	len += formatex(menubody[len], charsmax(menubody) - len, "%L", LANG_PLAYER, "m_SWAP_WEAPONS", LANG_PLAYER, g_Settings[SWAP_WEAPONS] ? "m_ENABLED" : "m_DISABLED");
	len += formatex(menubody[len], charsmax(menubody) - len, "%L", LANG_PLAYER, "m_SWAP_TEAMS", LANG_PLAYER, g_Settings[SWAP_TEAMS] ? "m_ENABLED" : "m_DISABLED");
	len += formatex(menubody[len], charsmax(menubody) - len, "%L", LANG_PLAYER, "m_RESPAWN", LANG_PLAYER, g_Settings[RESPAWN_PLAYER] ? "m_ENABLED" : "m_DISABLED");
	len += formatex(menubody[len], charsmax(menubody) - len, "%L", LANG_PLAYER, "m_REMEMBER_WEAPONS", LANG_PLAYER, g_Settings[REMEMBER_WEAPONS] ? "m_ENABLED" : "m_DISABLED");
	len += formatex(menubody[len], charsmax(menubody) - len, "%L", LANG_PLAYER, "m_BLOCK_BUYZONE", LANG_PLAYER, g_Settings[BLOCK_BUYZONE] ? "m_BLOCKED" : "m_UNBLOCKED");
	len += formatex(menubody[len], charsmax(menubody) - len, "%L", LANG_PLAYER, "m_BLOCK_WPN_PICKUP", LANG_PLAYER, g_Settings[BLOCK_WPN_PICKUP] ? "m_BLOCKED" : "m_UNBLOCKED");
	
	len += formatex(menubody[len], charsmax(menubody) - len, "%L", LANG_PLAYER, "m_EXTENDER");
	
	len += formatex(menubody[len], charsmax(menubody) - len, "%L", LANG_PLAYER, "m_CONTINUE");
	show_menu(id, keys, menubody, -1, "welcome_menu");
}

//----------------------------------------------------------------//
/*--------------------------SWAP WEAPONS--------------------------*/
//----------------------------------------------------------------//

stock swap_weapons(id1, id2)
{
	new weapons[32], weapon_name[32], iWeaponsCount;
	
	get_user_weapons(id2, weapons, iWeaponsCount);
	
	strip_user_weapons(id1);
	
	for (new i = 0; i < iWeaponsCount; i++)
	{
		get_weaponname(weapons[i], weapon_name, charsmax(weapon_name));
		give_item(id1, weapon_name);
		
		new weapon_id = get_weaponid(weapon_name);
		
		if((weapon_id != CSW_KNIFE) || ((1<<weapon_id) & GRENADES_WEAPONS_BIT_SUM))
			cs_set_user_bpammo(id1, weapon_id, MAXBPAMMO[weapon_id]);
		
	}
}

//----------------------------------------------------------------//
/*-------------------GET WEAPONS NAME(UPPERCASE)------------------*/
//----------------------------------------------------------------//

public get_weapons_name(id)
{
	new weapons[32], weapon_name[32], szBuffer[128], iLen, iWeaponsCount;
	
	get_user_weapons(id, weapons, iWeaponsCount);
	
	for (new i = 0; i < iWeaponsCount; i++)
	{
		get_weaponname(weapons[i], weapon_name, charsmax(weapon_name));
		new weapon_name_o[32];
		format(weapon_name_o, charsmax(weapon_name_o), "%s", weapon_name[7]);
		
		new weapon_name_o_uc = strtoupper(weapon_name_o);
		iLen += formatex(szBuffer[iLen], charsmax(szBuffer) - iLen, "%s, ", weapon_name_o_uc);
	}
	
	format(szBuffer[strlen(szBuffer) - 2], 2, "");
	
	return szBuffer;
}

//----------------------------------------------------------------//
/*---------------------------SWAP TEAMS---------------------------*/
//----------------------------------------------------------------//

stock swap_teams(id1, id2)
{
	new CsTeams:id1_team = cs_get_user_team(id1);
	new CsTeams:id2_team = cs_get_user_team(id2);
	
	if(id1_team != id2_team)
	{
		cs_set_user_team(id1, id2_team);
	}
}

//----------------------------------------------------------------//
/*-------------------------RESPAWN PLAYER-------------------------*/
//----------------------------------------------------------------//

public respawn_player(id)
{
	if (!is_user_connected(id) || is_user_alive(id) || cs_get_user_team(id) == CS_TEAM_SPECTATOR)
		return;
	
	set_pev(id, pev_deadflag, DEAD_RESPAWNABLE);
	dllfunc(DLLFunc_Think, id);
	
	if (is_user_bot(id) && pev(id, pev_deadflag) == DEAD_RESPAWNABLE)
	{
		dllfunc(DLLFunc_Spawn, id);
	}
	
	/*------------------BLOCK BUYZONE------------------*/
	if(g_Settings[BLOCK_BUYZONE])
	{
		if(g_Settings[BUYZONE_LOCKED_MSG])
			ColorChat(id, "%L", LANG_PLAYER, "c_BUYZONE_LOCKED");
		BlockBuyZones();
	}
	
	/*------------------SPAWN MONEY------------------*/
	if(g_Settings[SPAWN_MONEY] && !g_Settings[BLOCK_BUYZONE])
	{
		if(g_Settings[SPAWN_MONEY_MSG])
			ColorChat(id, "%L", LANG_PLAYER, "c_SPAWN_MONEY", g_Settings[SPAWN_MONEY_AMOUNT]);
				
		cs_set_user_money(id, g_Settings[SPAWN_MONEY_AMOUNT]);
	}
}

//----------------------------------------------------------------//
/*------------------------REMEMBER WEAPONS------------------------*/
//----------------------------------------------------------------//

public Ham_SpawnPost(id)
{
	if(!g_Settings[REMEMBER_WEAPONS])
		return HAM_IGNORED;
	
	new weapon_name[32]; 
	
	for( new i = 0; i < g_WeaponsData[id][W_NUM]; i++ )
	{
		get_weaponname(g_WeaponsData[id][WEAPONS][i], weapon_name, charsmax(weapon_name));
		give_item(id, weapon_name);
		
		new weapon_id = get_weaponid(weapon_name);
		
		if((weapon_id != CSW_KNIFE) || ((1<<weapon_id) & GRENADES_WEAPONS_BIT_SUM))
			cs_set_user_bpammo(id, weapon_id, MAXBPAMMO[weapon_id]);
	}
	
	g_WeaponsData[id][W_NUM] = 0;
	
	return HAM_IGNORED;
} 

//----------------------------------------------------------------//
/*------------------BLOCK WEAPONS DROP ON DEATH------------------*/
//----------------------------------------------------------------//

public forward_block_weapons_drop(entid, model[]) 
{
	if (!is_valid_ent(entid) || !equal(model, WBOX, 9) || !g_Settings[BLOCK_WPNS_DROP_DEATH])
		return FMRES_IGNORED;
	
	new id = entity_get_edict(entid, EV_ENT_owner);
	if (!id || !is_user_connected(id) || is_user_alive(id))
		return FMRES_IGNORED;
	
	if (equal(model, SHLD)) 
	{
		kill_entity(entid);
		return FMRES_IGNORED;
	}
	
	if (equal(model, WBOX)) 
	{
		g_entid[id] = entid;
		return FMRES_IGNORED;
	}
	
	if (entid != g_entid[id])
		return FMRES_IGNORED;
	
	g_entid[id] = 0;
	
	if (equal(model, BOMB))
		return FMRES_IGNORED;
	
	for (new i = 1; i <= g_maxents; ++i) 
	{
		if (is_valid_ent(i) && entid == entity_get_edict(i, EV_ENT_owner)) 
		{
			kill_entity(entid);
			kill_entity(i);
		}
	}
	
	return FMRES_IGNORED;
}

stock kill_entity(id) 
{
	entity_set_int(id, EV_INT_flags, entity_get_int(id, EV_INT_flags)|FL_KILLME);
}

//----------------------------------------------------------------//
/*--------------------BLOCK BUYZONE ON RESPAWN--------------------*/
//----------------------------------------------------------------//

public MessageStatusIcon(msgID, dest, receiver) 
{
	if(gBlockBuyZone && get_msg_arg_int(1)) 
	{
		
		new const buyzone[] = "buyzone";
		new icon[sizeof(buyzone) + 1];
		get_msg_arg_string(2, icon, charsmax(icon));
		
		if(equal(icon, buyzone)) 
		{
			RemoveFromBuyzone(receiver);
			set_msg_arg_int(1, ARG_BYTE, 0);
		}
	}
	return PLUGIN_CONTINUE;
}

BlockBuyZones() 
{
	message_begin(MSG_BROADCAST, gMsgStatusIcon);
	write_byte(0);
	write_string("buyzone");
	message_end();
	
	new players[32], pnum;
	get_players(players, pnum, "a");
	
	while(pnum-- > 0)
	{
		RemoveFromBuyzone(players[pnum]);
	}
	
	gBlockBuyZone = true;
}
	
RemoveFromBuyzone(id) 
{
	const m_fClientMapZone = 235;
	const MAPZONE_BUYZONE = (1 << 0);
	const XO_PLAYERS = 5;
	
	set_pdata_int(id, m_fClientMapZone, get_pdata_int(id, m_fClientMapZone, XO_PLAYERS) & ~MAPZONE_BUYZONE, XO_PLAYERS);
}

UnblockBuyZones() 
{
	gBlockBuyZone = false;
}

//----------------------------------------------------------------//
/*-----------------------BLOCK WEAPON PICKUP----------------------*/
//----------------------------------------------------------------//

public OnPlayerTouchArmoury(ent, id) 
{ 
	if(!g_Settings[BLOCK_WPN_PICKUP])
		return PLUGIN_CONTINUE;
	
	return PLUGIN_HANDLED;
} 	

public OnPlayerTouchWeaponBox(ent, id) 
{ 
	if(!g_Settings[BLOCK_WPN_PICKUP])
	return PLUGIN_CONTINUE;
	
	new weapon_id = GetWeaponBoxWeaponType(ent); 
	
	if(weapon_id != CSW_C4) 
	{ 
		return PLUGIN_HANDLED; 
	} 
	
	return PLUGIN_CONTINUE; 
} 

public OnPlayerTouchShield(ent, id) 
{ 
	if(!g_Settings[BLOCK_WPN_PICKUP])
		return PLUGIN_CONTINUE;
	
	return PLUGIN_HANDLED;
} 

GetWeaponBoxWeaponType(ent) 
{ 
	new weapon; 
	
	for(new i = 1; i<= 5; i++) 
	{ 
		weapon = get_pdata_cbase(ent, m_rgpPlayerItems_CWeaponBox[i], XO_CWEAPONBOX); 
		if(weapon > 0) 
		{ 
			return cs_get_weapon_id(weapon); 
		}	 
	} 
	
	return 0; 
}  

//----------------------------------------------------------------//
/*----------------IF ALL PLAYERS ARE IN ONE TEAM------------------*/
//----------------------------------------------------------------//

public check_teams()
{
	new players_t[32], players_ct[32], iCT, iT;
	get_players(players_ct, iCT, "e", "CT");
	get_players(players_t, iT, "e", "TERRORIST");
	
	if(iCT == 0)
	{
		set_task(3.0, "randomize_teams");
		
		set_dhudmessage(255, 255, 255, -1.0, 0.50, 1, 1.0, 1.0, 1.0, 1.0);
		show_dhudmessage(0, "%L", LANG_PLAYER, "h_T_SURVIVED");
		
		
	}
	
	else if(iT == 0)
	{
		set_task(3.0, "randomize_teams");
		
		set_dhudmessage(255, 255, 255, -1.0, 0.50, 1, 1.0, 1.0, 1.0, 1.0);
		show_dhudmessage(0, "%L", LANG_PLAYER, "h_CT_SURVIVED");
	}
}

public randomize_teams()
{
	new iPlayers[32], iCT, iT, CsTeams:iLess = CS_TEAM_UNASSIGNED;
	get_players(iPlayers, iCT, "e", "CT");
	get_players(iPlayers, iT, "e", "TERRORIST");
	
	if(iCT == iT)
		return;
	else if(iCT - iT >= 2)
		iLess = CS_TEAM_T;
	else if(iT - iCT >= 2)
		iLess = CS_TEAM_CT;
		
	if(iLess != CS_TEAM_UNASSIGNED)
	{
		new diff = abs(iCT-iT);
	
		while(diff > 1)
		{
			new iPlayer = iPlayers[random(iLess == CS_TEAM_CT ? iT : iCT)];
			cs_set_user_team(iPlayer, iLess);
			cs_reset_user_model(iPlayer);
			
			new CsTeams:new_team = cs_get_user_team(iPlayer);
			switch(new_team)
			{
				case CS_TEAM_T : hud_transferred_to_t(iPlayer);
				case CS_TEAM_CT : hud_transferred_to_ct(iPlayer);
			}
			respawn_player(iPlayer);
				
			diff--;
		}
	}
}

public hud_transferred_to_ct(id)
{
	set_dhudmessage(50, 50, 255, -1.0, -1.0, 0, 0.1, 2.0, 0.1, 0.1);
	show_dhudmessage(id, "%L", LANG_PLAYER, "h_TRANSFERED_TO_CT");
}

public hud_transferred_to_t(id)
{
	set_dhudmessage(255, 0, 0, -1.0, -1.0, 0, 0.1, 2.0, 0.1, 0.1);
	show_dhudmessage(id, "%L", LANG_PLAYER, "h_TRANSFERED_TO_T");
}

//----------------------------------------------------------------//
/*---------------------READING .CFG FILE--------------------------*/
//----------------------------------------------------------------//

public ReadFile()
{
	new szConfigsName[256], szFilename[256];
	get_configsdir(szConfigsName, charsmax(szConfigsName));
	formatex(szFilename, charsmax(szFilename), "%s/confusing_fun_mod.cfg", szConfigsName);
	
	if(!file_size(szFilename))
	{
		pause("ad");
		console_print(0, "Configuration file (%s) is empty. The plugin is paused.", szFilename);
		return;
	}
	
	new iFilePointer = fopen(szFilename, "rt")
	
	if(iFilePointer)
	{
		new szData[128], szKey[32], szValue[96];
		
		while(!feof(iFilePointer))
		{
			fgets(iFilePointer, szData, charsmax(szData));
			trim(szData);
			
			switch(szData[0])
			{
				case EOS, '#', ';': continue;
					
				default:
				{
					strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=');
					trim(szKey);
					trim(szValue);
					
					if(is_blank(szValue))
						continue;
						
					if(equal(szKey, "WELCOME_MSG"))
						g_Settings[WELCOME_MSG] = bool:(clamp(str_to_num(szValue), 0, 1));
						
					if(equal(szKey, "WELCOME_SOUND"))
						g_Settings[WELCOME_SOUND] = bool:(clamp(str_to_num(szValue), 0, 1));
					
					if(g_Settings[WELCOME_SOUND])
					{
						if(equal(szKey, "WELCOME_SOUND_PATH"))
							copy(g_Settings[WELCOME_SOUND_PATH], charsmax(g_Settings[WELCOME_SOUND_PATH]), szValue);
					}
						
					if(equal(szKey, "SWAP_WEAPONS"))
						g_Settings[SWAP_WEAPONS] = bool:(clamp(str_to_num(szValue), 0, 1));
						
					if(equal(szKey, "SWAP_TEAMS"))
						g_Settings[SWAP_TEAMS] = bool:(clamp(str_to_num(szValue), 0, 1));
						
					if(equal(szKey, "SWAP_TEAMS_MSG"))
						g_Settings[SWAP_TEAMS_MSG] = clamp(str_to_num(szValue), 1, 2);
						
					if(equal(szKey, "RESPAWN_PLAYER"))
						g_Settings[RESPAWN_PLAYER] = bool:(clamp(str_to_num(szValue), 0, 1));
						
					if(g_Settings[RESPAWN_PLAYER])
					{
						if(equal(szKey, "RESPAWN_TIME"))
						g_Settings[RESPAWN_TIME] = _:floatclamp(str_to_float(szValue), 0.0, 30.0);
					}
						
					if(equal(szKey, "REMEMBER_WEAPONS"))
						g_Settings[REMEMBER_WEAPONS] = bool:(clamp(str_to_num(szValue), 0, 1));
						
					if(equal(szKey, "SPAWN_MONEY"))
						g_Settings[SPAWN_MONEY] = bool:(clamp(str_to_num(szValue), 0, 1));
					
					if(g_Settings[SPAWN_MONEY])
					{
						if(equal(szKey, "SPAWN_MONEY_MSG"))
							g_Settings[SPAWN_MONEY_MSG] = bool:(clamp(str_to_num(szValue), 0, 1));
							
						if(equal(szKey, "SPAWN_MONEY_AMOUNT"))
							g_Settings[SPAWN_MONEY_AMOUNT] = bool:(clamp(str_to_num(szValue), 0, 16000));
					}
					
					if(equal(szKey, "BLOCK_WPNS_DROP_DEATH"))
						g_Settings[BLOCK_WPNS_DROP_DEATH] = bool:(clamp(str_to_num(szValue), 0, 1));
					
					if(equal(szKey, "BLOCK_BUYZONE"))
						g_Settings[BLOCK_BUYZONE] = bool:(clamp(str_to_num(szValue), 0, 1));
					
					if(g_Settings[BLOCK_BUYZONE])
					{
						if(equal(szKey, "BUYZONE_LOCKED_MSG"))
							g_Settings[BUYZONE_LOCKED_MSG] = bool:(clamp(str_to_num(szValue), 0, 1));
					}
						
					if(equal(szKey, "BLOCK_WPN_PICKUP"))
						g_Settings[BLOCK_WPN_PICKUP] = bool:(clamp(str_to_num(szValue), 0, 1));
						
					if(equal(szKey, "KILL_SOUND"))
						g_Settings[KILL_SOUND] = bool:(clamp(str_to_num(szValue), 0, 1));
						
					if(g_Settings[KILL_SOUND])
					{
						if(equal(szKey, "KILL_SOUND_PATH"))
							copy(g_Settings[KILL_SOUND_PATH], charsmax(g_Settings[KILL_SOUND_PATH]), szValue);
					}
				}
			}	
		}
		fclose(iFilePointer)
	}
}

bool:is_blank(szString[])
	return szString[0] == EOS;

//----------------------------------------------------------------//
/*-----------------------------EXTRAS-----------------------------*/
//----------------------------------------------------------------//

stock ColorChat(const id, const szInput[], any:...)
{
	new iPlayers[32], iCount = 1;
	static szMessage[191];
	vformat(szMessage, charsmax(szMessage), szInput, 3);
	format(szMessage[0], charsmax(szMessage), "%s", szMessage);
	
	replace_all(szMessage, charsmax(szMessage), "!g", "^4");
	replace_all(szMessage, charsmax(szMessage), "!n", "^1");
	replace_all(szMessage, charsmax(szMessage), "!t", "^3");
	
	if(id)
		iPlayers[0] = id;
	else
		get_players(iPlayers, iCount, "ch");
	
	for(new i, iPlayer; i < iCount; i++)
	{
		iPlayer = iPlayers[i];
		
		if(is_user_connected(iPlayer))
		{
			message_begin(MSG_ONE_UNRELIABLE, g_iSayText, _, iPlayer);
			write_byte(iPlayer);
			write_string(szMessage);
			message_end();
		}
	}
}

//----------------------------------------------------------------//
/*----------------------------------------------------------------*/
//----------------------------------------------------------------//
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang16393\\ f0\\ fs16 \n\\ par }
*/
