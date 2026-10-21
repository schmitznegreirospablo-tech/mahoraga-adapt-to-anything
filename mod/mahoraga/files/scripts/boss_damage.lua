dofile_once("mods/mahoraga/files/scripts/common.lua")

-- Mahoraga's adaptation: enough harm of one kind turns the wheel and he stops taking it.
-- Each turn of the wheel heals him fully, doubles his max HP and all his damage,
-- and some adaptations teach him a new technique (attacks sheet, unlock column).
-- Your summoned Mahoraga adapts the same way.
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
	local dmc = EntityGetFirstComponent( me, "DamageModelComponent" )
	local max_hp = ComponentGetValue2( dmc, "max_hp" )
	local count = mh_get( me, "adapt_count", 0 )
	-- fire burns in rapid ticks, so each tick counts for less (boss_progress_mult)
	local progress = mh_get( me, "progress_" .. t, 0 ) + damage / max_hp * row.boss_progress_mult
	local need = row.boss_threshold_frac * ( row.boss_threshold_growth ^ count )
	mh_set( me, "progress_" .. t, progress )
	if progress < need then return end

	mh_apply_adaptation( me, t, mh_is_summon( me ) and "summon" or "boss" )
end
