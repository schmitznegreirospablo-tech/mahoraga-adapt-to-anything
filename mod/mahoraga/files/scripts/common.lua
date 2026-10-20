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

-- How much harder Mahoraga hits: every adaptation adds adapt_damage_bonus.
function mh_power( boss )
	return 1 + mh_get( boss, "adapt_count", 0 ) * MAHORAGA_BOSS.mahoraga.adapt_damage_bonus
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

