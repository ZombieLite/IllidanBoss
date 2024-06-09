#include < zl_illidan >

#define PLAYER_HP

static g_Resource[][] = {
	"models/zl/npc/illidan/zl_illidan_alpha3.mdl",		// 0
	"models/zl/npc/illidan/zl_blade.mdl",
	"sprites/zl/npc/illidan/zl_hpbar.spr",
	"models/zl/npc/illidan/zl_attack.mdl",
	"sprites/zl/npc/illidan/zl_focus_start.spr",		// 4
	"sprites/zl/npc/illidan/zl_focus_end.spr",
	"models/zl/npc/illidan/zl_attack2.mdl",
	"models/zl/npc/illidan/zl_elem.mdl",			// 7
	"sprites/laserbeam.spr",
	"sprites/shockwave.spr",
	"models/zl/npc/illidan/zl_ball_alpha.mdl",			// 10
	"models/zl/npc/illidan/zl_splash.mdl",
	"sprites/zl/npc/illidan/zl_elem_hpbar_alpha.spr",
	"sprites/zl/npc/illidan/zl_zoom_alpha.spr"			// 13
}

new const g_SoundList[][] = {
	"zl/npc/illidan/Illidan_attack.wav",
	"zl/npc/illidan/Illidan_attack_blitz.wav",
	"zl/npc/illidan/Illidan_attack_roar.wav",
	"zl/npc/illidan/attack_killed.wav",		// 3
	"zl/npc/illidan/event_sp_prepare.wav",		// 4
	"zl/npc/illidan/event_start.wav",		// 5
	"zl/npc/illidan/elem_fly_start.wav",
	"zl/npc/illidan/event_demon.wav",		// 7
	"zl/npc/illidan/sp_scroll.wav",
	"zl/npc/illidan/event_phase2.wav",
	"zl/npc/illidan/event_phase_magma.wav",		// 10
	"zl/npc/illidan/event_ghost.wav"
}

// Other
static g_Illidan, g_Ability, g_HealthBar, g_MaxPlayers, g_Tank
static g_Blade[2], g_Elem[2], g_ElemFirstVictim[2], g_Hp[2]
static i_Resource[sizeof g_Resource]
static Float:o_start[3]
static g_Phase
static Float:g_LiderDamage[33], g_Player_Controll, g_Test, g_Focus_Entity
static Float: g_kill_time

// Cvars
static zl_cvar[11], Float:zl_fcvar[1]

// Msg
static g_msgBarTime

#define BOSS_Z		42.0
#define BOSS_B		7
native strip_user_weapons(index)
native give_item(index,const name[])

public plugin_init() {
	register_plugin("IllidanBoss", VERSION, "Alexander.3")
	
	if (zl_boss_map() != 6) {
		pause("ad")
		return
	}
	
	RegisterHam(Ham_Player_PreThink, "player", "Player_Think", 0)
	RegisterHam(Ham_TraceAttack, "info_target", "blade_trace")
	RegisterHam(Ham_Killed, "info_target", "blade_killed")
	
	register_think("boss_illidan", "think_boss")
	register_think("boss_illidan_hpbar", "think_hpbar")
	register_think("boss_illidan_attack", "think_attack")
	register_think("boss_illidan_elem", "think_elem")
	register_think("boss_illidan_elem_ball", "think_elem_ball")
	register_think("boss_illidan_splash","think_splash")
	register_think("boss_blade_hpbar", "think_blade_hpbar")
	
	register_touch("boss_illidan", "player", "touch_boss")
	register_touch("boss_illidan_ball", "*", "touch_ball")
	
	load_map_event()
	
	g_MaxPlayers = get_maxplayers()
	g_msgBarTime = get_user_msgid("BarTime")
}

public think_boss(boss) {
	if (pev(boss, pev_deadflag) == DEAD_DYING) {
		return
	}
	
	//if (zl_player_alive() < 1) {
	//	zl_anim(boss, 1, 1.0)
	//	set_pev(boss, pev_movetype, MOVETYPE_NONE)
	//	return
	//}
	
		
	switch(g_Ability) {
		case 0: {	// RUN
			static victim, anim
			victim = pev(boss, pev_victim)
			anim = pev(boss, pev_sequence)
			
			if (pev(boss, pev_takedamage) != DAMAGE_YES) {
				set_pev(boss, pev_takedamage, DAMAGE_YES)
				set_pev(boss, pev_deadflag, DEAD_NO)
			}
						
			if(!is_user_alive(victim) && !is_user_alive(g_Player_Controll)) {
				victim = zl_player_choose(boss, 0)
				set_pev(boss, pev_victim, victim)
				set_pev(boss, pev_nextthink, get_gametime() + 0.1)
				return
			}
			
			if(anim != 2 && victim > 0) {
				set_pev(boss, pev_movetype, MOVETYPE_PUSHSTEP)
				zl_anim(boss, 2, 1.0)
			}
			
			static Float:velocity[3], Float:angle[3], len
			
			if(anim != 1 && victim == 0 || victim == g_Player_Controll) {
				set_pev(boss, pev_nextthink, get_gametime() + 0.2)
				set_pev(boss, pev_movetype, MOVETYPE_NONE)
				zl_anim(boss, 1, 1.0)
				return
			}
			
			len = zl_move(boss, victim, (g_Phase == 2) ? float(zl_cvar[4]) : float(zl_cvar[1]), velocity, angle)
			
			if (len < 40 && g_Player_Controll && !is_user_alive(victim)) {
				set_pev(boss, pev_victim, 0)
				set_pev(boss, pev_nextthink, get_gametime() + 0.2)
				return
			}
						
			set_pev(boss, pev_velocity, velocity)
			set_pev(boss, pev_angles, angle)
			set_pev(boss, pev_nextthink, get_gametime() + 0.1)
			return
		}
		case 1: { 	// Attack
			static numeration
			switch(numeration) {
				case 0: { // prepare
					zl_anim(boss, 8, 1.0)
					set_pev(boss, pev_nextthink, get_gametime() + 0.5)
					++numeration
				}
				case 1: { // damage and end
					static victim; victim = pev(boss, pev_victim)
					set_pev(boss, pev_victim, 0)
					numeration = 0
					
					if (!is_user_alive(victim)) {
						set_pev(boss, pev_nextthink, get_gametime() + 0.1)
						g_Ability = 0
						return
					}
										
					if (entity_range(victim, boss) < 180) {
						if (zl_player_alive() <= 1) {
							ExecuteHamB(Ham_Killed, victim, victim, 2)
							return
						}
						
						if (victim == g_Tank) {
							zl_slap(victim, 200, 0, 1)
						} else {
							if (g_Phase < 2) {
								zl_slap(victim, 1000, zl_cvar[2], 1)
								zl_screenfade(victim, 1, 1, {0, 50, 0}, 50, 1)
								zl_screenshake(victim, 15, 3)
							} else {
								if (0 < victim <= 32) {
									if (is_user_alive(victim)) {
										set_rendering(victim)
										ExecuteHamB(Ham_Killed, victim, victim, 2)
										g_kill_time = 0.0
									}
								}
							}
						}
					}
					set_pev(boss, pev_nextthink, get_gametime() + 1.6)
					
					
					
					if (g_Phase < 3) {
						g_Ability = 0
						zl_attack(3)
					} else {
						g_Ability = 5
					}
				}
			}
		}
		case 2: { // SpecialAttack
			static num, ent
			
			new Float:origin[3], Float:EndOrigin[3]
			static Float: start_origin[3], Float:end_origin[3], Float:angle[3]
			
			switch(num) {
				case 0: { // prepare
					#define OFFSET_SPAWN	1.0
	
					/*
						CREATE ARROW
					*/
					
					new id = zl_player_choose(boss, 2)
					if(!is_user_alive(id)) return					
					
					pev(id, pev_origin, origin)
					
					new Float:origin_slap[3]
					origin_slap[0] = origin[0]
					origin_slap[1] = origin[1]
					origin_slap[2] = origin[2]
					
					ent = create_entity("info_target")
					engfunc(EngFunc_SetModel, ent, g_Resource[4])
					
					/* vector create */
					origin[2] = origin[2] + 300.0
					EndOrigin[0] = origin[0]
					EndOrigin[1] = origin[1]
					EndOrigin[2] = origin[2] - 600.0
					
					new tr_arrow
					engfunc(EngFunc_TraceLine, origin, EndOrigin, IGNORE_MONSTERS, ent, tr_arrow)
					get_tr2(tr_arrow, TR_vecEndPos, EndOrigin)
					EndOrigin[2] += OFFSET_SPAWN
					engfunc(EngFunc_SetOrigin, ent, EndOrigin)
					
					/* angle */
					new Float:yaw = random_float(-180.0, 180.0)
					origin[0] = 0.0
					origin[1] = yaw
					origin[2] = 0.0
					set_pev(g_Illidan, pev_angles, origin)
					origin[0] = 90.0
					origin[1] += 90.0
					set_pev(ent, pev_angles, origin)
					
					/*
						BOSS VECTOR
					*/
					pev(boss, pev_angles, angle)
					angle_vector(angle, ANGLEVECTOR_FORWARD, angle)
					start_origin[0] = EndOrigin[0] - angle[0] * 285.0
					start_origin[1] = EndOrigin[1] - angle[1] * 285.0
					start_origin[2] = EndOrigin[2] + BOSS_Z - OFFSET_SPAWN
					end_origin[0] = EndOrigin[0] + angle[0] * 285.0
					end_origin[1] = EndOrigin[1] + angle[1] * 285.0
					end_origin[2] = EndOrigin[2] + BOSS_Z - OFFSET_SPAWN
					
					set_pev(boss, pev_effects, EF_NODRAW)
					set_pev(g_HealthBar, pev_effects, EF_NODRAW)
					
					set_pev(boss, pev_movetype, MOVETYPE_NOCLIP)
					set_pev(boss, pev_solid, SOLID_NOT)
					set_pev(boss, pev_nextthink, get_gametime() + 3.0)
					zl_sound(0, g_SoundList[4], 0)
					num++
					
					new Float:origin_p[3], Float:vector[3]
					
					new i = 1
					for(i=1; i<=g_MaxPlayers; ++i) {
						if (!is_user_alive(i))
							continue
						
						pev(i, pev_origin, origin_p)
						xs_vec_sub(start_origin, origin_p, vector)
						xs_vec_normalize(vector, vector)
						xs_vec_mul_scalar(vector, 1000.0, vector)
						vector[2] = 250.0
						set_pev(i, pev_velocity, vector)
						zl_screenfade(i, 2, 1, {0, 0, 0}, 255, 1)
					}
				}
				case 1: {
					engfunc(EngFunc_SetOrigin, boss, start_origin)
					set_pev(g_HealthBar, pev_effects, pev(g_HealthBar, pev_effects) & ~EF_NODRAW)
					set_pev(boss, pev_effects, pev(boss, pev_effects) & ~EF_NODRAW)
					engfunc(EngFunc_SetModel, ent, g_Resource[5])
					set_pev(boss, pev_nextthink, get_gametime() + 0.5)
					zl_anim(boss, 10, 1.2)
					num++
				}
				case 2: {
					new Float:vector_attack[3]
					xs_vec_sub(end_origin, start_origin, vector_attack)
					xs_vec_normalize(vector_attack, vector_attack)
					xs_vec_mul_scalar(vector_attack, 1000.0, vector_attack)
					set_pev(boss, pev_velocity, vector_attack)
					set_pev(boss, pev_nextthink, get_gametime() + 0.3)
					num++
				}
				case 3: {					
					function_victim(start_origin, end_origin)
					
					set_pev(boss, pev_nextthink, get_gametime() + 0.2)
					num++
				}
				case 4: {
					set_pev(boss, pev_velocity, {0.0, 0.0, 0.0})
					set_pev(boss, pev_nextthink, get_gametime() + 1.0)
					num++
				}
				case 5: {
					set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME)
					set_pev(boss, pev_solid, SOLID_BBOX)
					set_pev(boss, pev_nextthink, get_gametime() + 1.0)
					for(new i = 0; i<3; ++i) {
						angle[i] = 0.0; EndOrigin[i] = 0.0; origin[i] = 0.0; end_origin[i] = 0.0; start_origin[i] = 0.0
					}
					num = 0; g_Ability = 3						
				}
			}
		}
		case 3: { // SCROLL DASH
			static num
			switch (num) {
				case 0: {
					if(pev(boss, pev_movetype) != MOVETYPE_NOCLIP)
						set_pev(boss, pev_movetype, MOVETYPE_NOCLIP)
					
					
					new victim = zl_player_choose(boss, 2)
					
					set_pev(boss, pev_movetype, MOVETYPE_FLY)
					set_pev(boss, pev_solid, SOLID_NOT)
					
					if (is_block_ent(victim) || !is_user_alive(victim)) {
						set_pev(boss, pev_nextthink, get_gametime() + 0.1)
						return
					}
										
					new Float:origin_victim[3], Float:EndOrigin[3]
					pev(victim, pev_origin, origin_victim)
					
					/* vector create */
					origin_victim[2] = origin_victim[2] + 300.0
					EndOrigin[0] = origin_victim[0]
					EndOrigin[1] = origin_victim[1]
					EndOrigin[2] = origin_victim[2] - 600.0
								
					new tr
					engfunc(EngFunc_TraceLine, origin_victim, EndOrigin, IGNORE_MONSTERS, -1, tr)
					get_tr2(tr, TR_vecEndPos, EndOrigin)
					EndOrigin[2] += BOSS_Z + 1.0
					engfunc(EngFunc_SetOrigin, boss, EndOrigin)
					
					zl_anim(boss, 11, 1.0)
					zl_sound(0, g_SoundList[8], 0)
					set_pev(boss, pev_nextthink, get_gametime() + 0.8)
					num++
				}
				case 1: {
					
					for(new i = 1; i <= g_MaxPlayers; ++i) {
						if (!is_user_alive(i))
							continue 
							
						if (entity_range(i, boss) < 180) {
							zl_slap(i, 1000, zl_cvar[3], 0)
							zl_screenfade(i, 1, 1, {0, 50, 0}, 50, 1)
							zl_screenshake(i, 15, 3)
						}
					}
					
					set_pev(boss, pev_nextthink, get_gametime() + 1.0)
					zl_attack(6)
					num++
				}
				case 2: {
					set_pev(boss, pev_solid, SOLID_BBOX)
					set_pev(boss, pev_nextthink, get_gametime() + 1.0)
					g_Ability = 0; num = 0
				}
			}
		}
		case 4: { // Phase elemental
			static num
			switch (num) {
				case 0: { // Pre push
					set_pev(boss, pev_movetype, MOVETYPE_PUSHSTEP)
					set_pev(boss, pev_solid, SOLID_BBOX)
					set_pev(boss, pev_nextthink, get_gametime() + 0.1)
					zl_anim(boss, 1, 1.0)
					num++
				}
				case 1: { // step
					static Float:o_boss[3], Float:len, Float:Angles[3], Float:vector[3]
					pev(boss, pev_origin, o_boss)
					xs_vec_sub(o_start, o_boss, vector)
					vector_to_angle(vector, Angles)
					len = xs_vec_len(vector)
					xs_vec_normalize(vector, vector)
					xs_vec_mul_scalar(vector, float(zl_cvar[1]), vector)
					set_pev(boss, pev_velocity, vector)
					set_pev(boss, pev_nextthink, get_gametime() + 0.1)
	
					Angles[0] = 0.0
					Angles[2] = 0.0
					
					set_pev(boss, pev_angles, Angles)
					
					if (pev(boss, pev_sequence) != 2) zl_anim(boss, 2, 1.0)
										
					if (len < 100) {
						set_pev(boss, pev_velocity, {0.0, 0.0, 0.0})
						set_pev(boss, pev_movetype, MOVETYPE_FLY)
						zl_anim(boss, 1, 1.0)
						num++
					}

				}
				case 2: {
					set_pev(boss, pev_nextthink, get_gametime() + 0.3)
					zl_anim(boss, 4, 1.0)
					num++
				}
				case 3: {
					zl_sound(0, g_SoundList[6], 0)
					set_pev(boss, pev_takedamage, DAMAGE_NO)
					set_pev(boss, pev_nextthink, get_gametime() + 0.4)
					set_pev(boss, pev_velocity, {0.0, 0.0, 850.0})
					num++
				}
				case 4: {
					zl_anim(boss, 5, 1.0)
					set_pev(boss, pev_body, 0)
					set_pev(boss, pev_velocity, {0.0, 0.0, 0.0})
					set_pev(boss, pev_nextthink, get_gametime() + 1.0)
					num++
					return
				}
				case 5: { // Blade and elem spawn
					
					//#define DEBUG_ELEM
					
					// HP generate
					static hp_set
					hp_set = PlayerHp(zl_cvar[0])
					hp_set = hp_set / zl_cvar[6]
					
					for (new i = 0; i < 2; ++i) {
						/*
							BLADE
						*/
						new ent = create_entity("info_target")
						g_Blade[i] = ent
						engfunc(EngFunc_SetModel, ent, g_Resource[1])
						engfunc(EngFunc_SetSize, ent, {-32.0, -5.0, -42.0}, {5.0, 5.0, 42.0})
						set_pev(ent, pev_classname, "illidan_blade")
						set_pev(ent, pev_health, float(hp_set))
						set_pev(ent, pev_max_health, float(hp_set))
						set_pev(ent, pev_takedamage, DAMAGE_YES)
						set_pev(ent, pev_movetype, MOVETYPE_FLY)
						set_pev(ent, pev_solid, SOLID_BBOX)
						set_pev(ent, pev_angles, {90.0, 0.0, 0.0})
						
						/*
							ELEM
						*/
						
						new ent2 = create_entity("info_target")
						g_Elem[i] = ent2
						engfunc(EngFunc_SetSize, ent2, {-32.0, -32.0, -42.0}, {32.0, 32.0, 62.0})
						set_pev(ent2, pev_movetype, MOVETYPE_PUSHSTEP)
						set_pev(ent2, pev_solid, SOLID_NOT)
						set_pev(ent2, pev_takedamage, DAMAGE_NO)
						set_pev(ent2, pev_classname, "boss_illidan_elem")
						set_pev(ent2, pev_nextthink, get_gametime() + 1.0)
						
						/*
							HPBAR
						*/
						// HpBar
						new hp = create_entity("info_target")
						g_Hp[i] = hp
						set_pev(hp, pev_nextthink, get_gametime() + 0.2)
						engfunc(EngFunc_SetModel, hp, g_Resource[12])
						set_pev(hp, pev_movetype, MOVETYPE_FOLLOW)
						set_pev(hp, pev_classname, "boss_blade_hpbar")
						set_pev(hp, pev_scale, 0.5)
						
						#if !defined DEBUG_ELEM
						// Player < 2
						if (zl_player_alive() < 2 && g_ElemFirstVictim[0])
							continue
						
						// Victim create
						while(g_ElemFirstVictim[i] == 0) {
							static v 
							v = zl_player_choose(ent2, 2)
							if (v != g_ElemFirstVictim[0]) {
								g_ElemFirstVictim[i] = v
							}
						}
						#else
						while(g_ElemFirstVictim[i] == 0) {
							static v 
							v = zl_player_choose(ent2, 2)
							g_ElemFirstVictim[i] = v
						}
						#endif
					}
					
					engfunc(EngFunc_SetOrigin, g_Hp[0], {-204.755142, 284.222656, 126.031250})
					engfunc(EngFunc_SetOrigin, g_Hp[1], {172.372299, 268.844909, 126.031250})
					engfunc(EngFunc_SetOrigin, g_Blade[0], {-204.755142, 284.222656, 36.031250})
					engfunc(EngFunc_SetOrigin, g_Blade[1], {172.372299, 268.844909, 36.031250})
					
					#if !defined DEBUG_ELEM
					if (zl_player_alive() < 2) {
						set_pev(boss, pev_nextthink, get_gametime() + 0.1)
						num = 101
						return
					}
					#endif
					num++
				}
				case 6: { // end phase
					set_pev(boss, pev_solid, SOLID_BBOX)
					set_pev(boss, pev_movetype, MOVETYPE_TOSS)
					zl_anim(boss, 6, 0.8)
					set_pev(boss, pev_nextthink, get_gametime() + 2.0)
					num++
				}
				case 7: {
					// skin
					set_pev(boss, pev_takedamage, DAMAGE_YES)
					set_pev(boss, pev_body, 7)
					set_pev(boss, pev_nextthink, get_gametime() + 1.0)
					static Float:max_hp
					pev(boss, pev_max_health, max_hp)
					set_pev(boss, pev_health, max_hp / 2)
					g_Ability = 5
					g_Phase = 3
					zl_sound(0, g_SoundList[7], 0)
				}
				case 101: { // Killed one player
					static num 
					switch(num) {
						case 0: {
							for(new i = 0; i < 2; ++i) {
								zl_laser(g_Blade[i], g_ElemFirstVictim[0], {0, 255, 0})
								
								set_pev(boss, pev_nextthink, get_gametime() + 0.1)
							}
							num++
						}
						case 1: {
							static Float:hp
							pev(g_ElemFirstVictim[0], pev_health, hp)
							if (hp - 10 <= 0) {
								ExecuteHamB(Ham_Killed, g_ElemFirstVictim[0], g_ElemFirstVictim[0], 2)
								return
							}
							zl_damage(g_ElemFirstVictim[0], 10, 0)
							set_pev(boss, pev_nextthink, get_gametime() + 0.3)
						}
					}
				}
			}
		}
		case 5: { // target tank
			if (pev(boss, pev_sequence) != 2) {
				set_pev(boss, pev_solid, SOLID_BBOX)
				set_pev(boss, pev_movetype, MOVETYPE_PUSHSTEP)
				zl_anim(boss, 2, 1.3)
			}
			
			static victim
			if (!is_user_alive(g_Tank)) {
				g_Tank = zl_player_choose(boss, 2)
				
				new szName[32]
				get_user_name(g_Tank, szName, charsmax(szName))
				
				new i
				for(i = 1; i<g_MaxPlayers; ++i) {
					if (zl_player_alive() <= 1) {
						zl_colorchat(i, "!g[BOSS] !t%s !nLast tank, !gDIE", szName)
					}
					
					if (g_Tank == i) {
						zl_colorchat(i, "!g[BOSS] !nYou !ttank!n, please tanking boss", szName)
						continue
					}
					zl_colorchat(i, "!g[BOSS] !t%s !nnew tank", szName)
				}
				set_rendering(g_Tank, kRenderFxGlowShell, 255, 255, 0, kRenderNormal, 80)
			}
			victim = zl_player_choose(boss, 0)
			set_pev(boss, pev_victim, victim)
			
			static Float:velocity[3], Float:angle[3]
			zl_move(boss, victim, float(zl_cvar[5]), velocity, angle)
			
			set_pev(boss, pev_angles, angle)
			set_pev(boss, pev_velocity, velocity)
			set_pev(boss, pev_nextthink, get_gametime() + 0.2)
		}
		case 6: { // ChangeTank
			static num, Float:velocity[3]
			switch (num) {
				case 0..10: {
					if (pev(boss, pev_sequence) != 1) zl_anim(boss, 1, 1.0)
					new i
					for(i = 1; i <= g_MaxPlayers; ++i) {
						if(!is_user_alive(i))
							continue
							
						zl_move(i, boss, 1000.0, velocity)
						set_pev(i, pev_velocity, velocity)
					}
					set_pev(boss, pev_nextthink, get_gametime() + 0.1)
					num++
				}
				case 11: {
					num++
					new i
					for(i = 1; i <= g_MaxPlayers; ++i) {
						if(!is_user_alive(i))
							continue
							
						zl_slap(i, 2000, 0, 0)
					}
					zl_anim(boss, 11, 1.0)
					num = 0
					g_Ability = 5
					set_pev(boss, pev_nextthink, get_gametime() + 2.7)
					set_rendering(g_Tank)
					g_Tank = 0
				}
			}
		}
		case 7: { // Phase controll
			static num, player
			switch(num) {
				case 0: {
					player = function_set_player_controll()
					
					if (!is_user_alive(player)) return
				
					set_pev(boss, pev_solid, SOLID_NOT)
					set_pev(boss, pev_movetype, MOVETYPE_NONE)
					set_pev(boss, pev_nextthink, get_gametime() + 0.1)
					zl_anim(boss, 0, 1.0)
					zl_laser(boss, player, {255, 255, 255})
					set_rendering(player, kRenderFxGlowShell, 255, 255, 255, kRenderNormal, 50)
					
					new name[32]
					get_user_name(player, name, charsmax(name))
					zl_colorchat(0, "!g[BOSS] !nBoss controlled by !g%s", name)
					g_kill_time = 0.0
					num++
				}
				case 1: {
					static Float:origin1[3], Float:origin2[3], Float:vector[3], Float:len
					pev(boss, pev_origin, origin1)
					pev(player, pev_origin, origin2)
					xs_vec_sub(origin1, origin2, vector)
					len = xs_vec_len(vector)
					xs_vec_normalize(vector, vector)
					xs_vec_mul_scalar(vector, 300.0, vector)
					set_pev(player, pev_velocity, vector)
					if (len <= 10) {
						g_Player_Controll = player
						strip_user_weapons(g_Player_Controll)
						set_pev(g_Player_Controll, pev_angles, {45.516357, -0.692138, 0.000000})
						set_pev(g_Player_Controll, pev_fixangle, 1)
						set_pev(g_Player_Controll, pev_movetype, MOVETYPE_NOCLIP)
						
						set_pev(g_Player_Controll, pev_origin, {-780.622680, 20.000539, 782.357971})
						set_pev(g_Player_Controll, pev_maxspeed, 1.0)
						set_pev(boss, pev_solid, SOLID_BBOX)
						set_rendering(g_Player_Controll, kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, 0)
	
						message_begin( MSG_BROADCAST, SVC_TEMPENTITY )
						write_byte( TE_KILLBEAM ) 
						write_short( boss )
						message_end()
						g_Ability = 0
						num = 0
					}
					set_pev(boss, pev_nextthink, get_gametime() + 0.1)
				}
			}
		}
	}
}

function_victim(Float:s[], Float:e[]) {
	new trace_damage, victim, Float:vector
					
	engfunc(EngFunc_TraceLine, s, e, DONT_IGNORE_MONSTERS, -1, trace_damage)
	get_tr2(trace_damage, TR_vecEndPos, vector)
	victim = engfunc(EngFunc_FindEntityInSphere, victim, vector, 20.0)
	if (is_user_alive(victim)) {
		ExecuteHamB(Ham_Killed, victim, victim, 2)
		function_victim(s, e)
	}
}

zl_attack(i) {
	static Float:origin_attack[3], Float:angle_attack[3]
	pev(g_Illidan, pev_origin, origin_attack)
	pev(g_Illidan, pev_angles, angle_attack)
	
	new ent = create_entity("info_target")
	set_rendering(ent, kRenderFxNone, 0, 0, 0, kRenderTransAdd, 255)
	engfunc(EngFunc_SetModel, ent, g_Resource[i])
	engfunc(EngFunc_SetOrigin, ent, origin_attack)
	set_pev(ent, pev_angles, angle_attack)
	set_pev(ent, pev_classname, "boss_illidan_attack")
	set_pev(ent, pev_button, 255)
	set_pev(ent, pev_nextthink, get_gametime() + 0.1)
	if (i == 6) zl_anim(ent, 1, 1.0)
}

public think_attack(ent) {
	if(!pev_valid(ent)) return
	
	static a
	a = pev(ent, pev_button)
	
	switch(a) {
		case 15..255: {
			static Float:b, c
			b = 240.0 / 3.0 / 10.0
			c = a - floatround(b)
			set_pev(ent, pev_button, c)
			set_rendering(ent, kRenderFxNone, 0, 0, 0, kRenderTransAdd, c)
		}
		default: {
			a = 0
			set_pev(ent, pev_button, a)
			set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME)
			return
		}
	}
	set_pev(ent, pev_nextthink, get_gametime() + 0.1)
}

public touch_boss(boss, entity) {
	if (pev(boss, pev_deadflag) == DEAD_RESPAWNABLE) return
	if (pev(boss, pev_sequence) != 2) return
	if (g_Ability == 4) {
		if(is_user_alive(entity)) {
			ExecuteHamB(Ham_Killed, entity, entity, 2)
		}
	}
	
	if (g_Ability == 0 || g_Ability == 5) {
		if (is_user_alive(entity)) {
			g_Ability = 1
			if (g_Phase == 2) {
				//set_pev(boss, pev_nextthink, get_gametime() + 0.1)
				static victim
				victim = pev(boss, pev_victim)
				if( is_user_alive(victim) && (0 < victim <= 32) ) set_rendering(victim)
				if( pev_valid(g_Focus_Entity) && (g_Focus_Entity > 32)) {
					set_pev(g_Focus_Entity, pev_flags, pev(g_Focus_Entity, pev_flags) | FL_KILLME)	
					g_Focus_Entity = 0
				}
			}
			set_pev(boss, pev_victim, entity)
		}
	}
}

public think_hpbar(e) {
	if (!pev_valid(e))
		return
		
	if (pev(g_Illidan, pev_deadflag) == DEAD_DYING) {
		set_pev(e, pev_flags, pev(e, pev_flags) | FL_KILLME)
		return
	}
	
	static Float:hp_current, Float:hp_maximum, Float:percent
	pev(g_Illidan, pev_max_health, hp_maximum)
	pev(g_Illidan, pev_health, hp_current)
	percent = 100 - hp_current * 100.0 / hp_maximum
	
	set_pev(e, pev_frame, percent)	
	
	static anim, hp_buff
	anim = pev(g_Illidan, pev_sequence)
	
	percent = 100 - percent
	
	if (g_Ability != 3 &&(anim == 2 || anim == 1) && (percent < hp_buff || hp_buff == 0)) {
		switch(floatround(percent)) {
			case 51..75: {
				if (g_Ability == 0) {
					g_Ability = 7
					g_Phase = 2
					hp_buff = 50
					zl_sound(0, g_SoundList[9], 0)
				}
			}
			case 40..50: {
				g_Ability = 4
				hp_buff = 39
				if (is_user_alive(g_Player_Controll)) {
					set_rendering(g_Player_Controll)
					set_pev(g_Player_Controll, pev_origin, {-586.850524, -64.463745, 36.031250})
					set_pev(g_Player_Controll, pev_movetype, MOVETYPE_NONE)
					set_pev(g_Player_Controll, pev_maxspeed, 255.0)
					give_item(g_Player_Controll, "weapon_knife")
					
					message_begin(MSG_ONE_UNRELIABLE, g_msgBarTime, _, g_Player_Controll)
					write_short(0)
					message_end()
				}
				g_Player_Controll = 0
				
				if( pev_valid(g_Focus_Entity)) set_pev(g_Focus_Entity, pev_flags, pev(g_Focus_Entity, pev_flags) | FL_KILLME)	
			}
			case 30..39: {
				g_Ability = 6
				hp_buff = 29
			}
			case 20..29: {
				static e = -1
				while ( (e = engfunc(EngFunc_FindEntityByString, e, "classname", "boss_illidan_splash")) )
					if(pev_valid(e)) set_pev(e, pev_flags, pev(e, pev_flags) | FL_KILLME)
				g_Ability = 6
				hp_buff = 19
				zl_sound(0, g_SoundList[10], 0)
			}
			case 10..19: {
				g_Ability = 6
				hp_buff = 9
			}
			case 1..9: {
				g_Ability = 6
				hp_buff = -1
			}
		}
	}
	
	
	set_pev(e, pev_nextthink, get_gametime() + 0.1)
}

public zl_timer(timer, prepare) {
	static bool:boss_spawn = false
	static hp, Float:ability_time
	
	if (prepare == 1) {
		#if defined PLAYER_HP
		set_pev(g_Illidan, pev_health, float(PlayerHp(zl_cvar[0])))
		set_pev(g_Illidan, pev_max_health, float(PlayerHp(zl_cvar[0])))
		#else
		set_pev(g_Illidan, pev_health, float(zl_cvar[0]))
		set_pev(g_Illidan, pev_max_health, float(zl_cvar[0]))
		#endif
		set_pev(g_Illidan, pev_movetype, MOVETYPE_PUSHSTEP)
		set_pev(g_Illidan, pev_nextthink, get_gametime() + 7.0)
		set_pev(hp, pev_nextthink, get_gametime() + 7.0)
		set_pev(hp, pev_effects, pev(hp, pev_effects) & ~EF_NODRAW)
		ability_time = get_gametime() + zl_fcvar[0]
		zl_sound(0, g_SoundList[5], 0)
		return
	}
	
	if (!boss_spawn) {
		// Boss
		engfunc(EngFunc_SetModel, g_Illidan, g_Resource[0])
		engfunc(EngFunc_SetSize, g_Illidan, Float:{-42.0, -42.0, -32.0}, Float:{BOSS_Z, 42.0, 72.0})
		set_pev(g_Illidan, pev_deadflag, DEAD_RESPAWNABLE)
		set_pev(g_Illidan, pev_takedamage, DAMAGE_NO)
		set_pev(g_Illidan, pev_solid, SOLID_SLIDEBOX)
		set_pev(g_Illidan, pev_movetype, MOVETYPE_TOSS)
		set_pev(g_Illidan, pev_classname, "boss_illidan")
		set_pev(g_Illidan, pev_body, 8)
		zl_anim(g_Illidan, 1, 1.0)
		
		// HpBar
		g_HealthBar = hp = create_entity("info_target")
		engfunc(EngFunc_SetModel, hp, g_Resource[2])
		set_pev(hp, pev_skin, g_Illidan)
		set_pev(hp, pev_body, 1)
		set_pev(hp, pev_movetype, MOVETYPE_FOLLOW)
		set_pev(hp, pev_classname, "boss_illidan_hpbar")
		set_pev(hp, pev_effects, EF_NODRAW)
		set_pev(hp, pev_scale, 0.3)
		
		boss_spawn = !boss_spawn
	}

	if (ability_time < get_gametime() && g_Ability == 0 && pev(g_Illidan, pev_sequence) == 2 && g_Phase < 2) {
		g_Ability = 2
		ability_time = get_gametime() + zl_fcvar[0]
	}
	
	if (is_user_alive(g_Player_Controll) && pev(g_Player_Controll, pev_movetype) == MOVETYPE_NOCLIP) {		
		if (g_kill_time == 0.0) { }
		else 
		if (g_kill_time <= get_gametime()) {
			ExecuteHamB(Ham_Killed, g_Player_Controll, g_Player_Controll, 2)
			g_Ability = 7
		} else if (g_kill_time > get_gametime()) return
		
		g_kill_time = get_gametime() + float(zl_cvar[10])
		
		message_begin(MSG_ONE_UNRELIABLE, g_msgBarTime, _, g_Player_Controll)
		write_short(zl_cvar[10])
		message_end()
	}
}

PlayerHp(hp) {
	new Count, Hp
	for(new id = 1; id <= g_MaxPlayers; id++)
		if (is_user_alive(id) && !is_user_bot(id))
			Count++
			
	Hp = hp * Count
	return Hp
}

load_map_event() {
	g_Illidan = engfunc(EngFunc_FindEntityByString, g_Illidan, "targetname", "boss")
	pev(g_Illidan, pev_origin, o_start)
}

public plugin_precache() {
	if (zl_boss_map() != 6)
		return
	
	static i = 0
	for (i = 0; i < sizeof g_Resource; ++i)
		i_Resource[i] = precache_model(g_Resource[i])
	
	for (i = 0; i < sizeof g_SoundList; ++i)
		precache_sound(g_SoundList[i])
}

public plugin_cfg() {			
	new path[64]
	get_localinfo("amxx_configsdir", path, charsmax(path))
	format(path, charsmax(path), "%s/zl/zl_illidanboss.ini", path)
    
	if (!file_exists(path)) {
		new error[100]
		formatex(error, charsmax(error), "Cannot load customization file %s!", path)
		set_fail_state(error)
		return
	}
    
	new linedata[2048], key[64], value[960], section
	new file = fopen(path, "rt")
    
	while (file && !feof(file)) {
		fgets(file, linedata, charsmax(linedata))
		replace(linedata, charsmax(linedata), "^n", "")
       
		if (!linedata[0] || linedata[0] == '/') continue;
		if (linedata[0] == '[') { section++; continue; }
       
		strtok(linedata, key, charsmax(key), value, charsmax(value), '=')
		trim(key)
		trim(value)
		
		switch (section) { 
			case 1: { // GENERAL
				if (equal(key, "BOSS_HP"))
					zl_cvar[0] = str_to_num(value)
				else if (equal(key, "BOSS_SPEED"))
					zl_cvar[1] = str_to_num(value)
				else if (equal(key, "BOSS_SPEED_PHASE2"))
					zl_cvar[4] = str_to_num(value)	
				else if (equal(key, "BOSS_SPEED_PHASE4"))
					zl_cvar[5] = str_to_num(value)	
				else if (equal(key, "BOSS_DAMAGE_ATTACK"))
					zl_cvar[2] = str_to_num(value)
				else if (equal(key, "BOSS_DAMAGE_ROLL"))
					zl_cvar[3] = str_to_num(value)
				else if (equal(key, "BOSS_TIME_BLITZ"))
					zl_fcvar[0] = str_to_float(value)
				else if (equal(key, "BOSS_TIME_MARUSIA"))
					zl_cvar[10] = str_to_num(value)

			}
			case 2: { // ELEM
				if (equal(key, "ELEM_HP"))
					zl_cvar[6] = str_to_num(value)
				else if (equal(key, "ELEM_SPEED"))
					zl_cvar[7] = str_to_num(value)
				else if (equal(key, "ELEM_DAMAGE_SPAWN"))
					zl_cvar[8] = str_to_num(value)
				else if (equal(key, "ELEM_SPLASH"))
					zl_cvar[9] = str_to_num(value)
			}
		}
	}
	if (file) fclose(file)
}

/* 
	PHASE FLY ( BLADE AND ELEMENTAL )
*/

public blade_trace(v, a, Float:dmg, Float:direction[3], tr, dt) {
	static szBlade[32]
	pev(v, pev_classname, szBlade, charsmax(szBlade))
	
	if (szBlade[0] == 'i' && szBlade[12] == 'e') {
		static Float:tr_end[3]
		get_tr2(tr, TR_vecEndPos, tr_end)
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_SPARKS)
		engfunc(EngFunc_WriteCoord, tr_end[0])
		engfunc(EngFunc_WriteCoord, tr_end[1])
		engfunc(EngFunc_WriteCoord, tr_end[2])
		message_end()
	} else if(szBlade[0] == 'b' && szBlade[11] == 'n') {
		g_LiderDamage[a] += dmg
	}
	return HAM_IGNORED
}

public think_elem(elem) {
	//if (!is_user_alive(g_ElemFirstVictim[1]))
	//	return
			
	if (g_Elem[0] == elem) { // FirstELem
		static victim1
		static Float:time_update
		
		static num
		switch(num) {
			case 0: {				
				static Float:origin_spawn[3]
				pev(g_ElemFirstVictim[0], pev_origin, origin_spawn)			
				zl_shockwave(origin_spawn, 10, 200, 200.0, {0, 255, 0})
				set_pev(elem, pev_nextthink, get_gametime() + 0.1)
				engfunc(EngFunc_SetOrigin, elem, origin_spawn)
				engfunc(EngFunc_SetModel, elem, g_Resource[7])
				zl_anim(elem, 1, 1.0)
				num++
				
				for(new i = 1; i <= g_MaxPlayers; ++i) {
					if (!is_user_alive(i))
						continue 
						
					if (entity_range(i, elem) < 200) {
						zl_slap(i, 1000, zl_cvar[8], 0)
						zl_screenfade(i, 1, 1, {0, 50, 0}, 50, 1)
						zl_screenshake(i, 15, 3)
					}
				}
				return
			}
			case 1: {
				set_pev(elem, pev_movetype, MOVETYPE_PUSHSTEP)
				set_pev(elem, pev_solid, SOLID_BBOX)
				zl_laser(elem, g_Blade[0], {0, 255, 0})
				set_pev(elem, pev_nextthink, get_gametime() + 4.3)
				num++
			}
			case 2: {
				if (pev(elem, pev_sequence) != 0) {
					zl_anim(elem, 0, 1.0)
				}
				
				if (pev(elem, pev_deadflag) == DEAD_DYING) {
					zl_anim(elem, 13, 1.0)
					set_pev(elem, pev_nextthink, get_gametime() + 3.0)
					num = 4
					return
				}
				
				static len
				victim1 = zl_player_choose(elem, 0)
				
				if(!is_user_alive(victim1)) {
					set_pev(elem, pev_nextthink, get_gametime() + 0.1)
					return
				}
				
				static Float:velocity[3], Float:angle[3]
				len = zl_move(elem, victim1, float(zl_cvar[7]), velocity, angle)
				set_pev(elem, pev_velocity, velocity)
				set_pev(elem, pev_angles, angle)
				set_pev(elem, pev_nextthink, get_gametime() + 0.1)
				
				if (len < 50) {
					zl_anim(elem, 10, 1.0)
					set_pev(elem, pev_nextthink, get_gametime() + 1.5)
					set_pev(elem, pev_velocity, {0.0, 0.0, 0.0})
					num++
				}
			}
			case 3: {
				if (entity_range(elem, victim1) < 180 && is_user_alive(victim1))
					ExecuteHamB(Ham_Killed, victim1, victim1, 2)
					
				set_pev(elem, pev_nextthink, get_gametime() + 1.0)
				num--
			}
			case 4: {
				message_begin( MSG_BROADCAST, SVC_TEMPENTITY )
				write_byte( TE_KILLBEAM ) 
				write_short( elem )
				message_end()
				set_pev(elem, pev_flags, pev(elem, pev_flags) | FL_KILLME)
				set_pev(g_Blade[0], pev_flags, pev(g_Blade[0], pev_flags) | FL_KILLME)
				g_Blade[0] = -1
				
				if(!pev_valid(g_Blade[0]) && !pev_valid(g_Blade[1])) {
					set_pev(g_Illidan, pev_nextthink, get_gametime() + 1.0)
					return
				}
				return
			}
		}
		
		
		if (pev_valid(elem)) {
			if (time_update < get_gametime()) {
				zl_laser(elem, g_Blade[0], {0, 255, 0})
				time_update = get_gametime() + 13.0
			}
		}
		
	} else if (g_Elem[1] == elem) { // LastElem
		static Float:time_update
		static Float:vector[3], Float:origin_start[3]
		
		static num
		switch(num) {
			case 0: {				
				static Float:origin_spawn[3]
				pev(g_ElemFirstVictim[1], pev_origin, origin_spawn)			
				zl_shockwave(origin_spawn, 10, 200, 200.0, {0, 255, 0})
				set_pev(elem, pev_nextthink, get_gametime() + 0.1)
				engfunc(EngFunc_SetOrigin, elem, origin_spawn)
				engfunc(EngFunc_SetModel, elem, g_Resource[7])
				zl_anim(elem, 1, 1.0)
				num++
				
				for(new i = 1; i <= g_MaxPlayers; ++i) {
					if (!is_user_alive(i))
						continue 
						
					if (entity_range(i, elem) < 200) {
						zl_slap(i, 1000, zl_cvar[8], 0)
						zl_screenfade(i, 1, 1, {0, 50, 0}, 50, 1)
						zl_screenshake(i, 15, 3)
					}
				}
				return
			}
			case 1: {
				zl_laser(elem, g_Blade[1], {0, 255, 0})
				set_pev(elem, pev_nextthink, get_gametime() + 4.3)
				num++
			}
			case 2: { // Attack
				if (pev(elem, pev_deadflag) == DEAD_DYING) {
					zl_anim(elem, 13, 1.0)
					set_pev(elem, pev_nextthink, get_gametime() + 3.0)
					num = 4
					return
				}
				
				zl_anim(elem, 9, 0.4)
				set_pev(elem ,pev_nextthink, get_gametime() + 0.8)
				
				new Float:origin_end[3], Float:angle[3]
				zl_position(g_Elem[1], 100.0, 0.0, 80.0, origin_start)
				new victim = zl_player_choose(g_Elem[1], 2)
				if(!is_user_alive(victim)) {
					set_pev(elem, pev_nextthink, get_gametime() + 0.1)
					return
				}
				pev(victim, pev_origin, origin_end)
				origin_end[2] -= 30.0
				xs_vec_sub(origin_end, origin_start, vector)
				vector_to_angle(vector, angle)
				angle[0] = 0.0
				angle[2] = 0.0
				xs_vec_normalize(vector, vector)
				xs_vec_mul_scalar(vector, 800.0, vector)
				set_pev(elem, pev_angles, angle)
				num++
			}
			case 3: {
				new ball = create_entity("info_target")
				engfunc(EngFunc_SetModel, ball, g_Resource[10])
				set_pev(ball, pev_solid, SOLID_TRIGGER)
				set_pev(ball, pev_movetype, MOVETYPE_FLY)
				zl_anim(ball, 1, 0.5)
				engfunc(EngFunc_SetOrigin, ball, origin_start)
				set_pev(ball, pev_velocity, vector)
				set_pev(elem, pev_nextthink, get_gametime() + 1.0) 
				set_pev(ball, pev_classname, "boss_illidan_ball")
				num--
				
				for(new i = 0; i<3; ++i)	{ origin_start[i] = 0.0; vector[i] = 0.0; }
			}
			case 4: {
				message_begin( MSG_BROADCAST, SVC_TEMPENTITY )
				write_byte( TE_KILLBEAM ) 
				write_short( elem )
				message_end()
				set_pev(elem, pev_flags, pev(elem, pev_flags) | FL_KILLME)
				set_pev(g_Blade[1], pev_flags, pev(g_Blade[1], pev_flags) | FL_KILLME)
				g_Blade[1] = -1
				
				if(!pev_valid(g_Blade[0]) && !pev_valid(g_Blade[1])) {
					set_pev(g_Illidan, pev_nextthink, get_gametime() + 1.0)
					return
				}
				return
			}
		}
		
		
		if (pev_valid(elem)) {
			if (time_update < get_gametime()) {
				zl_laser(elem, g_Blade[1], {0, 255, 0})
				time_update = get_gametime() + 13.0
			}
		}
	}
}

public touch_ball(ball, ent) {
	if (is_user_alive(ent)) {
		ExecuteHamB(Ham_Killed, ent, ent, 2)
	} else {
		new Float:origin[3]
		pev(ball, pev_origin, origin)
		zl_shockwave(origin, 10, 200, 150.0, {0, 255, 0})
		new i
		for (i = 1; i<=g_MaxPlayers; ++i) {
			if(!is_user_alive(i)) continue
			if(entity_range(ball, i) < 180) {
				zl_slap(i, 500, zl_cvar[2], 0)
				zl_screenfade(i, 1, 1, {0, 50, 0}, 50, 1)
				zl_screenshake(i, 15, 3)
			}
		}
		
		new Float:EndOrigin[3]
		new splash = create_entity("info_target")
		engfunc(EngFunc_SetModel, splash, g_Resource[11])
					
		/* vector create */
		origin[2] = origin[2] + 300.0
		EndOrigin[0] = origin[0]
		EndOrigin[1] = origin[1]
		EndOrigin[2] = origin[2] - 600.0
					
		new tr
		engfunc(EngFunc_TraceLine, origin, EndOrigin, IGNORE_MONSTERS, -1, tr)
		get_tr2(tr, TR_vecEndPos, EndOrigin)
		EndOrigin[2] += 1.0
		engfunc(EngFunc_SetOrigin, splash, EndOrigin)
		set_pev(splash, pev_classname, "boss_illidan_splash")
		set_pev(splash, pev_nextthink, get_gametime() + 0.2)
	}
	set_pev(ball, pev_flags, pev(ball, pev_flags) | FL_KILLME)
}

public think_splash(splash) {
	if(!pev_valid(splash))
		return
		
	new i
	for(i = 1; i<=g_MaxPlayers; ++i) {
		if(!is_user_alive(i))
			continue
			
		if(entity_range(splash, i) < 250) {
			zl_damage(i, zl_cvar[9], 0)
			zl_screenfade(i, 1, 1, {0, 50, 0}, 50, 1)
		}
	}
	set_pev(splash, pev_nextthink, get_gametime() + 0.2)
}

public blade_killed(v, a, c) {
	static szBlade[32]
	pev(v, pev_classname, szBlade, charsmax(szBlade))
	
	if (szBlade[0] == 'i' && szBlade[12] == 'e') {
		set_pev(v, pev_solid, SOLID_NOT)
		if (v == g_Blade[0]) set_pev(g_Elem[0], pev_deadflag, DEAD_DYING)
		if (v == g_Blade[1]) set_pev(g_Elem[1], pev_deadflag, DEAD_DYING)
		
		return HAM_SUPERCEDE
	}
	return HAM_IGNORED
}

public think_blade_hpbar( e ) {
	static Float:hp_current, Float:hp_maximum, Float:percent
	if (e == g_Hp[0]) {
		pev(g_Blade[0], pev_max_health, hp_maximum)
		pev(g_Blade[0], pev_health, hp_current)
	} else if (e == g_Hp[1]) {		
		pev(g_Blade[1], pev_max_health, hp_maximum)
		pev(g_Blade[1], pev_health, hp_current)
	}
	
	percent = 100 - hp_current * 100.0 / hp_maximum
	if (percent > 100) {
		set_pev(e, pev_flags, pev(e, pev_flags) | FL_KILLME)
		return
	}
	set_pev(e, pev_frame, (percent > 100.0) ? 100.0 : percent)
	set_pev(e, pev_nextthink, get_gametime() + 0.1)
}

/* 
	GHOST
*/
function_ghost_spawn() {
	new e = create_entity("info_target")
	new Float:origin[3]
	pev(g_Illidan, pev_origin, origin)
	
	engfunc(EngFunc_SetModel, e, g_Resource[0])
	engfunc(EngFunc_SetOrigin, e, origin)
	set_pev(e, pev_solid, SOLID_NOT)
}

/*
	BOSS CONTROL
*/
function_set_player_controll() {
	if (!g_Test) {
	new Float:dmg_buff, i = 1
	
	for (i = 1; i <= g_MaxPlayers; ++i) {
		if (!is_user_alive(i)) continue
				
		if (g_LiderDamage[i] > dmg_buff) {
			dmg_buff = g_LiderDamage[i]
			g_Player_Controll = i
		}
	}
	}
	if (g_Test) g_Player_Controll = g_Test
	return g_Player_Controll
}

public Player_Think(id) {
	if (g_Player_Controll == 0) return HAM_IGNORED
	if (g_Player_Controll != id) return HAM_IGNORED
	if (g_Ability != 0) return HAM_IGNORED
	if (!is_user_alive(g_Player_Controll)) return HAM_IGNORED
	
	static anim; anim = pev(g_Illidan, pev_sequence)
	if (anim == 2 || anim == 1) {	
		static buttons, buttons2
		buttons = pev(id, pev_button)
		buttons2 = pev(id, pev_oldbuttons)
		
		if(buttons & IN_ATTACK && !(buttons2 & IN_ATTACK)) {
			static aim, body,entity, entbuff
			get_user_aiming(id, aim, body)
			if (is_user_alive(aim) && (0 < aim <= 32)) {
				set_pev(g_Illidan, pev_victim, aim)
				
				if (is_user_alive(entbuff) && (0 < entbuff <= 32)) {
					set_rendering(entbuff)
					entbuff = 0
				}
				
				set_rendering(aim, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 50)
				
				if (pev_valid(g_Focus_Entity) && (g_Focus_Entity > 32)) {
					set_pev(entity, pev_flags, pev(entity, pev_flags) | FL_KILLME)
					entity = 0
					g_Focus_Entity = 0
				}
				
				entbuff = aim
				g_kill_time = 0.0
				
			} else {
				if (aim == g_Illidan) return HAM_IGNORED
				
				static iorigin[3], Float:origin[3], Float:EndOrigin[3]
				get_user_origin(id, iorigin, 2)
				IVecFVec(iorigin, origin)
				
				static Float:vector[3], Float:len
				xs_vec_sub(origin, Float:{-58.031250, 21.052875, 36.031250}, vector)
				len = xs_vec_len(vector)
				if (len > 600) return HAM_IGNORED
				
				if (pev_valid(g_Focus_Entity) && (g_Focus_Entity > 32)) {
					set_pev(entity, pev_flags, pev(entity, pev_flags) | FL_KILLME)
					entity = 0
					g_Focus_Entity = 0
				}
				
				if (is_user_alive(entbuff) && (0 < entbuff <= 32)) {
					set_rendering(entbuff)
					entbuff = 0
				}
				
				g_Focus_Entity = entity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
				engfunc(EngFunc_SetModel, entity, g_Resource[13])
				
				origin[2] = origin[2] + 300.0
				EndOrigin[0] = origin[0]
				EndOrigin[1] = origin[1]
				EndOrigin[2] = origin[2] - 600.0
						
				new tr
				engfunc(EngFunc_TraceLine, origin, EndOrigin, IGNORE_MONSTERS, -1, tr)
				get_tr2(tr, TR_vecEndPos, EndOrigin)
				EndOrigin[2] += 2.0
				engfunc(EngFunc_SetOrigin, entity, EndOrigin)
				set_pev(entity, pev_angles, {90.0, 0.0, 0.0})
				free_tr2(tr)
				
				set_pev(g_Illidan, pev_victim, entity)
			}
		}
	}
	return HAM_IGNORED
}

public client_disconnect(id) {
	if (g_Player_Controll == 0) return
	if (id == g_Player_Controll) {
		function_set_player_controll()
	}
}

/* 
	STOCK
*/
stock zl_laser(a, b, Color[3]) {
	message_begin( MSG_BROADCAST, SVC_TEMPENTITY ) 
	write_byte( TE_BEAMENTS ) 
	write_short( a )
	write_short( b )
	write_short( i_Resource[8] )
	write_byte( 1 )		// framestart 
	write_byte( 1 )		// framerate 
	write_byte( 10 * 100 )	// life in 0.1's 
	write_byte( 8 )		// width
	write_byte( 5 )		// noise 
	write_byte( Color[0] )		// r, g, b 
	write_byte( Color[1] )	// r, g, b 
	write_byte( Color[2] ) 		// r, g, b 
	write_byte( 200 )	// brightness 
	write_byte( 0 )		// speed 
	message_end()
}

stock zl_shockwave(Float:Orig[3], Life, Width, Float:Radius, Color[3]) {
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Orig, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, Orig[0]) // x
	engfunc(EngFunc_WriteCoord, Orig[1]) // y
	engfunc(EngFunc_WriteCoord, Orig[2]-40.0) // z
	engfunc(EngFunc_WriteCoord, Orig[0]) // x axis
	engfunc(EngFunc_WriteCoord, Orig[1]) // y axis
	engfunc(EngFunc_WriteCoord, Orig[2]+Radius) // z axis
	write_short(i_Resource[9]) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(Life) // life (4)
	write_byte(Width) // width (20)
	write_byte(0) // noise
	write_byte(Color[0]) // red
	write_byte(Color[1]) // green
	write_byte(Color[2]) // blue
	write_byte(255) // brightness
	write_byte(0) // speed
	message_end()
}

stock is_block_ent(ent) {
	new Float:origin[3], Float:vector[3], Float:len
	pev(ent, pev_origin, origin)
	xs_vec_sub(origin, Float:{-58.031250, 21.052875, 36.031250}, vector)
	len = xs_vec_len(vector)
	if (len > 600) return 1
	return 0
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1049\\ f0\\ fs16 \n\\ par }
*/
