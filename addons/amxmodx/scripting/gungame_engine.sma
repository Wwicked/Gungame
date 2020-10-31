#include <amxmodx>
#include <colorchat>
#include <hamsandwich>
#include <fakemeta_util>
#include <cstrike>
#include <engine>
#include <sqlx>
#include <fun>
#include <gungame_vip>
#include <StripWeapons>

// Do not change that, thank you
#define AUTHOR "Wicked - amxx.pl/user/60210-wicked/ | Ogen Dogen  - amxx.pl/user/21503-ogen-dogen/"

// Used in custom mapchooser.
native showMapVoteMenu();

#pragma semicolon 1
#pragma compress 1

// Uncomment if testmode should be enabled.
#define TEST_MODE

// Uncomment to provide amxx more detailed log_amx data when handling an error.
#define DEBUG_MODE

// Mainly used to create size of static arrays.
#define MAX_CHARS 33

// Used in loops and to determine static array sizes (+1).
#define MAX_PLAYERS 32

#define ForTeam(%1,%2) for(new %1 = 1; %1 <= MAX_PLAYERS; %1++) if (is_user_connected(%1) && user_data[%1][DATA_TEAM] == %2)
#define ForDynamicArray(%1,%2) for(new %1 = 0; %1 < ArraySize(%2); %1++)
#define ForPlayers(%1) for(new %1 = 1; %1 <= MAX_PLAYERS; %1++)
#define ForArray(%1,%2) for(new %1 = 0; %1 < sizeof(%2); %1++)
#define ForRange(%1,%2,%3) for(new %1 = %2; %1 <= %3; %1++)

// Task indexes.
enum _: (+= 2500)
{
	TASK_RESPAWN = 1337,
	TASK_NOTIFY,
	TASK_DISPLAYHUD,

	TASK_GIVEGRENADE,
	TASK_REWARDWINNER,

	TASK_SPAWNPROTECTION,
	TASK_RESPAWN_ON_JOIN,
	TASK_IDLECHECK,

	TASK_MONEY
};

// Enum for WeaponsData array.
enum _: (+= 1)
{
	weapon_CSW,
	weapon_kills,
	weapon_team_kills
};

// Main data array. [0] is weapon CSW_ index. [1] is kills required to level-up. [2] is kills required to level-up as a team.
static const WeaponsData[][] =
{
	{ CSW_GLOCK18, 2, 15 },
	{ CSW_USP, 2, 15 },
	{ CSW_P228, 2, 15 },

	{ CSW_FIVESEVEN, 2, 15 },
	{ CSW_DEAGLE, 2, 15 },
	{ CSW_ELITE, 2, 15 },
	
	{ CSW_M3, 3, 15 },
	{ CSW_XM1014, 3, 15 },
	{ CSW_TMP, 3, 15 },
	
	{ CSW_MAC10, 3, 15 },
	{ CSW_UMP45, 3, 15 },
	{ CSW_MP5NAVY, 3, 15 },
	
	{ CSW_P90, 4, 15 },
	{ CSW_GALIL, 4, 15 },
	{ CSW_FAMAS, 3, 15 },
	
	{ CSW_AK47, 4, 15 },
	{ CSW_SCOUT, 2, 15 },
	{ CSW_M4A1, 4, 15 },

	{ CSW_SG552, 4, 15 },
	{ CSW_AUG, 4, 15 },
	{ CSW_AWP, 4, 15 },

	{ CSW_G3SG1, 2, 15 },
	{ CSW_SG550, 2, 15 },
	{ CSW_M249, 2, 15 },

	{ CSW_HEGRENADE, 3, 3 },
	{ CSW_KNIFE, 1, 5 }
};

// Custom weapon names (used in HUD, ending-message etc).
static const CustomWeaponNames[][] =
{
	"Glock",
	"USP",
	"P228",

	"Five-seven",
	"Deagle",
	"Duals",
	
	"M3",
	"XM1014",
	"TMP",
	
	"Mac-10",
	"UMP",
	"MP5",
	
	"P90",
	"Galil",
	"Famas",
	
	"AK-47",
	"Scout",
	"M4A1",

	"SG-552",
	"AUG",
	"AWP",

	"Autokampa (TT)",
	"Autokampa (CT)",
	"M249",

	"Granat HE",
	"Noz"
};

// Commands to be blocked (using PLUGIN_HANDLED).
static const BlockedCommands[][] =
{
	"drop",
	"fullupdate",
	"kill",

	"radio1",
	"radio2",
	"radio3",
	"report",
	"coverme",
	"takepoint",
	"holdpos",
	"regroup",
	"followme",
	"takingfire",
	"go",
	"fallback",
	"sticktog",
	"getinpos",
	"stormfront",
	"roger",
	"enemyspot",
	"needbackup",
	"sectorclear",
	"inposition",
	"reportingin",
	"getout",
	"negative",
	"enemydown"
};

// RGB of colored shell (set_user_rendering) when in spawn protection.
static const SpawnProtectionColors[] = { 80, 0, 0 };

// Shell thickness.
static const SpawnProtectionShell = 100;


// Default HE explode time.
const Float:DefaultExplodeTime = 3.0;

// Modified HE explode time (set to DefaultExplodeTime to disable).
static const Float:HeGrenadeExplodeTime = 1.1;


// Hud objects enum.
enum (+= 1)
{
	hud_object_default = 0,
	hud_object_damage,
	hud_object_warmup
};

// HUD refresh time.
const Float:HudDisplayInterval = 1.0;

// HUD RGB colors.
static const HudColors[] = { 200, 130, 0 };


// RGB colors of warmup HUD.
static const WarmupHudColors[] = { 255, 255, 255 };


// Ammo indexes.
static const AmmoAmounts[] =
{
	0, 13, -0, 10, 1,
	7, 0, 30, 30, 1,
	30, 20, 25, 30, 35,
	25, 12, 20, 1, 30,
	100, 8, 30, 30, 20,
	2, 7, 30, 30, 0, 50
};


// Set that really high, so we dont have to worry about screen getting back to non-colored.
const Float:BlackScreenTimer = 50.0;


// Base weapon_* for wand.
static const WandBaseEntity[] = "weapon_knife";

// Wand models [0] - V_ || [1] - P_.
static const WandModels[][] =
{
	"models/gungame/v_wand.mdl",
	"models/gungame/p_wand.mdl"
};

// Wand sounds enum.
enum (+= 1)
{
	wand_sound_shoot
};

// Wand sounds.
static const WandSounds[][] =
{
	"gungame/wandShoot.wav"
};

// Wand primary attack sprite RGB.
static const WandAttackSpriteColor[] =
{
	20,
	20,
	200
};

// Wand sprites enum.
enum (+= 1)
{
	WAND_SPRITE_ATTACK,
	WAND_SPRITE_EXPLODE_ON_HIT,
	WAND_SPRITE_POST_HIT,
	WAND_SPRITE_BLOOD
};

static const WandSprites[][] =
{
	//"sprites/gungame/wand_attack.spr",
	"sprites/gungame/wandExplodeOnHit.spr",
	"sprites/gungame/wandPostHit.spr",
	"sprites/blood.spr"
};

// [0] - Damage || [1] - blood scale.
static const WandDamageEffects[][] =
{
	{ 0, 0 },		// None
	{ 90, 25 },		// Head
	{ 65, 15 },		// Chest
	{ 65, 15 },		// Chest
	{ 30, 10 },		// Hands
	{ 30, 10 },		// Hands
	{ 30, 10 },		// Legs
	{ 30, 10 }		// Legs
};


// Prefix shown in game-ending message and chat when leveling-up.
static const ChatPrefix[] = "[GUN GAME]";


// String that will replace rest of the nickname when clumping it to the short one.
static const NicknameReplaceToken[] = "...";

// Max. name length in short-name variable (to prevent char-overflow in ending message). Ex: "pretty long nickname" -> "pretty lon".
const MaxNicknameLength = 10 + charsmax(NicknameReplaceToken);


// Take damage hud colors.
static const TakeDamageHudColor[] = { 0, 200, 200 };


// Classnames of weapons on the ground (to prevent picking them up).
static const DroppedWeaponsClassnames[][] =
{
	"weaponbox",
	"armoury_entity",
	"weapon_shield"
};


// Sound types.
enum (+= 1)
{
	SOUND_LEVEL_UP = 0,
	SOUND_LEVEL_DOWN,
	SOUND_TIMER_TICK,

	SOUND_WARMUP,
	SOUND_ANNOUNCE_WINNER,
	SOUND_GAME_START,

	SOUND_TAKEN_LEAD,
	SOUND_LOST_LEAD
};

// Number of maximum sounds in SoundsData array.
static const MaxSounds = 2;

// Main sound-data array.
// Every index is a different sound.
// Indexes with strlen == 0 will be continued, instead plugin will use first available index.
static const SoundsData[][][] =
{
	{ "gungame/levelup.wav", "" },	// Levelup
	{ "gungame/leveldown.wav", "" },	// Leveldown
	{ "gungame/timertick4.wav", "" },	// Timer tick

	{ "gungame/warmup.wav", "" },	// Warmup
	{ "gungame/announcewinner.wav", "" },	// Announce winner
	{ "gungame/gungamestart.wav", "gungame/gungamestart2.wav" },	// Gungame start

	{ "gungame/takenlead.wav", "" },	// Taken lead
	{ "gungame/lostlead.wav", "" },		// Lost lead
	{ "gungame/tiedlead.wav", "" }		// Tied lead
};

// Custom volumes of each sound.
static const Float:SoundsVolumeData[][] =
{
	{ 1.0, 1.0 },	// Levelup
	{ 1.0, 1.0 },	// Leveldown
	{ 1.0, 1.0 },	// Timer tick

	{ 0.8, 1.0 },	// Warmup
	{ 1.0, 1.0 },	// Announce winner
	{ 1.0, 1.0 },	// Gungame start
	
	{ 1.0, 1.0 },	// Taken lead
	{ 1.0, 1.0 },	// Lost lead
	{ 1.0, 1.0 }	// Tied lead
};


// Sprites enum.
enum (+= 1)
{
	SPRITE_LEVEL_UP = 0
};

// Sprite paths.
static const SpritesData[][] =
{
	"sprites/levelupBeam.spr"
};

// Z axis.
static const Float:SpriteLevelupZaxis = 200.0;

// Life.
static const SpriteLevelupLife = 2;

// Width.
static const SpriteLevelupWidth = 15;

// RGB.
static const SpriteLevelupRGB[] = { 0, 255, 0 };

// Brightness.
static const SpriteLevelupBrightness = 80;


static const GameCvars[][][] =
{
	{ "mp_round_infinite", "1" },
	{ "mp_autoteambalance", "0" },
	{ "mp_roundover", "0" },

	{ "mp_nadedrops", "0" },
	{ "mp_auto_reload_weapons", "1" },
	{ "mp_refill_bpammo_weapons", "3" },

	{ "mp_auto_join_team", "1" },
	{ "mp_hostage_hurtable", "0" },
	{ "mp_show_radioicon", "0" },

	{ "sv_alltalk", "1" },
	{ "mp_freeforall", "1" },
	{ "mp_autokick", "0" },

	{ "sv_airaccelerate", "30" },
	{ "sv_maxspeed", "999" }
};


// Player-info command (checked in say_handle instead of register_clcmd to extract nickname from message).
static const LookupCommand[] = "/info";


// Commands to menu which lists weapons & their data.
static const ListWeaponsCommands[][] =
{
	"/lista",
	"/listabroni",
	"/bronie",
	"/bron",
	"/guns"
};


// Determines number of top-players that will be shown in game-ending message.
const TopPlayersDisplayed = 10;

// Top players motd HTML code.
static const TopPlayersMotdHTML[][] =
{
	"<style> body{ background: #202020 } tr{ text-align: left } table{ font-size: 12px; color: #ffffff; padding: 0px } h1{ color: #FFF; font-family: Verdana }</style><body>",
	"<table width = 100%% border = 0 align = center cellpadding = 0 cellspacing = 2>",
	"<tr>\
		<th>\
			<h3>Pozycja</h3>\
		</th>\
		<th>\
			<h3>Nazwa gracza</h3>\
		</th>\
		<th>\
			<h3>Wygrane gry</h3>\
		</th>\
		<th>\
			<h3>Zabicia nozem</h3>\
		</th>\
		<th>\
			<h3>%% Head shotow</h3>\
		</th>\
	</tr>"
};

// Top players motd commands.
static const TopPlayersMotdCommands[][] =
{
	"/top",
	"/topka",
	"/topgg"
};


#if defined DEBUG_MODE

// Prefix used in log_amx to log custom error messages.
static const NativesLogPrefix[] = "[GUNGAME ERROR]";

#endif

// Natives: [][0] is native name, [][1] is native function.
static const NativesData[][][] =
{
	{ "gg_set_user_level", "native_set_user_level" },
	{ "gg_get_user_level", "native_get_user_level" },

	{ "gg_set_team_level", "native_set_team_level" },
	{ "gg_get_team_level", "native_get_team_level" },
	
	{ "gg_get_max_level", "native_get_max_level" },
	
	{ "gg_respawn_player", "native_respawn_player" },
	
	{ "gg_get_user_weapon", "native_get_user_weapon" },
	{ "gg_get_weapons_data", "native_get_weapons_data" },

	{ "gg_get_user_wins", "native_get_user_wins" },
	{ "gg_get_user_combo", "native_get_user_combo" }
};

enum (+= 1)
{
	CVAR_SPAWN_PROTECTION_TIME,

	CVAR_RESPAWN_INTERVAL,

	CVAR_FLASHES_ENABLED,

	CVAR_GIVE_BACK_HE_INTERVAL,
	CVAR_GIVE_BACK_FLASH_INTERVAL,

	CVAR_WARMUP_DURATION,
	CVAR_WARMUP_LEVEL_REWARD,
	CVAR_WARMUP_HEALTH,
	CVAR_WARMUP_WEAPON,
	CVAR_WARUMP_RESPAWN_INTERVAL,

	CVAR_FALL_DAMAGE_ENABLED,

	CVAR_REFILL_WEAPON_AMMO,
	CVAR_REFILL_WEAPON_AMMO_TEAMPLAY,

	CVAR_IDLE_CHECK_INTERVAL,
	CVAR_IDLE_SLAP_POWER,
	CVAR_IDLE_MAX_STRIKES,
	CVAR_IDLE_MAX_DISTANCE,

	CVAR_DEFAULT_ARMOR_LEVEL,

	CVAR_KNIFE_KILL_INSTANT_LEVELUP,
	CVAR_KNIFE_KILL_LEVEL_DOWN_TEAMPLAY,
	CVAR_KNIFE_KILL_REWARD,

	CVAR_WAND_ENABLED,
	CVAR_WAND_ATTACK_SPRITE_BRIGHTNESS,
	CVAR_WAND_ATTACK_SPRITE_LIFE,
	CVAR_WAND_ATTACK_MAX_DISTANCE,
	CVAR_WAND_ATTACK_INTERVAL,

	CVAR_TAKE_DAMAGE_HUD_TIME,
	
	CVAR_REMOVE_WEAPONS_OFF_THE_GROUND,
	
	CVAR_NORMAL_FRIENDLY_FIRE,
	CVAR_TEAMPLAY_FRIENDLY_FIRE,

	CVAR_SPAWN_PROTECTION_TYPE,

	CVAR_MONEY,

	CVAR_BOMB_ENABLED,
	CVAR_BOMB_PLANT_REWARD,
	CVAR_BOMB_DEFUSE_REWARD,

	CVAR_ALLOW_BOMB_DROP,

	CVAR_TRANSFER_DROPPED_BOMB
};

static const GgCvarsData[][][] =
{
	{ "gg_spawn_protection_time", "1.5" }, // Time in which player CAN get killed, but the killer will not be granted any weapon kills if victim is in spawn protection.
	
	{ "gg_respawn_interval", "3.0" }, // Respawn time during GunGame.
	
	{ "gg_flashes_enabled", "1" }, // Determines wether to enable flashes on last level. Does not support wand.
	
	{ "gg_give_back_he_interval", "1.8" }, // Time between giving a player next HE grenade (during warmup & on HE weapon level).
	{ "gg_give_back_flash_interval", "4.5" }, // Time between giving a player next Flash grenade.
	
	{ "gg_warmup_duration", "10" }, // Time of warmup in seconds
	{ "gg_warmup_level_reward", "3" }, // Level that will be set to warmup winner. Value < 1 will disable notifications and picking warmup winner.
	{ "gg_warmup_health", "50" }, // Health that players will be set to during warmup.
	{ "gg_warmup_weapon", "-2" }, // Set that to CSW_ index, -1 to get random weapon, -2 to get wands (ignoring gg_wandEnabled value) or -3 to get random weapon for every player.
	{ "gg_warump_respawn_interval", "2.0" }, // Time to respawn player during warmup.
	
	{ "gg_fall_damage_enabled", "0" }, // Enable falldamage?
	
	{ "gg_refill_weapon_ammo", "1" }, // Refill weapon clip on kill? 0 - disabled, 1 - enabled to everyone, 2 - only vips
	{ "gg_refill_weapon_ammo_teamplay", "1" }, // Enabled on teamplay? 0 - disabled, 1 - enabled, refill whole team ammo, 2 - personal refill, 3 - only vips
	
	{ "gg_idle_check_interval", "6.0" }, // Determines interval between AFK checks.
	{ "gg_idle_slap_power", "5" }, // Hit power of a slap when player is 'AFK'.
	{ "gg_idle_max_strikes", "3" }, // Determines max strikes that player can have before slaps start occuring.
	{ "gg_idle_max_distance", "30" }, // Distance that resets camping-player idle strikes.
	
	{ "gg_default_armor_level", "0" }, // Armor level for every player.
	
	{ "gg_knife_kill_instant_levelup", "0" }, // If that's set to true, knife will instantly give you gg_knifeKillReward levels. Otherwise gg_knifeKillReward means weapon kills.
	{ "gg_knife_kill_level_down_teamplay", "1" }, // Allow to level down when knifed in teamplay?
	{ "gg_knife_kill_reward", "2" }, // Knife kill reward value based on CVAR_KNIFE_KILL_INSTANT_LEVELUP var.
	
	{ "gg_wand_enabled", "1" }, // Determines whether you want last level weapon to be knife (false) or wand (true).
	{ "gg_wand_attack_sprite_brightness", "255" }, // Wand primary attack sprite brightness.
	{ "gg_wand_attack_sprite_life", "4" }, // Wand primary attack sprite life.
	{ "gg_wand_attack_max_distance", "550" }, // Wand primary attack max distance.
	{ "gg_wand_attack_interval", "2.2" }, // Wand primary attack interval.
	
	{ "gg_take_damage_hud_time", "1.2" }, // Take damage hud hold-time.
	
	{ "gg_remove_weapons_off_the_ground", "1" }, // Remove weapons off the ground when loading map?

	{ "gg_normal_friendly_fire", "0" }, // Enable friendly fire in normal mode?
	{ "gg_teamplay_friendly_fire", "0" }, // Enable friendly fire in teamplay mode?

	{ "gg_spawn_protection_type", "0" }, // Spawn protection effect: 0 - godmode, 1 - no points granted to killer if victim is on spawn protection.

	{ "gg_money", "1" }, // Disable money? 0 - Money draw enabled, 1 - Money draw disabled

	{ "gg_bomb_enabled", "1" }, // Support bomb?
	{ "gg_bomb_reward_plant", "3" }, // Reward in weapon kills.
	{ "gg_bomb_reward_defuse", "3" }, // Reward in weapon kills.

	{ "gg_allow_bomb_drop", "1" }, // Allow dropping the bomb?

	{ "gg_transfer_dropped_bomb", "1" } // Transfer bomb when dropped? 0 - Disabled, 1 - Enabled, 2 - Only on "drop" command.
};

static const ForwardsNames[][] =
{
	"gg_level_up",
	"gg_level_down",
	"gg_game_end",
	"gg_game_beginning",
	"gg_player_spawned",
	"gg_combo_streak",
	"gg_game_mode_chosen"
};

enum _: ForwardsEnum (+= 1)
{
	FORWARD_LEVEL_UP,
	FORWARD_LEVEL_DOWN,
	FORWARD_GAME_END,
	FORWARD_GAME_BEGINNING,
	FORWARD_PLAYER_SPAWNED,
	FORWARD_COMBO_STREAK,
	FORWARD_GAME_MODE_CHOSEN
};

static const GameModes[][] =
{
	"Normalny",
	"Teamowy"
};

enum _: (+= 1)
{
	MODE_NORMAL,
	MODE_TEAMPLAY
};

static const TeamNames[][] =
{
	"TT",
	"CT"
};

enum UserDataEnumerator (+= 1)
{
	DATA_LEVEL,
	DATA_WEAPON_KILLS,
	DATA_SHORT_NAME[MAX_CHARS],
	DATA_SAFE_NAME[MAX_CHARS],
	DATA_TIME_TO_RESPAWN,
	bool:DATA_SPAWN_PROTECTION,
	DATA_COMBO,
	DATA_LAST_ORIGIN[3],
	DATA_IDLE_STRIKES,
	bool:DATA_FALLING,
	DATA_WARMUP_WEAPON,
	DATA_WARMUP_CUSTOM_WEAPON_INDEX,
	DATA_ALLOWED_WEAPONS,
	DATA_WINS,
	DATA_KILLS,
	DATA_KNIFE_KILLS,
	DATA_HEADSHOTS,
	DATA_WAND_LAST_ATTACK,
	DATA_TEAM,
	DATA_CURRENT_WEAPON
};

enum TopPlayersEnumerator (+= 1)
{
	TOP_NAMES[MAX_CHARS],
	TOP_WINS,
	TOP_KILLS,
	TOP_KNIFE_KILLS,
	TOP_HEADSHOTS
};

enum TopInfo (+= 1)
{
	bool:TOP_DATA_LOADED,
	TOP_MOTD_CODE[MAX_CHARS * 50],
	TOP_MOTD_LENGTH,
	TOP_MOTD_NAME,
	bool:TOP_MOTD_CREATED
};

enum WarmupEnumerator (+= 1)
{
	bool:WARMUP_ENABLED,
	WARMUP_TIMER,
	WARMUP_WEAPON_INDEX,
	WARMUP_WEAPON_NAME_INDEX
};

enum TeamplayEnumerator (+= 1)
{
	TP_TEAM_LEVEL[2],
	TP_TEAM_KILLS[2],
	bool:TP_ENABLED
};

enum DbEnumerator (+= 1)
{
	// These 4 need to be first.
	DB_HOST[MAX_CHARS * 2],
	DB_USER[MAX_CHARS * 2],
	DB_PASS[MAX_CHARS * 2],
	DB_DBASE[MAX_CHARS * 2],
	// These 4 need to be first.

	Handle:SQL_HANDLE,
	bool:SQL_LOADED,
	bool:SQL_CONFIG_FOUND
};

enum DcDataEnumerator (+= 1)
{
	Array:DC_DATA_LEVEL,
	Array:DC_DATA_NAME,
	Array:DC_DATA_WEAPON_KILLS
};

new user_data[MAX_PLAYERS + 1][UserDataEnumerator],

	warmup_data[WarmupEnumerator],

	top_players[TopPlayersDisplayed + 1][TopPlayersEnumerator],
	top_data[TopInfo],

	tp_data[TeamplayEnumerator],

	db_data[DbEnumerator],

	cvars_data[sizeof(GgCvarsData)],

	weapon_names[sizeof(WeaponsData)][MAX_CHARS - 1],
	weapon_entity_names[sizeof(WeaponsData)][MAX_CHARS],
	weapon_temp_name[MAX_CHARS],

	bool:gungame_ended,

	max_level,
	half_max_level,

	hud_objects[3],

	sprite_levelup_index,

	forward_handles[sizeof(ForwardsNames)],

	wand_sprites_indexes[sizeof(WandSprites)],

	game_votes[sizeof(GameModes)],
	bool:game_vote_enabled,
	game_mode = -1,

	disconnected_players_data[DcDataEnumerator],

	message_hide_weapon,
	message_hide_crosshair,

	bool:bomb_supported,

	old_leader,

	blank;


public plugin_init()
{
	register_plugin("GunGame", "v2.5", AUTHOR);

	// Register cvars.
	ForArray(i, GgCvarsData)
	{
		cvars_data[i] = register_cvar(GgCvarsData[i][0], GgCvarsData[i][1]);
	}

	// Register Death and team assign events.
	register_event("DeathMsg", "player_death_event", "a");
	register_event("TeamInfo", "on_team_assign", "a");

	// Remove weapons off the ground if enabled.
	if (get_pcvar_num(cvars_data[CVAR_REMOVE_WEAPONS_OFF_THE_GROUND]))
	{
		remove_weapons_off_ground();
		
		register_event("HLTV", "round_start", "a", "1=0", "2=0");
	}

	// CurWeapon for AWP reloading
	register_event("CurWeapon", "event_cur_weapon", "be", "1=1");

	// Register info change and model set events.
	register_forward(FM_ClientUserInfoChanged, "client_info_changed");
	register_forward(FM_SetModel, "set_entity_model");

	// Register message events (say, TextMsg and radio message).
	register_message(get_user_msgid("SayText"), "say_handle");
	register_message(get_user_msgid("TextMsg"), "text_grenade_message");
	register_message(get_user_msgid("SendAudio"), "audio_grenade_message");
	
	message_hide_weapon = get_user_msgid("HideWeapon");
	message_hide_crosshair = get_user_msgid("Crosshair");

	RegisterHam(Ham_Spawn, "player", "player_spawned", true);
	RegisterHam(Ham_TakeDamage, "player", "take_damage", false);
	RegisterHam(Ham_AddPlayerItem, "player", "on_dd_item_to_player");

	// Register greande think forward if HE explode time differs from default.
	if (HeGrenadeExplodeTime != DefaultExplodeTime)
	{
		RegisterHam(Ham_Think, "grenade", "he_grenade_think");
	}

	// Register knife deployement for model-changes if wand is enabled.
	if (get_pcvar_num(cvars_data[CVAR_WAND_ENABLED]))
	{
		RegisterHam(Ham_Item_Deploy, WandBaseEntity, "knife_deploy", true);
	}

	new weapon_classname[24];

	ForRange(i, 1, 30)
	{
		if (get_weaponname(i, weapon_classname, charsmax(weapon_classname)))
		{
			RegisterHam(Ham_Item_Deploy, weapon_classname, "weapon_deploy");
		}
	}

	// Register collision event on every weapon registered in gungame.
	ForArray(i, DroppedWeaponsClassnames)
	{
		RegisterHam(Ham_Touch, DroppedWeaponsClassnames[i], "on_player_weapon_touch", false);
	}

	// Get names of weapons.
	ForArray(i, WeaponsData)
	{
		get_weapons_name(i, WeaponsData[i][weapon_CSW], weapon_names[i], charsmax(weapon_names[]));
	}

	// Register primary attack with weapons registered in gungame.
	ForArray(i, WeaponsData)
	{
		RegisterHam(Ham_Weapon_PrimaryAttack, weapon_entity_names[i], "primary_attack");
	}

	// Block some commands.
	register_commands(BlockedCommands, sizeof(BlockedCommands), "block_command_usage", false);

	// Register weapon list commands.
	register_commands(ListWeaponsCommands, sizeof(ListWeaponsCommands), "list_weapons_menu");

	// Register top player menu commands.
	register_commands(TopPlayersMotdCommands, sizeof(TopPlayersMotdCommands), "top_players_motd_handler");
	
	// Create hud objects.
	ForRange(i, 0, charsmax(hud_objects))
	{
		hud_objects[i] = CreateHudSyncObj();
	}

	// Hook 'say' client command to create custom lookup command.
	register_clcmd("say", "say_custom_command_handle");

	// Get gungame max level.
	max_level = sizeof(WeaponsData) - 1;

	// Get half of max gungame level rounded, so we can limit level on freshly-joined players.
	half_max_level = floatround(float(max_level) / 2, floatround_round);

	// Create forwards.
	forward_handles[FORWARD_LEVEL_UP] = CreateMultiForward(ForwardsNames[0], ET_IGNORE, FP_CELL, FP_CELL, FP_CELL); // Level up (3)
	forward_handles[FORWARD_LEVEL_DOWN] = CreateMultiForward(ForwardsNames[1], ET_IGNORE, FP_CELL, FP_CELL, FP_CELL); // Level down (3)
	forward_handles[FORWARD_GAME_END] = CreateMultiForward(ForwardsNames[2], ET_IGNORE, FP_CELL); // Game end (1)
	forward_handles[FORWARD_GAME_BEGINNING] = CreateMultiForward(ForwardsNames[3], ET_IGNORE, FP_CELL); // Game beginning (1)
	forward_handles[FORWARD_PLAYER_SPAWNED] = CreateMultiForward(ForwardsNames[4], ET_IGNORE, FP_CELL); // Player spawn (1)
	forward_handles[FORWARD_COMBO_STREAK] = CreateMultiForward(ForwardsNames[5], ET_IGNORE, FP_CELL, FP_CELL); // Combo streak (2)
	forward_handles[FORWARD_GAME_MODE_CHOSEN] = CreateMultiForward(ForwardsNames[6], ET_IGNORE, FP_CELL); // Game mode chosen (1)

	// Toggle warmup a bit delayed from plugin start.
	set_task(1.0, "delayed_toggle_warmup");

	// Load info required to connect to database.
	load_sql_config();

	// Load bomb-supported maps.
	load_maps_info();

	// Load cvars.
	load_game_cvars();

	// Connect do mysql database.
	connect_database();

	// Initialize dynamic arrays.
	disconnected_players_data[DC_DATA_LEVEL] = ArrayCreate(1, 1);
	disconnected_players_data[DC_DATA_NAME] = ArrayCreate(32, 1);
	disconnected_players_data[DC_DATA_WEAPON_KILLS] = ArrayCreate(1, 1);

	// Load top players from MySQL.
	load_top_players();
	
	#if defined TEST_MODE

		// Test commands.
		register_clcmd("say /lvl", "setMaxLevel");
		register_clcmd("say /addlvl", "addLevel");
		register_clcmd("say /awp", "setAWPLevel");
		register_clcmd("say /godoff", "godmodOff");
		register_clcmd("say /kills", "addKills");
		register_clcmd("say /addkill", "addFrag");
		register_clcmd("say /winmessage", "testWinMessage");
		register_clcmd("say /warmup", "warmupFunction");
		register_clcmd("say /knife", "addKnifeKill");
		register_clcmd("say /headshot", "addHeadshot");
		register_clcmd("say /kill", "addKill");
		register_clcmd("say /win", "addWin");
		register_clcmd("say /weapon", "addWeapon");
		register_clcmd("say /takelead", "sound_TakeLead");
		register_clcmd("say /loselead", "sound_LoseLead");
		register_clcmd("say /paka", "addBomb");

	#endif
}

// Code sections are: "Natives", "Forwards & menus & unassigned publics", "Database", "Tasks" and "Functions"

/*
		[ Natives ]
*/

// Register natives on mode 0.
public plugin_natives()
{
	ForArray(i, NativesData)
	{
		register_native(NativesData[i][0], NativesData[i][1], false);
	}
}

public native_set_user_level(plugin, params)
{
	if (!check_params("set_user_level", 2, params))
	{
		return -1;
	}

	// Get targeted player index.
	new index = get_param(1);

	if (isPlayerConnected(index) == -1)
	{
		return -1;
	}

	// Get level to be set.
	new level = get_param(2);

	// Log to console and return if level is too high/low.
	if (0 > level > max_level)
	{
		#if defined DEBUG_MODE
		
		log_amx("%s Level value incorrect (%i) [min. %i | max. %i].", NativesLogPrefix, level, 0, max_level);
		
		#endif

		return -1;
	}

	// Set level.
	user_data[index][DATA_LEVEL] = level;

	return 1;
}

public native_get_user_level(plugin, params)
{
	if (!check_params("set_user_level", 1, params))
	{
		return -1;
	}

	// Get targeted player index.
	new index = get_param(1);

	if (isPlayerConnected(index) == -1)
	{
		return -1;
	}

	// Return user level.
	return user_data[index][DATA_LEVEL];
}

public native_set_team_level(plugin, params)
{
	if (!check_params("set_team_level", 3, params))
	{
		return -1;
	}

	new team = get_param(1);

	// Return false if team is invalid.
	if (team < 1 || team > 2)
	{
		return false;
	}

	new level = get_param(2);

	// Return false if level is invalid.
	if (level < 0 || level > sizeof(WeaponsData) - 1)
	{
		return false;
	}

	new bool:include_members = bool:get_param(3);

	tp_data[TP_TEAM_LEVEL][team - 1] = level;

	if (include_members)
	{
		ForTeam(i, team)
		{
			user_data[i][DATA_LEVEL] = level;
		}
	}

	return true;
}

public native_get_team_level(plugin, params)
{
	if (!check_params("get_team_level", 1, params))
	{
		return -1;
	}

	new team = get_param(1);

	// Return -1 if team is invalid.
	if (team < 1 || team > 2)
	{
		return -1;
	}

	return tp_data[TP_TEAM_LEVEL][team - 1];
}

public native_get_user_weapon_kills(plugin, params)
{
	if (!check_params("get_user_weapon_kills", 1, params))
	{
		return -1;
	}

	new index = get_param(1);

	if (isPlayerConnected(index) == -1)
	{
		return -1;
	}

	// Return weapon kills.
	return user_data[index][DATA_WEAPON_KILLS];
}

// Return max level.
public native_get_max_level(plugin, params)
{
	if (!check_params("get_max_level", 1, params))
	{
		return -1;
	}

	return max_level;
}

public native_respawn_player(plugin, params)
{
	if (!check_params("respawn_player", 2, params))
	{
		return -1;
	}

	new index = get_param(1);

	if (isPlayerConnected(index) == -1)
	{
		return -1;
	}

	new Float:time = get_param_f(2);

	// Log to console and return if respawn time is too low.
	if (time < 0.0)
	{
		#if defined DEBUG_MODE
		
		log_amx("%s Respawn time is too low (%f).", time);
		
		#endif

		return -1;
	}

	// Set respawn task.
	respawn_player(index, time);

	return 1;
}

public native_get_user_weapon(plugin, params)
{
	if (!check_params("get_user_weapon", 1, params))
	{
		return -1;
	}

	new index = get_param(1);

	if (isPlayerConnected(index) == -1)
	{
		return -1;
	}

	// Return user current weapon.
	return WeaponsData[user_data[index][DATA_LEVEL]][0];
}

public native_get_weapons_data(plugin, params)
{
	if (!check_params("get_weapons_data", 2, params))
	{
		return -1;
	}

	new index = get_param(1);

	if (isPlayerConnected(index) == -1)
	{
		return -1;
	}

	new value = get_param(2),
		min = 0,
		max = 2;

	// Log to console and return if data index is too high/low.
	if (min > value > max)
	{
		#if defined DEBUG_MODE
		
		log_amx("%s Weapons data array is too %s (%i [Min. %i | Max. %i]).", NativesLogPrefix, 0 > value ? "low" : "high", value, min, max);
		
		#endif

		return -1;
	}

	// Return weapons data.
	return WeaponsData[user_data[index][DATA_LEVEL]][value];
}

public native_get_user_wins(plugin, params)
{
	if (!check_params("get_user_wins", 1, params))
	{
		return -1;
	}

	new index = get_param(1);

	if (isPlayerConnected(index) == -1)
	{
		return -1;
	}

	return user_data[index][DATA_WINS];
}

public native_get_user_combo(plugin, params)
{
	if (!check_params("get_user_combo", 1, params))
	{
		return -1;
	}

	new index = get_param(1);

	if (isPlayerConnected(index) == -1)
	{
		return -1;
	}

	return user_data[index][DATA_COMBO];
}

/*
		[ Forwards & menus & unassigned publics ]
*/

public plugin_end()
{
	ArrayDestroy(disconnected_players_data[DC_DATA_NAME]);
	ArrayDestroy(disconnected_players_data[DC_DATA_LEVEL]);
	ArrayDestroy(disconnected_players_data[DC_DATA_WEAPON_KILLS]);
}

public plugin_precache()
{
	new file_path[MAX_CHARS * 3];

	// Loop through sounds data array and precache sounds.
	ForArray(i, SoundsData)
	{
		ForRange(j, 0, MaxSounds - 1)
		{
			// Continue if currently processed SoundsData cell length is 0.
			if (!strlen(SoundsData[i][j]))
			{
				continue;
			}

			// Add 'sound/' to downloaded file path.
			if (containi(SoundsData[i][j], "sound/") == -1)
			{
				formatex(file_path, charsmax(file_path), "sound/%s", SoundsData[i][j]);
			}

			if (!file_exists(file_path))
			{
				// Log error and continue to next sound file if currently processed file was not found.
				#if defined DEBUG_MODE

				log_amx("Warning: skipping file ^"%s^" precaching ([%i][%i]). File was not found.", SoundsData[i][j], i, j);
				
				#endif

				continue;
			}

			// Precache sound using fakemeta.
			engfunc(EngFunc_PrecacheSound, SoundsData[i][j]);
		}
	}

	// Precache sprite.
	sprite_levelup_index = engfunc(EngFunc_PrecacheModel, SpritesData[SPRITE_LEVEL_UP]);

	// Precache wand models.
	ForArray(i, WandModels)
	{
		engfunc(EngFunc_PrecacheModel, WandModels[i]);
	}

	// Precache wand sprites.
	ForArray(i, WandSprites)
	{
		wand_sprites_indexes[i] = engfunc(EngFunc_PrecacheModel, WandSprites[i]);
	}

	// Precache wand sounds.
	ForArray(i, WandSounds)
	{
		precache_sound(WandSounds[i]);
	}
}

public client_authorized(index)
{
	user_data[index][DATA_WARMUP_WEAPON] = -1;
	user_data[index][DATA_WARMUP_CUSTOM_WEAPON_INDEX] = -1;

	// Do nothing if user is a hltv.
	if (is_user_hltv(index) || is_user_bot(index))
	{
		return;
	}

	// Get name-related data.
	get_user_name_data(index);

	// Load mysql data.
	get_user_data(index);

	// Preset user level to 0.
	user_data[index][DATA_LEVEL] = 0;
	user_data[index][DATA_WEAPON_KILLS] = 0;

	// Reconnected?
	get_on_connect(index);

	// Dont calculate level if gungame has ended or player has reconnected.
	if (gungame_ended || user_data[index][DATA_LEVEL])
	{
		return;
	}

	new lowest_level = get_current_lowest_level(),
		new_level = (lowest_level > 0 ? lowest_level : 0 > half_max_level ? half_max_level : new_level);

	// Set user level to current lowest or half of max level if current lowest is greater than half.
	user_data[index][DATA_LEVEL] = new_level;
	user_data[index][DATA_WEAPON_KILLS] = 0;
}

public client_putinserver(index)
{
	// Respawn player.
	set_task(2.0, "respawn_player_on_join", index + TASK_RESPAWN_ON_JOIN);
	set_task(3.0, "show_game_vote_menu", index);
}

// Remove hud tasks on disconnect.
public client_disconnect(index)
{
	remove_hud(index);
	update_user_data(index);
	save_on_disconnect(index);
}

// Get user's name again when changed.
public client_info_changed(index)
{
	// Update name-related data.
	get_user_name_data(index);
}

public bomb_planting(index)
{
	if (bomb_supported)
	{
		return PLUGIN_CONTINUE;
	}

	return PLUGIN_HANDLED;
}

public bomb_planted(index)
{
	if (!get_pcvar_num(cvars_data[CVAR_BOMB_ENABLED]))
	{
		return;
	}

	static reward;

	reward = get_pcvar_num(cvars_data[CVAR_BOMB_PLANT_REWARD]);

	if (reward <= 0)
	{
		return;
	}
	
	increment_user_level(index, reward);

	static formater[] = "%s^x01 Gracz^x04 %n^x01 podlozyl bombe i otrzymal^x04 %i punkt",
		message[MAX_CHARS * 4];

	formatex(message, charsmax(message), formater, ChatPrefix, index, reward);

	switch(reward)
	{
		case 2..4: add(message, charsmax(message), "y^x01.");
		case 5..21: add(message, charsmax(message), "ow^x01.");
	}

	ColorChat(0, RED, message);
}

public bomb_defused(index)
{
	if (!get_pcvar_num(cvars_data[CVAR_BOMB_ENABLED]))
	{
		return;
	}

	static reward;

	reward = get_pcvar_num(cvars_data[CVAR_BOMB_DEFUSE_REWARD]);

	if (reward <= 0)
	{
		return;
	}

	increment_user_level(index, reward);

	static formater[] =  "%s^x01 Gracz^x04 %n^x01 rozbroil bombe i otrzymal^x04 %i punkt",
		message[MAX_CHARS * 4];

	formatex(message, charsmax(message), formater, ChatPrefix, index, reward);

	switch(reward)
	{
		case 2..4: add(message, charsmax(message), "y^x01.");
		case 5..21: add(message, charsmax(message), "ow^x01.");
	}

	ColorChat(0, RED, message);
}

// Prevent picking up weapons of off the ground.
public on_player_weapon_touch(entity, index)
{
	if (!is_user_connected(index))
	{
		return HAM_IGNORED;
	}

	new bool:is_bomb = bool:(entity == get_bomb_entity());

	if (is_bomb && user_data[index][DATA_ALLOWED_WEAPONS] & (1 << CSW_C4))
	{
		return HAM_IGNORED;
	}

	return HAM_SUPERCEDE;
}

public set_entity_model(entity, model[])
{
	// Return if this model is too short to work with.
	if (strlen(model) < 8)
	{
		return;
	}

	// Clamp down matches a bit.
	if (!equal(model[7], "w_", 2))
	{
		return;
	}

	// Get damage time of grenade.
	static Float:damageTime;
	pev(entity, pev_dmgtime, damageTime);

	// Return if grenade was not yet thrown.
	if (!damageTime)
	{
		return;
	}

	new owner = pev(entity, pev_owner);

	// Return if grenade owner is not present.
	if (!is_user_connected(owner))
	{
		return;
	}
			
	// Set tasks to give grenade back after it has exploded. 
	if (equal(model[9], "he", 2))
	{
		if (WeaponsData[user_data[owner][DATA_LEVEL]][weapon_CSW] == CSW_HEGRENADE || get_pcvar_num(cvars_data[CVAR_WARMUP_WEAPON]) == CSW_HEGRENADE && warmup_data[WARMUP_ENABLED])
		{
			set_task(get_pcvar_float(cvars_data[CVAR_GIVE_BACK_HE_INTERVAL]), "give_he_grenade", owner + TASK_GIVEGRENADE);
		}

		if (HeGrenadeExplodeTime != DefaultExplodeTime)
		{
			set_pev(entity, pev_dmgtime, get_gametime() + HeGrenadeExplodeTime);
		}
	}
	else if (equal(model[9], "fl", 2) && WeaponsData[user_data[owner][DATA_LEVEL]][weapon_CSW] == CSW_KNIFE)
	{
		set_task(get_pcvar_float(cvars_data[CVAR_GIVE_BACK_FLASH_INTERVAL]), "give_flash_grenade", owner + TASK_GIVEGRENADE);
	}
}

public primary_attack(entity)
{
	new index = get_pdata_cbase(entity, 41, 4);

	// Block attacking if gungame has ended.
	if (gungame_ended && is_user_alive(index))
	{
		return HAM_IGNORED;
	}

	// Cooldown on.
	if (user_data[index][DATA_WAND_LAST_ATTACK] + get_pcvar_float(cvars_data[CVAR_WAND_ATTACK_INTERVAL]) > get_gametime())
	{
		return HAM_SUPERCEDE;
	}

	new weapon_index = cs_get_weapon_id(entity);

	// Handle wand attacking.
	wand_attack(index, weapon_index);

	return HAM_IGNORED;
}

public on_dd_item_to_player(index, weapon_entity)
{
	new csw = cs_get_weapon_id(weapon_entity);

	// Skip kevlar.
	if (csw == CSW_VEST || csw == CSW_VESTHELM)
	{
		return HAM_IGNORED;
	}

	// User is allowed to carry that weapon?
	if (user_data[index][DATA_ALLOWED_WEAPONS] & (1 << csw))
	{
		return HAM_IGNORED;
	}

	if (csw == CSW_C4)
	{
		if (!bomb_supported)
		{
			// Disable player's planting ability.
			cs_set_user_plant(index, false, false);

			// Reset body model to get rid of bomb on the back.
			set_pev(index, pev_body, false);

			// Remove bomb from allowed weapons.
			if (user_data[index][DATA_ALLOWED_WEAPONS] & (1 << CSW_C4))
			{
				user_data[index][DATA_ALLOWED_WEAPONS] &= ~(1 << CSW_C4);
			}
		}
	}

	// Kill weapon entity.
	ExecuteHam(Ham_Item_Kill, weapon_entity);

	SetHamReturnInteger(false);

	return HAM_SUPERCEDE;
}

public event_cur_weapon(index)
{
	if (!is_user_connected(index))
	{
		return;
	}

	// todo: cvar here
	if (/*get_pcvar_num(gg_awp_oneshot) &&*/ read_data(2) == CSW_AWP && read_data(3) > 1)
	{
		new weapon_entity = find_ent_by_owner(-1, "weapon_awp", index);

		if (pev_valid(weapon_entity))
		{
			cs_set_weapon_ammo(weapon_entity, 1);
			cs_set_user_bpammo(index, CSW_AWP, 100);
		}
	}
}

public client_PreThink(index)
{
	// Return if player is not alive, is hltv or a bot.
	if (!get_pcvar_num(cvars_data[CVAR_FALL_DAMAGE_ENABLED]) || !is_user_alive(index) || is_user_hltv(index) || is_user_bot(index))
	{
		return;
	}

	// Set falling status based on current velocity.
	user_data[index][DATA_FALLING] = bool:(entity_get_float(index, EV_FL_flFallVelocity) > 350.00);
}

public client_PostThink(index)
{
	// Return if player is not alive, is hltv, is bot or is not falling.
	if (!get_pcvar_num(cvars_data[CVAR_FALL_DAMAGE_ENABLED]) || !is_user_alive(index) || is_user_hltv(index) || is_user_bot(index) || !user_data[index][DATA_FALLING])
	{
		return;
	}

	// Block falldamage.
	entity_set_int(index, EV_INT_watertype, -3);
}

public on_team_assign()
{
	new index = read_data(1);

	user_data[index][DATA_TEAM] = get_user_team(index);

	// Do noting if player already spawned.
	if (is_user_alive(index))
	{
		return;
	}

	// Narrow matches a bit.
	if (0 >= user_data[index][DATA_TEAM] > 2)
	{
		return;
	}

	// Remove respawn task if present.
	if (task_exists(index + TASK_RESPAWN))
	{
		remove_task(index + TASK_RESPAWN);
	}

	// Remove respawn info task if present.
	if (task_exists(index + TASK_NOTIFY))
	{
		remove_task(index + TASK_NOTIFY);
	}

	// Respawn player shortly after joining team.
	set_task(2.0, "respawn_player_on_join", index + TASK_RESPAWN_ON_JOIN);
}

public round_start()
{
	remove_weapons_off_ground();
}

public take_damage(victim, index_inflictor, attacker, Float:damage, damagebits)
{
	if (!is_user_alive(attacker) || victim == attacker || !damage || !is_user_alive(victim))
	{
		return HAM_IGNORED;
	}

	if (gungame_ended)
	{
		return HAM_SUPERCEDE;
	}

	// Block friendly fire on teamplay if set so.
	if (user_data[attacker][DATA_TEAM] == user_data[victim][DATA_TEAM])
	{
		if (game_mode == MODE_NORMAL && !get_pcvar_num(cvars_data[CVAR_NORMAL_FRIENDLY_FIRE]))
		{
			return HAM_SUPERCEDE;
		}
		else if (game_mode == MODE_TEAMPLAY && !get_pcvar_num(cvars_data[CVAR_TEAMPLAY_FRIENDLY_FIRE]))
		{
			return HAM_SUPERCEDE;
		}
	}

	// Prevent from spawn-killing.
	if (user_data[victim][DATA_SPAWN_PROTECTION] && !get_pcvar_num(cvars_data[CVAR_SPAWN_PROTECTION_TYPE]))
	{
		return HAM_SUPERCEDE;
	}

	// https://github.com/Wwicked/Gungame/commit/dbdc57bca81099fc3add150f1de7ed1f19d09759
	// This makes no sense whatsoever.
	//
	// if (get_pcvar_num(cvars_data[CVAR_WAND_ENABLED]))
	// {
	// 	// todo: fix here
	// 	if (is_on_last_level(attacker) /*|| get_pcvar_num(cvars_data[CVAR_WARMUP_WEAPON]) == -2*/)
	// 	{
	// 		return HAM_SUPERCEDE;
	// 	}
	// }

	// Show damage info in hud.
	set_hudmessage(TakeDamageHudColor[0], TakeDamageHudColor[1], TakeDamageHudColor[2], 0.5, 0.4, 0, 6.0, get_pcvar_float(cvars_data[CVAR_TAKE_DAMAGE_HUD_TIME]), 0.0, 0.0);
	ShowSyncHudMsg(attacker, hud_objects[hud_object_damage], "%i^n", floatround(damage, floatround_round));

	return HAM_IGNORED;
}

public he_grenade_think(entity)
{
	// Return if invalid entity or grenade is not HE.
	if (!pev_valid(entity) || !is_he_grenade(entity))
	{
		return;
	}

	// Set on ground flag to he grenade.
	set_pev(entity, pev_flags, FL_ONGROUND);
}

public weapon_deploy(entity)
{
	new index = pev(entity, pev_owner),
		weapon = cs_get_weapon_id(entity);

	if (!is_user_connected(index) || is_user_bot(index) || !is_user_alive(index))
	{
		return;
	}

	user_data[index][DATA_CURRENT_WEAPON] = weapon;

	// Check if player is holding weapon he shouldnt have.
	if (!(user_data[index][DATA_ALLOWED_WEAPONS] & (1 << weapon)))
	{
		// Take away the weapon.
		strip_user_weapon(index, weapon);
		
		return;
	}

	// We dont want to mess with the bomb.
	if (weapon == CSW_C4)
	{
		return;
	}

	if (weapon == CSW_KNIFE)
	{
		// Block if player is not on last level or its not a warmup.
		if (!warmup_data[WARMUP_ENABLED] || user_data[index][DATA_LEVEL] != max_level)
		{
			return;
		}

		// Block if warmup weapon is not a wand.
		if (warmup_data[WARMUP_ENABLED] && get_pcvar_num(cvars_data[CVAR_WARMUP_WEAPON]) != -2)
		{
			return;
		}

		// Block if wands are disabled.
		if (!get_pcvar_num(cvars_data[CVAR_WAND_ENABLED]))
		{
			return;
		}
		
		// Set the wand model.
		set_wand_models(index);
		set_weapon_animation(index, 3);
	}
}

public knife_deploy(entity)
{
	new index = pev(entity, pev_owner);

	// Block if somehow the player is dead.
	if (!is_user_alive(index))
	{
		return;
	}

	// Block if player is not on last level or its not a warmup.
	if (!warmup_data[WARMUP_ENABLED] || user_data[index][DATA_LEVEL] != max_level)
	{
		return;
	}

	// Block if warmup weapon is not a wand.
	if (warmup_data[WARMUP_ENABLED] && get_pcvar_num(cvars_data[CVAR_WARMUP_WEAPON]) != -2)
	{
		return;
	}

	// Block if wands are disabled.
	if (!get_pcvar_num(cvars_data[CVAR_WAND_ENABLED]))
	{
		return;
	}
	
	// Set the wand model.
	set_wand_models(index);
	set_weapon_animation(index, 3);
}

public player_death_event()
{
	new victim = read_data(2);

	// Return if victim is a bot or hltv.
	if (is_user_bot(victim) || is_user_hltv(victim))
	{
		return;
	}

	// Prevent weapon-drop to the floor.
	remove_player_weapons(victim, true);

	if (gungame_ended)
	{
		remove_idle_check(victim);

		return;
	}

	// Respawn player.
	if (warmup_data[WARMUP_ENABLED])
	{
		respawn_player(victim, get_pcvar_float(cvars_data[CVAR_WARUMP_RESPAWN_INTERVAL]));
	}
	else
	{
		respawn_player(victim, get_pcvar_float(cvars_data[CVAR_RESPAWN_INTERVAL]));
	}

	// Remove grenade task if present.
	if (task_exists(victim + TASK_GIVEGRENADE))
	{
		remove_task(victim + TASK_GIVEGRENADE);
	}

	remove_hud(victim);
	
	user_data[victim][DATA_COMBO] = 0;
	user_data[victim][DATA_ALLOWED_WEAPONS] = 0;

	new killer = read_data(1),
		weapon[12];

	read_data(4, weapon, charsmax(weapon));

	// Handle suicide.
	if (killer == victim)
	{
		new old_level;

		switch(game_mode)
		{
			case MODE_NORMAL:
			{
				old_level = user_data[victim][DATA_LEVEL];

				decrement_user_weapon_kills(victim, 1, true);

				if (user_data[victim][DATA_LEVEL] < old_level)
				{
					ColorChat(0, RED, "%s^x01 Gracz^x04 %n^x01 popelnil samobojstwo i spadl do poziomu^x04 %i (%s)^x01.",
						ChatPrefix,
						victim,
						user_data[victim][DATA_LEVEL],
						CustomWeaponNames[user_data[victim][DATA_LEVEL]]);
				}
			}
			
			case MODE_TEAMPLAY:
			{
				old_level = tp_data[TP_TEAM_LEVEL][user_data[victim][DATA_TEAM] - 1];

				decrement_team_weapon_kills(user_data[victim][DATA_TEAM], 1, true);

				if (tp_data[TP_TEAM_LEVEL][user_data[victim][DATA_TEAM] - 1] < old_level)
				{
					ColorChat(0, RED, "%s^x01 Przez samobojstwo gracza^x04 %n^x01 druzyna^x04 %s^x01 spadla do poziomu^x04 %i (%s)^x01.",
						ChatPrefix,
						victim,
						TeamNames[user_data[victim][DATA_TEAM] - 1],
						tp_data[TP_TEAM_LEVEL][user_data[victim][DATA_TEAM] - 1],
						CustomWeaponNames[tp_data[TP_TEAM_LEVEL][user_data[victim][DATA_TEAM] - 1]]);
				}
			}
		}
		
		return;
	}

	// End gungame if user/team has reached max level.
	if (game_mode == MODE_NORMAL && user_data[killer][DATA_LEVEL] == max_level)
	{
		end_gungame(killer);
		
		return;
	}
	else if (game_mode == MODE_TEAMPLAY)
	{
		if (tp_data[TP_TEAM_LEVEL][0] == max_level || tp_data[TP_TEAM_LEVEL][1] == max_level)
		{
			end_gungame(killer);

			return;
		}
	}

	// Handle killing on spawn protection.
	if (get_pcvar_num(cvars_data[CVAR_SPAWN_PROTECTION_TYPE]))
	{
		if (user_data[victim][DATA_SPAWN_PROTECTION])
		{
			// Remove protection task if present.
			if (task_exists(victim + TASK_SPAWNPROTECTION))
			{
				remove_task(victim + TASK_SPAWNPROTECTION);
			}

			// Toggle off respawn protection.
			toggle_spawn_protection(victim, false);

			return;
		}
	}
	
	if (equal(weapon, "knife"))
	{
		// Block leveling up if player is on HE level and killed someone with a knife.
		if (WeaponsData[user_data[killer][DATA_LEVEL]][weapon_CSW] == CSW_HEGRENADE)
		{
			return;
		}
		
		// Update stats.
		user_data[killer][DATA_KNIFE_KILLS]++;

		if (user_data[victim][DATA_LEVEL])
		{
			switch(game_mode)
			{
				case MODE_NORMAL: decrement_user_level(victim, 1);
				case MODE_TEAMPLAY:
				{
					if (get_pcvar_num(cvars_data[CVAR_KNIFE_KILL_LEVEL_DOWN_TEAMPLAY]))
					{
						decrement_team_level(user_data[victim][DATA_TEAM], 1);
					}
				}
			}

			ColorChat(victim, RED, "%s^x01 Zostales zabity z kosy przez^x04 %n^x01. %s spadl do^x04 %i^x01.",
				ChatPrefix,
				killer,
				game_mode == MODE_NORMAL ? "Twoj poziom" : "Poziom Twojej druzyny",
				tp_data[TP_TEAM_LEVEL][user_data[victim][DATA_TEAM]]);
		}

		// Handle instant-level-up when killing with knife.
		if (get_pcvar_num(cvars_data[CVAR_KNIFE_KILL_INSTANT_LEVELUP]))
		{
			switch(game_mode)
			{
				case MODE_NORMAL: increment_user_level(killer, get_pcvar_num(cvars_data[CVAR_KNIFE_KILL_REWARD]));
				case MODE_TEAMPLAY: increment_team_level(user_data[killer][DATA_TEAM], get_pcvar_num(cvars_data[CVAR_KNIFE_KILL_REWARD]));
			}
		}
		else
		{
			switch(game_mode)
			{
				case MODE_NORMAL: increment_user_weapon_kills(killer, get_pcvar_num(cvars_data[CVAR_KNIFE_KILL_REWARD]));
				case MODE_TEAMPLAY: increment_team_weapon_kills(user_data[killer][DATA_TEAM], get_pcvar_num(cvars_data[CVAR_KNIFE_KILL_REWARD]));
			}
		}
	}
	else
	{
		switch(game_mode)
		{
			case MODE_NORMAL: increment_user_weapon_kills(killer, 1);
			case MODE_TEAMPLAY: increment_team_weapon_kills(user_data[killer][DATA_TEAM], 1);
		}

		// Notify about killer's health left.
		ColorChat(victim, RED, "%s^x01 Zabity przez^x04 %n^x01 (^x04%i^x01 HP)", ChatPrefix, killer, get_user_health(killer));
	}

	// Update stats.
	if (read_data(3))
	{
		user_data[killer][DATA_HEADSHOTS]++;
	}
	
	user_data[killer][DATA_KILLS]++;

	// Handle ammo refill.
	switch(game_mode)
	{
		case MODE_NORMAL:
		{
			// Refill type.
			switch(get_pcvar_num(cvars_data[CVAR_REFILL_WEAPON_AMMO]))
			{
				case 1:
				{
					refill_ammo(killer);
				}
				
				// Vips only.
				case 2:
				{
					if (gg_get_user_vip(killer))
					{
						refill_ammo(killer);
					}
				}
			}
		}

		case MODE_TEAMPLAY:
		{
			// Refill type.
			switch (get_pcvar_num(cvars_data[CVAR_REFILL_WEAPON_AMMO_TEAMPLAY]))
			{
				// Whole team.
				case 1:
				{
					refill_ammo(user_data[killer][DATA_TEAM], true);
				}
				
				// Just the killer.
				case 2:
				{
					refill_ammo(killer);
				}

				// Vips only.
				case 3:
				{
					if (gg_get_user_vip(killer))
					{
						refill_ammo(killer);
					}
				}
			}
		}
	}
}

public player_spawned(index)
{
	// Return if gungame has ended or player isnt alive.
	if (!is_user_alive(index) || gungame_ended)
	{
		return;
	}

	if (warmup_data[WARMUP_ENABLED])
	{
		// Give weapons to player.
		give_warmup_weapons(index);

		set_user_health(index, get_pcvar_num(cvars_data[CVAR_WARMUP_HEALTH]));
	}
	else
	{
		// Enable hud.
		show_hud(index);

		// Give weapons to player.
		give_weapons(index);

		// Enbale spawn protection.
		toggle_spawn_protection(index, true);

		// Set task to disable spawn protection.
		set_task(get_pcvar_float(cvars_data[CVAR_SPAWN_PROTECTION_TIME]), "spawn_protection_off", index + TASK_SPAWNPROTECTION);

		// Set task to chcek if player is AFK.
		set_task(get_pcvar_float(cvars_data[CVAR_IDLE_CHECK_INTERVAL]), "check_idle", index + TASK_IDLECHECK, .flags = "b");

		ExecuteForward(forward_handles[FORWARD_PLAYER_SPAWNED], blank, index);
	}

	if (get_pcvar_num(cvars_data[CVAR_MONEY]))
	{
		set_task(0.4, "task_hide_money", index + TASK_MONEY);
	}
}

public say_handle(message_index, message_dest, message_ent)
{
	new index = get_msg_arg_int(1);

	// Return if sender is not connected anymore.
	if (!is_user_connected(index))
	{
		return PLUGIN_CONTINUE;
	}

	new chat_string[2][192],
		weapon_name[33];

	// Get message arguments.
	get_msg_arg_string(2, chat_string[0], charsmax(chat_string[]));

	// Replace "knife" with "wand".
	formatex(weapon_name, charsmax(weapon_name), (user_data[index][DATA_LEVEL] == max_level && get_pcvar_num(cvars_data[CVAR_WAND_ENABLED])) ? "Rozdzka" : CustomWeaponNames[user_data[index][DATA_LEVEL]]);

	if (equal(chat_string[0], "#Cstrike_Chat_All"))
	{
		// Get message arguments.
		get_msg_arg_string(4, chat_string[0], charsmax(chat_string[]));
		
		// Set argument to empty string.
		set_msg_arg_string(4, "");

		// Format new message to be sent.
		if (game_mode == MODE_NORMAL)
		{
			formatex(chat_string[1], charsmax(chat_string[]), "^x04[%i Lvl (%s)]^x03 %n^x01 :  %s", user_data[index][DATA_LEVEL] + 1, weapon_name, index, chat_string[0]);
		}
		else
		{
			formatex(chat_string[1], charsmax(chat_string[]), "^x04[%s]^x03 %n^x01 :  %s", weapon_name, index, chat_string[0]);
		}
	}
	else // Format new message to be sent.
	{
		if (game_mode == MODE_NORMAL)
		{
			formatex(chat_string[1], charsmax(chat_string[]), "^x04[%i Lvl (%s)]^x01 %s", user_data[index][DATA_LEVEL] + 1, weapon_name, chat_string[0]);
		}
		else
		{
			formatex(chat_string[1], charsmax(chat_string[]), "^x04[%s]^x01 %s", weapon_name, chat_string[0]);
		}
	}

	// Send new message.
	set_msg_arg_string(2, chat_string[1]);

	return PLUGIN_CONTINUE;
}

public say_custom_command_handle(index)
{
	new message[MAX_CHARS],
		command[MAX_CHARS];

	// Remove quotes from message.
	get_chat_message_arguments(message, charsmax(message));
	
	// Retrieve command from message.
	get_first_argument(command, charsmax(command), message, charsmax(message));

	// Show player info if commands are matching.
	if (containi(command, LookupCommand) > -1)
	{
		show_player_info(index, get_player_by_name(message));
	}

	return PLUGIN_CONTINUE;
}

public text_grenade_message(msgid, dest, index)
{
	// Return if text is not the one we are looking for.
	if (get_msg_args() != 5 || get_msg_argtype(5) != ARG_STRING)
	{
		return PLUGIN_CONTINUE;
	}

	static argument_text[MAX_CHARS - 1];

	// Get message argument.
	get_msg_arg_string(5, argument_text, charsmax(argument_text));

	// Return if it is not the one we are looking for.
	if (!equal(argument_text, "#Fire_in_the_hole"))
	{
		return PLUGIN_CONTINUE;
	}

	// Get message argument.
	get_msg_arg_string(2, argument_text, charsmax(argument_text));

	// Return if player is not alive.
	if (!is_user_alive(str_to_num(argument_text)))
	{
		return PLUGIN_CONTINUE;
	}

	// Block message.
	return PLUGIN_HANDLED;
}

public audio_grenade_message()
{
	// Return if this sound is not the one we are interesed in.
	if (get_msg_args() != 3 || get_msg_argtype(2) != ARG_STRING)
	{
		return PLUGIN_CONTINUE;
	}

	new argument_text[MAX_CHARS - 10];

	// Get message arguments.
	get_msg_arg_string(2, argument_text, charsmax(argument_text));

	// Return if it is not the one we are looking for.
	if (!equal(argument_text[1], "!MRAD_FIREINHOLE"))
	{
		return PLUGIN_CONTINUE;
	}

	// Block sending audio message.
	return PLUGIN_HANDLED;
}

public task_hide_money(task_index)
{
	new index = task_index - TASK_MONEY;

	if (!is_user_connected(index))
	{
		return;
	}

	const MoneyBitsum = (1 << 5);

	// Hide money
	message_begin(MSG_ONE, message_hide_weapon, _, index);
	write_byte(MoneyBitsum);
	message_end();
	
	// Hide the HL crosshair that's drawn
	message_begin(MSG_ONE, message_hide_crosshair, _, index);
	write_byte(0);
	message_end();
}

public display_warmup_timer()
{
	// Return if warmup has ended.
	if (!warmup_data[WARMUP_ENABLED])
	{
		return;
	}

	// Decrement warmup timer.
	warmup_data[WARMUP_TIMER]--;

	if (warmup_data[WARMUP_TIMER] >= 0)
	{
		// Play timer tick sound.
		play_sound(0, SOUND_TIMER_TICK, -1);

		// Get warmup weapon name index if not done so yet.
		if (warmup_data[WARMUP_WEAPON_NAME_INDEX] == -1)
		{
			get_warmup_weapon_name();
		}
		
		// Display warmup hud.
		set_hudmessage(WarmupHudColors[0], WarmupHudColors[1], WarmupHudColors[2], -1.0, 0.1, 0, 6.0, 0.6, 0.2, 0.2);
		
		if (get_pcvar_num(cvars_data[CVAR_WARMUP_WEAPON]) == -3)
		{
			ForPlayers(i)
			{
				if (!is_user_alive(i) || is_user_hltv(i) || is_user_bot(i) || user_data[i][DATA_WARMUP_WEAPON] == -1)
				{
					continue;
				}

				ShowSyncHudMsg(i, hud_objects[hud_object_warmup],
					"[ ROZGRZEWKA: %i sekund ]^n[ Bron na rozgrzewke: %s ]",
					warmup_data[WARMUP_TIMER],
					CustomWeaponNames[user_data[i][DATA_WARMUP_CUSTOM_WEAPON_INDEX]]);
			}
		}
		else
		{
			new weapon_name[MAX_CHARS];

			// Warmup weapon is a wand?
			if (get_pcvar_num(cvars_data[CVAR_WARMUP_WEAPON]) == -2)
			{
				formatex(weapon_name, charsmax(weapon_name), "Rozdzki");
			}
			else
			{
				if (get_pcvar_num(cvars_data[CVAR_WARMUP_WEAPON]) == -1)
				{
					copy(weapon_name, charsmax(weapon_name), CustomWeaponNames[warmup_data[WARMUP_WEAPON_INDEX]]);
				}
				else
				{
					copy(weapon_name, charsmax(weapon_name), CustomWeaponNames[warmup_data[WARMUP_WEAPON_NAME_INDEX]]);
				}
			}

			ShowSyncHudMsg(0, hud_objects[hud_object_warmup],
				"[ ROZGRZEWKA: %i sekund ]^n[ Bron na rozgrzewke: %s ]",
				warmup_data[WARMUP_TIMER],
				weapon_name);
		}

		// Set task to display hud again.
		set_task(1.2, "display_warmup_timer");
	}
	else // Disable warmup if timer is less than 0.
	{
		toggle_warmup(false);
	}
}

public list_weapons_menu(index)
{
	// Create menu handler.
	new menu_index = menu_create("Lista broni:^n[Bron ^t-^tpoziom  ^t-^t ilosc wymaganych zabojstw]", "listWeaponsMenu_handler"),
		menu_item[MAX_CHARS * 3],
		weapon_name[MAX_CHARS];

	ForArray(i, WeaponsData)
	{
		if (i == max_level && get_pcvar_num(cvars_data[CVAR_WAND_ENABLED]))
		{
			formatex(weapon_name, charsmax(weapon_name), "Rozdzka");
		}
		else
		{
			copy(weapon_name, charsmax(weapon_name), CustomWeaponNames[i]);
		}

		formatex(menu_item, charsmax(menu_item), "[%s - %i lv. - %i (%i)]", weapon_name, i + 1, WeaponsData[i][weapon_kills], WeaponsData[i][weapon_team_kills]);

		// Add item to menu.
		menu_additem(menu_index, menu_item);
	}

	// Display menu to player.
	menu_display(index, menu_index);

	return PLUGIN_CONTINUE;
}

public listWeaponsMenu_handler(id, menu, item)
{
	// Destroy menu.
	menu_destroy(menu);

	return PLUGIN_CONTINUE;
}

public top_players_motd_handler(index)
{
	if (!is_user_connected(index))
	{
		return PLUGIN_HANDLED;
	}

	// Return if top players data was not loaded yet.
	if (!top_data[TOP_DATA_LOADED])
	{
		ColorChat(index, RED, "%s^x01 Topka nie zostala jeszcze zaladowana.", ChatPrefix);

		return PLUGIN_CONTINUE;
	}

	// Create top players motd if this is the first time someone has used command on this map.
	if (!top_data[TOP_MOTD_CREATED])
	{
		create_top_players_motd();
	}

	// Display motd.
	show_motd(index, top_data[TOP_MOTD_CODE], top_data[TOP_MOTD_NAME]);

	return PLUGIN_CONTINUE;
}

/*
		[ TASKS ]
*/

public delayed_toggle_warmup()
{
	toggle_warmup(true);
}

public reward_warmup_winner(task_index)
{
	new winner = task_index - TASK_REWARDWINNER;

	// Return if user is not connected or his level is somehow incorrect. 
	if (!is_user_connected(winner) || user_data[winner][DATA_LEVEL] >= get_pcvar_num(cvars_data[CVAR_WARMUP_LEVEL_REWARD]))
	{
		return;
	}

	// For regular players add VIP for this map, for VIPs add 3 levels.
	if (gg_get_user_vip(winner))
	{
		increment_user_level(winner, get_pcvar_num(cvars_data[CVAR_WARMUP_LEVEL_REWARD]) - user_data[winner][DATA_LEVEL] - 1, false);
	}
	else
	{
		gg_set_user_vip(winner, true);
	}
}

public give_he_grenade(task_index)
{
	new index = task_index - TASK_GIVEGRENADE;

	// Return if player is not alive or this type of grenade is none of his weapons.
	if (!is_user_alive(index) || !warmup_data[WARMUP_ENABLED] && WeaponsData[user_data[index][DATA_LEVEL]][weapon_CSW] != CSW_HEGRENADE || warmup_data[WARMUP_ENABLED] && warmup_data[WARMUP_WEAPON_INDEX] == CSW_HEGRENADE)
	{
		return;
	}

	// Add grenade.
	give_item(index, "weapon_hegrenade");
}

public give_flash_grenade(task_index)
{
	new index = task_index - TASK_GIVEGRENADE;

	// Return if player is not alive or flash grenade is none of his allowed weapons.
	if (!is_user_alive(index) || WeaponsData[user_data[index][DATA_LEVEL]][weapon_CSW] != CSW_KNIFE)
	{
		return;
	}

	// Add grenade.
	give_item(index, "weapon_flashbang");
}

public spawn_protection_off(task_index)
{
	new index = task_index - TASK_SPAWNPROTECTION;

	// Return if player is not alive.
	if (!is_user_alive(index))
	{
		return;
	}

	// Disable spawn protection.
	toggle_spawn_protection(index, false);
}

public check_idle(task_index)
{
	new index = task_index - TASK_IDLECHECK;

	// Return if player is not alive.
	if (!is_user_alive(index))
	{
		return;
	}

	new current_origin[3];

	// Get user position.
	get_user_origin(index, current_origin);

	if (!user_data[index][DATA_LAST_ORIGIN][0] && !user_data[index][DATA_LAST_ORIGIN][1] && !user_data[index][DATA_LAST_ORIGIN][2])
	{
		// Handle position update.
		ForRange(i, 0, 2)
		{
			user_data[index][DATA_LAST_ORIGIN][i] = current_origin[i];
		}

		return;
	}

	// Get distance from last position to current position.
	new last_origin[3];
	copy(last_origin, sizeof(last_origin), user_data[index][DATA_LAST_ORIGIN]); // Workaround with const argument in get_distance.

	new distance = get_distance(last_origin, current_origin);

	// Handle position update.
	ForRange(i, 0, 2)
	{
		user_data[index][DATA_LAST_ORIGIN][i] = current_origin[i];
	}

	if (distance < get_pcvar_num(cvars_data[CVAR_IDLE_MAX_DISTANCE]))
	{
		// Slap player if he's camping, make sure not to kill him.
		if (++user_data[index][DATA_IDLE_STRIKES] >= get_pcvar_num(cvars_data[CVAR_IDLE_MAX_STRIKES]))
		{
			ForRange(i, 0, 1)
			{
				user_slap(index, !i ? (get_user_health(index) > get_pcvar_num(cvars_data[CVAR_IDLE_SLAP_POWER]) ? get_pcvar_num(cvars_data[CVAR_IDLE_SLAP_POWER]) : 0) : 0);
			}
		}
	}
	else
	{
		// Set user strikes back to 0.
		user_data[index][DATA_IDLE_STRIKES] = 0;
		
		// Set user last position to 0.
		ForRange(i, 0, 2)
		{
			user_data[index][DATA_LAST_ORIGIN][i] = 0;
		}
	}
}

public client_respawn(task_index)
{
	new index = task_index - TASK_RESPAWN;

	// Return if player is not connected anymore.
	if (!is_user_connected(index))
	{
		return;
	}

	// Execute spawn forward on this player.
	ExecuteHamB(Ham_CS_RoundRespawn, index);
}

public respawn_notify(task_index)
{
	new index = task_index - TASK_NOTIFY;

	// Return if player not connected or gungame has ended.
	if (!is_user_connected(index) || gungame_ended)
	{
		return;
	}

	// Remove tasks if they exists somehow.
	if (is_user_alive(index))
	{
		if (task_exists(index + TASK_RESPAWN))
		{
			remove_task(index + TASK_RESPAWN);
		}

		if (task_exists(index + TASK_NOTIFY))
		{
			remove_task(index + TASK_NOTIFY);
		}

		return;
	}

	// Print respawn-time info.
	client_print(index, print_center, "Odrodzenie za: %i", user_data[index][DATA_TIME_TO_RESPAWN]);

	// Decrease respawn time.
	user_data[index][DATA_TIME_TO_RESPAWN]--;
}

public display_hud(task_index)
{
	new index = task_index - TASK_DISPLAYHUD;

	if (!is_user_alive(index))
	{
		return;
	}

	new leader_counter,
		leader = get_game_leader(leader_counter),
		leader_data[MAX_CHARS * 5],
		next_weapon[25];

	// Format leader's data if available.
	if (leader == -1)
	{
		formatex(leader_data, charsmax(leader_data), "^nLider: Remis");
	}
	else
	{
		if (game_mode == MODE_NORMAL)
		{
			static leader_name[MAX_CHARS * 2];

			if (leader_counter > 1)
			{
				formatex(leader_name, charsmax(leader_name), "%n + %i innych", leader, leader_counter - 1);
			}
			else
			{
				copy(leader_name, charsmax(leader_name), fmt("%n", leader));
			}

			formatex(leader_data, charsmax(leader_data), "^nLider: %s :: %i poziom [%s - %i/%i]",
					leader_name,
					user_data[leader][DATA_LEVEL] + 1,
					user_data[leader][DATA_LEVEL] == max_level ? (get_pcvar_num(cvars_data[CVAR_WAND_ENABLED]) ? "Rozdzka" : CustomWeaponNames[user_data[leader][DATA_LEVEL]]) : CustomWeaponNames[user_data[leader][DATA_LEVEL]],
					user_data[leader][DATA_WEAPON_KILLS],
					WeaponsData[user_data[leader][DATA_LEVEL]][weapon_kills]);
		}
		else
		{
			formatex(leader_data, charsmax(leader_data), "^nLider: %s :: %i poziom [%s - %i/%i]",
					TeamNames[leader],
					tp_data[TP_TEAM_LEVEL][leader] + 1,
					tp_data[TP_TEAM_LEVEL][leader] == max_level ? (get_pcvar_num(cvars_data[CVAR_WAND_ENABLED]) ? "Rozdzka" : CustomWeaponNames[tp_data[TP_TEAM_LEVEL][leader]]) : CustomWeaponNames[tp_data[TP_TEAM_LEVEL][leader]],
					tp_data[TP_TEAM_KILLS][leader],
					WeaponsData[tp_data[TP_TEAM_LEVEL][leader]][weapon_team_kills]);
		}
	}

	// Format next weapon name if available, change knife to wand if enabled so.
	if (user_data[index][DATA_LEVEL] == sizeof(WeaponsData) - 2)
	{
		formatex(next_weapon, charsmax(next_weapon), get_pcvar_num(cvars_data[CVAR_WAND_ENABLED]) ? "Rozdzka" : CustomWeaponNames[user_data[index][DATA_LEVEL] + 1]);
	}
	else
	{
		formatex(next_weapon, charsmax(next_weapon), is_on_last_level(index) ? "Brak" : CustomWeaponNames[user_data[index][DATA_LEVEL] + 1]);
	}

	// Display hud.
	set_hudmessage(HudColors[0], HudColors[1], HudColors[2], -1.0, 0.02, 0, 6.0, HudDisplayInterval + 0.1, 0.0, 0.0);
	
	if (game_mode == MODE_NORMAL)
	{
		ShowSyncHudMsg(index, hud_objects[hud_object_default],
			"-- Tryb normalny --^nTwoj poziom: %i/%i [%s - %i/%i] :: Zabic z rzedu: %i^nNastepna bron: %s%s",
			user_data[index][DATA_LEVEL] + 1,
			sizeof(WeaponsData),
			is_on_last_level(index) ? (get_pcvar_num(cvars_data[CVAR_WAND_ENABLED]) ? "Rozdzka" : CustomWeaponNames[user_data[leader][DATA_LEVEL]]) : CustomWeaponNames[user_data[index][DATA_LEVEL]],
			user_data[index][DATA_WEAPON_KILLS],
			WeaponsData[user_data[index][DATA_LEVEL]][weapon_kills],
			user_data[index][DATA_COMBO],
			next_weapon,
			leader_data);
	}
	else
	{
		new team = user_data[index][DATA_TEAM] - 1;

		ShowSyncHudMsg(index, hud_objects[hud_object_default],
			"-- Tryb teamplay --^nPoziom druzyny: %i/%i [%s - %i/%i]^nNastepna bron: %s%s",
			tp_data[TP_TEAM_LEVEL][team] + 1,
			sizeof(WeaponsData),
			is_on_last_level(index) ? (get_pcvar_num(cvars_data[CVAR_WAND_ENABLED]) ? "Rozdzka" : CustomWeaponNames[user_data[leader][DATA_LEVEL]]) : CustomWeaponNames[user_data[index][DATA_LEVEL]],
			tp_data[TP_TEAM_KILLS][team],
			WeaponsData[user_data[index][DATA_LEVEL]][weapon_team_kills],
			next_weapon,
			leader_data);
	}
}

// Respawn player.
public respawn_player_on_join(task_index)
{
	new index = task_index - TASK_RESPAWN_ON_JOIN;

	respawn_player(index, 0.1);
}

/*
		[ Database ]
*/

connect_database()
{
	new mysql_request[MAX_CHARS * 10];

	// Create mysql tuple.
	db_data[SQL_HANDLE] = SQL_MakeDbTuple(db_data[DB_HOST], db_data[DB_USER], db_data[DB_PASS], db_data[DB_DBASE]);

	// Format mysql request.
	formatex(mysql_request, charsmax(mysql_request),
		"CREATE TABLE IF NOT EXISTS `gungame` \
			(`name` VARCHAR(35) NOT NULL, \
			`wins` INT NOT NULL DEFAULT 0, \
			`knife_kills` INT NOT NULL DEFAULT 0, \
			`kills` INT NOT NULL DEFAULT 0, \
			`headshot_kills` INT NOT NULL DEFAULT 0, \
		PRIMARY KEY (`name`));");

	// Send request to database.
	SQL_ThreadQuery(db_data[SQL_HANDLE], "connect_database_handler", mysql_request);
}

public connect_database_handler(fail_state, Handle:query, error[], error_code, data[], data_size)
{
	// Connection has succeded?
	db_data[SQL_LOADED] = bool:(fail_state == TQUERY_SUCCESS);

	// Throw log to server's console if error occured.
	if (!db_data[SQL_LOADED])
	{
		log_amx("Database connection status: Not connected. Error (%i): %s", error_code, error);
	}

	return PLUGIN_CONTINUE;
}

get_user_data(index)
{
	if (is_user_hltv(index) || is_user_bot(index))
	{
		return;
	}

	new mysql_request[MAX_CHARS * 3],
		data[2];

	data[0] = index;

	// Format mysql request.
	formatex(mysql_request, charsmax(mysql_request), "SELECT * FROM `gungame` WHERE `name` = '%s';", user_data[index][DATA_SAFE_NAME]);

	// Send request to database.
	SQL_ThreadQuery(db_data[SQL_HANDLE], "get_user_info_data_handler", mysql_request, data, charsmax(data));
}

// Read user wins from database.
public get_user_info_data_handler(fail_state, Handle:query, error[], error_code, data[], data_size)
{
	new index = data[0];

	if (SQL_NumRows(query))
	{
		user_data[index][DATA_WINS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "wins"));
		user_data[index][DATA_KNIFE_KILLS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "knife_kills"));
		user_data[index][DATA_HEADSHOTS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "headshot_kills"));
		user_data[index][DATA_KILLS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "kills"));
	}
	else
	{
		insert_user_data(index);
	}
}

insert_user_data(index)
{
	if (is_user_hltv(index) || is_user_bot(index))
	{
		return;
	}

	new mysql_request[MAX_CHARS * 10];

	// Format request.
	formatex(mysql_request, charsmax(mysql_request),
		"INSERT INTO `gungame` \
			(`name`, `wins`, `knife_kills`, `kills`, `headshot_kills`) \
		VALUES \
			('%s', %i, %i, %i, %i);", user_data[index][DATA_SAFE_NAME], user_data[index][DATA_WINS], user_data[index][DATA_KNIFE_KILLS], user_data[index][DATA_KILLS], user_data[index][DATA_HEADSHOTS]);

	// Send request.
	SQL_ThreadQuery(db_data[SQL_HANDLE], "ignore_handle", mysql_request);
}

update_user_data(index)
{
	if (!is_user_connected(index) || is_user_hltv(index) || is_user_bot(index))
	{
		return;
	}

	new mysql_request[MAX_CHARS * 10];

	// Format mysql request.
	formatex(mysql_request, charsmax(mysql_request),
		"UPDATE `gungame` SET \
			`name` = '%s',\
			`wins` = %i,\
			`knife_kills` = %i,\
			`kills` = %i,\
			`headshot_kills` = %i \
		WHERE \
			`name` = '%s';", user_data[index][DATA_SAFE_NAME], user_data[index][DATA_WINS], user_data[index][DATA_KNIFE_KILLS], user_data[index][DATA_KILLS], user_data[index][DATA_HEADSHOTS], user_data[index][DATA_SAFE_NAME]);

	// Send request.
	SQL_ThreadQuery(db_data[SQL_HANDLE], "ignore_handle", mysql_request);
}

// Pretty much ignore any data that database sends back.
public ignore_handle(fail_state, Handle:query, error[], error_code, data[], data_size)
{
	return PLUGIN_CONTINUE;
}

load_top_players()
{
	new mysql_request[MAX_CHARS * 3];

	// Format mysql request.
	formatex(mysql_request, charsmax(mysql_request), "SELECT * FROM `gungame` ORDER BY `wins` DESC LIMIT %i;", TopPlayersDisplayed + 1);

	// Send request to database.
	SQL_ThreadQuery(db_data[SQL_HANDLE], "load_top_players_handler", mysql_request);
}

public load_top_players_handler(fail_state, Handle:query, error[], error_code, data[], data_size)
{
	new iterator;

	// Load top players while there are any.
	while (SQL_MoreResults(query))
	{
		// Get top player name.
		SQL_ReadResult(query, SQL_FieldNameToNum(query, "name"), top_players[iterator][TOP_NAMES], MAX_CHARS - 1);
		
		// Assign his info to variables.
		top_players[iterator][TOP_WINS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "wins"));
		top_players[iterator][TOP_KNIFE_KILLS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "knife_kills"));
		top_players[iterator][TOP_HEADSHOTS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "headshot_kills"));
		top_players[iterator][TOP_KILLS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "kills"));

		// Iterate loop.
		iterator++;

		// Go to next result.
		SQL_NextRow(query);
	}

	// Database laoded successfully.
	top_data[TOP_DATA_LOADED] = true;

	// Create motd.
	create_top_players_motd();
}

/*
		[ FUNCTIONS ]
*/

bool:check_params(native_name[], required, given)
{
	if (required != given)
	{
		#if defined DEBUG_MODE

		log_amx("[NATIVE ERROR] Native ^"%s^" was given invalid amount of paramaters: %i, expected %i.", native_name, given, required);
		
		#endif

		return false;
	}

	return true;
}

set_progress_bar(index, Float:time, start = 0)
{
	static barMessageHandle;
	
	if (!barMessageHandle)
	{
		barMessageHandle = get_user_msgid("BarTime2");
	}
	
	message_begin(index ? MSG_ONE : MSG_ALL, barMessageHandle, _, index);
	write_short(floatround(time));
	write_short(start);
	message_end();
}

save_on_disconnect(index)
{
	ArrayPushCell(disconnected_players_data[DC_DATA_LEVEL], user_data[index][DATA_LEVEL]);
	ArrayPushCell(disconnected_players_data[DC_DATA_WEAPON_KILLS], user_data[index][DATA_WEAPON_KILLS]);
	ArrayPushString(disconnected_players_data[DC_DATA_NAME], fmt("%n", index));
}

get_on_connect(index)
{
	static name[MAX_CHARS];

	ForDynamicArray(i, disconnected_players_data[DC_DATA_NAME])
	{
		ArrayGetString(disconnected_players_data[DC_DATA_NAME], i, name, charsmax(name));

		// Not our guy.
		if (!equal(name, fmt("%n", index)))
		{
			continue;
		}

		// Set new level and weapon kills.
		user_data[index][DATA_LEVEL] = ArrayGetCell(disconnected_players_data[DC_DATA_LEVEL], i);
		user_data[index][DATA_WEAPON_KILLS] = ArrayGetCell(disconnected_players_data[DC_DATA_WEAPON_KILLS], i);

		// Delete data from dynamic arrays.
		ArrayDeleteItem(disconnected_players_data[DC_DATA_LEVEL], i);
		ArrayDeleteItem(disconnected_players_data[DC_DATA_WEAPON_KILLS], i);
		ArrayDeleteItem(disconnected_players_data[DC_DATA_NAME], i);

		break;
	}
}

get_user_name_data(index)
{
	if (is_user_hltv(index) || is_user_bot(index))
	{
		return;
	}

	// Clamp down player's name so we can use that to prevent char-overflow in HUD etc.
	clamp_down_client_name(index, user_data[index][DATA_SHORT_NAME], MAX_CHARS - 1, MaxNicknameLength, NicknameReplaceToken);

	// Get player's name to mysql-request-safe state.
	escape_string(fmt("%n", index), user_data[index][DATA_SAFE_NAME], MAX_CHARS * 2);
}

escape_string(const source[], output[], length)
{
	copy(output, length, source);

	replace_all(output, length, "\\", "\\\\");
	replace_all(output, length, "\0", "\\0");
	replace_all(output, length, "\n", "\\n");
	replace_all(output, length, "\r", "\\r");
	replace_all(output, length, "\x1a", "\Z");
	replace_all(output, length, "'", "\'");
	replace_all(output, length, "`", "\`");
	replace_all(output, length, "^"", "\^"");
}

load_sql_config()
{
	static const SqlConfigPath[] = "addons/amxmodx/configs/gg_sql.cfg";

	static const SqlConfigLabels[][] =
	{
		"gg_sql_host",
		"gg_sql_user",
		"gg_sql_pass",
		"gg_sql_db"
	};

	if (!file_exists(SqlConfigPath))
	{
		db_data[SQL_CONFIG_FOUND] = false;

		return;
	}

	new file_handle = fopen(SqlConfigPath, "r"),
		line_content[MAX_CHARS * 10],
		key[MAX_CHARS * 5],
		value[MAX_CHARS * 5],
		entries;

	while (file_handle && !feof(file_handle) && entries < sizeof(SqlConfigLabels))
	{
		// Read one line at a time.
		fgets(file_handle, line_content, charsmax(line_content));
		
		// Replace newlines with a null character.
		replace(line_content, charsmax(line_content), "^n", "");
		
		// Blank line or comment.
		if (!line_content[0] || line_content[0] == ';')
		{
			continue;
		}
		
		// Get key and value.
		strtok(line_content, key, charsmax(key), value, charsmax(value), '=');
		
		// Trim spaces.
		trim(key);
		trim(value);

		remove_quotes(value);

		ForArray(i, SqlConfigLabels)
		{
			if (!equal(key, SqlConfigLabels[i]))
			{
				continue;
			}

			switch(entries)
			{
				case 0: copy(db_data[DB_HOST], MAX_CHARS * 2, value);
				case 1: copy(db_data[DB_USER], MAX_CHARS * 2, value);
				case 2: copy(db_data[DB_PASS], MAX_CHARS * 2, value);
				case 3: copy(db_data[DB_DBASE], MAX_CHARS * 2, value);
			}

			entries++;
		
			break;
		}
	}

	db_data[SQL_CONFIG_FOUND] = true;
}

load_maps_info()
{
	static const FilePath[] = "addons/amxmodx/configs/gg_bomb_maps.ini";

	bomb_supported = false;

	if (!file_exists(FilePath))
	{
		return;
	}
	
	new file_handle = fopen(FilePath, "r"),
		line_content[MAX_CHARS * 3],
		current_map_name[MAX_CHARS];
	
	get_mapname(current_map_name, charsmax(current_map_name));

	while (file_handle && !feof(file_handle))
	{
		// Read one line at a time.
		fgets(file_handle, line_content, charsmax(line_content));
		
		// Replace newlines with a null character.
		replace(line_content, charsmax(line_content), "^n", "");
		
		// Blank line or comment.
		if (!line_content[0] || line_content[0] == ';')
		{
			continue;
		}
		
		// Trim spaces.
		trim(line_content);

		remove_quotes(line_content);

		if (!equal(line_content, current_map_name))
		{
			continue;
		}

		bomb_supported = true;

		break;
	}
}

load_game_cvars()
{
	ForArray(i, GameCvars)
	{
		set_cvar_num(GameCvars[i][0], str_to_num(GameCvars[i][1]));
	}
}

bool:is_on_last_level(index)
{
	return bool:(user_data[index][DATA_LEVEL] == max_level);
}

// To be used in natives only.
isPlayerConnected(index)
{
	// Throw error and return error value if player is not connected.
	if (!is_user_connected(index))
	{
		#if defined DEBUG_MODE
		
		log_amx("%s Player is not connected (%i).", NativesLogPrefix, index);
		
		#endif

		return -1;
	}

	return 1;
}

create_top_players_motd()
{
	new players_displayed;

	// Add HTML code to string in a loop.
	ForArray(i, TopPlayersMotdHTML)
	{
		top_data[TOP_MOTD_LENGTH] += formatex(top_data[TOP_MOTD_CODE][top_data[TOP_MOTD_LENGTH]], charsmax(top_data[TOP_MOTD_CODE]), TopPlayersMotdHTML[i]);
	}

	ForRange(i, 0, TopPlayersDisplayed - 1)
	{
		// Continue if player has no wins at all.
		if (!top_players[i][TOP_WINS])
		{
			continue;
		}

		// Add HTML to motd.
		top_data[TOP_MOTD_LENGTH] += formatex(top_data[TOP_MOTD_CODE][top_data[TOP_MOTD_LENGTH]], charsmax(top_data[TOP_MOTD_CODE]),
			"<tr>\
				<td>\
					<b>\
						<h4># %d</h4>\
					</b>\
				<td>\
					<h4>%s</h4>\
				<td>\
					<h4>%d</h4>\
				</td>\
				<td>\
					<h4>%d</h4>\
				</td>\
				<td>\
					<h4>%d</h4>\
				</td>\
			</tr>",
			i + 1, top_players[i][TOP_NAMES], top_players[i][TOP_WINS], top_players[i][TOP_KNIFE_KILLS], floatround(float(top_players[i][TOP_HEADSHOTS]) / float(top_players[i][TOP_KILLS]) * 100.0));

		players_displayed++;
	}

	// Format motd title.
	formatex(top_data[TOP_MOTD_NAME], charsmax(top_data[TOP_MOTD_NAME]), "Top %i graczy GunGame", players_displayed);

	top_data[TOP_MOTD_CREATED] = true;
}

remove_idle_check(index)
{
	// AFK-check task exists?
	if (task_exists(index + TASK_IDLECHECK))
	{
		// Remove AFK-check task.
		remove_task(index + TASK_IDLECHECK);
		
		// Set last user position to 0 to prevent bugs with respawning close to death-place.
		ForRange(i, 0, 2)
		{
			user_data[index][DATA_LAST_ORIGIN][i] = 0;
		}
	
		// Set AFK-strikes to zero.
		user_data[index][DATA_IDLE_STRIKES] = 0;
	}
}

give_warmup_weapons(index)
{
	// Return if player is not alive.
	if (!is_user_alive(index))
	{
		return;
	}

	// Strip weapons.
	remove_player_weapons(index);

	user_data[index][DATA_ALLOWED_WEAPONS] = (1 << CSW_KNIFE);

	// Add bomb to allowed weapons if it's supported. Remove it if player is a CT.
	if (bomb_supported)
	{
		switch (user_data[index][DATA_TEAM])
		{
			case 1:
			{
				if (!(user_data[index][DATA_ALLOWED_WEAPONS] & (1 << CSW_C4)))
				{
					user_data[index][DATA_ALLOWED_WEAPONS] |= (1 << CSW_C4);
				}
			}

			case 2:
			{
				if (user_data[index][DATA_ALLOWED_WEAPONS] & (1 << CSW_C4))
				{
					user_data[index][DATA_ALLOWED_WEAPONS] &= ~(1 << CSW_C4);
				}
			}
		}
	}

	// Give knife as a default weapon.
	give_item(index, "weapon_knife");
	
	if (get_pcvar_num(cvars_data[CVAR_WARMUP_WEAPON]) > -1)
	{
		new weapon_name[MAX_CHARS - 1],
			weapon = get_pcvar_num(cvars_data[CVAR_WARMUP_WEAPON]),
			weapon_entity;
	
		user_data[index][DATA_ALLOWED_WEAPONS] |= (1 << weapon);

		// Get warmup weapon entity classname.
		get_weaponname(weapon, weapon_name, charsmax(weapon_name));

		weapon_entity = give_item(index, weapon_name);

		// Set weapon backpack ammo.
		if (weapon == CSW_AWP)
		{
			cs_set_user_bpammo(index, weapon, 100);
			cs_set_weapon_ammo(weapon_entity, 1);
		}
		else
		{
			cs_set_user_bpammo(index, weapon, 100);
		}
	}

	// Add random warmup weapon multiple times.
	else if (get_pcvar_num(cvars_data[CVAR_WARMUP_WEAPON]) == -1)
	{
		new weapon = get_weaponid(weapon_entity_names[warmup_data[WARMUP_WEAPON_INDEX]]);

		user_data[index][DATA_ALLOWED_WEAPONS] |= (1 << weapon);

		// Add weapon.
		give_item(index, weapon_entity_names[warmup_data[WARMUP_WEAPON_INDEX]]);

		cs_set_user_bpammo(index, weapon, 100);
		// Set weapon bp ammo.
		// if (weapon == CSW_AWP)
		// {
		// 	cs_set_user_bpammo(index, weapon, 100);
		// }
		// else
		// {
		// 	cs_set_user_bpammo(index, weapon, 100);
		// }
	}

	// Set wand model.
	else if (get_pcvar_num(cvars_data[CVAR_WARMUP_WEAPON]) == -2)
	{
		set_wand_models(index);
	}

	// Add random weapon.
	else if (get_pcvar_num(cvars_data[CVAR_WARMUP_WEAPON]) == -3)
	{
		random_warmup_weapon(index);
	}
}

// Remove quotes from message.
get_chat_message_arguments(message[], length)
{
	// Get message arguments.
	read_args(message, length);

	// Get rid of quotes.
	remove_quotes(message);
}

get_first_argument(word[], word_length, string[], string_length)
{
	if (string[0] == '^"')
	{
		// Handle message different if it has quotes in it.	
		strtok(string[1], word, word_length, string, string_length, '^"');

		// Get rid of white-chars.
		trim(string);
	}
	else
	{
		strtok(string, word, word_length, string, string_length);
	}
}

bool:is_he_grenade(entity)
{
	// Return if entity is invalid.
	if (!pev_valid(entity))
	{
		return false;
	}

	new classname[9];

	// Get classname of entity.
	pev(entity, pev_classname, classname, charsmax(classname));

	// Return if classname is not grenade.
	if (!equal(classname, "grenade") || get_pdata_int(entity, 96) & 1 << 8)
	{
		return false;
	}

	// Return if grenade type is not HE.
	if (!(get_pdata_int(entity, 114) & 1 << 1))
	{
		return false;
	}

	return true;
}

get_bomb_entity()
{
	static const IsBomb = 105;
	static const WeaponBox = 4;

	new bomb_entity;

	while (pev_valid((bomb_entity = find_ent_by_class(bomb_entity, "weaponbox"))))
	{
		if (!get_pdata_int(bomb_entity, IsBomb, WeaponBox))
		{
			continue;
		}

		return bomb_entity;
	}

	return 0;
}

set_wand_models(index)
{
	// Set V and P wand models.
	set_pev(index, pev_viewmodel2, WandModels[0]);
	set_pev(index, pev_weaponmodel2, WandModels[1]);
}

set_weapon_animation(index, animation)
{
	// Set weapon animation.
	set_pev(index, pev_weaponanim, animation);

	// Display animation.
	message_begin(1, 35, _, index);
	write_byte(animation);
	write_byte(pev(index, pev_body));
	message_end();
}

remove_weapons_off_ground()
{
	new entity,
		bomb_entity = get_bomb_entity();

	// Remove all weapons off the ground.
	ForArray(i, DroppedWeaponsClassnames)
	{
		while ((entity = find_ent_by_class(entity, DroppedWeaponsClassnames[i])))
		{
			if (entity == bomb_entity)
			{
				continue;
			}
			
			remove_entity(entity);
		}
	}
}

show_player_info(index, target)
{
	if (is_user_connected(target))
	{
		ColorChat(index, RED, "%s^x01 Gracz ^x04%n^x01 jest na poziomie^x04 %i^x01 [^x04%s^x01 - ^x04%i^x01/^x04%i^x01]. Wygral ^x04%i^x01 razy. Status uslugi:^x04 %s^x01.",
			ChatPrefix,
			target,
			user_data[target][DATA_LEVEL] + 1,
			is_on_last_level(target) ? (get_pcvar_num(cvars_data[CVAR_WAND_ENABLED]) ? "Rozdzka" : CustomWeaponNames[user_data[target][DATA_LEVEL]]) : CustomWeaponNames[user_data[target][DATA_LEVEL]],
			user_data[target][DATA_WEAPON_KILLS],
			WeaponsData[user_data[target][DATA_LEVEL]][game_mode == MODE_NORMAL ? weapon_kills : weapon_team_kills],
			user_data[target][DATA_WINS],
			gg_get_user_vip(target) ? "VIP" : "Brak");
	}
	else
	{
		ColorChat(index, RED, "%s^x01 %s", ChatPrefix, target == -1 ? "Wiecej niz jeden gracz pasuje do podanego nicku." : " Gracz o tym nicku nie zostal znaleziony.");
	}
}

randomize_sound_index(sound_type)
{
	// Create dynamic array to store valid sound indexes.
	new Array:sound_indexes = ArrayCreate(1, 1);

	// Iterate through sounds array to find valid sounds, then add them to dynamic array.
	ForRange(j, 0, MaxSounds - 1)
	{
		if (strlen(SoundsData[sound_type][j]))
		{
			ArrayPushCell(sound_indexes, j);
		}
	}

	// Randomize valid index read from dynamic array.
	new sound_index = ArrayGetCell(sound_indexes, random_num(0, ArraySize(sound_indexes) - 1));
	
	// Get rid of array to save data space.
	ArrayDestroy(sound_indexes);

	return sound_index;
}

play_sound(index, sound_type, sound_index)
{
	enum (+= 1)
	{
		type_mpthree,
		type_wav,
		type_emitsound
	}

	static sound_extension;

	// Sound index is set to random?
	if (sound_index < 0)
	{
		sound_index = randomize_sound_index(sound_type);
	}

	// Get sound extension.
	if (containi(SoundsData[sound_type][sound_index], ".mp3") != -1)
	{
		sound_extension = type_mpthree;
	}
	else if (containi(SoundsData[sound_type][sound_index], ".wav") != -1)
	{
		sound_extension = type_wav;
	}
	else
	{
		sound_extension = type_emitsound;
	}

	switch(sound_extension)
	{
		case type_wav: client_cmd(index, "spk ^"%s^"", SoundsData[sound_type][sound_index]);
		case type_mpthree: client_cmd(index, "mp3 play ^"%s^"", SoundsData[sound_type][sound_index]);
		case type_emitsound: emit_sound(index, CHAN_AUTO, SoundsData[sound_type][sound_index], SoundsVolumeData[sound_type][sound_index], ATTN_NORM, (1 << 8), PITCH_NORM);
	}
}

play_sound_for_team(team, sound_type, sound_index)
{
	enum (+= 1)
	{
		type_mpthree,
		type_wav,
		type_emitsound
	}

	static sound_extension;

	// Sound index is set to random?
	if (sound_index < 0)
	{
		sound_index = randomize_sound_index(sound_type);
	}

	// Get sound extension.
	if (containi(SoundsData[sound_type][sound_index], ".mp3") != -1)
	{
		sound_extension = type_mpthree;
	}
	else if (containi(SoundsData[sound_type][sound_index], ".wav") != -1)
	{
		sound_extension = type_wav;
	}
	else
	{
		sound_extension = type_emitsound;
	}
	
	// Play sound.
	switch(sound_extension)
	{
		case type_wav:
		{
			ForTeam(i, team)
			{
				client_cmd(i, "spk ^"%s^"", SoundsData[sound_type][sound_index]);
			}
		}

		case type_mpthree:
		{
			ForTeam(i, team)
			{
				client_cmd(i, "mp3 play ^"%s^"", SoundsData[sound_type][sound_index]);
			}
		}

		case type_emitsound:
		{
			ForTeam(i, team)
			{
				emit_sound(i, CHAN_AUTO, SoundsData[sound_type][sound_index], SoundsVolumeData[sound_type][sound_index], ATTN_NORM, (1 << 8), PITCH_NORM);
			}
		}
	}
}

toggle_warmup(bool:status)
{
	warmup_data[WARMUP_WEAPON_NAME_INDEX] = -1;
	warmup_data[WARMUP_ENABLED] = status;

	set_warmup_hud(status);

	// Warmup set to disabled?
	if (!warmup_data[WARMUP_ENABLED])
	{
		finish_game_vote();

		if (game_mode == MODE_NORMAL)
		{
			// Get warmup winner based on kills.
			new winner = get_warmup_winner();

			// Set task to reward winner after game restart.
			if (is_user_connected(winner))
			{
				set_task(2.0, "reward_warmup_winner", winner + TASK_REWARDWINNER);
			}

			ExecuteForward(forward_handles[FORWARD_GAME_BEGINNING], blank, winner);
		}
		else
		{
			ExecuteForward(forward_handles[FORWARD_GAME_BEGINNING], blank, -1);
		}

		// Restart the game.
		set_cvar_num("sv_restartround", 1);

		// Play gungame start sound.
		play_sound(0, SOUND_GAME_START, -1);
	}
	else
	{
		// Disable freezetime.
		set_cvar_num("mp_freezetime", 0);

		// Make sure that freezetime is disabled, set to 0 if not.
		if (get_cvar_num("mp_freezetime"))
		{
			server_cmd("amx_cvar mp_freezetime 0");
		}

		// Remove hud tasks.
		ForPlayers(i)
		{
			if (!is_user_connected(i) || task_exists(i + TASK_DISPLAYHUD))
			{
				continue;
			}
			
			remove_task(i + TASK_DISPLAYHUD);
		}

		// Get random weapon, only if its not a knife.
		warmup_data[WARMUP_WEAPON_INDEX] = random_num(0, sizeof(CustomWeaponNames) - 2);

		// Play warmup start sound.
		play_sound(0, SOUND_WARMUP, -1);

		set_game_vote();
	}
}

// Set timer HUD task.
set_warmup_hud(bool:status)
{
	if (status)
	{
		set_task(1.0, "display_warmup_timer");

		warmup_data[WARMUP_TIMER] = get_pcvar_num(cvars_data[CVAR_WARMUP_DURATION]);
	}
}

toggle_spawn_protection(index, bool:status)
{
	// Toggle spawn protection on index.
	user_data[index][DATA_SPAWN_PROTECTION] = status;

	// Toggle godmode.
	if (get_pcvar_num(cvars_data[CVAR_SPAWN_PROTECTION_TYPE]))
	{
		set_user_godmode(index, status);
	}

	// Set glowshell to indicate spawn protection. Disable any rendering if status is false.
	if (status)
	{
		set_user_rendering(index, kRenderFxGlowShell, SpawnProtectionColors[0], SpawnProtectionColors[1], SpawnProtectionColors[2], kRenderGlow, SpawnProtectionShell);
	}
	else
	{
		set_user_rendering(index);
	}
}

// Set hud display task.
show_hud(index)
{
	set_task(HudDisplayInterval, "display_hud", index + TASK_DISPLAYHUD, .flags = "b");
}

// Remove hud display task.
remove_hud(index)
{
	if (task_exists(index + TASK_DISPLAYHUD))
	{
		remove_task(index + TASK_DISPLAYHUD);
	}
}

respawn_player(index, Float:time)
{
	// Player already respawned?
	if (is_user_alive(index))
	{
		return;
	}

	// Not interested in spectator and unassigned players.
	if (user_data[index][DATA_TEAM] != 1 && user_data[index][DATA_TEAM] != 2)
	{
		return;
	}

	// Get respawn time to int.
	new int_time = floatround(time, floatround_round);

	// Set user respawn time to integer value.
	user_data[index][DATA_TIME_TO_RESPAWN] = int_time;

	// Set tasks to notify about timeleft to respawn.
	ForRange(i, 0, int_time - 1)
	{
		set_task(float(i), "respawn_notify", index + TASK_NOTIFY);
	}

	// Set an actuall respawn function delayed.
	set_task(time, "client_respawn", index + TASK_RESPAWN);
}

increment_user_weapon_kills(index, value)
{
	// Set kills required and killstreak.
	user_data[index][DATA_COMBO] += value;
	user_data[index][DATA_WEAPON_KILLS] += value;

	ExecuteForward(forward_handles[FORWARD_COMBO_STREAK], blank, index, user_data[index][DATA_COMBO]);

	// Levelup player if weapon kills are greater than reqiured for his current level.
	while (user_data[index][DATA_WEAPON_KILLS] >= WeaponsData[user_data[index][DATA_LEVEL]][weapon_kills])
	{
		increment_user_level(index, 1);
	}
}

increment_team_weapon_kills(team, value)
{
	tp_data[TP_TEAM_KILLS][team - 1] += value;

	while (tp_data[TP_TEAM_KILLS][team - 1] >= WeaponsData[tp_data[TP_TEAM_LEVEL][team - 1]][weapon_team_kills])
	{
		increment_team_level(team, 1);
	}
}

// Decrement weapon kills, take care of leveldown.
decrement_user_weapon_kills(index, value, bool:level_Lose)
{
	user_data[index][DATA_WEAPON_KILLS] -= value;

	if (level_Lose && user_data[index][DATA_WEAPON_KILLS] < 0)
	{
		decrement_user_level(index, 1);
	}

	if (user_data[index][DATA_WEAPON_KILLS] < 0)
	{
		user_data[index][DATA_WEAPON_KILLS] = 0;
	}
}

// Decrement weapon kills, take care of leveldown.
decrement_team_weapon_kills(team, value, bool:level_Lose)
{
	tp_data[TP_TEAM_KILLS][team - 1] -= value;

	if (tp_data[TP_TEAM_KILLS][team - 1] < 0)
	{
		tp_data[TP_TEAM_KILLS][team - 1] = 0;
	}

	ForTeam(i, team)
	{
		user_data[i][DATA_WEAPON_KILLS] = tp_data[TP_TEAM_KILLS][team - 1];
	}

	if (!level_Lose)
	{
		return;
	}

	decrement_team_level(team, 1);
}

increment_user_level(index, value, bool:notify = true)
{
	// Set weapon kills based on current level required kills. Set new level if valid number.
	user_data[index][DATA_WEAPON_KILLS] -= WeaponsData[user_data[index][DATA_LEVEL]][weapon_kills];
	user_data[index][DATA_LEVEL] = (user_data[index][DATA_LEVEL] + value > max_level ? max_level : user_data[index][DATA_LEVEL] + value);

	// Levelup effect.
	display_levelup_sprite(index);

	// Make sure player's kills are positive.
	if (user_data[index][DATA_WEAPON_KILLS] < 0)
	{
		user_data[index][DATA_WEAPON_KILLS] = 0;
	}

	// Add weapons for player's current level.
	give_weapons(index);

	ExecuteForward(forward_handles[FORWARD_LEVEL_UP], blank, index, user_data[index][DATA_LEVEL], -1);

	if (notify)
	{
		// Notify about levelup.
		ColorChat(0, RED, "%s^x01 Gracz^x04 %n^x01 awansowal na poziom^x04 %i^x01 ::^x04 %s^x01.",
			ChatPrefix,
			index,
			user_data[index][DATA_LEVEL] + 1,
			user_data[index][DATA_LEVEL] == max_level ? (get_pcvar_num(cvars_data[CVAR_WAND_ENABLED]) ? "Rozdzka" : CustomWeaponNames[user_data[index][DATA_LEVEL]]) : CustomWeaponNames[user_data[index][DATA_LEVEL]]);
		
		// Play levelup sound.
		play_sound(index, SOUND_LEVEL_UP, -1);
	}

	if (game_mode == MODE_NORMAL)
	{
		static new_leader;

		new_leader = get_game_leader(blank);

		// It's not our guy.
		if (new_leader != index)
		{
			return;
		}

		// Leader did not change.
		if (old_leader == index)
		{
			return;
		}

		// Finally play the sounds.
		play_sound(old_leader, SOUND_LOST_LEAD, -1);
		play_sound(new_leader, SOUND_TAKEN_LEAD, -1);

		old_leader = index;
	}
}

increment_team_level(team, value, bool:notify = true)
{
	// Set weapon kills based on current level required kills. Set new level if valid number.
	tp_data[TP_TEAM_KILLS][team - 1] = 0;
	tp_data[TP_TEAM_LEVEL][team - 1] = (tp_data[TP_TEAM_LEVEL][team - 1] + value > max_level ? max_level : tp_data[TP_TEAM_LEVEL][team - 1] + value);

	ForTeam(i, team)
	{
		user_data[i][DATA_LEVEL] = tp_data[TP_TEAM_LEVEL][team - 1];
		user_data[i][DATA_WEAPON_KILLS] = tp_data[TP_TEAM_KILLS][team - 1];

		// Levelup effect.
		display_levelup_sprite(i);

		// Add weapons.
		give_weapons(i);
	
		ExecuteForward(forward_handles[FORWARD_LEVEL_UP], blank, i, tp_data[TP_TEAM_LEVEL][team - 1], team);
	}

	if (notify)
	{
		// Notify about levelup.
		ColorChat(0, RED, "%s^x01 Druzyna^x04 %s^x01 awansowala na poziom^x04 %i^x01 ::^x04 %s^x01.",
			ChatPrefix,
			TeamNames[team - 1],
			tp_data[TP_TEAM_LEVEL][team - 1] + 1,
			tp_data[TP_TEAM_LEVEL][team - 1] == max_level ? (get_pcvar_num(cvars_data[CVAR_WAND_ENABLED]) ? "Rozdzka" : CustomWeaponNames[tp_data[TP_TEAM_LEVEL][team - 1]]) : CustomWeaponNames[tp_data[TP_TEAM_LEVEL][team - 1]]);
	}
}

display_levelup_sprite(index)
{
	new Float:user_origin[3];

	pev(index, pev_origin, user_origin);

	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, user_origin, 0);
	write_byte(TE_BEAMCYLINDER);
	engfunc(EngFunc_WriteCoord, user_origin[0]);
	engfunc(EngFunc_WriteCoord, user_origin[1]);
	engfunc(EngFunc_WriteCoord, user_origin[2]);
	engfunc(EngFunc_WriteCoord, user_origin[0]);
	engfunc(EngFunc_WriteCoord, user_origin[1]);
	engfunc(EngFunc_WriteCoord, user_origin[2] + SpriteLevelupZaxis);
	write_short(sprite_levelup_index);
	write_byte(0);
	write_byte(0);
	write_byte(SpriteLevelupLife);
	write_byte(SpriteLevelupWidth);
	write_byte(0);
	write_byte(SpriteLevelupRGB[0]);
	write_byte(SpriteLevelupRGB[1]);
	write_byte(SpriteLevelupRGB[2]);
	write_byte(SpriteLevelupBrightness);
	write_byte(0);
	message_end();
}

decrement_user_level(index, value)
{
	// Decrement user level, make sure his level is not negative.
	user_data[index][DATA_LEVEL] = (user_data[index][DATA_LEVEL] - value < 0 ? 0 : user_data[index][DATA_LEVEL] - value);
	user_data[index][DATA_WEAPON_KILLS] = 0;

	// Play leveldown sound.
	play_sound(index, SOUND_LEVEL_DOWN, -1);

	ExecuteForward(forward_handles[FORWARD_LEVEL_DOWN], blank, index, user_data[index][DATA_LEVEL], -1);
}

decrement_team_level(team, value)
{
	// Decrement team level and kills, make sure level is not negative.
	tp_data[TP_TEAM_LEVEL][team - 1] = (tp_data[TP_TEAM_LEVEL][team - 1] - value < 0 ? 0 : tp_data[TP_TEAM_LEVEL][team - 1] - value);
	tp_data[TP_TEAM_KILLS][team - 1] = 0;

	// Update level and kills of players in the team.
	ForTeam(i, team)
	{
		user_data[i][DATA_LEVEL] = tp_data[TP_TEAM_LEVEL][team - 1];
		user_data[i][DATA_WEAPON_KILLS] = tp_data[TP_TEAM_KILLS][team - 1];
	
		ExecuteForward(forward_handles[FORWARD_LEVEL_DOWN], blank, i, tp_data[TP_TEAM_LEVEL][team - 1], team);
	}

	// Play leveldown sound.
	play_sound_for_team(team, SOUND_LEVEL_DOWN, -1);
}

end_gungame(winner)
{
	// Mark gungame as ended.
	gungame_ended = true;

	ExecuteForward(forward_handles[FORWARD_GAME_END], blank, winner);

	// Remove hud, and tasks if they exist.
	ForPlayers(i)
	{
		if (!is_user_alive(i) && task_exists(i + TASK_RESPAWN))
		{
			remove_task(i + TASK_RESPAWN);

			if (task_exists(i + TASK_NOTIFY))
			{
				remove_task(i + TASK_NOTIFY);
			}
		}

		remove_hud(i);
		update_user_data(i);
	}

	new win_message[MAX_CHARS * 10],
		temp_message[MAX_CHARS * 5],
		top_players[TopPlayersDisplayed + 1],
		index;

	// Set black screen.
	set_black_screen_fade(2);

	// Recursevly set black screen every second so player has it colored no matter what.
	set_task(1.0, "set_black_screen_on");

	// Update top players.
	load_top_players();

	// Get top players.
	get_player_by_top_level(top_players, charsmax(top_players));

	// Reward winner.
	user_data[winner][DATA_WINS]++;

	// Format win message.
	formatex(win_message, charsmax(win_message), "%s^nTopowi gracze:^n^n^n^n", ChatPrefix);

	// Format top players message.
	ForArray(i, top_players)
	{
		index = top_players[i];

		if (!is_user_connected(index) || is_user_hltv(index))
		{
			continue;
		}

		formatex(temp_message, charsmax(temp_message), "^n^n%i. %s (%i lvl - %s [%i fragow] [wygranych: %i])",
			i + 1,
			user_data[index][DATA_SHORT_NAME],
			user_data[index][DATA_LEVEL] + 1,
			CustomWeaponNames[user_data[index][DATA_LEVEL]],
			user_data[index][DATA_KILLS],
			user_data[index][DATA_WINS]);

		add(win_message, charsmax(win_message), temp_message, charsmax(temp_message));
	}

	// Play game win sound to winner.
	play_sound(winner, SOUND_ANNOUNCE_WINNER, -1);

	// Display formated win message.
	set_hudmessage(255, 255, 255, -1.0, -1.0, 0, 6.0, BlackScreenTimer, 0.0, 0.0);
	ShowSyncHudMsg(0, hud_objects[hud_object_default], win_message);

	// Vote for next map.
	showMapVoteMenu();
}

give_weapons(index)
{
	if (!is_user_alive(index))
	{
		return;
	}

	// We dont want players to have armor.
	set_user_armor(index, get_pcvar_num(cvars_data[CVAR_DEFAULT_ARMOR_LEVEL]));

	// Strip weapons.
	remove_player_weapons(index);

	// Reset player allowed weapons and add knife.
	user_data[index][DATA_ALLOWED_WEAPONS] = (1 << CSW_KNIFE);

	// Add bomb to allowed weapons if it's supported. Remove it if player is a CT.
	if (bomb_supported)
	{
		switch (user_data[index][DATA_TEAM])
		{
			case 1:
			{
				if (!(user_data[index][DATA_ALLOWED_WEAPONS] & (1 << CSW_C4)))
				{
					user_data[index][DATA_ALLOWED_WEAPONS] |= (1 << CSW_C4);
				}
			}

			case 2:
			{
				if (user_data[index][DATA_ALLOWED_WEAPONS] & (1 << CSW_C4))
				{
					user_data[index][DATA_ALLOWED_WEAPONS] &= ~(1 << CSW_C4);
				}
			}
		}
	}

	// Add wand if player is on last level and such option is enabled.
	if (user_data[index][DATA_LEVEL] != max_level)
	{
		// Add weapon couple of times to make sure backpack ammo is right.
		new csw = get_weaponid(weapon_entity_names[user_data[index][DATA_LEVEL]]),
			weapon_entity;

		// Add weapon to allowed to carry by player.
		user_data[index][DATA_ALLOWED_WEAPONS] |= (1 << csw);

		weapon_entity = give_item(index, weapon_entity_names[user_data[index][DATA_LEVEL]]);

		if (csw != CSW_HEGRENADE && csw != CSW_KNIFE && csw != CSW_FLASHBANG)
		{
			if (csw == CSW_AWP)
			{
				cs_set_user_bpammo(index, csw, 100);
				cs_set_weapon_ammo(weapon_entity, 1);
			}
			else
			{
				cs_set_user_bpammo(index, csw, 100);
			}
		}

		// Deploy primary weapon.
		engclient_cmd(index, weapon_entity_names[user_data[index][DATA_LEVEL]]);

		// Add knife last so the primary weapon gets drawn out (dont switch to powerful weapon fix).
		give_item(index, "weapon_knife");
	}
	else
	{
		// Add knife first, so the models can be set.
		give_item(index, "weapon_knife");

		// Set wand model.
		if (get_pcvar_num(cvars_data[CVAR_WAND_ENABLED]))
		{
			set_wand_models(index);
		}
		else
		{
			// Add two flashes.
			if (get_pcvar_num(cvars_data[CVAR_FLASHES_ENABLED]))
			{
				user_data[index][DATA_ALLOWED_WEAPONS] |= (1 << CSW_FLASHBANG);

				ForRange(i, 0, 1)
				{
					give_item(index, "weapon_flashbang");
				}
			}
		}
	}
}

get_warmup_winner()
{
	// Return if warmup reward is none.
	if (get_pcvar_num(cvars_data[CVAR_WARMUP_LEVEL_REWARD]) < 2)
	{
		return 0;
	}

	new winner,
		Array:candidates = ArrayCreate(2, 32);

	// Collect all players data
	ForPlayers(i)
	{
		if (is_user_connected(i) && !is_user_hltv(i))
		{
			new data_set[4];

			data_set[0] = i; // id
			data_set[1] = get_user_frags(i); // frags
			data_set[2] = get_user_deaths(i); // deaths

			ArrayPushArray(candidates, data_set);
		}
	}

	ArraySortEx(candidates, "sort_players_by_kills");

	new candidates_amount = ArraySize(candidates);

	if (!candidates_amount)
	{
		// There is no winner, no real players on server
		return 0;
	}
	// Check if top player is best by frags only
	
	// Only one player
	if (candidates_amount == 1)
	{
		new player[4];

		ArrayGetArray(candidates, 0, player);

		winner = player[0];

		announce_warmup_winner(winner);
		
		ArrayDestroy(candidates);

		return winner;
	}
	// More players
	else if (candidates_amount >= 2)
	{
		new top1_player[4],
			top2_player[4];

		ArrayGetArray(candidates, 0, top1_player);
		ArrayGetArray(candidates, 1, top2_player);

		if (top1_player[1] > top2_player[1])
		{
			winner = top1_player[0];

			ArrayDestroy(candidates);
			
			announce_warmup_winner(winner);

			return winner;
		}
		else if (top1_player[1] < top2_player[1])
		{
			winner = top2_player[0];
			
			ArrayDestroy(candidates);

			announce_warmup_winner(winner);

			return winner;
		}
		// Else top players are ex aequo, let's choose by kills and deaths difference
	}

	ArraySortEx(candidates, "sort_players_by_kills_death_difference");

	// Get only players with best score
	new Array:best_players = ArrayCreate(2, 32),
		candidate_data[3];
	
	ArrayGetArray(candidates, 0, candidate_data);

	// Get top player
	new maximum = candidate_data[1] + candidate_data[2],
		top_frags = candidate_data[1];
	
	// Best player has killed someone = not everybody has 0:0 stats
	if (top_frags > 0)
	{
		ForDynamicArray(i, candidates)
		{
			ArrayGetArray(candidates, i, candidate_data);

			if (candidate_data[1] < maximum)
			{
				break;
			}

			ArrayPushArray(best_players, candidate_data);
		}

		// Only player with top score, he's the winner
		new best_players_amount = ArraySize(best_players);

		if (best_players_amount == 1)
		{
			ArrayGetArray(best_players, 0, candidate_data);

			winner = candidate_data[0];
		}
		else // There are more players with top score, let's randomly choose one
		{
			new choosen = random_num(0, best_players_amount - 1);

			ArrayGetArray(best_players, choosen, candidate_data);

			winner = candidate_data[0];
		}

		announce_warmup_winner(winner);
	}
	else if (top_frags == 0) // No one got killed
	{
		winner = 0;
	}

	ArrayDestroy(candidates);
	ArrayDestroy(best_players);

	return winner;
}

announce_warmup_winner(winner)
{
	// Print win-message couple times in chat.
	if (is_user_connected(winner))
	{
		ForRange(i, 0, 2)
		{
			if (gg_get_user_vip(winner))
			{
				ColorChat(0, RED, "%s^x01 Zwyciezca rozgrzewki:^x04 %n^x01! W nagrode zaczyna GunGame z poziomem^x04 %i^x01!", ChatPrefix, winner, get_pcvar_num(cvars_data[CVAR_WARMUP_LEVEL_REWARD]));
			}
			else
			{
				ColorChat(0, RED, "%s^x01 Zwyciezca rozgrzewki:^x04 %n^x01! W nagrode otrzymuje VIPA do konca mapy!", ChatPrefix, winner);
			}
		}
	}
}

public sort_players_by_kills(Array:array, elem1[], elem2[], const data[], data_size)
{
	new p1_kills = elem1[1];
	new p2_kills = elem2[1];

	if (p1_kills > p2_kills)
	{
		return -1;
	}
	else if (p1_kills < p2_kills)
	{
		return 1;
	}
	return 0;
}

public sort_players_by_kills_death_difference(Array:array, elem1[], elem2[], const data[], data_size)
{
	new p1_kills = elem1[1];
	new p1_deaths = elem1[2];

	new p2_kills = elem2[1];
	new p2_deaths = elem2[2];

	new p1_difference = p1_kills - p1_deaths;
	new p2_difference = p2_kills - p2_deaths;

	if (p1_difference > p2_difference)
	{
		return -1;
	}
	else if (p1_difference < p2_difference)
	{
		return 1;
	}
	return 0;
}

get_weapons_name(iterator, weapon_index, string[], length)
{
	// Get weapon classname.
	get_weaponname(weapon_index, weapon_entity_names[iterator], charsmax(weapon_entity_names[]));

	// Get rid of "weapon_" prefix.
	copy(weapon_temp_name, charsmax(weapon_temp_name), weapon_entity_names[iterator][7]);
	
	// Get weapon name to upper case.
	strtoupper(weapon_temp_name);

	// Copy weapon name to original output.
	copy(string, length, weapon_temp_name);
}

get_game_leader(&leaders_counter)
{
	static highest;

	highest = 0;
	
	if (game_mode == MODE_NORMAL)
	{
		// Loop through all players, get one with highest level and kills.
		ForPlayers(i)
		{
			if (!is_user_connected(i))
			{
				continue;
			}

			// No leader was chosen yet.
			if (!is_user_connected(highest))
			{
				highest = i;
				leaders_counter = 1;

				continue;
			}
			
			// Leading by level.
			if (user_data[i][DATA_LEVEL] > user_data[highest][DATA_LEVEL])
			{
				highest = i;
				leaders_counter = 1;
			}

			// Leading by weapon kills.
			else if (user_data[i][DATA_LEVEL] == user_data[highest][DATA_LEVEL])
			{
				// Higher weapon kills - he's a new leader.
				if (user_data[i][DATA_WEAPON_KILLS] > user_data[highest][DATA_WEAPON_KILLS])
				{
					highest = i;
					leaders_counter = 1;
				}
				else if (user_data[i][DATA_WEAPON_KILLS] == user_data[highest][DATA_WEAPON_KILLS])
				{
					leaders_counter++;
				}
			}
		}

		old_leader = highest;
	}
	else if (game_mode == MODE_TEAMPLAY)
	{
		// Get leading team by level.
		if (tp_data[TP_TEAM_LEVEL][0] == tp_data[TP_TEAM_LEVEL][1])
		{
			highest = -1;
		}
		else if (tp_data[TP_TEAM_LEVEL][0] > tp_data[TP_TEAM_LEVEL][1])
		{
			highest = 0;
		}
		else
		{
			highest = 1;
		}

		// Get leading team by kills if they're at the same level.
		if (highest == -1)
		{
			if (tp_data[TP_TEAM_KILLS][0] == tp_data[TP_TEAM_KILLS][1])
			{
				highest = -1;
			}
			else if (tp_data[TP_TEAM_KILLS][0] > tp_data[TP_TEAM_KILLS][1])
			{
				highest = 0;
			}
			else
			{
				highest = 1;
			}
		}
	}

	return highest;
}

get_current_lowest_level()
{
	// Just return 0 if there are less than 3 players, no need for a loop.
	if (get_playersnum() < 3)
	{
		return 0;
	}

	new lowest;

	// Loop through all players and get lowest level.
	ForPlayers(i)
	{
		if (!is_user_connected(i) || user_data[i][DATA_LEVEL] > lowest)
		{
			continue;
		}

		lowest = user_data[i][DATA_LEVEL];
	}

	return lowest;
}

get_player_by_name(name[])
{
	// Get rid of white spaces.
	trim(name);

	// Return error value if name was not specified.
	if (!strlen(name))
	{
		// Throw error to server console.
		#if defined DEBUG_MODE
		
		log_amx("Function: get_player_by_name ^"name^" argument's length is %i.", name, strlen(name));
		
		#endif

		return -2;
	}

	new found_player_index,
		players_found;

	// Loop through players, get index if names are matching.
	ForPlayers(i)
	{
		if (!is_user_connected(i) || containi(fmt("%n", i), name) == -1)
		{
			continue;
		}
		
		players_found++;
			
		found_player_index = i;
	}

	// Return -1 if found more than one guy.
	if (players_found > 1)
	{
		return -1;
	}

	return found_player_index;
}

get_player_by_top_level(array[], count)
{
	new highest_levels[MAX_PLAYERS + 1],
		counter;

	ForPlayers(index)
	{
		if (!is_user_connected(index))
		{
			continue;
		}

		for (new i = count - 1; i >= 0; i--)
		{
			if (highest_levels[i] < user_data[index][DATA_LEVEL] + 1 && i)
			{
				continue;
			}

			if (highest_levels[i] >= user_data[index][DATA_LEVEL] + 1 && i < count - 1)
			{
				counter = i + 1;
			}

			else if (!i)
			{
				counter = 0;
			}

			else 
			{
				break;
			}

			for (new j = count - 2; j >= counter; j--)
			{
				highest_levels[j + 1] = highest_levels[j];

				array[j + 1] = array[j];
			}

			highest_levels[counter] = user_data[index][DATA_LEVEL] + 1;
			array[counter] = index;
		}
	}
}

get_warmup_weapon_name()
{
	// Return if warmup weapon is static.
	if (warmup_data[WARMUP_WEAPON_NAME_INDEX] > -1)
	{
		return;
	}

	// Loop through all weapons, find one with same ID as warmup weapon.
	ForArray(i, WeaponsData)
	{
		if (get_pcvar_num(cvars_data[CVAR_WARMUP_WEAPON]) == WeaponsData[i][weapon_CSW])
		{
			warmup_data[WARMUP_WEAPON_NAME_INDEX] = i;

			break;
		}
	}
}

refill_ammo(index, bool:team = false)
{
	// Return if player is not alive or gungame has ended.
	if (gungame_ended)
	{
		return;
	}

	static weapon_classname[MAX_CHARS - 1],
		weapon_entity;

	if (team)
	{
		ForTeam(i, index)
		{
			if (!is_user_alive(i))
			{
				continue;
			}

			// Continue if for some reason player has no weapon.
			if (!user_data[i][DATA_CURRENT_WEAPON])
			{
				continue;
			}

			// Get weapon classname.
			get_weaponname(user_data[index][DATA_CURRENT_WEAPON], weapon_classname, charsmax(weapon_classname));

			// Get entity index of player's weapon.
			weapon_entity = find_ent_by_owner(-1, weapon_classname, i);

			// Continue if weapon index is invalid.
			if (!weapon_entity)
			{
				continue;
			}

			// Refill weapon ammo.
			cs_set_weapon_ammo(weapon_entity, AmmoAmounts[user_data[index][DATA_CURRENT_WEAPON]]);
		}
	}
	else
	{
		// Return if for some reason player has no weapon.
		if (!user_data[index][DATA_CURRENT_WEAPON])
		{
			return;
		}
		
		// Get weapon classname.
		get_weaponname(user_data[index][DATA_CURRENT_WEAPON], weapon_classname, charsmax(weapon_classname));

		// Get entity index of player's weapon.
		weapon_entity = find_ent_by_owner(-1, weapon_classname, index);

		// Return if weapon index is invalid.
		if (!weapon_entity)
		{
			return;
		}

		// Refill weapon ammo.
		cs_set_weapon_ammo(weapon_entity, AmmoAmounts[user_data[index][DATA_CURRENT_WEAPON]]);
	}
}

random_warmup_weapon(index)
{
	// Return if player is not alive or warmup is not enabled.
	if (!is_user_alive(index) || !warmup_data[WARMUP_ENABLED])
	{
		return;
	}

	new csw,
		weapon_classname[MAX_CHARS - 1],
		weapons_array_index = random_num(0, sizeof(WeaponsData) - 2);

	// Get random index from WeaponsData array.
	csw = WeaponsData[weapons_array_index][0];

	// Get classname of randomized weapon.
	get_weaponname(csw, weapon_classname, charsmax(weapon_classname));

	user_data[index][DATA_ALLOWED_WEAPONS] |= (1 << csw);

	// Add weapon to player.
	give_item(index, weapon_classname);

	// Set weapon bp ammo to 100.
	cs_set_user_bpammo(index, csw, 100);

	user_data[index][DATA_WARMUP_WEAPON] = csw;
	user_data[index][DATA_WARMUP_CUSTOM_WEAPON_INDEX] = weapons_array_index;
}

// Clamp down user name if its length is greater than "value" argument.
clamp_down_client_name(index, output[], length, const value, const token[])
{
	if (strlen(fmt("%n", index)) > value)
	{
		format(output, value, fmt("%n", index));

		add(output, length, token);
	}
	else
	{
		// Just copy his original name instead.
		copy(user_data[index][DATA_SHORT_NAME], MAX_CHARS - 1, fmt("%n", index));
	}
}

wand_attack(index, weapon)
{
	// He ded >.<
	if (!is_user_alive(index))
	{
		return PLUGIN_HANDLED;
	}

	// Wand enabled?
	if (!get_pcvar_num(cvars_data[CVAR_WAND_ENABLED]))
	{
		return PLUGIN_HANDLED;
	}

	if (weapon != CSW_KNIFE)
	{
		return PLUGIN_HANDLED;
	}
	
	// Not on last level & not a warmup.
	if (!warmup_data[WARMUP_ENABLED] && !is_on_last_level(index))
	{
		return PLUGIN_HANDLED;
	}

	// Warmup weapon is not wand.
	if (warmup_data[WARMUP_ENABLED] && get_pcvar_num(cvars_data[CVAR_WARMUP_WEAPON]) != -2)
	{
		return PLUGIN_HANDLED;
	}

	// Cooldown is still on.
	if (user_data[index][DATA_WAND_LAST_ATTACK] + get_pcvar_float(cvars_data[CVAR_WAND_ATTACK_INTERVAL]) > get_gametime())
	{
		return PLUGIN_HANDLED;
	}

	new end_origin[3],
		start_origin[3];

	// Get player position and end position.
	get_user_origin(index, start_origin, 0);
	get_user_origin(index, end_origin, 3);

	// Block shooting if distance is too high.
	if (get_distance(start_origin, end_origin) > get_pcvar_num(cvars_data[CVAR_WAND_ATTACK_MAX_DISTANCE]))
	{
		return PLUGIN_HANDLED;
	}

	// Animate attacking.
	set_weapon_animation(index, 1);

	// Show progress bar
	set_progress_bar(index, get_pcvar_float(cvars_data[CVAR_WAND_ATTACK_INTERVAL]));

	// Play attack sound.
	emit_sound(index, CHAN_AUTO, WandSounds[wand_sound_shoot], 1.0, 0.80, SND_SPAWNING, 100);

	static victim, bodyPart;

	// Animate attacking.
	set_pev(index, pev_weaponanim, 5);

	message_begin(8, 35, _, index);
	write_byte(5);
	write_byte(0);
	message_end();

	// Animate shooting.
	message_begin(0, 23);
	write_byte(1);
	write_short(index | 0x1000);
	write_coord(end_origin[0]);
	write_coord(end_origin[1]);
	write_coord(end_origin[2]);
	write_short(wand_sprites_indexes[WAND_SPRITE_ATTACK]);
	write_byte(0);
	write_byte(5);
	write_byte(get_pcvar_num(cvars_data[CVAR_WAND_ATTACK_SPRITE_LIFE]));
	write_byte(30);
	write_byte(40);
	write_byte(WandAttackSpriteColor[0]);
	write_byte(WandAttackSpriteColor[1]);
	write_byte(WandAttackSpriteColor[2]);
	write_byte(get_pcvar_num(cvars_data[CVAR_WAND_ATTACK_SPRITE_BRIGHTNESS]));
	write_byte(0);
	message_end();

	// Animate explosion on hit.
	message_begin(0, 23);
	write_byte(3);
	write_coord(end_origin[0]);
	write_coord(end_origin[1]);
	write_coord(end_origin[2]);
	write_short(wand_sprites_indexes[WAND_SPRITE_EXPLODE_ON_HIT]);
	write_byte(10);	
	write_byte(15);
	write_byte(4);
	message_end();

	// Get index of player that index is aiming at.
	get_user_aiming(index, victim, bodyPart);

	// Block attacking if they are in the same team.
	if (user_data[index][DATA_TEAM] == user_data[victim][DATA_TEAM])
	{
		return PLUGIN_HANDLED;
	}

	// Set punchangle whenever player attacks.
	set_pev(index, pev_punchangle, Float:{ -1.5, 0.0, 0.0 });

	// Log last attack.
	user_data[index][DATA_WAND_LAST_ATTACK] = floatround(get_gametime());

	// Create temp. entity.
	new entity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));

	static Float:victimOrigin[3];

	// Get end point vector.
	IVecFVec(end_origin, victimOrigin);

	// Set temp. entity's origin.
	set_pev(entity, pev_origin, victimOrigin);

	// Remove temp. entity.
	engfunc(EngFunc_RemoveEntity, entity);

	if (!is_user_alive(victim))
	{
		return PLUGIN_HANDLED;
	}

	static Float:victimVelocity[3];
	pev(victim, pev_velocity, victimVelocity);

	// Slow down victim.
	victimVelocity[0] *= 0.7;
	victimVelocity[1] *= 0.7;
	victimVelocity[2] *= 0.7;

	// Set victim's velocity.
	set_pev(victim, pev_velocity, victimVelocity);

	new hit_damage,
		blood_scale,
		attacker_health = pev(victim, pev_health);

	// Calculate damage and blood scale.
	hit_damage = WandDamageEffects[bodyPart][0];
	blood_scale = WandDamageEffects[bodyPart][1];

	// Execute damage.
	ExecuteHamB(Ham_TakeDamage, victim, 0, index, float(hit_damage), (1<<1));

	if (attacker_health > hit_damage)
	{
		static Float:vicOrigin[3];
		pev(victim, pev_origin, vicOrigin);

		message_begin(0, 23);
		write_byte(115);
		write_coord(floatround(vicOrigin[0] + random_num(-20, 20)));
		write_coord(floatround(vicOrigin[1] + random_num(-20, 20)));
		write_coord(floatround(vicOrigin[2] + random_num(-20, 20)));
		//write_short(wand_sprites_indexes[WAND_SPRITE_BLOOD]);
		//write_short(wand_sprites_indexes[WAND_SPRITE_BLOOD]);
		write_byte(248);
		write_byte(blood_scale);
		message_end();

		message_begin(8, 71, _, victim);
		write_byte(0);
		write_byte(0);
		write_long(1 << 16);
		write_coord(0);
		write_coord(0);
		write_coord(0);
		message_end();

		message_begin(8, 98, _, victim);
		write_short(1 << 13);
		write_short(1 << 14);
		write_short(0x0000);
		write_byte(0);
		write_byte(255);
		write_byte(0);
		write_byte(100);
		message_end();

		message_begin(1, 97, _, victim);
		write_short(0xFFFF);
		write_short(1 << 13);
		write_short(0xFFFF);
		message_end();

		static Float:victimOrigin[3];
		pev(victim, pev_origin, victimOrigin);

		message_begin(0, 23);
		write_byte(15);
		engfunc(EngFunc_WriteCoord, victimOrigin[0]);
		engfunc(EngFunc_WriteCoord, victimOrigin[1]);
		engfunc(EngFunc_WriteCoord, victimOrigin[2] + 200.0);
		engfunc(EngFunc_WriteCoord, victimOrigin[0]);
		engfunc(EngFunc_WriteCoord, victimOrigin[1]);
		engfunc(EngFunc_WriteCoord, victimOrigin[2] + 20.0);
		write_short(wand_sprites_indexes[WAND_SPRITE_POST_HIT]);
		write_byte(15);
		write_byte(random_num(27, 30));
		write_byte(2);
		write_byte(random_num(30, 70));
		write_byte(40);
		message_end();
	}
	else if (attacker_health <= hit_damage)
	{
		static Float:victimOrigin[3];
		pev(victim, pev_origin, victimOrigin);

		message_begin(0, 23);
		write_byte(15);
		engfunc(EngFunc_WriteCoord, victimOrigin[0]);
		engfunc(EngFunc_WriteCoord, victimOrigin[1]);
		engfunc(EngFunc_WriteCoord, victimOrigin[2] + 200.0);
		engfunc(EngFunc_WriteCoord, victimOrigin[0]);
		engfunc(EngFunc_WriteCoord, victimOrigin[1]);
		engfunc(EngFunc_WriteCoord, victimOrigin[2] + 20.0);
		write_short(wand_sprites_indexes[WAND_SPRITE_POST_HIT]);
		write_byte(15);
		write_byte(random_num(27, 30));
		write_byte(2);
		write_byte(random_num(30, 70));
		write_byte(40);
		message_end();
	}

	return PLUGIN_CONTINUE;
}

get_random_player(team = -1, bool:alive = false, Array:excluded)
{
	static player;

	player = 0;
	
	if (!get_playersnum())
	{
		return player;
	}

	static bool:skip,
		Array:players_list;

	players_list = ArrayCreate(1, 1);

	ForPlayers(i)
	{
		if (!is_user_connected(i))
		{
			continue;
		}

		if (team && user_data[i][DATA_TEAM] != team)
		{
			continue;
		}

		if (alive && !is_user_alive(i))
		{
			continue;
		}

		skip = false;

		ForDynamicArray(j, excluded)
		{
			if (ArrayGetCell(excluded, j) == i)
			{
				skip = true;

				break;
			}
		}

		if (skip)
		{
			continue;
		}

		ArrayPushCell(players_list, i);
	}

	if (ArraySize(players_list))
	{
		player = ArrayGetCell(players_list, random_num(0, ArraySize(players_list) - 1));
	}
	else
	{
		player = 0;
	}

	ArrayDestroy(players_list);

	return player;
}

stock strip_user_weapon(index, weapon_csw, weapon_slot = 0, bool:switch_weapon = true)
{
	if (!weapon_slot)
	{
		static const WeaponSlots[] = { -1, 2, -1, 1, 4, 1, 5, 1, 1, 4, 2, 2, 1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 1, 1, 1, 4, 2, 1, 1, 3, 1 };
		
		weapon_slot = WeaponSlots[weapon_csw];
	}

	const PlayerOffset = 5;
	const SlotOffset = 367;
	const WeaponOffset = 4;
	const NextCbase = 42;
	const IndexCbase = 43;
	const ActiveItem = 373;

	new weapon = get_pdata_cbase(index, SlotOffset + weapon_slot, PlayerOffset);

	while (weapon)
	{
		// Break if we got the weapon right away.
		if (get_pdata_int(weapon, IndexCbase, WeaponOffset) == weapon_csw)
		{
			break;
		}

		// Assign new entity.
		weapon = get_pdata_cbase(weapon, NextCbase, WeaponOffset);
	}

	if (weapon)
	{
		if (switch_weapon && get_pdata_cbase(index, ActiveItem, PlayerOffset) == weapon)
		{
			ExecuteHamB(Ham_Weapon_RetireWeapon, weapon);
		}

		if (ExecuteHamB(Ham_RemovePlayerItem, index, weapon))
		{
			// Honestly dont know what is the point of this one.
			user_has_weapon(index, weapon_csw, 0);

			// Kill weapon entity.
			ExecuteHamB(Ham_Item_Kill, weapon);

			// Weapon removed successfully.
			return true;
		}
	}

	// Weapon not found.
	return false;
}

stock register_commands(const array[][], array_size, function[], include_say = true)
{
	#if !defined ForRange

		#define ForRange(%1,%2,%3) for(new %1 = %2; %1 <= %3; %1++)

	#endif

	#if AMXX_VERSION_NUM > 183
	
	ForRange(i, 0, array_size - 1)
	{
		ForRange(j, 0, 1)
		{
			if (include_say)
			{
				register_clcmd(fmt("%s %s", !j ? "say" : "say_team", array[i]), function);
			}
			else
			{
				register_clcmd(array[i], function);
			}
		}
	}

	#else

	new new_command[33];

	ForRange(i, 0, array_size - 1)
	{
		ForRange(j, 0, 1)
		{
			if (include_say)
			{
				formatex(new_command, charsmax(new_command), "%s %s", !j ? "say" : "say_team", array[i]);
				register_clcmd(new_command, function);
			}
			else
			{
				register_clcmd(array[i], function);
			}
		}
	}

	#endif
}

public block_command_usage(index)
{
	// Allow droping the bomb.
	if (get_pcvar_num(cvars_data[CVAR_ALLOW_BOMB_DROP]) && user_data[index][DATA_CURRENT_WEAPON] == CSW_C4)
	{
		return PLUGIN_CONTINUE;
	}

	return PLUGIN_HANDLED;
}

public set_black_screen_on()
{
	set_black_screen_fade(1);
}

set_black_screen_fade(fade)
{
	new time,
		hold,
		flags;

	static message_screen_fade;

	if (!message_screen_fade)
	{
		message_screen_fade = get_user_msgid("ScreenFade");
	}
	
	switch (fade)
	{
		case 1:
		{
			time = 1;
			hold = 1;
			flags = 4;
		}

		case 2:
		{
			time = 4096;
			hold = 1024;
			flags = 1;
		}
		
		default:
		{
			time = 4096;
			hold = 1024;
			flags = 2;
		}
	}

	message_begin(MSG_BROADCAST, message_screen_fade);
	write_short(time);
	write_short(hold);
	write_short(flags);
	write_byte(0);
	write_byte(0);
	write_byte(0);
	write_byte(255);
	message_end();
}

stock remove_player_weapons(index, bool:drop_bomb = false)
{
	new bool:has_bomb = bool:user_has_weapon(index, CSW_C4);

	if (drop_bomb && has_bomb)
	{
		static const WeaponClassname[] = "weapon_c4";

		// Make player drop the bomb.
		engclient_cmd(index, "drop", WeaponClassname);

		// Transfer dropped bomb to someone else?
		if (get_pcvar_num(cvars_data[CVAR_TRANSFER_DROPPED_BOMB]) == 1)
		{
			static Array:excluded_indexes,
				receiver;

			excluded_indexes = ArrayCreate(1, 1);

			// Add our guy to skipped indexes so we dont target him as a bomb receiver.
			ArrayPushCell(excluded_indexes, index);
			
			// Get random alive terrorist.
			receiver = get_random_player(user_data[index][DATA_TEAM], true, excluded_indexes);
			
			// Don't leak memory, please.
			ArrayDestroy(excluded_indexes);

			// Bomb receiver connected?
			if (is_user_connected(receiver))
			{
				static bomb_entity;
				
				bomb_entity = get_bomb_entity();

				if (bomb_entity)
				{
					// Remove on-ground flag from bomb's pevs.
					set_pev(bomb_entity, pev_flags, pev(bomb_entity, pev_flags) | FL_ONGROUND);
					
					// Simulate touching the bom by the bomb receiver.
					dllfunc(DLLFunc_Touch, bomb_entity, receiver);
				}
			}
		}
	}
	
	// Kill entities.
	static entity;

	// Create an entity 'player_weaponstrip' which works in a way that
	// if a player uses it, his weapons are removed entirely.
	entity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "player_weaponstrip"));

	// Invalid entity.
	if (!pev_valid(entity))
	{
		return;
	}
	
	dllfunc(DLLFunc_Spawn, entity); // Spawn the remove-weapons entity.
	dllfunc(DLLFunc_Use, entity, index); // Force player to use it.
	engfunc(EngFunc_RemoveEntity, entity); // Kill it right away.
}

#if defined TEST_MODE

public setMaxLevel(index)
{
	if (game_mode == MODE_NORMAL)
	{
		user_data[index][DATA_LEVEL] = sizeof(WeaponsData) - 3;
		
		increment_user_level(index, 1);
	}
	else
	{

		tp_data[TP_TEAM_LEVEL][user_data[index][DATA_TEAM] - 1] = sizeof(WeaponsData) - 3;

		increment_team_level(user_data[index][DATA_TEAM], 1);
	}
}

public addLevel(index)
{
	if (game_mode == MODE_NORMAL)
	{
		increment_user_level(index, 1);
	}
	else
	{
		increment_team_level(user_data[index][DATA_TEAM], 1);
	}
}

public setAWPLevel(index)
{
	if (game_mode == MODE_NORMAL)
	{
		user_data[index][DATA_LEVEL] = 19;
		increment_user_level(index, 1);
	}
	else
	{
		tp_data[TP_TEAM_LEVEL][user_data[index][DATA_TEAM] - 1] = 19;
		increment_team_level(user_data[index][DATA_TEAM], 1);
	}
}

public godmodOff(index)
{
	set_user_godmode(index, 0);
}

public addKills(index)
{
	increment_user_weapon_kills(index, 1);
}

public addFrag(index)
{
	set_user_frags(index, get_user_frags(index) + 2);
}

public testWinMessage(index)
{
	end_gungame(index);
}

public warmupFunction(index)
{
	toggle_warmup(!warmup_data[WARMUP_ENABLED]);

	client_print(0, print_chat, "Warmup = %s", warmup_data[WARMUP_ENABLED] ? "ON" : "OFF");
}

public addKnifeKill(index)
{
	user_data[index][DATA_KNIFE_KILLS]++;
	client_print(0, print_chat, "%i", user_data[index][DATA_KNIFE_KILLS]);
}

public addHeadshot(index)
{
	user_data[index][DATA_HEADSHOTS]++;
	client_print(0, print_chat, "%i", user_data[index][DATA_HEADSHOTS]);
}

public addKill(index)
{
	user_data[index][DATA_KILLS]++;
	client_print(0, print_chat, "%i", user_data[index][DATA_KILLS]);
}

public addWin(index)
{
	user_data[index][DATA_WINS]++;
	client_print(0, print_chat, "%i", user_data[index][DATA_WINS]);
}

public addWeapon(index)
{
	user_data[index][DATA_LEVEL] = 19;
	increment_user_level(index, 1);
}

public sound_TakeLead(index)
{
	play_sound(index, SOUND_TAKEN_LEAD, -1);
}

public sound_LoseLead(index)
{
	play_sound(index, SOUND_LOST_LEAD, -1);
}

public addBomb(index)
{
	give_item(index, "weapon_c4");
}

#endif

/*
		[ Game mode ]
*/

public show_game_vote_menu(index)
{
	if (!game_vote_enabled || !is_user_connected(index))
	{
		return PLUGIN_HANDLED;
	}

	new menu_index = menu_create("Wybierz tryb gry:", "show_game_vote_menu_handler");

	// Add game mode names to the menu.
	ForArray(i, GameModes)
	{
		menu_additem(menu_index, GameModes[i]);
	}

	// Disable exit option.
	menu_setprop(menu_index, MPROP_EXIT, MEXIT_NEVER);

	menu_display(index, menu_index);
	
	return PLUGIN_HANDLED;
}

public show_game_vote_menu_handler(index, menu_index, item)
{
	menu_destroy(menu_index);
	
	// Block player's vote if voting is not enabled.
	if (item == MENU_EXIT || !game_vote_enabled)
	{
		return PLUGIN_HANDLED;
	}

	// Add vote.
	game_votes[item]++;

	ColorChat(index, RED, "%s^x01 Wybrales tryb:^x04 %s^x01.", ChatPrefix, GameModes[item]);

	return PLUGIN_HANDLED;
}

set_game_vote()
{
	// Set votes to zero.
	ForArray(i, GameModes)
	{
		game_votes[i] = 0;
	}

	game_vote_enabled = true;

	// Show game mode vote menu to all players.
	ForPlayers(i)
	{
		if (!is_user_connected(i))
		{
			continue;
		}

		show_game_vote_menu(i);
	}
}

public finish_game_vote()
{
	game_vote_enabled = false;
	game_mode = 0;

	new bool:tie,
		sum_of_votes = game_votes[0] + game_votes[1];

	// Handle game mode votes.
	if (game_votes[0] == game_votes[1])
	{
		tie = true;
	}
	else
	{
		if (game_votes[0] > game_votes[1])
		{
			game_mode = 0;
		}
		else
		{
			game_mode = 1;
		}
	}

	// If there is no definitive winner, get one randomly.
	if (tie || !sum_of_votes)
	{
		game_mode = random_num(0, sizeof(GameModes) - 1);

		tp_data[TP_ENABLED] = bool:(game_mode == MODE_TEAMPLAY);
	}

	if (get_playersnum())
	{
		new message[191];

		ForPlayers(i)
		{
			if (!is_user_connected(i))
			{
				continue;
			}
			
			formatex(message, charsmax(message), "%s^x01 %sygral tryb:^x04 %s.", ChatPrefix, tie ? "Droga losowania w" : "W", GameModes[game_mode]);

			if (sum_of_votes)
			{
				format(message, charsmax(message), "%s ^x01Zdobyl^x04 %i procent^x01 glosow.", message, floatround(float(game_votes[game_mode]) / float(sum_of_votes) * 100.0));
			}

			ColorChat(i, RED, message);
		}
	}

	ExecuteForward(forward_handles[FORWARD_GAME_MODE_CHOSEN], blank, game_mode);
}