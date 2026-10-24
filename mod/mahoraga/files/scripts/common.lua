dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/mahoraga/files/generated/boss_data.lua")
dofile_once("mods/mahoraga/files/generated/attack_data.lua")
dofile_once("mods/mahoraga/files/generated/projectile_data.lua")
dofile_once("mods/mahoraga/files/generated/adaptation_data.lua")
dofile_once("mods/mahoraga/files/generated/world_data.lua")

-- Per-entity values kept in VariableStorageComponents so they survive save/load.
function mh_get( entity_id, name, default )
	local comps = EntityGetComponentIncludingDisabled( entity_id, "VariableStorageComponent" ) or {}
	for _, c in ipairs( comps ) do
		if ComponentGetValue2( c, "name" ) == name then
			return ComponentGetValue2( c, "value_float" )
		end
	end
	return default
end

function mh_set( entity_id, name, value )
	local comps = EntityGetComponentIncludingDisabled( entity_id, "VariableStorageComponent" ) or {}
	for _, c in ipairs( comps ) do
		if ComponentGetValue2( c, "name" ) == name then
			ComponentSetValue2( c, "value_float", value )
			return
		end
	end
	EntityAddComponent2( entity_id, "VariableStorageComponent", { name = name, value_float = value } )
end

-- Which adaptation row a hit belongs to: from Noita's damage message first,
-- then from the strongest damage type of the projectile that caused it.
local translated = nil
function mh_damage_type( message, projectile_id )
	if message ~= nil and message ~= "" then
		for _, t in ipairs( MAHORAGA_ADAPT_ORDER ) do
			if message == MAHORAGA_ADAPT[t].message_key then return t end
		end
		if translated == nil then
			translated = {}
			for _, t in ipairs( MAHORAGA_ADAPT_ORDER ) do
				translated[ GameTextGetTranslatedOrNot( MAHORAGA_ADAPT[t].message_key ) ] = t
			end
		end
		if translated[ message ] then return translated[ message ] end
	end
	if projectile_id ~= nil and projectile_id ~= 0 and EntityGetIsAlive( projectile_id ) then
		local pc = EntityGetFirstComponentIncludingDisabled( projectile_id, "ProjectileComponent" )
		if pc ~= nil then
			local best, best_v = nil, 0
			local base = ComponentGetValue2( pc, "damage" ) or 0
			if base > best_v then best, best_v = "projectile", base end
			for _, t in ipairs( MAHORAGA_ADAPT_ORDER ) do
				local f = MAHORAGA_ADAPT[t].field
				if f ~= "projectile" then
					local v = ComponentObjectGetValue2( pc, "damage_by_type", f ) or 0
					if v > best_v then best, best_v = t, v end
				end
			end
			return best
		end
	end
	return nil
end

-- How hard Mahoraga hits: every damage value in the sheets x damage_scale, doubled (adapt_damage_mult) per adaptation.
function mh_power( boss )
	local B = MAHORAGA_BOSS.mahoraga
	return B.damage_scale * B.adapt_damage_mult ^ mh_get( boss, "adapt_count", 0 )
end

function mh_is_summon( e ) return mh_get( e, "summon", 0 ) == 1 end

-- The wheel turns: immune to type t from now on, fully healed, max HP and all damage doubled.
-- how: "boss" (his fight messages), "summon" (your Mahoraga, announced) or "quiet".
function mh_apply_adaptation( me, t, how )
	local row = MAHORAGA_ADAPT[ t ]
	local B = MAHORAGA_BOSS.mahoraga
	local dmc = EntityGetFirstComponent( me, "DamageModelComponent" )
	if dmc == nil or mh_get( me, "adapted_" .. t, 0 ) == 1 then return end
	local count = mh_get( me, "adapt_count", 0 ) + 1
	mh_set( me, "adapted_" .. t, 1 )
	mh_set( me, "adapt_count", count )
	mh_set( me, "wheel_spin", GameGetFrameNum() )
	GamePlayAnimation( me, "adapt", 20, "stand", 0 )   -- glows for as long as the wheel turns (~36 frames)
	if t == "drowning" then
		ComponentSetValue2( dmc, "air_needed", false )
	else
		ComponentObjectSetValue2( dmc, "damage_multipliers", row.field, row.boss_result_mult )
	end
	mh_adaptation_bonus( me, t )
	local new_max = ComponentGetValue2( dmc, "max_hp" ) * B.adapt_hp_mult
	ComponentSetValue2( dmc, "max_hp", new_max )
	ComponentSetValue2( dmc, "hp", new_max )
	local ai = EntityGetFirstComponentIncludingDisabled( me, "AnimalAIComponent" )
	if ai ~= nil then
		ComponentSetValue2( ai, "attack_melee_damage_min", B.contact_damage * mh_power( me ) )
		ComponentSetValue2( ai, "attack_melee_damage_max", B.contact_damage * mh_power( me ) )
	end
	if how == "quiet" then return end

	local x, y = EntityGetTransform( me )
	GamePlaySound( "data/audio/Desktop/animals.bank", "animals/statue/appear", x, y )
	EntityLoad( "data/entities/particles/heal_effect.xml", x, y - 20 )
	local mult = math.floor( B.adapt_damage_mult ^ count + 0.5 )
	local who = ( how == "summon" ) and "Your Mahoraga" or "Mahoraga"
	GamePrint( who .. "'s wheel turns: adapted to " .. row.display_name .. "! Fully healed, health and damage doubled (x" .. mult .. ")." )
	for _, id in ipairs( MAHORAGA_ATTACKS_ORDER ) do
		local a = MAHORAGA_ATTACKS[ id ]
		if a.unlock == t then
			GamePrintImportant( who .. " learns " .. a.name, "Adapted to " .. row.display_name .. ", the wheel grants a new technique." )
		end
	end
end

-- Your Mahoraga takes every adaptation the player has (Adapt to Anything: each kind of harm with at least
-- one step), with the same doubling and the techniques they unlock. Returns how many it gained.
function mh_summon_sync( summon, player, how )
	local gained = 0
	for _, t in ipairs( MAHORAGA_ADAPT_ORDER ) do
		if mh_get( player, "padapt_steps_" .. t, 0 ) >= 1 and mh_get( summon, "adapted_" .. t, 0 ) == 0 then
			mh_apply_adaptation( summon, t, how )
			gained = gained + 1
		end
	end
	return gained
end

-- Nearest living enemy your Mahoraga can reach.
function mh_summon_target( me, x, y, range )
	local best, best_d = nil, range * range
	for _, e in ipairs( EntityGetInRadiusWithTag( x, y, range, "enemy" ) or {} ) do
		if e ~= me and EntityGetIsAlive( e ) and not mh_is_ally( e, mh_player() ) then
			local ex, ey = EntityGetTransform( e )
			local d = ( ex - x ) ^ 2 + ( ey - y ) ^ 2
			if d < best_d then best, best_d = e, d end
		end
	end
	return best
end

-- Scale every kind of damage a freshly shot projectile deals.
function mh_scale_projectile( pid, mult )
	if mult == 1 or pid == nil or pid == 0 then return end
	local pc = EntityGetFirstComponentIncludingDisabled( pid, "ProjectileComponent" )
	if pc == nil then return end
	ComponentSetValue2( pc, "damage", ( ComponentGetValue2( pc, "damage" ) or 0 ) * mult )
	for _, t in ipairs( MAHORAGA_ADAPT_ORDER ) do
		local f = MAHORAGA_ADAPT[t].field
		if f ~= "projectile" and f ~= "drowning" then
			local v = ComponentObjectGetValue2( pc, "damage_by_type", f ) or 0
			if v > 0 then ComponentObjectSetValue2( pc, "damage_by_type", f, v * mult ) end
		end
	end
	local e = ComponentObjectGetValue2( pc, "config_explosion", "damage" ) or 0
	if e > 0 then ComponentObjectSetValue2( pc, "config_explosion", "damage", e * mult ) end
end

function mh_world_width()
	local w, h = BiomeMapGetSize()
	return w * 512
end

-- Index of the parallel world containing x (0 = main world, 1 = east, -1 = west ...).
function mh_world_index( x )
	local W = mh_world_width()
	return math.floor( ( x + W * 0.5 ) / W )
end

-- Arena rectangle for world index n.
function mh_arena_rect( n )
	local W = mh_world_width()
	local left = n * W + W * 0.5 + MAHORAGA_WORLD.arena_offset_x
	local top = MAHORAGA_WORLD.arena_top_y
	return left, top, left + 352, top + 208
end

function mh_player()
	local p = EntityGetWithTag( "player_unit" )
	if p ~= nil and #p > 0 then return p[1] end
	return nil
end


-- Summon key, chosen in Options > Mod settings (settings.lua); default G.
MAHORAGA_KEY_NAMES = {
	[4]="A",[5]="B",[6]="C",[7]="D",[8]="E",[9]="F",[10]="G",[11]="H",[12]="I",[13]="J",[14]="K",[15]="L",[16]="M",
	[17]="N",[18]="O",[19]="P",[20]="Q",[21]="R",[22]="S",[23]="T",[24]="U",[25]="V",[26]="W",[27]="X",[28]="Y",[29]="Z",
	[30]="1",[31]="2",[32]="3",[33]="4",[34]="5",[35]="6",[36]="7",[37]="8",[38]="9",[39]="0",
	[58]="F1",[59]="F2",[60]="F3",[61]="F4",[62]="F5",[63]="F6",[64]="F7",[65]="F8",[66]="F9",[67]="F10",[68]="F11",[69]="F12",
}
function mahoraga_summon_key()
	local v = tonumber( ModSettingGet( "mahoraga.summon_key" ) )
	if v == nil then return 10 end
	return math.floor( v )
end
function mahoraga_summon_key_name()
	local k = mahoraga_summon_key()
	return MAHORAGA_KEY_NAMES[ k ] or ( "key " .. tostring( k ) )
end

-- What some adaptations give Mahoraga besides immunity (boss and summon alike).
function mh_adaptation_bonus( me, t )
	if t == "projectile" then
		-- two energy shields, like Skoude's
		local x, y = EntityGetTransform( me )
		for _, n in ipairs( { "outer", "inner" } ) do
			EntityAddChild( me, EntityLoad( "mods/mahoraga/files/entities/mahoraga_shield_" .. n .. ".xml", x, y - 20 ) )
		end
	elseif t == "drowning" then
		-- at home in water: no drag, no currents pushing him (boss_ai.lua also swims him at his target)
		local cpc = EntityGetFirstComponent( me, "CharacterPlatformingComponent" )
		if cpc ~= nil then
			ComponentSetValue2( cpc, "swim_drag", 1 )
			ComponentSetValue2( cpc, "swim_extra_horizontal_drag", 1 )
			ComponentSetValue2( cpc, "swim_idle_buoyancy_coeff", 1 )
			ComponentSetValue2( cpc, "swim_up_buoyancy_coeff", 1.2 )
			ComponentSetValue2( cpc, "swim_down_buoyancy_coeff", 1 )
		end
		local cdc = EntityGetFirstComponent( me, "CharacterDataComponent" )
		if cdc ~= nil then ComponentSetValue2( cdc, "liquid_velocity_coeff", 0 ) end
	end
end

-- Divine Dogs perk ---------------------------------------------------------------------------------
dofile_once("mods/mahoraga/files/generated/dog_data.lua")

function mahoraga_dog_key()
	local v = tonumber( ModSettingGet( "mahoraga.dog_key" ) )
	if v == nil then return 11 end
	return math.floor( v )
end
function mahoraga_dog_key_name()
	local k = mahoraga_dog_key()
	return MAHORAGA_KEY_NAMES[ k ] or ( "key " .. tostring( k ) )
end

function mh_dogs()
	local out = {}
	for _, e in ipairs( EntityGetWithTag( "mahoraga_dog" ) or {} ) do
		if EntityGetIsAlive( e ) and mh_get( e, "dismissed", 0 ) == 0 then table.insert( out, e ) end
	end
	return out
end

-- Phase 1: the white dog. Phase 2: white and black, both stronger. Phase 3: Totality, the two merged.
function mahoraga_spawn_dogs( player )
	local px, py = EntityGetTransform( player )
	local phase = mh_get( player, "dog_phase", 1 )
	local kinds = { "white" }
	if phase == 2 then kinds = { "white", "black" } elseif phase >= 3 then kinds = { "totality" } end
	local mult = ( phase == 2 ) and MAHORAGA_WORLD.dog_phase2_mult or 1
	for i, k in ipairs( kinds ) do
		local x = px + ( ( i == 1 ) and 20 or -20 )
		local e = EntityLoad( "mods/mahoraga/files/entities/dog_" .. k .. ".xml", x, py )
		mh_make_ally( e )
		mh_set( e, "bite_mult", mult )
		local dmc = EntityGetFirstComponent( e, "DamageModelComponent" )
		if dmc ~= nil and mult ~= 1 then
			ComponentSetValue2( dmc, "max_hp", ComponentGetValue2( dmc, "max_hp" ) * mult )
			ComponentSetValue2( dmc, "hp", ComponentGetValue2( dmc, "hp" ) * mult )
		end
		EntityLoad( "data/entities/particles/poof_white_appear.xml", x, py - 10 )
	end
end

function mahoraga_dismiss_dogs()
	for _, e in ipairs( mh_dogs() ) do
		local x, y = EntityGetTransform( e )
		mh_set( e, "dismissed", 1 )   -- dog_death.lua: sent away, not killed
		EntityLoad( "data/entities/particles/poof_white_appear.xml", x, y - 10 )
		EntityKill( e )
	end
end

-- A dog's bite finished someone: 50 kills (or one boss) grow the dogs to their next phase.
function mahoraga_dog_kill( player, was_boss )
	local phase = mh_get( player, "dog_phase", 1 )
	if phase >= 3 then return end
	local kills = mh_get( player, "dog_kills", 0 ) + 1
	mh_set( player, "dog_kills", kills )
	if not was_boss and kills < MAHORAGA_WORLD.dog_kills_per_phase then return end
	mh_set( player, "dog_phase", phase + 1 )
	mh_set( player, "dog_kills", 0 )
	if #mh_dogs() > 0 then
		mahoraga_dismiss_dogs()
		mahoraga_spawn_dogs( player )
	end
	local x, y = EntityGetTransform( player )
	GamePlaySound( "data/audio/Desktop/event_cues.bank", "event_cues/orb_distant_monster/create", x, y )
	if phase + 1 == 2 then
		GamePrintImportant( "The Black Divine Dog joins", "Both Divine Dogs now fight for you, stronger than before." )
	else
		GamePrintImportant( "Divine Dog: Totality", "The two dogs merge into one great beast." )
	end
end

-- The player's allies (summoned Mahoraga, Divine Dogs) are built on data/entities/base_enemy_basic.xml, which tags
-- them "enemy": take it off, or they bite themselves, bite each other and draw every "enemy" seeker.
function mh_make_ally( e )
	if EntityHasTag( e, "enemy" ) then EntityRemoveTag( e, "enemy" ) end
	local ai = EntityGetFirstComponentIncludingDisabled( e, "AnimalAIComponent" )
	if ai ~= nil then ComponentSetValue2( ai, "dont_counter_attack_own_herd", true ) end
end

-- Who the summoned Mahoraga must never hurt: the player, other summons and the Divine Dogs.
function mh_is_ally( e, player )
	return e == player or EntityHasTag( e, "player_unit" ) or EntityHasTag( e, "mahoraga_summon" ) or EntityHasTag( e, "mahoraga_dog" )
end
