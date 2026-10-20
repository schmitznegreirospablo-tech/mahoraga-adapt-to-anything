dofile_once("mods/mahoraga/files/scripts/common.lua")

-- Mahoraga's adaptation: enough harm of one kind turns the wheel and he stops taking it.
-- Each turn of the wheel also heals him fully, raises his max HP and makes his attacks hit harder,
-- and some adaptations teach him a new technique (attacks sheet, unlock column).
function damage_received( damage, message, entity_thats_responsible, is_fatal, projectile_thats_responsible )
	local me = GetUpdatedEntityID()
	if damage <= 0 or is_fatal then return end
	if entity_thats_responsible == me and message ~= "$damage_drowning" then return end
	local t = mh_damage_type( message, projectile_thats_responsible )
	if t == nil then
		print( "[mahoraga] unknown damage message: " .. tostring( message ) )
		return
	end
	if mh_get( me, "adapted_" .. t, 0 ) == 1 then return end

	local row = MAHORAGA_ADAPT[ t ]
	local B = MAHORAGA_BOSS.mahoraga
	local dmc = EntityGetFirstComponent( me, "DamageModelComponent" )
	local max_hp = ComponentGetValue2( dmc, "max_hp" )
	local count = mh_get( me, "adapt_count", 0 )
	-- fire burns in rapid ticks, so each tick counts for less (boss_progress_mult)
	local progress = mh_get( me, "progress_" .. t, 0 ) + damage / max_hp * row.boss_progress_mult
	local need = row.boss_threshold_frac * ( row.boss_threshold_growth ^ count )
	mh_set( me, "progress_" .. t, progress )
	if progress < need then return end

	-- the wheel turns
	mh_set( me, "adapted_" .. t, 1 )
	mh_set( me, "adapt_count", count + 1 )
	mh_set( me, "wheel_spin", GameGetFrameNum() )
	if t == "drowning" then
		ComponentSetValue2( dmc, "air_needed", false )
	else
		ComponentObjectSetValue2( dmc, "damage_multipliers", row.field, row.boss_result_mult )
	end

	-- fully healed, tougher, and hitting harder
	local new_max = max_hp * ( 1 + B.adapt_max_hp_bonus )
	ComponentSetValue2( dmc, "max_hp", new_max )
	ComponentSetValue2( dmc, "hp", new_max )
	local ai = EntityGetFirstComponentIncludingDisabled( me, "AnimalAIComponent" )
	if ai ~= nil then
		local m = 1 + ( count + 1 ) * B.adapt_damage_bonus
		ComponentSetValue2( ai, "attack_melee_damage_min", B.contact_damage * m )
		ComponentSetValue2( ai, "attack_melee_damage_max", B.contact_damage * m )
	end

	local x, y = EntityGetTransform( me )
	GamePlaySound( "data/audio/Desktop/animals.bank", "animals/statue/appear", x, y )
	EntityLoad( "data/entities/particles/heal_effect.xml", x, y - 20 )
	local pct = math.floor( ( count + 1 ) * B.adapt_damage_bonus * 100 + 0.5 )
	GamePrint( "Mahoraga's wheel turns: he has adapted to " .. row.display_name .. "! Fully healed, stronger (+" .. pct .. "% damage)." )

	for _, id in ipairs( MAHORAGA_ATTACKS_ORDER ) do
		local a = MAHORAGA_ATTACKS[ id ]
		if a.unlock == t then
			GamePrintImportant( "Mahoraga learns " .. a.name, "Adapted to " .. row.display_name .. ", the wheel grants a new technique." )
		end
	end
end
