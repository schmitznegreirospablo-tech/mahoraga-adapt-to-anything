dofile_once("mods/mahoraga/files/scripts/common.lua")

-- Adapt to Anything: each kind of harm the player keeps suffering hurts less, in steps.
function damage_received( damage, message, entity_thats_responsible, is_fatal, projectile_thats_responsible )
	if damage <= 0 then return end
	local me = GetUpdatedEntityID()
	local t = mh_damage_type( message, projectile_thats_responsible )
	if t == nil then return end
	local row = MAHORAGA_ADAPT[ t ]
	local steps = mh_get( me, "padapt_steps_" .. t, 0 )
	if steps >= row.player_max_steps then return end
	-- rapid ticks (burning, drowning) count as one hit per player_hit_cooldown_frames
	local now = GameGetFrameNum()
	if row.player_hit_cooldown_frames > 0 then
		if now - mh_get( me, "padapt_last_" .. t, -100000 ) < row.player_hit_cooldown_frames then return end
		mh_set( me, "padapt_last_" .. t, now )
	end
	local hits = mh_get( me, "padapt_hits_" .. t, 0 ) + 1
	if hits < row.player_hits_per_step then
		mh_set( me, "padapt_hits_" .. t, hits )
		return
	end
	mh_set( me, "padapt_hits_" .. t, 0 )
	mh_set( me, "padapt_steps_" .. t, steps + 1 )
	local dmc = EntityGetFirstComponent( me, "DamageModelComponent" )
	if dmc ~= nil then
		if t == "drowning" then
			-- less harm when out of air, and the lungs hold more of it
			ComponentSetValue2( dmc, "air_lack_of_damage", ComponentGetValue2( dmc, "air_lack_of_damage" ) * row.player_step_mult )
			local lungs = ComponentGetValue2( dmc, "air_in_lungs_max" ) / row.player_step_mult
			ComponentSetValue2( dmc, "air_in_lungs_max", lungs )
			ComponentSetValue2( dmc, "air_in_lungs", lungs )
		else
			local cur = ComponentObjectGetValue2( dmc, "damage_multipliers", row.field ) or 1
			ComponentObjectSetValue2( dmc, "damage_multipliers", row.field, cur * row.player_step_mult )
		end
	end
	-- spin the player's wheel (player_wheel.lua reads this)
	for _, child in ipairs( EntityGetAllChildren( me ) or {} ) do
		if EntityGetName( child ) == "mahoraga_player_wheel" then mh_set( child, "wheel_spin", now ) end
	end
	local x, y = EntityGetTransform( me )
	GamePlaySound( "data/audio/Desktop/animals.bank", "animals/statue/appear", x, y )
	local pct = math.floor( 100 * ( 1 - row.player_step_mult ^ ( steps + 1 ) ) + 0.5 )
	GamePrint( "The wheel turns: you have adapted to " .. row.display_name .. " (" .. pct .. "% less harm)" )
end
